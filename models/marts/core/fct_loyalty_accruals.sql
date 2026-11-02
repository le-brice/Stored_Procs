-- Analytical projection of the EARN branch of dbo.usp_AccrueLoyalty.
-- Shipment events and return clawbacks are not available in the current feeds.
with loyalty_config as (
    select
        coalesce(
            try_to_decimal(max(param_value), 18, 6),
            1::decimal(18, 6)
        ) as points_rate
    from {{ ref('stg_config_param') }}
    where param_key = 'loyalty.points.per.currency.unit'
),

order_amounts as (
    select
        orders.order_id,
        orders.external_order_ref,
        orders.customer_id,
        orders.order_date,
        orders.currency_code,
        greatest(orders.subtotal - orders.discount_total, 0)::decimal(18, 4) as net_amount,
        loyalty_config.points_rate
    from {{ ref('fct_orders') }} as orders
    cross join loyalty_config
),

accruals as (
    select
        order_id,
        external_order_ref,
        customer_id,
        order_date,
        currency_code,
        net_amount,
        points_rate,
        floor(net_amount * points_rate)::integer as points,
        'EARN' as txn_type
    from order_amounts
)

select
    order_id,
    external_order_ref,
    customer_id,
    order_date,
    currency_code,
    net_amount,
    points_rate,
    points,
    txn_type
from accruals
where points <> 0
