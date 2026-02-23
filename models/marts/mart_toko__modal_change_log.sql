with
    inventory_history as (select * from {{ref('stg_toko__inventory_history')}}),
    modal_price_change_log as (select * from {{ref('stg_toko__modal_change_log')}}),
    inventory as (select * from {{ref('stg_toko__inventory')}}),

    modal_log1 as (
select
    item_id,
    harga / quantity as modal_barang,
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
    new_modal_price as modal_barang,
    changed_at
from
    modal_price_change_log
order by 
    changed_at desc),

modal_log3 as (
select
    item_id,
    modal_barang,
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