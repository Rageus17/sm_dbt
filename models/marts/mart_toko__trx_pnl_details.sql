with

    transaksi_details as (select * from {{ ref('int_toko__transaksi') }}),
    modal_log as (select * from {{ ref('mart_toko__modal_change_log') }}),
    return_details as (select * from {{ source('toko_db', 'transaksi_return_details') }}),

    -- Fallback: earliest modal per item for sales that happened
    -- before any modal price was ever recorded for that item
    modal_earliest as (
        select
            item_id,
            argMin(modal_barang, changed_at) as modal_barang,
            min(changed_at) as earliest_changed_at
        from
            modal_log
        group by item_id
    ),

    -- ASOF JOIN replaces the old: modal_jual → modal_jual_tz →
    -- semi1 → semi2 → final1 → final2 → final (6 CTEs + 2 window fns)
    -- It finds the most recent modal price at or before the sale date per item.
    -- coalesce handles the fallback when no prior modal price exists.
    modal_jual as (
        select
            td.transaksi_id,
            td.item_id,
            td.nama                         as item_name,
            td.item_qty                     as quantity,
            td.harga                        as price,
            td.item_qty * td.harga          as subtotal,
            coalesce(m.modal_barang, me.modal_barang) as modal_barang,
            td.created_at,
            coalesce(m.changed_at, me.earliest_changed_at) as changed_at,
            transaksi_id || '-' || td.item_id         as pnl_id
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
