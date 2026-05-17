with 
    pnl_trx as (select * from {{ref('mart_toko__trx_pnl_details')}}),
    transaksi as (select * from {{ref('stg_toko__transaksi')}}),

    diskon_pnl as (
        select 
            p.*,
            coalesce(t.diskon_nominal,0) as diskon_nominal
        from    
            pnl_trx p
        left join 
            transaksi t
        on 
            p.transaksi_id = t.transaksi_id
    )

    select 
        date_trunc('day',created_at) as month_id,
        sum(nett_total) as total_transaksi,
        sum(diskon_nominal) as diskon_transaksi,
        sum(pnl) as pnl
    from 
        diskon_pnl
    group by 1
    order by 1 desc