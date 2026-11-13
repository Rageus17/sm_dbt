with
    inventory as (select * from {{ref('stg_toko__inventory')}}),
    transaksi as (select * from {{ref('stg_toko__transaksi')}}),
    transaksi_details as (select * from {{ ref('int_toko__transaksi') }}),
    modal_log as (select * from {{ ref('mart_toko__modal_change_log') }}),
    return_details as (select * from {{ source('toko_db', 'public_transaksi_return_details') }}),
    item_map as (select * from {{ ref(var('item_mapping', 'item_mapping_cm' if target.name == 'cm' else 'item_mapping_sk' if target.name == 'sk' else 'item_mapping_sm')) }}),
    item_map2 as (
        select
            item_id,
            arrayStringConcat(groupUniqArray(description), ', ') as description
        from (
            select item_id, description
            from {{ref('int_toko__item_descriptions')}}
            where description is not null
        )
        group by item_id
    ),
    item_key_val as (select * from {{ref('int_toko__item_key_value')}}),
    -- Fallback: harga modal terlama dari SEMUA sumber (termasuk harga awal sistem
    -- di tabel inventory dan perubahan manual), untuk 2 kasus:
    -- 1. Penjualan terjadi sebelum ada data pembelian tercatat
    -- 2. Slow moving item — tidak ada MASUK di inventory_history sama sekali,
    --    tapi masih punya harga modal bawaan sistem (inventory table / modal_log3)
    modal_earliest as (
        select
            item_id,
            argMin(modal_barang, changed_at) as modal_barang,
            min(changed_at)                  as earliest_changed_at
        from
            modal_log
        group by item_id
    ),

    -- FIFO: ASOF JOIN langsung ke modal_log.
    -- Mengambil harga modal batch pertama yang tersedia pada atau sebelum tanggal jual.
    modal_jual as (
        select
            td.transaksi_id,
            
            td.item_id as item_id,
            td.nama                                       as item_name,
            td.item_qty                                   as quantity,
            td.harga_satuan                               as price,
            td.item_qty * td.harga_satuan                 as subtotal,
            coalesce(CAST(td.modal_barang, 'Nullable(Float64)'), CAST(m.modal_barang, 'Nullable(Float64)'), CAST(me.modal_barang, 'Nullable(Float64)')) as modal_barang,
            td.created_at,
            coalesce(m.changed_at, me.earliest_changed_at) as changed_at,
            transaksi_id || '-' || td.item_id             as pnl_id
        from
            transaksi_details td
        asof left join
            modal_log m
            on td.item_id = m.item_id
            and td.created_at >= m.changed_at
        left join
            modal_earliest me
            on td.item_id = me.item_id
        
        where
        td.transaksi_id not in (select transaksi_id from transaksi
        where customer_id in ({{ excluded_customers() }})
        or is_cancelled = True)
    ),

    -- Beberapa item punya >1 baris retur untuk transaksi+item yang sama (retur
    -- terpisah beneran, atau kadang double-submit dari sisi kasir). Diagregat di sini
    -- supaya join ke pnl tidak fan-out row per baris retur.
    return_barang as (
        select
            transaksi_id || '-' || item_id as pnl_id,
            any(id)                        as return_id,
            transaksi_id,
            item_id,
            sum(qty_returned)              as qty_returned
        from
            return_details
        group by transaksi_id, item_id
    ),

    pnl as (
        select
            mj.transaksi_id  as transaksi_id,
            mj.item_id       as item_id,
            mj.item_name     as item_name,
            mj.quantity      as quantity,
            mj.price         as price,
            mj.subtotal      as subtotal,
            mj.modal_barang  as modal_barang,
            i.modal_barang as modal_barang_inv,
            mj.created_at    as created_at,
            mj.changed_at    as changed_at,
            mj.pnl_id        as pnl_id,
            r.return_id,
            -- Cap di quantity terjual: retur yang ke-double-submit di source tidak boleh
            -- membuat qty_returned lebih besar dari qty yang terjual.
            least(coalesce(r.qty_returned, 0), mj.quantity)                       as qty_returned,
            mj.price * (mj.quantity - least(coalesce(r.qty_returned,0), mj.quantity)) as nett_total,

            case
                when
                    mj.quantity = qty_returned then 0

                when mj.modal_barang = 0
                    then (mj.price - i.modal_barang) * (mj.quantity - qty_returned)

                when mj.price < mj.modal_barang and mj.price > i.modal_barang
                    then (mj.price - i.modal_barang) * (mj.quantity - qty_returned)

                else (mj.price-mj.modal_barang) * (mj.quantity - qty_returned)
                    -- mj.subtotal - ((mj.quantity + coalesce(r.qty_returned, 0)) * mj.modal_barang)
            end as pnl
        from
            modal_jual mj
        left join
            return_barang r
            on mj.pnl_id = r.pnl_id
        left join 
            inventory i
            on mj.item_id = i.item_id
        
    ),

    -- Kolom ditulis eksplisit: p.* + join on item_id bikin ClickHouse menamai kolomnya "p.item_id"
    final as (select
        p.transaksi_id     as transaksi_id,
        p.item_id          as item_id,
        p.item_name        as item_name,
        p.quantity         as quantity,
        p.price            as price,
        p.subtotal         as subtotal,
        p.modal_barang     as modal_barang,
        p.modal_barang_inv as modal_barang_inv,
        p.created_at       as created_at,
        p.changed_at       as changed_at,
        p.pnl_id           as pnl_id,
        p.return_id        as return_id,
        p.qty_returned     as qty_returned,
        p.nett_total       as nett_total,
        p.pnl              as pnl,
        nullIf(coalesce(ikv.merk,im2.description), '') as description
    from pnl p
    -- left join item_map im
    -- on p.item_id = im.item_id
    left join item_map2 im2
    on p.item_id = im2.item_id
    left join item_key_val ikv
    on ikv.item_id = p.item_id)

    select * from final 
    order by toDate(created_at) desc, pnl desc