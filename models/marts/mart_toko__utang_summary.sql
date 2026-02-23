with

    payments as (select * from {{ ref('stg_toko__payment') }}),
    transaksi as (select * from {{ ref('stg_toko__transaksi') }}),

    utang_transactions as (
        select distinct transaksi_id
        from payments
        where payment_method = 'UTANG'
    ),

    utang_start as (
        select
            transaksi_id,
            min(payment_date) as utang_at
        from
            payments
        where
            payment_method = 'UTANG'
        group by 1
    ),

    utang_payments as (
        select
            transaksi_id,
            count(*) as total_cicilan,
            max(payment_date) as last_payment_at
        from
            payments
        where
            transaksi_id in (select transaksi_id from utang_transactions)
            and payment_method != 'UTANG'
        group by 1
    ),

    final as (
        select
            t.transaksi_id,
            t.customer_id,
            t.nama_pelanggan,
            t.total,
            t.outstanding_balance,
            t.payment_status,
            us.utang_at,
            case
                when t.payment_status = 'PAID'
                    then up.last_payment_at
            end as paid_fully_at,
            coalesce(up.total_cicilan, 0) as total_cicilan,
            case
                when t.payment_status = 'PAID'
                    then up.last_payment_at::date - us.utang_at::date
            end as days_to_pay
        from
            transaksi t
        inner join
            utang_start us
            on t.transaksi_id = us.transaksi_id
        left join
            utang_payments up
            on t.transaksi_id = up.transaksi_id
    )

    select * from final
