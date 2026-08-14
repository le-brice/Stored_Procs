select
    promotionid as promotion_id,
    promocode as promo_code,
    description,
    promotype as promo_type,
    discountpct as discount_pct,
    discountamt as discount_amt,
    minspend as min_spend,
    categoryid as category_id,
    try_to_date(effectivefrom::varchar) as effective_from,
    try_to_date(effectiveto::varchar) as effective_to,
    maxredemptions as max_redemptions,
    isactive as is_active,
    0 as times_redeemed
from {{ ref('promotion') }}
