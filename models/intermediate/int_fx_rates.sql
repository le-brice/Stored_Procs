with combined as (
    select from_currency, to_currency, rate_date, rate
    from {{ ref('stg_ref_fx_rates') }}

    union all

    select from_currency, to_currency, rate_date, rate
    from {{ ref('stg_raw_fx_rates') }}
    where rate_date is not null
      and rate is not null
),

direct_rates as (
    select
        from_currency,
        to_currency,
        rate_date,
        rate
    from combined
    qualify row_number() over (
        partition by from_currency, to_currency, rate_date
        order by rate desc
    ) = 1
),

inverse_rates as (
    select
        to_currency as from_currency,
        from_currency as to_currency,
        rate_date,
        1.0 / nullif(rate, 0) as rate
    from direct_rates
)

select * from direct_rates
union all
select * from inverse_rates
