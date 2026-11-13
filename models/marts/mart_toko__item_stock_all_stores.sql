with
    descriptions as (
        select
            case
                when source_relation like '%dbt_toko%' then 'toko'
                when source_relation like '%dbt_cm%' then 'cm'
                when source_relation like '%dbt_sk%' then 'sk'
                when source_relation like '%dbt_cat%' then 'aksata'
            end as toko,
            item_id,
            nama_barang,
            description
        from {{ ref('int_toko__item_descriptions_all_stores') }}
    ),
    inventory as (
        select
            case
                when source_relation like '%dbt_toko%' then 'toko'
                when source_relation like '%dbt_cm%' then 'cm'
                when source_relation like '%dbt_sk%' then 'sk'
                when source_relation like '%dbt_cat%' then 'aksata'
            end as toko,
            item_id,
            quantity,
            modal_barang
        from {{ ref('int_toko__inventory_all_stores') }}
    )

select
    d.toko,
    d.item_id,
    d.nama_barang,
    d.description,
    i.quantity,
    i.modal_barang
from
    descriptions d
left join
    inventory i
    on d.toko = i.toko
    and d.item_id = i.item_id
