with
    inventory as (select * from {{source('toko_db','inventory')}}),

    deduped as (
        select
            *,
            row_number() over (partition by item_id order by last_updated desc) as rn
        from
            inventory
    )

select
    item_id,
    modal_barang,
    last_updated
from
    deduped
where rn = 1