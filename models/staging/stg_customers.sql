select
    customerid as customer_id,
    customerno as customer_no,
    firstname as first_name,
    lastname as last_name,
    email,
    phone,
    countrycode as country_code,
    status
from {{ ref('customer') }}
