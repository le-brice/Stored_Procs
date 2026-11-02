# Purchasing low-stock migration

## Business goal

Purchasing needs a repeatable worklist of warehouse/product combinations requiring
replenishment, with available stock, incoming quantity, and supplier details.
Migrate the existing reporting logic into a small, tested, documented dbt pipeline.

## Starting point

- Original procedure: `procedures--legacy/reporting/usp_LowStockReport.sql`.
- Existing inputs: `stg_stock_levels`, `stg_products`, and `stg_suppliers`.
- Input preview: `analyses/inspect_purchasing_inputs.sql`.
- The existing inventory reports and other business domains are out of scope.

## Scope to agree before implementation

Implement the procedure's **live-stock ELSE branch only**. Preserve its seven output
fields, using the project's snake_case convention. Include every warehouse and let
consumers filter and sort when querying.

The snapshot branch uses different inputs and purchase-order aggregation. It is
not included in this migration. Do not retire the procedure or claim full-procedure
parity after completing this slice.

## Before the session

- Start on `main`, without the new `models/purchasing/` implementation.
- Verify the Snowflake connection, warehouse, development schema, and permissions.
- Confirm the existing stock, product, and supplier seeds are loaded and their
  staging views are available in development. Build only those inputs if needed.
- Preview stock inputs; do not reset seeds or run the whole project during the session.
- Create a working branch from `main` before implementing the transformation.
- Keep the completed solution on `feat/migrate-purchasing-low-stock-report` as a
  recovery reference; do not merge it into the starting branch.

The SQL Server procedure is source material, not executable Snowflake/dbt SQL.
No new packages, project settings, production jobs, or operational writes are needed.
Existing similarly named reports should remain untouched.

## Live implementation request

> Migrate only the live-stock branch of rpt.usp_LowStockReport into a small dbt
> pipeline under models/purchasing. Reuse the three existing staging inputs.
> Preserve the output fields and business rules. Add unit tests for the threshold
> boundary, incoming-stock coverage, allocations, the default reorder point, and
> missing suppliers. Add grain and required-value data tests, plus model and column
> documentation. Build only the relevant slice and inspect the output. Do not edit
> existing models, seeds, project configuration, or unrelated files.

## Acceptance criteria

- Available stock, the reorder rule, and the default threshold match the selected
  procedure branch, including equality at the threshold and negative availability.
- Products without a matching supplier remain visible; product joins retain the
  selected branch's behavior.
- Output grain is one row per warehouse/product, with no duplicate or null keys.
- Tests exercise business edge cases using fixed fixtures, independent of seed data.
- The selected build and tests pass in development, and output is inspected.
- Validate the seven output fields against an equivalent query over the same inputs.
  Do not treat a successful build or matching row counts alone as proof of parity.
- Ship only the two new models, colocated tests/documentation, and a short runbook.
- No production deployment, procedure retirement, scheduling, or snapshot history is
  implied by a successful development build.

## Suggested flow

Read the procedure, inspect the inputs, implement the two-model transformation,
add business-rule tests and documentation, build the selected slice, and inspect
its result and lineage. Finish by stating the migration boundary and what remains.

Production comparison is optional after a baseline exists. The rehearsal environment
has no configured state manifest, so do not rely on dbt compare for the live flow.
Do not hardcode a report row count as an acceptance test; the data may change.
