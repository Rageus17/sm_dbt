with

    transaksi_details as (select * from {{ ref('int_toko__transaksi') }}),

    combo_2 as (
        select
            a.item_id as item_id_1,
            a.nama as item_name_1,
            b.item_id as item_id_2,
            b.nama as item_name_2,
            count(distinct a.transaksi_id) as total_transactions
        from
            transaksi_details a
        inner join
            transaksi_details b
            on a.transaksi_id = b.transaksi_id
            and a.item_id < b.item_id
        group by 1, 2, 3, 4
    ),

    combo_2_ranked as (
        select
            *,
            row_number() over (order by total_transactions desc) as combo_rank
        from
            combo_2
    ),

    combo_3 as (
        select
            a.item_id as item_id_1,
            a.nama as item_name_1,
            b.item_id as item_id_2,
            b.nama as item_name_2,
            c.item_id as item_id_3,
            c.nama as item_name_3,
            count(distinct a.transaksi_id) as total_transactions
        from
            transaksi_details a
        inner join
            transaksi_details b
            on a.transaksi_id = b.transaksi_id
            and a.item_id < b.item_id
        inner join
            transaksi_details c
            on a.transaksi_id = c.transaksi_id
            and b.item_id < c.item_id
        group by 1, 2, 3, 4, 5, 6
    ),

    combo_3_ranked as (
        select
            *,
            row_number() over (order by total_transactions desc) as combo_rank
        from
            combo_3
    )

    select
        '2-item' as combo_type,
        item_id_1,
        item_name_1,
        item_id_2,
        item_name_2,
        null as item_id_3,
        null as item_name_3,
        total_transactions,
        combo_rank
    from
        combo_2_ranked

    union all

    select
        '3-item' as combo_type,
        item_id_1,
        item_name_1,
        item_id_2,
        item_name_2,
        item_id_3,
        item_name_3,
        total_transactions,
        combo_rank
    from
        combo_3_ranked
