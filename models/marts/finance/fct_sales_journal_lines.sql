with order_amounts as (
    select
        orders.order_date as entry_date,
        round(sum(orders.grand_total * rates.usd_rate), 4) as total_grand,
        round(sum((orders.subtotal - orders.discount_total) * rates.usd_rate), 4) as total_net,
        round(sum(orders.tax_total * rates.usd_rate), 4) as total_tax
    from {{ ref('fct_orders') }} as orders
    inner join {{ ref('int_order_usd_rates') }} as rates
        on rates.order_id = orders.order_id
    where orders.status in ('PAID', 'SHIPPED', 'COMPLETED', 'CONFIRMED')
    group by orders.order_date
),

cogs as (
    select
        orders.order_date as entry_date,
        round(sum(lines.qty * coalesce(product.unit_cost, 0)), 4) as cogs_amount
    from {{ ref('fct_orders') }} as orders
    inner join {{ ref('fct_order_lines') }} as lines
        on lines.order_id = orders.order_id
    inner join {{ ref('int_product_master') }} as product
        on product.product_id = lines.product_id
    where orders.status in ('PAID', 'SHIPPED', 'COMPLETED', 'CONFIRMED')
    group by orders.order_date
),

daily as (
    select
        order_amounts.entry_date,
        order_amounts.total_grand,
        order_amounts.total_net,
        order_amounts.total_tax,
        coalesce(cogs.cogs_amount, 0) as cogs_amount,
        order_amounts.total_grand - (order_amounts.total_net + order_amounts.total_tax) as ar_plug
    from order_amounts
    left join cogs
        on cogs.entry_date = order_amounts.entry_date
    where order_amounts.total_grand <> 0
       or coalesce(cogs.cogs_amount, 0) <> 0
),

journal_lines as (
    select entry_date, 'SALES' as source, 'Daily sales' as description, '1200' as account_code, total_grand as debit_amount, 0 as credit_amount from daily
    union all
    select entry_date, 'SALES', 'Daily sales', '4000', 0, total_net from daily
    union all
    select entry_date, 'SALES', 'Daily sales', '2200', 0, total_tax from daily
    union all
    select entry_date, 'SALES', 'Daily sales', '9999', iff(ar_plug < 0, abs(ar_plug), 0), iff(ar_plug > 0, ar_plug, 0) from daily
    union all
    select entry_date, 'SALES', 'Daily sales', '5000', cogs_amount, 0 from daily
    union all
    select entry_date, 'SALES', 'Daily sales', '1300', 0, cogs_amount from daily
)

select
    md5(journal_lines.entry_date::varchar || '-' || journal_lines.source || '-' || journal_lines.account_code || '-' || journal_lines.debit_amount::varchar || '-' || journal_lines.credit_amount::varchar) as journal_line_key,
    journal_lines.entry_date,
    journal_lines.source,
    journal_lines.description,
    account.gl_account_id,
    journal_lines.account_code,
    journal_lines.debit_amount,
    journal_lines.credit_amount
from journal_lines
left join {{ ref('stg_gl_accounts') }} as account
    on account.account_code = journal_lines.account_code
where debit_amount <> 0
   or credit_amount <> 0
