with order_category_lines as (
    select
        orders.order_date as summary_date,
        orders.warehouse_id,
        coalesce(product.category_id, 0) as category_id,
        orders.order_id,
        lines.qty,
        lines.unit_price * lines.qty as gross,
        lines.line_discount,
        lines.unit_price * lines.qty - lines.line_discount as line_net_before_header_discount,
        lines.qty * coalesce(product.unit_cost, 0) as cost,
        orders.discount_total as order_discount_total,
        sum(lines.unit_price * lines.qty) over (partition by orders.order_id) as order_gross
    from {{ ref('fct_orders') }} as orders
    inner join {{ ref('fct_order_lines') }} as lines
        on lines.order_id = orders.order_id
    inner join {{ ref('int_product_master') }} as product
        on product.product_id = lines.product_id
    where orders.status not in ('CANCELLED', 'NEW')
      and orders.warehouse_id is not null
),

allocated as (
    select
        *,
        case
            when order_gross = 0 then 0
            else round(order_discount_total * (gross / order_gross), 4)
        end as allocated_header_discount
    from order_category_lines
)

select
    summary_date,
    warehouse_id,
    category_id,
    count(distinct order_id) as order_count,
    sum(qty) as units_sold,
    sum(gross) as gross_revenue,
    sum(line_discount + allocated_header_discount) as discount_total,
    sum(line_net_before_header_discount - allocated_header_discount) as net_revenue,
    sum(line_net_before_header_discount - allocated_header_discount) - sum(cost) as est_margin
from allocated
group by 1, 2, 3
