with
    transaksi as (select * from {{ref('stg_toko__transaksi')}}),
    transaksi_details as (select * from {{ ref('int_toko__transaksi') }}),
    modal_log as (select * from {{ ref('mart_toko__modal_change_log') }}),
    return_details as (select * from {{ source('toko_db', 'public_transaksi_return_details') }}),

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
        where customer_id in (788, 7, 6, 1162, 178, 194, 576, 821, 1140, 1344, 1354, 1435)
        or is_cancelled = True)
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
            mj.price * (mj.quantity - coalesce(r.qty_returned,0)) as nett_total,
            
            case 
                when 
                    quantity = qty_returned then 0
                else 
                    (mj.price-mj.modal_barang) * (mj.quantity - coalesce(r.qty_returned,0))
                    -- mj.subtotal - ((mj.quantity + coalesce(r.qty_returned, 0)) * mj.modal_barang) 
            end as pnl
        from
            modal_jual mj
        left join
            return_barang r
            on mj.pnl_id = r.pnl_id
        
    )

    select *
    from pnl
