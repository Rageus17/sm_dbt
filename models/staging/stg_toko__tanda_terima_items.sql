with 
    tanda_terima_items as (select *,
        row_number() over (partition by id order by _peerdb_synced_at desc) as rn
     from {{source('toko_db','public_tanda_terima_items')}})

    select 
        id as tanda_terima_item_id,
        nominal,
        receiving_log_id,
        tanda_terima_id
    from 
        tanda_terima_items
    where 
        rn = 1
        and _peerdb_is_deleted = 0
