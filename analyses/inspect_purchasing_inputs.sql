-- Input inspection only; no reorder calculation or report filtering.
-- Run against development after the existing staging inputs are available.
select
    warehouse_id,
    product_id,
    qty_on_hand,
    qty_allocated,
    qty_on_order,
    reorder_point,
    reorder_qty
from {{ ref('stg_stock_levels') }}
order by warehouse_id, product_id
