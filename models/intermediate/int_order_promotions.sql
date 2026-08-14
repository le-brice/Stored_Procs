with order_subtotals as (
    select
        orders.external_order_ref,
        orders.promo_code,
        orders.order_date,
        sum(lines.unit_price * lines.qty) as subtotal
    from {{ ref('int_valid_order_refs') }} as orders
    inner join {{ ref('int_order_line_inputs') }} as lines
        on lines.external_order_ref = orders.external_order_ref
    group by 1, 2, 3
),

promo_lines as (
    select
        order_subtotals.external_order_ref,
        order_subtotals.order_date,
        promo.promotion_id,
        promo.promo_type,
        order_subtotals.subtotal,
        sum(
            case
                when promo.category_id is not null
                    and product.category_id = promo.category_id
                    then lines.unit_price * lines.qty
                else 0
            end
        ) as category_subtotal,
        promo.discount_pct,
        promo.discount_amt,
        case
            when promo.promotion_id is null then 'Unknown promo code'
            when promo.is_active = 0 then 'Promotion inactive'
            when order_subtotals.order_date < promo.effective_from
                or (promo.effective_to is not null and order_subtotals.order_date > promo.effective_to)
                then 'Promotion not in effective window'
            when promo.min_spend is not null and order_subtotals.subtotal < promo.min_spend
                then 'Subtotal below minimum spend'
            when promo.max_redemptions is not null and promo.times_redeemed >= promo.max_redemptions
                then 'Promotion fully redeemed'
        end as invalid_reason
    from order_subtotals
    left join {{ ref('stg_promotions') }} as promo
        on promo.promo_code = order_subtotals.promo_code
    left join {{ ref('int_order_line_inputs') }} as lines
        on lines.external_order_ref = order_subtotals.external_order_ref
    left join {{ ref('int_product_master') }} as product
        on product.product_id = lines.product_id
    where order_subtotals.promo_code is not null
    group by
        order_subtotals.external_order_ref,
        order_subtotals.order_date,
        promo.promotion_id,
        promo.promo_type,
        order_subtotals.subtotal,
        promo.discount_pct,
        promo.discount_amt,
        promo.category_id,
        promo.is_active,
        promo.effective_from,
        promo.effective_to,
        promo.min_spend,
        promo.max_redemptions,
        promo.times_redeemed
)

select
    external_order_ref,
    promotion_id,
    invalid_reason,
    case
        when invalid_reason is not null then 0
        when promo_type = 'PCT' then least(
            subtotal,
            coalesce(nullif(category_subtotal, 0), subtotal) * (discount_pct / 100.0)
        )
        when promo_type = 'AMOUNT' then least(subtotal, coalesce(discount_amt, 0))
        when promo_type = 'FREESHIP' then 0
        else 0
    end as discount_total
from promo_lines
