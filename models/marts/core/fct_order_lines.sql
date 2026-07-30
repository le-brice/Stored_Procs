with merged_lines as (
    select
        orders.external_order_ref,
        dense_rank() over (order by orders.external_order_ref) + 100000 as order_id,
        lines.product_id,
        min(lines.row_id) as first_row_id,
        sum(lines.qty) as qty,
        min_by(lines.unit_price, lines.row_id) as unit_price,
        min_by(lines.tax_rate, lines.row_id) as tax_rate
    from {{ ref('int_valid_order_refs') }} as orders
    inner join {{ ref('int_order_line_inputs') }} as lines
        on lines.external_order_ref = orders.external_order_ref
    group by orders.external_order_ref, lines.product_id
)

select
    order_id * 1000 + row_number() over (
        partition by order_id
        order by first_row_id
    ) as order_line_id,
    order_id,
    row_number() over (
        partition by order_id
        order by first_row_id
    ) as line_no,
    product_id,
    qty,
    unit_price,
    0::decimal(18, 4) as line_discount,
    tax_rate,
    round((unit_price * qty) * tax_rate, 4) as line_tax,
    round((unit_price * qty) + ((unit_price * qty) * tax_rate), 4) as line_total
from merged_lines
