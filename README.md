Original migration prompt: "My project here has a large amount of stored procs in procedures and schemas set in schema. I need you to migrate these stored procedures into dbt models and adhere to best practice. Seeds have already run so data should be available to validate"

# Stored Procedure Migration Summary

This project contained a large SQL Server-style stored procedure estate for a
RetailDW application. Wizard migrated the analytical and reporting behavior into
idiomatic dbt models using the seed data already available in the warehouse.

## Performance

- Migration time: **13m 15s**
- Stored procedure estate reviewed: **51 procedures**
- Source schema files reviewed: **7 schema DDL files**
- dbt models added: **41 staging, intermediate, and mart models**
- Custom data tests added: **4**
- Final validation status: **Passed**

## What Wizard Built

Wizard replaced the starter dbt example models with a layered dbt project:

- `models/staging`: clean, typed wrappers over seeds and raw feed files.
- `models/intermediate`: reusable business logic for FX, customer/product
  enrichment, raw order validation, pricing, tax, promotions, and order USD
  conversion.
- `models/marts/core`: deterministic order header and order line facts.
- `models/marts/reporting`: daily sales, customer LTV, inventory snapshot, and
  top-products reporting marts.
- `models/marts/inventory`: low-stock and reorder recommendation outputs.
- `models/marts/finance`: generated sales journal lines and journal balance
  checks.

## Stored Procedure Logic Migrated

Wizard focused on stored procedure behavior that belongs in dbt: deterministic
analytical transformations and reporting outputs.

Migrated behavior includes:

- Raw order validation from `etl.usp_ImportRawOrders`.
- Customer and product enrichment from raw feeds.
- Product category and supplier auto-creation logic from product loading.
- FX direct and inverse-rate fallback logic from `dbo.usp_ConvertCurrency`.
- Imported unit-price override and price fallback logic.
- Tax-rate logic from `dbo.usp_GetTaxRate`.
- Header-level promotion discount logic from `sales.usp_ApplyPromotion`.
- Order total recalculation logic from `sales.usp_RecalcOrderTotals`.
- Daily sales summary logic from `rpt.usp_BuildDailySales`.
- Customer LTV and segmentation logic from `rpt.usp_BuildCustomerLtv`.
- Inventory snapshot and reorder logic from inventory/reporting procedures.
- Sales journal line generation from `fin.usp_GenerateSalesJournal`.

Wizard intentionally did **not** recreate operational side effects as dbt models:

- Procedure logging and error-log writes.
- Batch-control rows.
- Identity/doc-number generation.
- Cursor orchestration.
- Stock allocation mutations.
- Payment capture, shipment, return, and purchase-order side effects.

This keeps the dbt project aligned with best practice: dbt owns repeatable,
idempotent transformations rather than application transaction workflows.

## Steps Wizard Took

1. Inspected the dbt project state and confirmed the project originally only had
   starter example models plus seeds.
2. Read the schema DDL to understand table grains, keys, and operational domains.
3. Sampled representative procedures across ETL, orders, pricing, inventory,
   finance, and reporting.
4. Separated modelable analytical logic from OLTP-style mutation logic.
5. Confirmed migration choices with the user:
   - migrate analytical models rather than literal procedural side effects;
   - build all available history instead of only yesterday's batch date.
6. Implemented layered dbt models using `ref()` against the existing seeds.
7. Added documentation and generic/custom tests for grains, relationships,
   accepted values, order total reconciliation, and journal balance.
8. Ran dbt validation and iterated on Snowflake-specific issues.
9. Re-ran validation until parse, build, tests, and validation-agent review all
   passed.

## Reasoning and Tradeoffs

The original stored procedures mixed several responsibilities:

- loading and cleansing raw feeds;
- creating and mutating operational records;
- applying pricing, tax, and promotions;
- orchestrating nightly batches;
- producing reporting tables;
- writing logs and error records.

Wizard migrated the deterministic transformation/reporting portions into dbt and
left transactional side effects out of scope. That split is important because dbt
models should be declarative, repeatable, lineage-aware, and safe to rebuild.

Notable decisions:

- Raw order dates are used to build all-history analytical facts.
- Imported unit prices are prioritized, matching the raw order import procedure.
- Orders derived from raw feeds are treated as `CONFIRMED` so seeded data flows
  into marts and finance outputs.
- `rpt_top_products_by_revenue` returns true product-grain results, intentionally
  fixing the legacy procedure's category-as-product fallback bug.
- Finance journal models include balance checks so debit/credit issues are
  visible through dbt tests.

## Validation Results

Wizard ran:

- `dbt parse`
- `dbt compile --select models/staging models/intermediate models/marts`
- `dbt build --select models/staging models/intermediate models/marts tests/assert_*`
- `dbt test --select models/staging models/intermediate models/marts tests/assert_*`
- validation-agent review

Final result:

- Parse: **passed**
- Compile: **passed**
- Build: **passed**
- Tests: **passed**
- Validation agent: **passed**

Only warnings were environment/tooling warnings, including an existing
`--use-colors` warning and dbt state freshness fallback warnings.

## Post-Migration Row Counts

After the successful build, the key marts produced:

| Model | Row count |
| --- | ---: |
| `fct_orders` | 5 |
| `fct_order_lines` | 8 |
| `rpt_daily_sales_summary` | 3 |
| `rpt_customer_ltv` | 5 |
| `rpt_inventory_snapshot` | 90 |
| `fct_sales_journal_lines` | 17 |

## How Wizard Performed

Wizard completed the migration quickly while preserving the important business
rules embedded in the stored procedures. The strongest outcomes were:

- Fast discovery of procedure dependencies and business rules.
- Correct separation of analytical dbt logic from procedural OLTP side effects.
- Snowflake-compatible implementation of SQL Server procedure behavior.
- Iterative validation with fixes for real warehouse compile/build errors.
- Test coverage for the riskiest outputs: order totals, mart grains, and journal
  balancing.
- A final passing dbt build and validation-agent review.

Overall, Wizard performed well for this migration: it transformed a procedural
SQL estate into a maintainable dbt DAG in **13m 15s**, with validated outputs,
clear lineage, and a best-practice modeling structure.
