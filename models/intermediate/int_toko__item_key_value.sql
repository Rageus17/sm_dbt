{%- set attribute_keys = dbt_utils.get_column_values(
    table=ref('int_toko__descriptions2'),
    column='lower(trim(attribute_key))',
    max_records=200
) -%}

select
    item_id,
    {{ dbt_utils.pivot(
        column='lower(trim(attribute_key))',
        values=attribute_keys,
        agg='max',
        then_value='attribute_value',
        else_value='NULL',
        quote_identifiers=False
    ) }}
from {{ ref('int_toko__descriptions2') }}
group by item_id
