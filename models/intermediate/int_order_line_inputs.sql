with valid_lines as (
    select raw.*
    from {{ ref('int_raw_orders_validated') }} as raw
    inner join {{ ref('int_valid_order_refs') }} as orders
        on orders.external_order_ref = raw.external_order_ref
    where raw.reject_reason is null
),

price_list_prices as (
    select
        line.row_id,
        item.unit_price
    from valid_lines as line
    inner join {{ ref('stg_price_lists') }} as list
        on list.currency_code = line.currency_code
        and list.is_active = 1
        and list.effective_from <= line.order_date
        and (list.effective_to is null or list.effective_to >= line.order_date)
    inner join {{ ref('stg_price_list_items') }} as item
        on item.price_list_id = list.price_list_id
        and item.product_id = line.product_id
    qualify row_number() over (
        partition by line.row_id
        order by list.effective_from desc
    ) = 1
),

list_price_fx as (
    select
        line.row_id,
        fx.rate
    from valid_lines as line
    inner join {{ ref('int_product_master') }} as product
        on product.product_id = line.product_id
    left join {{ ref('int_fx_rates') }} as fx
        on fx.from_currency = 'USD'
        and fx.to_currency = line.currency_code
        and fx.rate_date <= line.order_date
    qualify row_number() over (
        partition by line.row_id
        order by fx.rate_date desc nulls last
    ) = 1
)

select
    line.row_id,
    line.external_order_ref,
    line.customer_id,
    line.order_date,
    line.product_id,
    line.qty,
    coalesce(
        line.unit_price,
        price_list_prices.unit_price,
        round(product.list_price * coalesce(list_price_fx.rate, 1), 4)
    ) as unit_price,
    case
        when customer.country_code in ('GB', 'FR') then 0.2000
        when customer.country_code = 'IE' then 0.2300
        when customer.country_code = 'DE' then 0.1900
        when customer.country_code = 'CA' then 0.0500
        else 0.0000
    end as base_tax_rate,
    case
        when product.category_id in (12, 19) and customer.country_code in ('GB', 'IE') then 0.0000
        when customer.country_code in ('GB', 'FR') then 0.2000
        when customer.country_code = 'IE' then 0.2300
        when customer.country_code = 'DE' then 0.1900
        when customer.country_code = 'CA' then 0.0500
        else 0.0000
    end as tax_rate
from valid_lines as line
inner join {{ ref('int_product_master') }} as product
    on product.product_id = line.product_id
inner join {{ ref('int_customer_master') }} as customer
    on customer.customer_id = line.customer_id
left join price_list_prices
    on price_list_prices.row_id = line.row_id
left join list_price_fx
    on list_price_fx.row_id = line.row_id
