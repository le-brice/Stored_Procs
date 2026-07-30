# RetailDW dbt Migration Evaluation

This repository has been converted from a starter dbt project plus a large
T-SQL stored procedure estate into a functional dbt analytics project. The
stored procedures remain in `procedures/` as reference material, while the dbt
project now provides the maintained analytical transformation path.

## Performance Evaluation

The migration was successful against the agreed scope: build an analytics DAG
from populated seeds rather than emulate every OLTP side effect from the legacy
stored procedures.

What went well:

- Replaced the default dbt example models with a complete layered project.
- Converted the stored-procedure business flow into deterministic dbt models.
- Preserved core business intent while fixing clear reporting bugs called out
  in the legacy procedure documentation.
- Added model and seed documentation so reviewers can understand grain,
  purpose, and key columns.
- Added generic and custom tests for important financial and reporting checks.
- Validation passed: SQL validation, lint, `dbt run` for all 41 models, tests,
  and downstream validation all completed successfully.

Known limitations:

- The dbt project models analytical outputs, not operational side effects like
  writing purchase orders, stock movement events, loyalty transactions, or batch
  logs.
- Stored procedure orchestration has been replaced by dbt DAG dependencies, so
  `etl.usp_RunNightlyBatch` remains historical reference rather than runtime
  control flow.
- A production-vs-development data comparison with `dbt compare` is still a
  useful optional follow-up before merge.

## Migration Summary

The project now contains:

- 41 dbt models across staging, intermediate, and mart layers.
- 20 documented seeds that provide reference, master, inventory, finance, and
  raw feed data for validation.
- Custom data tests for order total reconciliation, journal balancing, daily
  sales grain, and inventory snapshot grain.
- A simplified `dbt_project.yml` that sets staging and intermediate models to
  views and marts to tables.
- Documented intentional behavior changes, including product-grain top products
  reporting instead of reproducing the legacy category-as-product fallback bug.

Removed legacy starter artifacts:

- `models/example/my_first_dbt_model.sql`
- `models/example/my_second_dbt_model.sql`
- `models/example/schema.yml`

## dbt Project Structure

### `models/staging`

Staging models are thin, typed views over seeds and raw feeds. They standardize
legacy column names into snake_case and perform light parsing only.

Examples:

- `stg_raw_orders` parses order feed dates, quantities, prices, currency, and
  source-system fields.
- `stg_products`, `stg_customers`, and `stg_stock_levels` expose master data in
  a consistent analytical shape.
- `stg_ref_fx_rates`, `stg_ref_countries`, and `stg_ref_currencies` expose
  reference data for downstream enrichment.

### `models/intermediate`

Intermediate models encode the stored-procedure business logic in set-based
SQL. This layer is where validation, enrichment, pricing, promotions, FX, and
order preparation happen.

Important models:

- `int_raw_orders_validated` applies deterministic reject reasons for bad order
  feed rows.
- `int_valid_order_refs` keeps only order references whose lines all pass
  validation.
- `int_order_line_inputs` resolves product, customer, price, and tax inputs.
- `int_order_promotions` calculates valid promotion discounts.
- `int_fx_rates` adds inverse FX rates for currency conversion.
- `int_customer_master` and `int_product_master` combine seeded master data with
  valid raw feed records.

### `models/marts/core`

Core marts are the main order facts used by reporting and finance.

- `fct_orders` creates deterministic order headers from valid raw order groups.
- `fct_order_lines` creates deterministic order line facts, including merged
  repeated SKUs, tax, discounts, and line totals.

### `models/marts/finance`

Finance marts replace the analytical outputs of the finance stored procedures.

- `fct_sales_journal_lines` creates sales journal lines in USD.
- `fct_journal_balance` checks whether generated journal entries balance by
  entry date and source.

### `models/marts/inventory`

Inventory marts replace reporting-oriented inventory procedures.

- `rpt_inventory_snapshot` calculates stock availability, stock value, and
  below-reorder flags.
- `rpt_low_stock_report` identifies low-stock products for purchasing review.
- `rpt_reorder_recommendations` recommends reorder quantities using configured
  or default thresholds.

### `models/marts/reporting`

Reporting marts provide business-consumable outputs.

- `rpt_daily_sales_summary` summarizes daily sales by date, warehouse, and
  category.
- `rpt_customer_ltv` calculates customer spend, recency score, and segment.
- `rpt_top_products_by_revenue` reports product-grain revenue and fixes the
  legacy procedure fallback that mislabeled categories as products.

### `tests`

Custom tests protect the main analytical contracts:

- `assert_order_totals_reconcile` verifies order totals match line totals.
- `assert_sales_journal_balanced` verifies generated journals balance.
- `assert_daily_sales_summary_grain` verifies daily sales summary uniqueness.
- `assert_inventory_snapshot_grain` verifies inventory snapshot uniqueness.

Schema YAML files also add generic tests such as `not_null`, `unique`,
`relationships`, and `accepted_values` on key model columns.

### `seeds`

Seeds are the source data for this migration. They include reference tables,
master data, stock levels, finance accounts, promotions, and raw feed files.

The `seeds/feeds/` files intentionally include dirty input data so the dbt
validation layer can exercise reject logic that previously lived inside T-SQL
procedures.

## Running the Project

Use the standard dbt workflow:

```bash
dbt parse
dbt compile --select staging intermediate marts
dbt run --select staging intermediate marts
dbt test
```

For a production comparison before merge, run `dbt compare` on the affected
models if Fusion deferral is configured.

## Legacy Reference Material

The original stored procedure estate is still available for audit and context:

- `procedures/` contains the T-SQL stored procedures.
- `procedures_overview.md` maps procedure domains and call relationships.
- `schema/` contains the original SQL Server DDL and constraint scripts.
- `deploy_all.sql` remains the legacy SQLCMD deployment entrypoint.

These files document where the business logic came from, but the dbt project is
now the primary analytical transformation interface.
