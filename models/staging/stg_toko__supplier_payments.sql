with 
    supplier_payments as (select *,
        row_number() over (partition by id order by _peerdb_synced_at desc) as rn
     from {{source('toko_db','public_supplier_payments')}})

    select 
        id as supplier_payment_id,
        po_id,
        supplier_id,
        tanda_terima_id,
        payment_amount,
        discount_amount,
        payment_method,
        payment_date
    from 
        supplier_payments
    where 
        rn = 1
        and is_deleted = false
        and _peerdb_is_deleted = 0
