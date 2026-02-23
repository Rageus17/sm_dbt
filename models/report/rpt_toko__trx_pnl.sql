with

    transaksi_details as (select * from {{ ref('int_toko__transaksi') }}),
    modal_log as (select * from {{ ref('mart_toko__modal_change_log') }}),
    return_details as (select * from {{ source('toko_db', 'transaksi_return_details') }}),

    modal_jual as (
        select
            td.transaksi_id,
            td.item_id,
            td.nama as item_name,
            td.item_qty as quantity,
            td.harga as price,
            td.item_qty * td.harga as subtotal,
            m.modal_barang,
            td.created_at,
            m.changed_at
        from
            transaksi_details td
        left join
            modal_log m
            on td.item_id = m.item_id
        where
            td.customer_id not in (788, 178, 7, 6)
    ),

    modal_jual_tz as (
        select
            *,
            dateDiff('second', changed_at, created_at) as time_delta,
            transaksi_id || '-' || item_id as pnl_id
        from
            modal_jual
    ),

    semi1 as (
        select
            *,
            row_number() over (
                partition by transaksi_id, item_id
                order by time_delta
            ) as rn
        from
            modal_jual_tz
        where
            created_at >= changed_at
    ),

    semi2 as (
        select
            *,
            row_number() over (
                partition by transaksi_id, item_id
                order by time_delta desc
            ) as rn
        from
            modal_jual_tz
        where
            created_at < changed_at
    ),

    final1 as (
        select * from semi1 where rn = 1
    ),

    final2 as (
        select *
        from semi2
        where
            rn = 1
            and pnl_id not in (select pnl_id from final1)
    ),

    final as (
        select * from final1
        union all
        select * from final2
    ),

    return_barang as (
        select
            transaksi_id || '-' || item_id as pnl_id,
            id as return_id,
            transaksi_id,
            item_id,
            qty_returned
        from
            return_details
    ),

    pnl_tmp as (
        select
            f.*,
            r.return_id,
            coalesce(r.qty_returned, 0) as qty_returned
        from
            final f
        left join
            return_barang r
            on f.pnl_id = r.pnl_id
    ),

    pnl as (
        select
            *,
            subtotal - ((quantity + qty_returned) * modal_barang) as pnl
        from
            pnl_tmp
    )

    select
        toStartOfMonth(created_at) as month_id,
        sum(pnl) as total_pnl,
        count(return_id) as total_returns
    from
        pnl
    group by 1
