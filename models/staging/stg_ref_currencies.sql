select
    currencycode as currency_code,
    currencyname as currency_name,
    minorunits as minor_units
from {{ ref('ref_currency') }}
