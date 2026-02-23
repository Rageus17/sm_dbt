with 
    inventory as (select * from {{source('toko_db','inventory')}})

select
    item_id,
    modal_barang,
    last_updated
from
    inventory