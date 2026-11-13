{{ dbt_utils.union_relations(
    relations=[
        source('store_toko', 'int_toko__item_descriptions'),
        source('store_cm', 'int_toko__item_descriptions'),
        source('store_sk', 'int_toko__item_descriptions'),
        source('store_aksata', 'int_toko__item_descriptions'),
    ],
    source_column_name='source_relation'
) }}
