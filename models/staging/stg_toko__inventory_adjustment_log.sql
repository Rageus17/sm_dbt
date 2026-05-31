with 
    log as (
        select *, 
        row_number() over (partition by id order by _peerdb_synced_at desc) as rn
        from {{source('toko_db','public_inventory_adjustment_log')}}),

    final as (
    select
        id as inventory_adjustment_log_id,
        item_id,
        old_quantity,
        new_quantity,
        adjustment_qty,
        adjusted_at
    from 
        log
    where 
        rn = 1)

        select * from final