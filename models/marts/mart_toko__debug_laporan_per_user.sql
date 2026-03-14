{% set payment_methods = ['TUNAI', 'UTANG', 'TRANSFER', 'DEBIT', 'QRIS', 'KREDIT'] %}

with
    payment as (select * from {{ref('stg_toko__transaction_payments')}}),
    trx as (select * from {{ref('stg_toko__transaksi')}})

    select
        t.transaksi_id,
        t.created_at,
        t.items,
        t.total,
        t.total_returned,
        t.subtotal,
        t.diskon_nominal,
        t.customer_id,
        t.total_paid,
        {% for method in payment_methods %}
        sum(case when p.payment_method = '{{ method }}' then p.amount else 0 end) as paid_{{ method | lower }}
        {% if not loop.last %},{% endif %}
        {% endfor %}
    from trx t
    left join payment p on t.transaksi_id = p.transaksi_id
    group by
        t.transaksi_id,
        t.created_at,
        t.items,
        t.total,
        t.total_returned,
        t.subtotal,
        t.diskon_nominal,
        t.customer_id,
        t.total_paid