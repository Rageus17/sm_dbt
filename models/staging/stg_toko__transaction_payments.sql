with 
    payment as (select *,
    row_number() over (partition by id order by _peerdb_synced_at desc) as rn
     from {{source('toko_db','transaction_payments')}})

    select 
        id as transaction_payment_id,
        transaksi_id,
        payment_method,
        amount,
        payment_date,
        notes,
        recorded_by
    from 
        payment
    where 
        rn = 1

