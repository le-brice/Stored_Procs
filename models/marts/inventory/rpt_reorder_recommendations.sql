select
    stock.warehouse_id,
    product.supplier_id,
    stock.product_id,
    coalesce(stock.reorder_qty, config_values.default_reorder_qty) as recommended_order_qty,
    product.unit_cost,
    coalesce(stock.reorder_qty, config_values.default_reorder_qty) * coalesce(product.unit_cost, 0) as estimated_cost
from {{ ref('stg_stock_levels') }} as stock
inner join {{ ref('int_product_master') }} as product
    on product.product_id = stock.product_id
    and product.status = 'ACTIVE'
cross join {{ ref('int_config_values') }} as config_values
where stock.qty_on_hand - stock.qty_allocated + stock.qty_on_order
    <= coalesce(stock.reorder_point, config_values.default_reorder_point)
  and product.supplier_id is not null
