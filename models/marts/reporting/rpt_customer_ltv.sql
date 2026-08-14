with order_spend as (
    select
        orders.customer_id,
        orders.order_id,
        orders.order_date,
        round(orders.grand_total * rates.usd_rate, 4) as grand_usd
    from {{ ref('fct_orders') }} as orders
    inner join {{ ref('int_order_usd_rates') }} as rates
        on rates.order_id = orders.order_id
    where orders.status not in ('CANCELLED', 'NEW')
),

agg as (
    select
        customer_id,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,
        count(*) as order_count,
        sum(grand_usd) as total_net_spend
    from order_spend
    group by customer_id
)

select
    customer_id,
    first_order_date,
    last_order_date,
    order_count,
    total_net_spend,
    total_net_spend / nullif(order_count, 0) as avg_order_value,
    round(
        total_net_spend
        * case when datediff(day, last_order_date, current_date()) > 365 then 0.5 else 1.0 end,
        2
    ) as ltv_score,
    case
        when total_net_spend >= 12000 then 'VIP'
        when datediff(day, last_order_date, current_date()) > 365 then 'LAPSED'
        when order_count = 1 then 'NEW'
        else 'REGULAR'
    end as segment
from agg
