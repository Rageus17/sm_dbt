with
    inventory_hist as (select * from {{source('toko_db','inventory_history')}})

    select
        item_id,
        change_type,
        quantity,
        notes,
        changed_at,
        changed_by,
        metode_bayar,
        harga,
        inv_id,
        trx_id,
        unit_type,
        supplier_name
    from 
        inventory_hist