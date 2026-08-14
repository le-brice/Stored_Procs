select
    productid as product_id,
    sku,
    productname as product_name,
    categoryid as category_id,
    supplierid as supplier_id,
    unitcost as unit_cost,
    listprice as list_price,
    weight_g,
    status
from {{ ref('product') }}
