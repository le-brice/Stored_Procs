with non_usd_rates as (
    select
        orders.order_id,
        fx.rate
    from {{ ref('fct_orders') }} as orders
    left join {{ ref('int_fx_rates') }} as fx
        on fx.from_currency = orders.currency_code
        and fx.to_currency = 'USD'
        and fx.rate_date <= orders.order_date
    where orders.currency_code <> 'USD'
    qualify row_number() over (
        partition by orders.order_id
        order by fx.rate_date desc nulls last
    ) = 1
)

select
    orders.order_id,
    case
        when orders.currency_code = 'USD' then 1
        else coalesce(non_usd_rates.rate, 1)
    end as usd_rate
from {{ ref('fct_orders') }} as orders
left join non_usd_rates
    on non_usd_rates.order_id = orders.order_id
