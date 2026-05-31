with 
    modal_change_log as (select * from {{source('toko_db','public_modal_price_change_log')}})

    select 
        id as modal_log_id,
        item_id,
        old_modal_price,
        new_modal_price,
        changed_by,
        changed_at,
        reason,
        change_type
    from 
        modal_change_log