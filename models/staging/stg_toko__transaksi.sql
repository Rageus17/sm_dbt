with
    transaksi as (select * from {{source('toko_db','transaksi')}}),

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
        customer_id,
        payment_status,
        total_paid,
        outstanding_balance,
        created_at
    from 
        deduped
    where  rn = 1