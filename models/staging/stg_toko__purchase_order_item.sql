with 
    poi as (select *,
        row_number() over (partition by id order by _peerdb_synced_at desc) as rn
     from {{source('toko_db','public_purchase_order_items')}})

    select 
        id as poi_id,
        po_id,
        item_id,
        quantity_ordered,
        quantity_received,
        harga_satuan,
        subtotal,
        notes,
        created_at
    from 
        poi
    where 
        rn = 1