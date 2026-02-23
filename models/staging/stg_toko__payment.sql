with 
    payments as (select * from {{source('toko_db','transaction_payments')}})

    select 
        id as payment_id,
        transaksi_id,
        payment_method,
        amount,
        payment_date,
        notes,
        recorded_by
    from 
        payments