select
    row_number() over (order by customerno, email) as row_id,
    nullif(trim(customerno), '') as customer_no,
    nullif(trim(firstname), '') as first_name,
    nullif(trim(lastname), '') as last_name,
    nullif(trim(email), '') as email,
    nullif(trim(phone), '') as phone,
    nullif(trim(country), '') as country_raw
from {{ ref('raw_customer') }}
