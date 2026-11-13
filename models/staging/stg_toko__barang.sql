with
    barang as (select * from {{source('toko_db','public_barang')}}),

    deduped as (
        select
            *,
            row_number() over (partition by item_id order by _peerdb_synced_at desc) as rn
        from
            barang
    )

    select
        item_id,
        nama_barang,
        harga_jual,
        base_item_id,
        conversion_factor,
        inputted_by,
        min_harga_jual,
        is_deleted,
        descriptions

    from
        deduped
    where rn = 1
