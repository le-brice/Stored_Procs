select
    categoryid as category_id,
    categoryname as category_name,
    parentcategoryid as parent_category_id,
    defaultmarginpct as default_margin_pct
from {{ ref('product_category') }}
