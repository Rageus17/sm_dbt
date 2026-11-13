{{ config(materialized='table') }}

{#
    Perkiraan cashflow harian per toko + gabungan semua cabang (store = 'ALL').

    Aktual (day_id <= today) diambil dari mart_toko__cash_in_out tiap schema.
    Forecast (today < day_id <= today + forecast_horizon_days):
      - cash_in_external : rata-rata harian cash masuk dari customer luar selama
                           run_rate_window_days terakhir (sudah termasuk pelunasan utang
                           customer, jadi piutang tidak ditambah lagi biar tidak dobel)
      - opex             : rata-rata harian opex di window yang sama
      - po_out           : jadwal bayar supplier yang sudah diketahui (supplier_payments,
                           tanda terima, receive + 2 bulan). Lewat today + po_payment_lag_days
                           jadwal itu sudah tidak mencakup pembelian baru, jadi ditambah
                           rata-rata harian po_out
      - cash_in_internal : tidak di-forecast (pelunasan antar-toko tidak teratur)

    Transfer internal (excluded_customers() / excluded_suppliers()) dieliminasi di
    baris ALL: cash_in_internal toko A = uang dari toko/proyek owner sendiri, dan sisi
    keluarnya di toko pembayar memang sudah tidak dihitung (excluded_suppliers).

    running_balance mulai dari 0 (tidak ada saldo awal / prive owner).
#}

{% set horizon = var('forecast_horizon_days', 90) %}
{% set window = var('run_rate_window_days', 90) %}
{% set po_lag = var('po_payment_lag_days', 60) %}

{% set stores = [
    ('toko', 'store_toko'),
    ('cm', 'store_cm'),
    ('sk', 'store_sk'),
    ('cat', 'store_aksata'),
] %}

with

    cash_in_out as (
        {% for store, src in stores %}
        select
            '{{ store }}' as store,
            day_id,
            toFloat64(paid_amount) - toFloat64(paid_amount_internal) as cash_in_external,
            toFloat64(paid_amount_internal) as cash_in_internal,
            toFloat64(internal_billed_cost) as internal_billed_cost,
            toFloat64(expense_amount) as opex,
            toFloat64(total_po) as po_scheduled
        from {{ source(src, 'mart_toko__cash_in_out') }}
        -- buang tanggal sampah (mis. 2079) & di luar horizon
        where day_id <= today() + {{ horizon }}
        {% if not loop.last %}union all{% endif %}
        {% endfor %}
    ),

    run_rate as (
        select
            store,
            sum(cash_in_external) / {{ window }} as rr_cash_in_external,
            sum(opex) / {{ window }} as rr_opex,
            sum(po_scheduled) / {{ window }} as rr_po_out
        from cash_in_out
        where day_id between today() - {{ window }} and today() - 1
        group by 1
    ),

    actual as (
        select
            store,
            day_id,
            cash_in_external,
            cash_in_internal,
            internal_billed_cost,
            opex,
            po_scheduled as po_out,
            false as is_forecast
        from cash_in_out
        where day_id <= today()
    ),

    scheduled_future as (
        select store, day_id, po_scheduled
        from cash_in_out
        where day_id > today()
    ),

    forecast as (
        select
            rr.store as store,
            today() + n as day_id,
            rr.rr_cash_in_external as cash_in_external,
            0. as cash_in_internal,
            0. as internal_billed_cost,
            rr.rr_opex as opex,
            coalesce(sf.po_scheduled, 0)
                + if(today() + n > today() + {{ po_lag }}, rr.rr_po_out, 0) as po_out,
            true as is_forecast
        from run_rate rr
        array join range(1, {{ horizon }} + 1) as n
        left join scheduled_future sf
            on rr.store = sf.store and today() + n = sf.day_id
    ),

    per_store as (
        select * from actual
        union all
        select * from forecast
    ),

    consolidated as (
        select
            'ALL' as store,
            day_id,
            sum(cash_in_external) as cash_in_external,
            0. as cash_in_internal,
            0. as internal_billed_cost,
            sum(opex) as opex,
            sum(po_out) as po_out,
            max(is_forecast) as is_forecast
        from per_store
        group by day_id
    ),

    combined as (
        select * from per_store
        union all
        select * from consolidated
    ),

    final as (
        select
            store,
            day_id,
            is_forecast,
            cash_in_external,
            cash_in_internal,
            opex,
            po_out,
            cash_in_external + cash_in_internal - opex - po_out as net_cash_flow,
            sum(cash_in_external + cash_in_internal - opex - po_out)
                over (partition by store order by day_id rows between unbounded preceding and current row) as running_balance,
            -- saldo barang yang sudah dikirim ke toko lain / proyek owner tapi belum dibayar (nilai modal)
            if(store = 'ALL', null,
                sum(internal_billed_cost - cash_in_internal)
                    over (partition by store order by day_id rows between unbounded preceding and current row)
            ) as internal_receivable_cost
        from combined
    )

select * from final
order by store, day_id
