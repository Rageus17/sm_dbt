with 
    pri as (select *,
        row_number() over (partition by id order by _peerdb_synced_at desc) as rn
     from {{source('toko_db','public_po_receiving_items')}})

    select 
        id as pri_id,
        receiving_log_id,
        poi_id,
        item_id,
        quantity_received,
        inv_id,
        created_at
    from
        pri
    where 
        rn = 1