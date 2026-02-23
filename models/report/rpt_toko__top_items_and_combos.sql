with

    top_selling as (select * from {{ ref('mart_toko__top_selling_items') }}),
    item_combos as (select * from {{ ref('mart_toko__item_combos') }}),

    top_daily as (
        select
            period_start,
            item_id,
            item_name,
            total_qty_sold,
            total_revenue,
            total_transactions,
            rank
        from
            top_selling
        where
            period_type = 'daily'
            and rank <= 10
    ),

    top_weekly as (
        select
            period_start,
            item_id,
            item_name,
            total_qty_sold,
            total_revenue,
            total_transactions,
            rank
        from
            top_selling
        where
            period_type = 'weekly'
            and rank <= 10
    ),

    top_combo_2 as (
        select
            item_name_1,
            item_name_2,
            total_transactions,
            combo_rank
        from
            item_combos
        where
            combo_type = '2-item'
            and combo_rank <= 20
    ),

    top_combo_3 as (
        select
            item_name_1,
            item_name_2,
            item_name_3,
            total_transactions,
            combo_rank
        from
            item_combos
        where
            combo_type = '3-item'
            and combo_rank <= 20
    )

    select
        'daily_top_seller' as report_type,
        period_start::text as period,
        item_name as label,
        null as label_2,
        null as label_3,
        total_qty_sold,
        total_revenue,
        total_transactions,
        rank as ranking
    from top_daily

    union all

    select
        'weekly_top_seller' as report_type,
        period_start::text as period,
        item_name as label,
        null as label_2,
        null as label_3,
        total_qty_sold,
        total_revenue,
        total_transactions,
        rank as ranking
    from top_weekly

    union all

    select
        'top_2_item_combo' as report_type,
        null as period,
        item_name_1 as label,
        item_name_2 as label_2,
        null as label_3,
        null as total_qty_sold,
        null as total_revenue,
        total_transactions,
        combo_rank as ranking
    from top_combo_2

    union all

    select
        'top_3_item_combo' as report_type,
        null as period,
        item_name_1 as label,
        item_name_2 as label_2,
        item_name_3 as label_3,
        null as total_qty_sold,
        null as total_revenue,
        total_transactions,
        combo_rank as ranking
    from top_combo_3
