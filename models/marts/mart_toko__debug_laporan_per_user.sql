{% set payment_methods = ['TUNAI', 'UTANG', 'TRANSFER', 'DEBIT', 'QRIS', 'KREDIT'] %}

with
    payment as (select * from {{ref('stg_toko__transaction_payments')}}),
    trx as (select * from {{ref('stg_toko__transaksi')}} where customer_id not in (788, 178, 7, 6)),
    utang_excluded as (
        select distinct p_utang.transaction_payment_id
        from payment p_utang
        join payment p_other
            on  p_utang.transaksi_id   = p_other.transaksi_id
            and toDate(p_utang.payment_date) = toDate(p_other.payment_date)
            and p_other.payment_method != 'UTANG'
        where p_utang.payment_method = 'UTANG'
    )

    select
        t.transaksi_id,
        t.inputted_by,
        p.recorded_by as payment_recorded_by,
        t.created_at,
        t.items,
        t.total,
        t.total_returned,
        t.subtotal,
        t.diskon_nominal,
        t.customer_id,
        t.total_paid,
        {% for method in payment_methods %}
        sum(case
            when p.payment_method = '{{ method }}'
            {% if method == 'UTANG' %}
                and p.transaction_payment_id not in (select transaction_payment_id from utang_excluded)
            {% endif %}
            then p.amount else 0
        end) as paid_{{ method | lower }}
        {% if not loop.last %},{% endif %}
        {% endfor %}
    from trx t
    
    left join payment p on t.transaksi_id = p.transaksi_id
    group by
        t.transaksi_id,
        t.inputted_by,
        p.recorded_by,
        t.created_at,
        t.items,
        t.total,
        t.total_returned,
        t.subtotal,
        t.diskon_nominal,
        t.customer_id,
        t.total_paid