with

    transaksi_details as (select * from {{ ref('int_toko__transaksi') }}),
    modal_log as (select * from {{ ref('mart_toko__modal_change_log') }}),
    return_details as (select * from {{ source('toko_db', 'transaksi_return_details') }}),

    -- WAC: Weighted Average Cost per item, dihitung kumulatif dari setiap pembelian.
    -- Lebih akurat dari ASOF karena memperhitungkan sisa stok batch lama
    -- yang masih ada saat batch baru datang.
    -- Formula: SUM(qty × unit_cost, s/d t) / SUM(qty, s/d t)
    modal_wac as (
        select
            item_id,
            changed_at,
            sum(modal_barang * quantity) over (partition by item_id order by changed_at)
            / sum(quantity) over (partition by item_id order by changed_at) as wac
        from
            modal_log
        where
            quantity is not null
    ),

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

    -- ASOF JOIN ke modal_wac menggantikan join langsung ke modal_log.
    -- Mengambil WAC terbaru pada atau sebelum tanggal jual per item.
    modal_jual as (
        select
            td.transaksi_id,
            td.item_id,
            td.nama                              as item_name,
            td.item_qty                          as quantity,
            td.harga_satuan                      as price,
            td.item_qty * td.harga_satuan        as subtotal,
            coalesce(m.wac, me.modal_barang)     as modal_barang,
            td.created_at,
            coalesce(m.changed_at, me.earliest_changed_at) as changed_at,
            transaksi_id || '-' || td.item_id    as pnl_id
        from
            transaksi_details td
        asof left join
            modal_wac m
            on td.item_id = m.item_id
            and td.created_at >= m.changed_at
        left join
            modal_earliest me
            on td.item_id = me.item_id
        where
            td.customer_id not in (788, 178, 7, 6)
    ),

    return_barang as (
        select
            transaksi_id || '-' || item_id as pnl_id,
            id                             as return_id,
            transaksi_id,
            item_id,
            qty_returned
        from
            return_details
    ),

    pnl as (
        select
            mj.*,
            r.return_id,
            coalesce(r.qty_returned, 0)                                        as qty_returned,
            
            case 
                when 
                    quantity = qty_returned then 0
                else 
                    mj.subtotal - ((mj.quantity + coalesce(r.qty_returned, 0)) * mj.modal_barang) 
            end as pnl
        from
            modal_jual mj
        left join
            return_barang r
            on mj.pnl_id = r.pnl_id
    )

    select *
    from pnl
