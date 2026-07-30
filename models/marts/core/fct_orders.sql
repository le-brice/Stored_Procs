with order_ids as (
    select
        dense_rank() over (order by external_order_ref) + 100000 as order_id,
        external_order_ref,
        customer_id,
        order_date,
        currency_code,
        promo_code,
        source_system
    from {{ ref('int_valid_order_refs') }}
),

line_totals as (
    select
        order_id,
        sum(unit_price * qty) as subtotal,
        sum(line_discount) as line_discount_total,
        sum(line_tax) as tax_total
    from {{ ref('fct_order_lines') }}
    group by order_id
),

default_warehouse as (
    select warehouse.warehouse_id
    from {{ ref('stg_warehouses') }} as warehouse
    cross join {{ ref('int_config_values') }} as config_values
    where warehouse.warehouse_code = coalesce(config_values.default_warehouse_code, 'WH01')
    qualify row_number() over (order by warehouse.warehouse_id) = 1
)

select
    order_ids.order_id,
    'ORD-' || lpad(order_ids.order_id::varchar, 8, '0') as order_no,
    order_ids.external_order_ref,
    order_ids.customer_id,
    order_ids.order_date,
    'CONFIRMED' as status,
    order_ids.currency_code,
    promo.promotion_id,
    coalesce(line_totals.subtotal, 0) as subtotal,
    coalesce(promo.discount_total, 0) as discount_total,
    coalesce(line_totals.tax_total, 0) as tax_total,
    0::decimal(18, 4) as shipping_total,
    coalesce(line_totals.subtotal, 0)
        - coalesce(line_totals.line_discount_total, 0)
        - coalesce(promo.discount_total, 0)
        + coalesce(line_totals.tax_total, 0) as grand_total,
    default_warehouse.warehouse_id,
    order_ids.source_system,
    promo.invalid_reason as promo_reject_reason
from order_ids
left join line_totals
    on line_totals.order_id = order_ids.order_id
left join {{ ref('int_order_promotions') }} as promo
    on promo.external_order_ref = order_ids.external_order_ref
cross join default_warehouse
