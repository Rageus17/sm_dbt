with
    transaksi as (select * from {{source('toko_db','public_transaksi')}}),

    deduped as (
        select 
            *,
            row_number() over (partition by transaksi_id order by _peerdb_synced_at desc) as rn
        from 
            transaksi
    )

    select 
        id, 
        transaksi_id,
        items,
        total,
        nama_pelanggan,
        alamat_pengiriman,
        metode_pembayaran,
        inputted_by,
        is_returned,
        returned_at,
        returned_by,
        return_reason,
        total_returned,
        subtotal,
        diskon_nominal,
        nullIf(customer_id,0) as customer_id,
        payment_status,
        total_paid,
        outstanding_balance,
        created_at,
        nullIf(referral_id,0) as referral_id,
        is_cancelled,
        tukang_id
    from
        deduped
    where  rn = 1