with 
    po as (select *,
        row_number() over (partition by id order by _peerdb_synced_at desc) as rn
     from {{source('toko_db','public_purchase_orders')}})

    select 
        id as po_id,
        po_number,
        supplier_id,
        supplier_name,
        status,
        total_amount,
        notes,
        created_by,
        created_at,
         updated_at,
        sent_at,
        completed_at,
        cancelled_at
    from 
        po
    where 
        rn = 1