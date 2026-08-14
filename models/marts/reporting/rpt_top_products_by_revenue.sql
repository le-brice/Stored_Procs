select
    product.product_id,
    product.product_name,
    product.category_id,
    sum(lines.unit_price * lines.qty - lines.line_discount) as net_revenue,
    sum(lines.qty) as units_sold,
    min(orders.order_date) as first_order_date,
    max(orders.order_date) as last_order_date
from {{ ref('fct_orders') }} as orders
inner join {{ ref('fct_order_lines') }} as lines
    on lines.order_id = orders.order_id
inner join {{ ref('int_product_master') }} as product
    on product.product_id = lines.product_id
where orders.status not in ('CANCELLED', 'NEW')
group by 1, 2, 3
