SELECT
    item_id,
    splitByChar(':', assumeNotNull(description))[1] AS attribute_key,
    splitByChar(':', assumeNotNull(description))[2] AS attribute_value
FROM {{ ref('int_toko__item_descriptions') }}
WHERE description IS NOT NULL AND position(description, ':') > 0