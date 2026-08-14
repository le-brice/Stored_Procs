select
    raw.row_id,
    raw.external_order_ref,
    raw.customer_no,
    customer.customer_id,
    raw.order_date,
    raw.sku,
    product.product_id,
    raw.qty,
    raw.unit_price,
    raw.promo_code,
    raw.currency_code,
    raw.source_system,
    case
        when raw.customer_no is null then 'missing customer no'
        when customer.customer_id is null then 'unknown customer ' || raw.customer_no
        when product.product_id is null then 'unknown sku ' || coalesce(raw.sku, '(null)')
        when raw.qty is null or raw.qty <= 0 then 'bad qty'
    end as reject_reason
from {{ ref('stg_raw_orders') }} as raw
left join {{ ref('int_customer_master') }} as customer
    on customer.customer_no = raw.customer_no
    and customer.status = 'ACTIVE'
left join {{ ref('int_product_master') }} as product
    on product.sku = raw.sku
    and product.status = 'ACTIVE'
