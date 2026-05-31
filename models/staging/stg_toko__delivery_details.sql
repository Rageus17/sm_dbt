with 
    delivery_details as (select * from {{source('toko_db','public_delivery_details')}}),

    ranked as (
  select
    *,
    row_number() over (
      partition by id
      order by _peerdb_synced_at desc
    ) as rn
  from delivery_details
),

final as (
  select *
  from ranked
  where rn = 1
)
    select 
        id as delivery_detail_id,
        delivery_note_id,
        delivery_later_id,
        item_id,
        qty_delivered,
        delivered_at,
        delivered_by,
        is_canceled
    from 
        final