with
    pnl_trx as (select * from {{ref('mart_toko__trx_pnl_details')}}),
    transaksi as (select * from {{ref('stg_toko__transaksi')}}),

    daily_pnl as (
        select
            toDate(created_at) as day_id,
            sum(nett_total)    as total_transaksi,
            sum(pnl)           as pnl
        from pnl_trx
        group by 1
    ),

    daily_diskon as (
        select
            toDate(created_at)               as day_id,
            sum(coalesce(diskon_nominal, 0)) as diskon_transaksi
        from transaksi
        group by 1
    )

    select
        p.day_id,
        p.total_transaksi,
        coalesce(d.diskon_transaksi, 0) as diskon_transaksi,
        p.pnl
    from daily_pnl p
    left join daily_diskon d on p.day_id = d.day_id
    order by 1 desc