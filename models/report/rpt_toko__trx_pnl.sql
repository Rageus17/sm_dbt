with 
    pnl_trx as (select * from {{ref('mart_toko__trx_pnl_details')}})

    select 
        date_trunc('month',created_at) as month_id,
        sum(pnl) as pnl
    from 
        pnl_trx
    group by 1
    order by 1 desc