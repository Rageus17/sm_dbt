with
    inventory_hist as (
        select *,
            row_number() over (partition by inv_id order by _peerdb_synced_at desc) as rn
        from {{source('toko_db','public_inventory_history')}}
    ),

    final as (
        select
            item_id,
            change_type,
            quantity,
            nullIf(notes, '')         as notes,
            changed_at,
            nullIf(changed_by, '')    as changed_by,
            nullIf(metode_bayar, '')  as metode_bayar,
            harga,
            inv_id,
            nullIf(trx_id, '')        as trx_id,
            nullIf(unit_type, '')     as unit_type,
            nullIf(supplier_name, '') as supplier_name,

            nullIf(old_qty, 0) as old_qty,
            nullIf(new_qty, 0) as new_qty
        from
            inventory_hist
        where
            rn = 1
    )

select * from final