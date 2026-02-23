with
    transaksi as (select * from {{source('toko_db','transaksi')}})

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
        transaksi