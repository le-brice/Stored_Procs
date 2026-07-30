select
    supplierid as supplier_id,
    suppliername as supplier_name,
    countrycode as country_code,
    leadtimedays as lead_time_days,
    isactive as is_active
from {{ ref('supplier') }}
