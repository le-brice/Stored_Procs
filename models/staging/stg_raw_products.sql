select
    row_number() over (order by sku, productname) as row_id,
    nullif(trim(sku), '') as sku,
    nullif(trim(productname), '') as product_name,
    nullif(trim(categoryname), '') as category_name,
    nullif(trim(suppliername), '') as supplier_name,
    try_to_decimal(nullif(trim(unitcost), ''), 18, 4) as unit_cost,
    try_to_decimal(nullif(trim(listprice), ''), 18, 4) as list_price
from {{ ref('raw_product') }}
