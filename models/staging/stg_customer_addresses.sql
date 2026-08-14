select
    addressid as address_id,
    customerid as customer_id,
    addresstype as address_type,
    line1,
    line2,
    city,
    postcode as post_code,
    countrycode as country_code,
    isdefault as is_default
from {{ ref('customer_address') }}
