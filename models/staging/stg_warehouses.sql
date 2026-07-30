select
    warehouseid as warehouse_id,
    warehousecode as warehouse_code,
    warehousename as warehouse_name,
    countrycode as country_code,
    isactive as is_active
from {{ ref('warehouse') }}
