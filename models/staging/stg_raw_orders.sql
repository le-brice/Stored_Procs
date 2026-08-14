select
    row_number() over (order by externalorderref, sku, qty, unitpricetext) as row_id,
    nullif(trim(externalorderref), '') as external_order_ref,
    nullif(trim(customerno), '') as customer_no,
    try_to_date(nullif(trim(orderdatetext), '')) as order_date,
    nullif(trim(sku), '') as sku,
    try_to_number(nullif(trim(qty), '')) as qty,
    try_to_decimal(nullif(trim(unitpricetext), ''), 18, 4) as unit_price,
    nullif(trim(promocode), '') as promo_code,
    coalesce(nullif(trim(currencycode), ''), 'USD') as currency_code,
    nullif(trim(sourcesystem), '') as source_system
from {{ ref('raw_order') }}
