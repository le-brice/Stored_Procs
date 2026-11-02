{{ config(materialized='view') }}

with stock as (
    select
        warehouse_id,
        product_id,
        qty_on_hand,
        qty_allocated,
        qty_on_order,
        coalesce(reorder_point, 10) as reorder_point
    from {{ ref('stg_stock_levels') }}
)

select
    warehouse_id,
    product_id,
    qty_on_hand,
    qty_allocated,
    qty_on_order,
    reorder_point,
    qty_on_hand - qty_allocated as qty_available,
    qty_on_hand - qty_allocated + qty_on_order <= reorder_point as below_reorder
from stock
