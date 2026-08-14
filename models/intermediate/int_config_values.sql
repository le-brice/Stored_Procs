select
    max(case when param_key = 'default.warehouse.code' then param_value end) as default_warehouse_code,
    coalesce(
        try_to_number(max(case when param_key = 'reorder.default.point' then param_value end)),
        10
    ) as default_reorder_point,
    coalesce(
        try_to_number(max(case when param_key = 'reorder.default.qty' then param_value end)),
        50
    ) as default_reorder_qty,
    coalesce(
        try_to_decimal(max(case when param_key = 'recon.tolerance' then param_value end), 18, 4),
        0.01
    ) as recon_tolerance
from {{ ref('stg_config_param') }}
