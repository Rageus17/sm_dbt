with
    transaksi as (select * from {{ref('int_toko__transaksi')}}),
    return_details as (select * from {{ref('stg_toko__transaksi_return_details')}}),

    semi as (select
        customer_id,
        transaksi_id,
        created_at,
        returned_at,
        item_id,
        item_qty,
        harga_satuan,
        item_qty * harga_satuan as total_purchased_idr,
        qty_returned
    from 
        transaksi
    left join 
        return_details 
    on 
        transaksi.transaksi_id = return_details.transaksi_id
    and 
        transaksi.item_id = return_details.item_id)

    select 
        *,
        case 
            when item_qty - qty_returned > 0 
                then harga_satuan * (item_qty - qty_returned)
            when item_qty - qty_returned <= 0
                then 0
            end as net_transaksi_idr
            
    from 
        semi