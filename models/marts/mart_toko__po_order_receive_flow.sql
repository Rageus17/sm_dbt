with 
    po as (select * from {{ref('stg_toko__purchase_orders')}}),
    poi as (select * from {{ref('stg_toko__purchase_order_item')}}),
    ri as (select * from {{ref('stg_toko__po_receiving_items')}}),
    -- satu receiving_log bisa ada di tanda terima yang sudah dihapus + yang baru,
    -- jadi join ke tanda terima aktif dulu supaya baris receive tidak dobel
    tt as (select
            tti.receiving_log_id as receiving_log_id,
            nullIf(tt.tanda_terima_id, 0) as tanda_terima_id,
            tt.kembali_tanggal as kembali_tanggal,
            tt.payment_status as payment_status
        from {{ref('stg_toko__tanda_terima_items')}} tti
        inner join {{ref('stg_toko__tanda_terima')}} tt
        on tti.tanda_terima_id = tt.tanda_terima_id),

    semi as (select 
        po.po_number as po_number,
        p.po_id as po_id,
        p.poi_id as poi_id,
        po.supplier_id,
        po.status as status,
        p.item_id as item_id,
        p.quantity_ordered as qty_ordered,
        r.harga_satuan as harga_satuan,
        r.subtotal as subtotal,
        r.quantity_received as quantity_received,
        r.created_at as received_at,
        r.receiving_log_id as receiving_log_id,
        nullIf(tt.tanda_terima_id, 0) as tanda_terima_id,
        tt.kembali_tanggal as kembali_tanggal,
        nullIf(tt.payment_status, '') as tt_payment_status
    from 
        poi p
    left join 
        ri r
    on 
        p.poi_id = r.poi_id
    and 
        p.item_id = r.item_id
    left join po 
    on 
        p.po_id = po.po_id
    left join tt
    on 
        r.receiving_log_id = tt.receiving_log_id
    where po.status not in  ('CANCELLED','DRAFT',''))

    select *,
        sum(quantity_received) over (partition by po_number, item_id order by received_at) as total_qty,
        -- estimasi bayar ke supplier: tanggal balik tanda terima, kalau belum
        -- masuk tanda terima diasumsikan 2 bulan setelah barang diterima
        coalesce(kembali_tanggal, toDate32(received_at) + interval 2 month) as estimated_pay_date
    from 
        semi
