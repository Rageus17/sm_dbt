with 
    pnl_trx as (select * from {{ref('mart_toko__trx_pnl_details')}}),
    transaksi as (select * from {{ref('stg_toko__transaksi')}}),

    trx_summary as (
        select
            transaksi_id,
            min(created_at) as created_at,
            sum(nett_total) as total_transaksi,
            sum(pnl) as trx_pnl
        from
            pnl_trx
        group by transaksi_id
    ),

    diskon_pnl as (
        select
            s.*,
            coalesce(t.diskon_nominal,0) as diskon_nominal
        from
            trx_summary s
        left join
            transaksi t
        on
            s.transaksi_id = t.transaksi_id
    )

    select
        date_trunc('month',created_at) as month_id,
        sum(total_transaksi) as total_transaksi,
        sum(diskon_nominal) as diskon_transaksi,
        round(sum(trx_pnl)) as pnl_before_discount,
        round(sum(trx_pnl) - sum(diskon_nominal)) as pnl
    from
        diskon_pnl
    group by 1
    order by 1 desc