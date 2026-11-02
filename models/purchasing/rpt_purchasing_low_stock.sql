{{ config(materialized='table') }}

select
    stock.warehouse_id,
    stock.product_id,
    product.sku,
    product.product_name,
    supplier.supplier_name,
    stock.qty_available,
    stock.qty_on_order as on_order
from {{ ref('int_stock_availability') }} as stock
inner join {{ ref('stg_products') }} as product
    on product.product_id = stock.product_id
left join {{ ref('stg_suppliers') }} as supplier
    on supplier.supplier_id = product.supplier_id
where stock.below_reorder
