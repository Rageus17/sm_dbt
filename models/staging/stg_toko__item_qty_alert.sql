with 
    qty_alert as (select *,
                    row_number() over (partition by item_id order by _peerdb_synced_at desc) as rn 
     from {{source('toko_db','public_item_qty_alert')}} 
    where _peerdb_is_deleted = 0)

    select 
        item_id,
        qty_alert,
        created_at
    from qty_alert
    where rn  = 1
