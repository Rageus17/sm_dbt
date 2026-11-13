with 
    tanda_terima as (select *,
        row_number() over (partition by id order by _peerdb_synced_at desc) as rn
     from {{source('toko_db','public_tanda_terima')}})

    select 
        id as tanda_terima_id,
        supplier_id,
        supplier_name,
        total_amount,
        discount_amount,
        amount_paid,
        payment_status,
        nullIf(paid_at, toDateTime64('1970-01-01 00:00:00', 6)) as paid_at,
        nullIf(kembali_tanggal, toDate32('1970-01-01')) as kembali_tanggal,
        created_at
    from 
        tanda_terima
    where 
        rn = 1
        and is_deleted = false
        and _peerdb_is_deleted = 0
