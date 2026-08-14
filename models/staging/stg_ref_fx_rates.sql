select
    fromcurrency as from_currency,
    tocurrency as to_currency,
    ratedate as rate_date,
    rate
from {{ ref('ref_fxrate') }}
