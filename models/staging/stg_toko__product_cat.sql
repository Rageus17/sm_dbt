{# public_product_cat cuma ada di ch_aksata, jadi model ini hanya aktif di target aksata #}
{{ config(enabled = target.name == 'aksata') }}

with 
    product_cat as (select *,
        row_number() over (partition by id order by _peerdb_synced_at desc) as rn
     from {{source('toko_db','public_product_cat')}})

    select 
        id as product_cat_id,
        item_id,
        nama_warna,
        base_item_id,
        base_volume,
        brand,
        created_at,
        updated_at
    from 
        product_cat
    where 
        rn = 1
        and _peerdb_is_deleted = 0
