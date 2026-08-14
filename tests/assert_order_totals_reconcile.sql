with line_totals as (
    select
        order_id,
        round(sum(unit_price * qty), 4) as subtotal,
        round(sum(line_tax), 4) as tax_total
    from {{ ref('fct_order_lines') }}
    group by order_id
)

select
    orders.order_id,
    orders.subtotal,
    line_totals.subtotal as line_subtotal,
    orders.tax_total,
    line_totals.tax_total as line_tax_total
from {{ ref('fct_orders') }} as orders
inner join line_totals
    on line_totals.order_id = orders.order_id
where abs(orders.subtotal - line_totals.subtotal) > 0.005
   or abs(orders.tax_total - line_totals.tax_total) > 0.005
