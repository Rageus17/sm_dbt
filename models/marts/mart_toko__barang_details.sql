with 
    inventory as (select * from {{ref('stg_toko__inventory')}}),
    barang as (select * from {{ref('stg_toko__barang')}}),
    qty_alert as (select * from {{ref('stg_toko__item_qty_alert')}})

    select 
        b.item_id,
        b.nama_barang,
        b.harga_jual,
        b.min_harga_jual,
        i.quantity,
        i.modal_barang,
        q.qty_alert
    from 
        barang b
    left join 
        inventory i
    on 
        b.item_id = i.item_id
    left join 
        qty_alert q
    on 
        b.item_id = q.item_id

        where 
    b.is_deleted = 0