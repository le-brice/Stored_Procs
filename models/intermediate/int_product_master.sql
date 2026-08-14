with raw_products as (
    select
        100000 + row_number() over (order by raw.sku) as product_id,
        raw.sku,
        raw.product_name,
        cat.category_id,
        sup.supplier_id,
        raw.unit_cost,
        raw.list_price,
        null as weight_g,
        'ACTIVE' as status
    from {{ ref('stg_raw_products') }} as raw
    left join {{ ref('int_product_categories') }} as cat
        on cat.category_name = raw.category_name
    left join {{ ref('int_suppliers') }} as sup
        on sup.supplier_name = raw.supplier_name
    where raw.sku is not null
      and raw.sku not in (select sku from {{ ref('stg_products') }})
    qualify row_number() over (partition by raw.sku order by raw.row_id) = 1
)

select * from {{ ref('stg_products') }}

union all

select * from raw_products
