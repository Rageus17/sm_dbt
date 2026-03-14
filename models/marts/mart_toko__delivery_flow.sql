with
    trx_details as (
        select transaksi_id, item_id, item_qty
        from {{ ref('int_toko__transaksi') }}
    ),
    delivery_later as (
        select delivery_later_id, transaksi_id, item_id, qty_delivery, qty_delivered
        from {{ ref('stg_toko__delivery_later') }}
    ),
    delivery_details as (
        select delivery_detail_id, delivery_later_id, qty_delivered, delivered_at
        from {{ ref('stg_toko__delivery_details') }}
    )

select
    trx_details.transaksi_id,
    trx_details.item_id,
    trx_details.item_qty                        as item_ordered,
    delivery_later.qty_delivery                 as qty_planned_delivery,
    delivery_later.qty_delivered                as qty_delivered_planned,  -- rename as fits your domain
    delivery_later.delivery_later_id,
    delivery_details.delivery_detail_id,
    delivery_details.qty_delivered              as qty_delivered_actual,
    delivery_details.delivered_at,
    sum(delivery_details.qty_delivered) over (
        partition by delivery_later.delivery_later_id
        order by delivery_details.delivered_at
    )                                           as cum_qty_delivered
from trx_details
join delivery_later
    on  trx_details.transaksi_id = delivery_later.transaksi_id
    and trx_details.item_id      = delivery_later.item_id
join delivery_details
    on delivery_later.delivery_later_id = delivery_details.delivery_later_id