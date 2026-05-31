with
    inventory_history as (select * from {{ref('stg_toko__inventory_history')}}),
    modal_price_change_log as (select * from {{ref('stg_toko__modal_change_log')}}),
    inventory as (select * from {{ref('stg_toko__inventory')}}),

    modal_log1 as (
select
    item_id,
    CAST(quantity,               'Nullable(Float64)') as quantity,
    CAST(harga / quantity,       'Nullable(Float64)') as modal_barang,
    changed_at
from
    inventory_history
where
    change_type = 'MASUK'
    and metode_bayar != 'ADJUSTMENT'
    and metode_bayar != 'RETURN'

    order by changed_at desc),

modal_log2 as (
select
    item_id,
    CAST(null,            'Nullable(Float64)') as quantity,
    CAST(new_modal_price, 'Nullable(Float64)') as modal_barang,
    changed_at
from
    modal_price_change_log
where 
    change_type = 'modal_change'
order by
    changed_at desc),

modal_log3 as (
select
    item_id,
    CAST(null,         'Nullable(Float64)') as quantity,
    CAST(modal_barang, 'Nullable(Float64)') as modal_barang,
    last_updated
from
    inventory),

modal_log as (
    select * from modal_log1
    union all
    select * from modal_log2
    union all
    select * from modal_log3)

select * from modal_log
order by item_id, changed_at