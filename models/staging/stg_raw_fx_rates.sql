select
    row_number() over (order by fromcurrency, tocurrency, ratedatetext) as row_id,
    nullif(trim(fromcurrency), '') as from_currency,
    nullif(trim(tocurrency), '') as to_currency,
    try_to_date(nullif(trim(ratedatetext), '')) as rate_date,
    try_to_decimal(nullif(trim(ratetext), ''), 18, 8) as rate
from {{ ref('raw_fxrate') }}
