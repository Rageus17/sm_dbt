with

barang as (select * from {{ ref('stg_toko__barang') }}),

items as (
    select
        *,
        JSONExtract(descriptions, 'Array(String)') as desc_array
    from barang
),

-- descriptions yang udah migrasi ke format "key:value" -> 1 baris per attribute
migrated as (
    select
        * except (desc_array),
        nullIf(desc_item, '') as description
    from items
    array join arrayFilter(x -> position(x, ':') > 0, desc_array) as desc_item
),

-- descriptions lama yang belum migrasi (bukan format "key:value", masih json bebas
-- kayak ["keramik","ikad","40x40"]) -> digabung jadi 1 baris per item biar nggak
-- keduplicate per elemen array. item tanpa descriptions sama sekali juga tetep
-- keikut 1 baris (description null) biar nggak ilang dari model ini.
legacy as (
    select
        * except (desc_array),
        nullIf(
            arrayStringConcat(arrayFilter(x -> position(x, ':') = 0 and x != '', desc_array), ', '),
            ''
        ) as description
    from items
    where empty(desc_array) or arrayExists(x -> position(x, ':') = 0 and x != '', desc_array)
)

select * from migrated
union all
select * from legacy
