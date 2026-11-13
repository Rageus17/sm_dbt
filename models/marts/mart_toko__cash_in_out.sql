-- {{ config(materialized='table') }}

with
    -- excluded_customers() = inter-store transfers & owner's own projects (cm->sk/skc,
    -- cm->toko, proyek). These are recorded through the normal POS sale flow at harga
    -- jual (selling price) instead of harga modal (cost), because there's no dedicated
    -- transfer feature. The cash collected against them is real (bank transfer), but the
    -- markup baked into the invoice is not genuine external profit/cash-generating
    -- activity — it's the same rupiah moving between the owner's own pockets at an
    -- inflated price. price_adj scales each transaction's payments down to cost basis
    -- for these accounts only; regular external sales are untouched (ratio = 1).
    transaksi_scope as (
        select transaksi_id, customer_id, created_at
        from {{ref('stg_toko__transaksi')}}
        where is_cancelled = false
    ),

    price_adj as (
        select
            transaksi_id,
            sum(item_qty * harga_satuan) as billed_amount,
            sum(item_qty * coalesce(modal_barang, CAST(harga_satuan, 'Float64'))) as cost_amount
        from {{ref('int_toko__transaksi')}}
        group by transaksi_id
    ),

    transaction_payment as (
        select
            tp.transaksi_id,
            tp.payment_method,
            tp.payment_date,
            ts.customer_id in ({{ excluded_customers() }}) as is_internal,
            case
                when ts.customer_id in ({{ excluded_customers() }}) and coalesce(pa.billed_amount, 0) > 0
                    then CAST(tp.amount, 'Float64') * (pa.cost_amount / pa.billed_amount)
                else CAST(tp.amount, 'Float64')
            end as amount
        from {{ref('stg_toko__transaction_payments')}} tp
        inner join transaksi_scope ts on tp.transaksi_id = ts.transaksi_id
        left join price_adj pa on tp.transaksi_id = pa.transaksi_id
    ),
    opex as (select * from {{ref('stg_toko__operational_expenses')}}),

    -- fitur PO baru mulai dipakai 2026-03-09; sebelum itu barang masuk cuma
    -- tercatat di inventory_history tanpa po_number
    receive_flow as (
        select *
        from {{ref('mart_toko__po_order_receive_flow')}}
        where
            received_at >= '2026-03-09'
            and supplier_id not in ({{ excluded_suppliers() }})
    ),

    supplier_payment as (
        select *
        from {{ref('stg_toko__supplier_payments')}}
        where supplier_id not in ({{ excluded_suppliers() }})
    ),

    pembelian_pra_po as (
        select
            changed_at,
            harga,
            metode_bayar,
            supplier_id
        from {{ref('stg_toko__inventory_history')}}
        where
            change_type = 'MASUK'
            and metode_bayar not in ('ADJUSTMENT', 'RETURN', 'INTERNAL', 'CANCEL')
            and supplier_id not in ({{ excluded_suppliers() }})
            and changed_at < '2026-03-09'
    ),

    daily_tp as (
        select 
            toDate(payment_date) as day_id,
            sum(case when payment_method != 'UTANG' then amount end) as paid_amount,
            sum(case when payment_method != 'UTANG' and is_internal then amount end) as paid_amount_internal
        from   
            transaction_payment
        group by 1
    ),

    -- barang yang dikirim ke excluded_customers() (nilai modal) per hari; dibanding
    -- paid_amount_internal kumulatif = saldo piutang antar-toko/proyek owner
    daily_internal_billed as (
        select
            toDate(ts.created_at) as day_id,
            sum(pa.cost_amount) as internal_billed_cost
        from transaksi_scope ts
        inner join price_adj pa on ts.transaksi_id = pa.transaksi_id
        where ts.customer_id in ({{ excluded_customers() }})
        group by 1
    ),

    daily_opex as (
        select 
            toDate(created_at) as day_id,
            sum(jumlah) as expense_amount
        from 
            opex
        group by 1
    ),

    po_daily_pra_po as (
        -- TUNAI/TRANSFER dibayar langsung; HUTANG/UTANG diasumsikan dibayar 2 bulan
        -- kemudian, konsisten dengan asumsi yang dipakai untuk PO di bawah
        select
            case
                when metode_bayar in ('TUNAI', 'TRANSFER') then toDate(changed_at)
                else toDate(changed_at) + interval 2 month
            end as day_id,
            CAST(sum(harga), 'Float64') as total_po
        from
            pembelian_pra_po
        group by 1
    ),

    -- cash out PO, urutan truth:
    --   1. pembayaran aktual di supplier_payments (tanggal bayar)
    --   2. sisa tagihan tanda terima yang belum dibayar -> kembali_tanggal
    --   3. barang diterima yang belum masuk tanda terima -> received_at + 2 bulan
    po_paid as (
        select
            toDate(payment_date) as day_id,
            CAST(sum(payment_amount), 'Float64') as total_po
        from
            supplier_payment
        group by 1
    ),

    tt_paid as (
        select
            tanda_terima_id,
            sum(payment_amount + discount_amount) as settled_amount
        from
            supplier_payment
        where
            tanda_terima_id > 0
        group by 1
    ),

    tt_outstanding as (
        select
            toDate(tt.kembali_tanggal) as day_id,
            CAST(sum(tt.total_amount - coalesce(tp.settled_amount, 0)), 'Float64') as total_po
        from
            {{ref('stg_toko__tanda_terima')}} tt
        left join
            tt_paid tp
        on
            tt.tanda_terima_id = tp.tanda_terima_id
        where
            tt.supplier_id not in ({{ excluded_suppliers() }})
            and tt.total_amount - coalesce(tp.settled_amount, 0) > 0
        group by 1
    ),

    -- pembayaran langsung ke PO (tanpa tanda terima) mengurangi sisa receive
    -- PO tsb secara proporsional
    po_direct_paid as (
        select
            po_id,
            sum(payment_amount + discount_amount) as settled_amount
        from
            supplier_payment
        where
            tanda_terima_id = 0
            and po_id > 0
        group by 1
    ),

    rf_no_tt as (
        select
            po_id,
            received_at,
            subtotal,
            sum(subtotal) over (partition by po_id) as po_unbilled_total
        from
            receive_flow
        where
            tanda_terima_id is null
            and subtotal > 0
    ),

    po_outstanding as (
        select
            toDate(r.received_at) + interval 2 month as day_id,
            sum(CAST(r.subtotal, 'Float64') * greatest(0, 1 - CAST(coalesce(pp.settled_amount, 0), 'Float64') / CAST(r.po_unbilled_total, 'Float64'))) as total_po
        from
            rf_no_tt r
        left join
            po_direct_paid pp
        on
            r.po_id = pp.po_id
        group by 1
    ),

    po_daily_po as (
        select * from po_paid
        union all
        select * from tt_outstanding
        union all
        select * from po_outstanding
    ),

    po_daily as (
        select day_id, sum(total_po) as total_po
        from (
            select * from po_daily_pra_po
            union all
            select * from po_daily_po
        )
        group by 1
    ),

    days as (
        select day_id from daily_tp
        union distinct
        select day_id from daily_opex
        union distinct
        select day_id from po_daily
        union distinct
        select day_id from daily_internal_billed
    ),

    final as (
        select
            d.day_id as day_id,
            coalesce(paid_amount, 0) as paid_amount,
            coalesce(paid_amount_internal, 0) as paid_amount_internal,
            coalesce(internal_billed_cost, 0) as internal_billed_cost,
            coalesce(expense_amount, 0) as expense_amount,
            coalesce(total_po, 0) as total_po,
            coalesce(paid_amount, 0) - coalesce(expense_amount, 0) - coalesce(total_po, 0) as net_cash_flow,
            sum(coalesce(round(paid_amount), 0) - coalesce(round(expense_amount), 0) - coalesce(round(total_po), 0))
                over (order by d.day_id rows between unbounded preceding and current row) as running_balance,
            d.day_id > today() as is_forecast
        from
            days d
        left join
            daily_tp dt
        on
            d.day_id = dt.day_id
        left join
            daily_opex do
        on
            d.day_id = do.day_id
        left join
            po_daily rf
        on
            d.day_id = rf.day_id
        left join
            daily_internal_billed dib
        on
            d.day_id = dib.day_id

    )

    select * from final
    order by 1 desc


