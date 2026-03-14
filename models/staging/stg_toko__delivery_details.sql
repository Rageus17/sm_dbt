with 
    delivery_details as (select * from {{source('toko_db','delivery_details')}})

    select 
        id as delivery_detail_id,
        delivery_note_id,
        delivery_later_id,
        item_id,
        qty_delivered,
        delivered_at,
        delivered_by,
        is_canceled
    from 
        delivery_details