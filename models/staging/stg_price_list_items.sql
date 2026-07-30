select
    pricelistitemid as price_list_item_id,
    pricelistid as price_list_id,
    productid as product_id,
    unitprice as unit_price
from {{ ref('price_list_item') }}
