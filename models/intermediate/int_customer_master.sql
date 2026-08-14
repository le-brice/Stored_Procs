with raw_customers as (
    select
        100000 + row_number() over (order by customer_no) as customer_id,
        customer_no,
        first_name,
        last_name,
        email,
        phone,
        country_raw
    from {{ ref('stg_raw_customers') }}
    where customer_no is not null
      and customer_no not in (select customer_no from {{ ref('stg_customers') }})
    qualify row_number() over (partition by customer_no order by row_id) = 1
),

raw_mapped as (
    select
        raw_customers.customer_id,
        raw_customers.customer_no,
        raw_customers.first_name,
        raw_customers.last_name,
        raw_customers.email,
        raw_customers.phone,
        coalesce(country.country_code, raw_customers.country_raw) as country_code,
        'ACTIVE' as status
    from raw_customers
    left join {{ ref('stg_ref_countries') }} as country
        on lower(country.country_name) = lower(raw_customers.country_raw)
        or lower(country.country_code) = lower(raw_customers.country_raw)
)

select * from {{ ref('stg_customers') }}

union all

select * from raw_mapped
