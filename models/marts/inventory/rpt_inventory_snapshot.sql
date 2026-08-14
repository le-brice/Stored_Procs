select
    current_date() as snapshot_date,
    stock.warehouse_id,
    stock.product_id,
    stock.qty_on_hand,
    stock.qty_allocated,
    stock.qty_on_hand - stock.qty_allocated as qty_available,
    round(stock.qty_on_hand * coalesce(product.unit_cost, 0), 4) as stock_value,
    case
        when stock.qty_on_hand - stock.qty_allocated + stock.qty_on_order
            <= coalesce(stock.reorder_point, config_values.default_reorder_point)
            then 1
        else 0
    end as below_reorder
from {{ ref('stg_stock_levels') }} as stock
inner join {{ ref('int_product_master') }} as product
    on product.product_id = stock.product_id
cross join {{ ref('int_config_values') }} as config_values
