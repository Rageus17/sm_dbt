with

    transaksi_details as (select * from {{ ref('int_toko__transaksi') }}),

    daily_sales as (
        select
            created_at::date as sale_date,
            item_id,
            nama as item_name,
            sum(item_qty) as total_qty_sold,
            sum(item_qty * harga) as total_revenue,
            count(distinct transaksi_id) as total_transactions
        from
            transaksi_details
        group by 1, 2, 3
    ),

    daily_ranked as (
        select
            *,
            row_number() over (
                partition by sale_date
                order by total_qty_sold desc
            ) as daily_rank
        from
            daily_sales
    ),

    weekly_sales as (
        select
            date_trunc('week', created_at)::date as week_start,
            item_id,
            nama as item_name,
            sum(item_qty) as total_qty_sold,
            sum(item_qty * harga) as total_revenue,
            count(distinct transaksi_id) as total_transactions
        from
            transaksi_details
        group by 1, 2, 3
    ),

    weekly_ranked as (
        select
            *,
            row_number() over (
                partition by week_start
                order by total_qty_sold desc
            ) as weekly_rank
        from
            weekly_sales
    )

    select
        'daily' as period_type,
        sale_date as period_start,
        item_id,
        item_name,
        total_qty_sold,
        total_revenue,
        total_transactions,
        daily_rank as rank
    from
        daily_ranked

    union all

    select
        'weekly' as period_type,
        week_start as period_start,
        item_id,
        item_name,
        total_qty_sold,
        total_revenue,
        total_transactions,
        weekly_rank as rank
    from
        weekly_ranked
