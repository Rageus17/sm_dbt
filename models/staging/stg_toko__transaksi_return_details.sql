with 
    return_details as (select * from {{source('toko_db','public_transaksi_return_details')}})

    select 
        transaksi_id,
        item_id,
        qty_returned,
        harga as harga_returned,
        subtotal,
        returned_at,
        returned_by
    from 
        return_details