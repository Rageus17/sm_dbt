with 
    barang as (select * from {{source('toko_db','public_barang')}})

    select  
        item_id,
        nama_barang,
        harga_jual,
        base_item_id,
        conversion_factor,
        inputted_by,
        min_harga_jual,
        is_deleted

    from 
    barang  