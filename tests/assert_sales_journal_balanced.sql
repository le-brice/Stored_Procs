select *
from {{ ref('fct_journal_balance') }}
where not is_balanced
