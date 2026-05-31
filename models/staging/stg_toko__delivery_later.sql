with 
    delivery_later as (select * from {{source('toko_db','public_delivery_later')}}),

ranked as (
  select
    *,
    row_number() over (
      partition by id
      order by _peerdb_synced_at desc
    ) as rn
  from delivery_later
),

final as (
  select *
  from ranked
  where rn = 1
)

select 
    id as delivery_later_id,
    trx_id as transaksi_id,
    item_id,
    qty_delivery,
    qty_delivered,
    status,
    created_at
from final