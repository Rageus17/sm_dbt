with
    inventory_history as (select * from {{ref('int_toko__pembelian')}}),
    supplier_mapping as (select * from {{ref('supplier_mapping')}}),

    agg_month as (
    select 
        date_trunc('month',changed_at) as month_id,
        supplier_id,
        sum(harga) as purchase_idr
    from 
        inventory_history
    group by 1,2),

    final as (
        select 
            a.*,
            s.supplier_name
        from 
            agg_month a
        join 
            supplier_mapping s
        on 
            a.supplier_id = s.supplier_id
    )

    select * from final
