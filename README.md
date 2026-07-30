# Stored_Procs
Repo of stored procs for use with dbt wizard migration
# RetailDW Stored Procedures

Database: **RetailDW** (SQL Server 2016+)

This repo holds the stored procedures and supporting schema for the retail
operational + reporting database. Originally split out of the old `RMS`
monolith back in 2017, migrated piecemeal ever since.

> NOTE (2019): the nightly batch is orchestrated by SQL Agent job
> `JOB_NightlyBatch` which calls `etl.usp_RunNightlyBatch`. Do **not** run the
> ETL procs by hand on prod unless you know what you're doing — they assume the
> staging tables have already been loaded by the SSIS package.

## Layout

| Folder | Schema(s) | What lives here |
|--------|-----------|-----------------|
| `schema/`            | all        | DDL: schemas, tables, seed reference data, constraints + indexes (`08`) |
| `seed/`              | all        | CSV base data + `load_seed.sql` loader (see below) |
| `procedures/util`    | `util`     | logging, error handling, config, batch control |
| `procedures/customer`| `dbo`      | customer + loyalty maintenance |
| `procedures/inventory`| `inv`     | stock levels, movements, purchase orders, reorder |
| `procedures/orders`  | `sales`    | order capture, payment, fulfilment, returns |
| `procedures/pricing` | `sales`,`dbo` | price lookups, promotions, discounts |
| `procedures/finance` | `fin`      | journals, settlement, reconciliation |
| `procedures/reporting`| `rpt`     | daily/periodic summary builds |
| `procedures/etl`     | `etl`,`stg`| staging loads + nightly orchestration |

## Naming (mostly...)

- `usp_` prefix for procedures. A few older ones are just `sp_` or `proc_` —
  leave them, things reference them by name.
- `_v2` suffix means the original is still around and probably still called
  somewhere. Check before deleting.

## Build order

1. `schema/00`–`schema/06` — schemas and tables, in numeric order.
2. `procedures/util` — everything depends on `util.usp_LogStart` /
   `util.usp_LogEnd`, so these load before anything else.
3. the rest of `procedures/`, in any order.
4. `schema/07_seed_reference.sql` — seed. Must come after util, because it
   calls `util.usp_BuildCalendar`.
5. `schema/08_constraints_indexes.sql` — **last**. The FKs and check
   constraints there are declared `WITH CHECK`, so they validate the rows that
   are already loaded; and several of them cross schemas (`dbo` → `sales`,
   `fin` → `util`) in ways the 01–06 order can't express.

`deploy_all.sql` does all of this in one go (SQLCMD mode).

Note that a few constraints in `08` are deliberately created disabled — they
document relationships the live data genuinely violates. The header comment in
that file explains which and why. Don't re-enable them without reading it.

## Seed data

`seeds/` holds CSV base data and a `seeds/load_seed.sql` loader. It populates
the reference + master tables, then drops the `seeds/feeds/*.csv` raw files into
the `stg.*` staging tables so the ETL / nightly batch has something to chew on.

```
seeds/
  *.csv              ← reference + master data (keyed with explicit ids)
  feeds/*.csv        ← raw landing files (deliberately a bit dirty) for stg.*
  load_seed.sql      ← BULK INSERT loader (SQLCMD: set :seeddir to a server path)
```

Roughly 9,500 data rows:

| File | Rows | |
|---|--:|---|
| `ref_currency` / `ref_country`      |    12 / 32 | |
| `ref_fxrate`                        |        990 | `USD→X`, 11 currencies × 90 days |
| `product_category`                  |         34 | 6 departments + 28 leaves, self-referencing |
| `supplier` / `warehouse`            |    31 / 10 | |
| `product`                           |        600 | ~5% `DISCONTINUED` |
| `price_list` / `price_list_item`    |   6 / 3000 | FX-scaled off `Product.ListPrice` |
| `customer`                          |        500 | + `INACTIVE` / `BLOCKED` / the `C9001`+`C9002` dupes |
| `customer_address`                  |        657 | ~30% have a separate `BILL` address |
| `loyalty_account`                   |        298 | tier derived from lifetime points |
| `stock_level`                       |      2,286 | not every product in every warehouse |
| `promotion` / `gl_account`          |    24 / 28 | all four promo types; full-ish chart of accounts |
| `feeds/raw_order`                   |        806 | ~278 orders |
| `feeds/raw_customer` / `_product` / `_fxrate` | 49 / 36 / 29 | |

Everything satisfies the enforced constraints in `schema/08`, so a clean
`deploy_all.sql` run validates rather than blowing up. FX rates are stored
`USD→X`; `dbo.usp_ConvertCurrency` gets `X→USD` through its inverse-pair
fallback.

Heads up:
- `load_seed.sql` is an **alternative** to the inline `schema/07_seed_reference.sql`
  — run **one or the other**, not both, or they collide on primary keys.
- It's a **first-load** script: assumes the target tables are empty (loads ids
  verbatim under `IDENTITY_INSERT`).
- `BULK INSERT` reads files from the **SQL Server box's** filesystem, not your
  client. Point `:seeddir` at a path the service account can see (or use `bcp`).
- The seed deliberately includes two duplicate customers (`C9001`, `C9002`) so
  `dbo.proc_FixCustomerDupes` actually finds something, and the `feeds/` files
  include bad rows (unknown SKU/customer, zero qty, non-numeric cost) to exercise
  the ETL reject paths. These are intentional, not data-quality bugs to "fix".
- `feeds/raw_customer.csv` also carries rows whose country arrives as a bare
  2-char code we have no `ref.Country` row for (`nl`, `ZZ`), plus free-text
  values that don't map (`Ruritania`). The 2-char ones land verbatim via the
  `LEN(@CountryRaw) = 2` branch in `dbo.usp_UpsertCustomer` and are the reason
  `FK_Cust_Country` is disabled in `schema/08_constraints_indexes.sql`.
- `feeds/raw_order.csv` exercises every branch of the import's three validation
  passes on purpose: unknown SKU, unknown customer, discontinued product,
  `BLOCKED` and `INACTIVE` customers, zero / negative / non-numeric qty, empty
  and non-numeric price, unparseable order date (severity 3 — still imports),
  unknown currency, unknown promo code, one order whose lines disagree about the
  customer (ETL-63), retried rows that the dedupe pass supersedes, and repeated
  SKUs in one order that `usp_AddOrderLine` silently merges. About 92% of orders
  import; the rest reject with a stamped reason. All intentional.

## Known issues / TODO

- `sales.usp_RecalcOrderTotals` and `sales.usp_RecalculateOrderTotals_v2` both
  exist. Pretty sure only one is correct. (see SALES-412)
- FX rates load is flaky, sometimes `etl.usp_LoadFxRates` silently no-ops if the
  feed is late.
- reorder thresholds are hardcoded in a couple of places AND in `util.ConfigParam`.
- nobody is 100% sure what `dbo.proc_FixCustomerDupes` does anymore. it's run
  manually every few months.
- `fin.usp_GenerateSalesJournal` keys off `OrderHeader.ModifiedUtc`, not
  `OrderDate`, so any later edit to an order re-journals it. The delta-only fix
  went in in 2019 and was dropped by the 2020 rewrite. (FIN-412)
- `@Mode = 'BOTH'` on the sales journal double-counts orders that were both
  modified and paid on the same date, and its timing-difference entry excludes
  exactly the orders it's supposed to measure. Finance runs `ACCRUAL`. (FIN-412)
- deferred revenue is recomputed nightly as a delta against the previous
  night's posting. If that posting was reversed, the whole balance re-defers.
  Nothing releases the deferral when the order actually ships. (FIN-503)
- the import's price-variance check compares a feed price in order currency
  against `Product.ListPrice` in USD without converting first, so it's
  meaningless for non-USD orders. Tightening it would reject real GBP orders.
  (ETL-91)
- `@ReprocessRejects = 1` on the import usually does nothing on its own,
  because it clears the reject stamps but not the watermark. (ETL-88)
- the nightly batch's step 40 depends on step 30 only. If the customer load
  (20) fails and the product load (30) succeeds, the import still runs and
  rejects every order for a new customer. `#steps` has one `DependsOn`
  column. (ETL-104)
- external order refs aren't stored on `sales.OrderHeader` at all, so the
  "already imported" check has to interrogate the staging table's own
  history. (ETL-40)
