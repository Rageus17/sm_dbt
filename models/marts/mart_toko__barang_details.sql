with 
    inventory as (select * from {{ref('stg_toko__inventory')}}),
    barang as (select * from {{ref('stg_toko__barang')}})

    select 
        b.item_id,
        b.nama_barang,
        b.harga_jual,
        b.min_harga_jual,
        i.quantity,
        i.modal_barang
    from 
        barang b
    join 
        inventory i
    on 
        b.item_id = i.item_id