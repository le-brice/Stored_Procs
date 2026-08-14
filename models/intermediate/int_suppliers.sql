with raw_suppliers as (
    select distinct supplier_name
    from {{ ref('stg_raw_products') }}
    where supplier_name is not null
      and supplier_name not in (
          select supplier_name from {{ ref('stg_suppliers') }}
      )
)

select
    supplier_id,
    supplier_name,
    country_code,
    lead_time_days,
    is_active
from {{ ref('stg_suppliers') }}

union all

select
    100000 + row_number() over (order by supplier_name) as supplier_id,
    supplier_name,
    null as country_code,
    7 as lead_time_days,
    1 as is_active
from raw_suppliers
