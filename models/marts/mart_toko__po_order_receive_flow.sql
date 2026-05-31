with 
    po as (select * from {{ref('stg_toko__purchase_orders')}}),
    poi as (select * from {{ref('stg_toko__purchase_order_item')}}),
    ri as (select * from {{ref('stg_toko__po_receiving_items')}}),

    semi as (select 
        po.po_number as po_number,
        p.po_id as po_id,
        p.poi_id as poi_id,
        p.item_id as item_id,
        p.quantity_ordered as qty_ordered,
        r.quantity_received as quantity_received,
        r.created_at as received_at
    from 
        poi p
    left join 
        ri r
    on 
        p.poi_id = r.poi_id
    and 
        p.item_id = r.item_id
    left join po 
    on 
        p.po_id = po.po_id
    where po.status not in  ('CANCELLED','DRAFT'))

    select *,
        sum(quantity_received) over (partition by po_number, item_id order by created_at) as total_qty
    from 
        semi

