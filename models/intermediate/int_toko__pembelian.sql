with 
    inv_hist as (select * from {{ref('stg_toko__inventory_history')}}),
    supplier_mapping as (select * from {{ref('supplier_mapping')}})

    select
        item_id,
        change_type,
        quantity,
        harga,
        harga / quantity as modal_barang,
        changed_at,
        supplier_mapping.supplier_id
    from 
        inv_hist
    left join
        supplier_mapping 
    on 
        inv_hist.supplier_name = supplier_mapping.supplier_name
    where 
        change_type = 'MASUK'
    and
        metode_bayar != 'ADJUSTMENT'
