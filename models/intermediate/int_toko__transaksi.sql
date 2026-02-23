with
    transaksi as (
        select
            *,
            JSONExtractArrayRaw(items) as items_array
        from {{ ref('stg_toko__transaksi') }}
    )

    select
        t.id,
        t.created_at,
        t.transaksi_id,
        t.customer_id,
        JSONExtractString(item, 'id')    as item_id,
        JSONExtractFloat(item, 'qty')    as item_qty,
        JSONExtractString(item, 'nama')  as nama,
        JSONExtractInt(item, 'harga')    as harga
    from
        transaksi t
    array join
        t.items_array as item