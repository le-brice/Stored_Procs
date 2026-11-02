# Purchasing low-stock pipeline

## Business outcome

Give purchasing a reusable worklist of products requiring replenishment, including
available quantity, incoming stock, and supplier details for each warehouse.

## Migration boundary

Source procedure: `procedures--legacy/reporting/usp_LowStockReport.sql`.
This pipeline implements **the live-stock (ELSE) branch only**. It is an additive
migration slice and does not replace or alter the existing inventory reports.

The snapshot branch has different semantics: it reads today's inventory snapshot
and calculates open quantities from purchase-order headers and lines. That branch
is deliberately outside this migration. Do not claim full procedure equivalence
or retire the procedure until that behavior has been addressed.

## Pipeline

```text
stg_stock_levels -> int_stock_availability -> rpt_purchasing_low_stock
stg_products ------------------------------> rpt_purchasing_low_stock
stg_suppliers -----------------------------> rpt_purchasing_low_stock
```

- `int_stock_availability` is a view at warehouse/product grain. It calculates
  available stock and applies the reorder rule once.
- `rpt_purchasing_low_stock` is a rebuilt table at the same grain, containing only
  low-stock items, enriched with product and optional supplier details.
- Existing staging models and their seeded inputs are reused without file changes.
- All new models, documentation, and tests are contained in this directory.
  No new packages, macros, jobs, or project settings are required.

## Preserved rules

| Procedure behavior | dbt implementation |
| --- | --- |
| Available = on-hand minus allocated | `qty_available` in the availability model |
| Reorder when available + incoming <= threshold | `below_reorder`, including equality |
| Missing reorder point defaults to 10 | `coalesce(reorder_point, 10)`; zero remains zero |
| OnOrder comes from live stock levels | `qty_on_order` exposed as `on_order` |
| Product master inner join | Unknown products do not appear in the report |
| Supplier left join | Missing suppliers do not drop low-stock products |
| Optional warehouse parameter | Query-time filter on `warehouse_id` |
| Sort by availability | Query-time `order by qty_available` |

The report preserves the procedure's seven output fields, using snake_case.
It includes every warehouse. A dbt table has no guaranteed row order.
Negative availability is retained. Null quantities are not silently filled;
not-null data tests surface them as input-quality failures. A relationships test
also surfaces stock referencing a missing product, although the report retains
the original inner-join behavior.

## Tests and documentation

`schema.yml` contains model and column documentation, data tests for composite
grains, required values, and product relationships, plus two fixture-based unit
tests:

1. Reorder boundaries, incoming-stock coverage, allocated stock, default thresholds,
   and negative availability.
2. Report filtering, multiple warehouses, missing suppliers, and the product join.

These fixtures exercise edge cases even when current warehouse data does not.

## Walkthrough

1. Open the original procedure and focus on its live-stock branch. Identify the
   calculation, filter, inner product join, and left supplier join.
2. Open `int_stock_availability.sql`, then `rpt_purchasing_low_stock.sql`. Show how
   business logic and the purchasing output are separated into two small models.
3. Open `schema.yml`. Read one threshold fixture and its expected result, then
   show the grain and column descriptions.
4. Build and test just this dependency slice in the development environment:

   ```text
   dbt build --select +rpt_purchasing_low_stock+ --defer
   ```

   The ancestor selector includes the three staging inputs and their seeds. It
   does not select the existing inventory, LTV, sales, or finance marts.
5. Preview the purchasing worklist, filtering the warehouse when needed and sorting
   by available quantity. Show the lineage and the passing tests together.
6. Compare the new models with deferred production when a baseline exists:

   ```text
   dbt compare --select int_stock_availability+ --defer
   ```

   New models may have no production counterparts until first deployed. A missing
   baseline is not evidence of matching data. Validate live-branch parity separately
   against the equivalent query over the same inputs.

The value of this migration is reusable logic, visible dependencies, explicit
business definitions, and automated regression checks, with a deliberately small
change surface. The output reflects current inputs at the last successful build;
it is not an inventory history or an operational purchase-order workflow.
