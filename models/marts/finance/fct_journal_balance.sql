select
    entry_date,
    source,
    round(sum(debit_amount), 4) as debit_amount,
    round(sum(credit_amount), 4) as credit_amount,
    round(sum(debit_amount) - sum(credit_amount), 4) as variance_amount,
    abs(round(sum(debit_amount) - sum(credit_amount), 4)) <= 0.005 as is_balanced
from {{ ref('fct_sales_journal_lines') }}
group by 1, 2
