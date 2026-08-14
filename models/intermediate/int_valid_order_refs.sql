select
    external_order_ref,
    max(customer_no) as customer_no,
    max(customer_id) as customer_id,
    coalesce(max(order_date), current_date()) as order_date,
    max(currency_code) as currency_code,
    max(promo_code) as promo_code,
    max(source_system) as source_system
from {{ ref('int_raw_orders_validated') }}
where external_order_ref is not null
group by external_order_ref
having count_if(reject_reason is not null) = 0
