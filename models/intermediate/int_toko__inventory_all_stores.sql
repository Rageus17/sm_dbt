{{ dbt_utils.union_relations(
    relations=[
        source('store_toko', 'stg_toko__inventory'),
        source('store_cm', 'stg_toko__inventory'),
        source('store_sk', 'stg_toko__inventory'),
        source('store_aksata', 'stg_toko__inventory'),
    ],
    source_column_name='source_relation'
) }}
