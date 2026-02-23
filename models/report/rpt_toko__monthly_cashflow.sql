with 

    transaksi_details as (select * from {{ref('stg_toko__transaksi')}}),
    inventory_history as (select * from {{ref('int_toko__pembelian')}}),
    payments as (select * from {{ref('stg_toko__payment')}}),

    payment_filtered as (
        select p.*,
        td.customer_id
        from payments p
        join transaksi_details td
        on p.transaksi_id = td.transaksi_id
             
        where customer_id not in (788, 178, 7, 6)
    ),

    cashflow_in as (
        select 
            date_trunc('month',t.created_at) as month_id,
            sum(total) as trx_in_rp
        from transaksi_details t
        where 
            customer_id not in (788, 178, 7, 6)

        group by 1
    ),

    cf_in_payment as (
        select 
            date_trunc('month',payment_date) as month_id,
            sum(amount) as cashflow_in_paid
        from
            payment_filtered
        where 
            payment_method != 'UTANG'
        group by 1
    ),

    cashflow_out as (
        select 
            date_trunc('month',changed_at) as month_id,
            sum(harga) as cashflow_out
        from 
            inventory_history
        where 
            supplier_id not in (16,37,70,47)
        group by 1
    ),

    final as (
        select 
            ci.month_id,
            trx_in_rp,
            cashflow_in_paid,
            cashflow_out

        from 
            cashflow_in ci
        left join 
            cashflow_out co
        on ci.month_id = co.month_id
        left join cf_in_payment cip
        on ci.month_id = cip.month_id
    )

    select * from final