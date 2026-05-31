with 
    operational_expense as (select * from {{source('toko_db','public_operational_expenses')}})

    select 
        id as operational_expense_id,
        kategori,
        keterangan,
        jumlah,
        payment_method,
        created_by,
        created_at
    from
        operational_expense