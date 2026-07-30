select
    paramkey as param_key,
    paramvalue as param_value,
    paramtype as param_type,
    description
from {{ ref('config_param') }}
