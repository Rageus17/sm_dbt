with
    inventory_history as (select * from {{ref('int_toko__pembelian')}}),
    supplier_mapping as (select * from {{ref('supplier_mapping')}}),

    agg_month as (
    select
        date_trunc('month', changed_at) as month_id,
        supplier_id,
        supplier_name,
        sum(harga) as purchase_idr
    from
        inventory_history
    group by 1, 2,3),

    ranked as (
        select
            a.month_id,
            a.supplier_id,
            a.supplier_name,
            a.purchase_idr,
            row_number() over (partition by a.supplier_id order by a.month_id desc) as rn
        from
            agg_month a
        left join
            supplier_mapping s
        on
            a.supplier_id = s.supplier_id
    )

    select month_id, supplier_id, supplier_name, purchase_idr
    from ranked
    where rn = 1
