with
    barang as (
        select item_id, nama_barang, is_deleted
        from {{ ref('stg_toko__barang') }}
    ),

    current_stock as (
        select
            i.item_id,
            i.quantity        as qty_on_hand,
            i.modal_barang,
            i.last_updated
        from
            {{ ref('stg_toko__inventory') }} i
        left join
            barang b on i.item_id = b.item_id
        where
            coalesce(b.is_deleted, false) = false
    ),

    purchases as (
        select
            item_id,
            min(changed_at)     as first_received_at,
            max(changed_at)     as last_received_at
        from
            {{ ref('stg_toko__inventory_history') }}
        where
            change_type = 'MASUK'
            and metode_bayar != 'ADJUSTMENT'
            and metode_bayar != 'RETURN'
        group by
            item_id
    ),

    sales_out as (
        select
            item_id,
            any(nama)                           as item_name,
            sum(item_qty)                       as qty_sold,
            min(created_at)                     as first_sold_at,
            max(created_at)                     as last_sold_at,
            count(distinct transaksi_id)        as total_transactions
        from
            {{ ref('int_toko__transaksi') }}
        where
            customer_id not in (788, 178, 7, 6)
        group by
            item_id
    ),

    final as (
        select
            cs.item_id                                  as item_id,
            coalesce(so.item_name, b.nama_barang)       as item_name,
            cs.qty_on_hand,
            coalesce(so.qty_sold, 0)                    as qty_sold,
            p.first_received_at,
            p.last_received_at,
            so.first_sold_at,
            so.last_sold_at,
            coalesce(so.total_transactions, 0)          as total_transactions,
            cs.modal_barang,
            cs.qty_on_hand * cs.modal_barang            as stock_value_idr,
            if(so.last_sold_at is not null,
                dateDiff('day', so.last_sold_at, now()),
                null)                                   as days_since_last_sale,
            if(p.last_received_at is not null,
                dateDiff('day', p.last_received_at, now()),
                null)                                   as days_since_last_purchase,
            multiIf(
                coalesce(so.qty_sold, 0) = 0,
                    'never_sold',
                dateDiff('day', so.last_sold_at, now()) > 90,
                    'critical',
                dateDiff('day', so.last_sold_at, now()) > 30,
                    'warning',
                dateDiff('day', so.last_sold_at, now()) > 14,
                    'watch',
                'active'
            )                                           as dead_stock_status
        from
            current_stock cs
        left join
            purchases p on cs.item_id = p.item_id
        left join
            sales_out so on cs.item_id = so.item_id
        left join
            barang b on cs.item_id = b.item_id
        where
            cs.qty_on_hand > 0
        order by
            stock_value_idr desc
    )

select *
from final
