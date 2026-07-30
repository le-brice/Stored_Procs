select
    pricelistid as price_list_id,
    pricelistname as price_list_name,
    currencycode as currency_code,
    try_to_date(effectivefrom::varchar) as effective_from,
    try_to_date(effectiveto::varchar) as effective_to,
    isactive as is_active
from {{ ref('price_list') }}
