# Migration plan: `sp_load_order_profitability`

This stored procedure is a good dbt migration demo because it contains a lot of the usual legacy patterns in one place:

- direct reads from raw tables
- inline cleansing and type casting
- temp tables used as pseudo-model layers
- current-record deduping logic
- a full-refresh `delete` + `insert` target load
- business logic mixed into the load step

The dbt version should split those concerns into a small DAG with clear grain at each layer.

## Recommended target DAG

```text
raw seeds
├── raw_orders
├── raw_order_items
├── raw_payments
├── raw_customers
├── raw_guild_memberships
└── raw_shops

staging
├── stg_orders
├── stg_order_items
├── stg_payments
├── stg_customers
├── stg_guild_memberships
└── stg_shops

intermediate
├── int_order_item_rollup
├── int_payments_rollup
└── int_memberships_current

mart
└── fct_order_profitability
```

## Mapping from stored procedure to dbt models

### 1. `tmp_orders_clean` → `stg_orders`

**Current procedure behavior**
- reads `raw_orders`
- parses `ordered_at`
- normalizes `status` and `channel`
- converts `discount_copper` to numeric
- derives `discount_gold`
- filters out null `order_id`

**dbt model responsibility**
`stg_orders` should own all column cleanup for the raw order table.

**Suggested shape**
- grain: one row per `order_id`
- columns:
  - `order_id`
  - `customer_id`
  - `shop_id`
  - `ordered_at`
  - `order_status`
  - `order_channel`
  - `discount_copper`
  - `discount_gold`

**Suggested tests**
- `order_id`: `unique`, `not_null`
- `customer_id`: `not_null`
- `shop_id`: `not_null`

---

### 2. `tmp_order_item_rollup` → `int_order_item_rollup`

**Current procedure behavior**
- aggregates `raw_order_items` to order grain
- calculates quantity, gross revenue, line count, and distinct potions

**dbt model responsibility**
Keep `stg_order_items` at line-item grain, and move the rollup to a separate intermediate model.

**Suggested shape**
- grain: one row per `order_id`
- columns:
  - `order_id`
  - `item_quantity`
  - `gross_revenue_copper`
  - `gross_revenue_gold`
  - `line_count`
  - `distinct_potions`

**Suggested tests**
- `order_id`: `unique`, `not_null`

---

### 3. `tmp_payments_rollup` → `int_payments_rollup`

**Current procedure behavior**
- aggregates payment attempts to order grain
- sums successful payment amounts only
- captures latest paid timestamp
- flags whether the order has any successful payment

**dbt model responsibility**
Keep raw payment cleanup in `stg_payments`, and centralize business rollup logic in an intermediate model.

**Suggested shape**
- grain: one row per `order_id`
- columns:
  - `order_id`
  - `paid_amount_copper`
  - `paid_amount_gold`
  - `latest_paid_at`
  - `has_successful_payment`
  - `payment_attempt_count`

**Suggested tests**
- `order_id`: `unique`, `not_null`

---

### 4. `tmp_membership_current` → `int_memberships_current`

**Current procedure behavior**
- dedupes membership history to a single current record per customer
- picks the latest valid membership using `row_number()`

**dbt model responsibility**
This is classic intermediate logic and should be isolated because it has a business rule worth testing independently.

**Suggested shape**
- grain: one row per `customer_id`
- columns:
  - `customer_id`
  - `guild_id`
  - `guild_tier`
  - `valid_from`
  - `valid_to`

**Suggested tests**
- `customer_id`: `unique`, `not_null`
- optional unit test for tie-breaking / latest-record selection

---

### 5. `tmp_customer_clean` → `stg_customers`

**Current procedure behavior**
- normalizes email case
- standardizes `home_region`
- parses sign-up date and birth year
- normalizes discipline casing

**dbt model responsibility**
All customer cleanup belongs in staging.

**Suggested shape**
- grain: one row per `customer_id`
- columns:
  - `customer_id`
  - `full_name`
  - `email`
  - `home_region`
  - `signed_up_at`
  - `birth_year`
  - `favored_discipline`

**Suggested tests**
- `customer_id`: `unique`, `not_null`

---

### 6. `tmp_shop_clean` → `stg_shops`

**Current procedure behavior**
- standardizes region formatting
- parses `opened_at`

**dbt model responsibility**
This belongs in staging with simple type cleanup and naming alignment.

**Suggested shape**
- grain: one row per `shop_id`
- columns:
  - `shop_id`
  - `shop_name`
  - `city`
  - `shop_region`
  - `opened_at`

**Suggested tests**
- `shop_id`: `unique`, `not_null`

---

### 7. `tmp_fct_order_profitability` + final `delete/insert` → `fct_order_profitability`

**Current procedure behavior**
- joins all cleaned and rolled-up datasets
- derives net revenue and payment state
- flags home-region loyalty
- writes a full replacement of the mart table

**dbt model responsibility**
This becomes a fact model that depends on staging and intermediate models through `ref()`.

**Suggested shape**
- grain: one row per `order_id`
- materialization: start with `table`
- columns:
  - order attributes
  - customer attributes
  - guild attributes
  - shop attributes
  - order item revenue rollups
  - payment rollups
  - final derived metrics and flags

**Suggested tests**
- `order_id`: `unique`, `not_null`
- relationships:
  - `customer_id` → `stg_customers.customer_id`
  - `shop_id` → `stg_shops.shop_id`
- optional assertions:
  - `net_revenue_gold >= 0`
  - accepted values for `payment_state`

## Recommended model order for the live demo

I’d build this in the following order so the migration tells a clear story:

1. declare sources for the raw seed tables
2. build `stg_orders`
3. build `stg_order_items`
4. build `stg_payments`
5. build `stg_customers`
6. build `stg_guild_memberships`
7. build `stg_shops`
8. build `int_order_item_rollup`
9. build `int_payments_rollup`
10. build `int_memberships_current`
11. build `fct_order_profitability`
12. add tests
13. compare the dbt fact output to the procedure output if you want a parity check demo

## What improves in the dbt version

### Lineage
The stored procedure hides dependencies inside imperative SQL. In dbt, every dependency becomes visible through `source()` and `ref()`.

### Testability
The procedure only gives you confidence at the very end. dbt lets you test:
- key uniqueness in staging
- rollup grain in intermediate models
- current-membership selection logic
- fact integrity and relationships

### Reusability
The temp tables in the procedure disappear after execution. In dbt, `stg_customers`, `int_payments_rollup`, and `int_memberships_current` become reusable building blocks for other marts.

### Maintainability
The procedure mixes cleansing, transformation, business rules, and loading into one object. dbt spreads that logic across small models with obvious ownership.

### Deployment flexibility
The proc hard-codes a full-reload pattern. dbt lets you start with a table and later move to incremental if volume or SLA needs change.

## Good demo talking points

- `NR` to `Northern Reaches` is a nice example of low-level cleanup that belongs in staging.
- `row_number()` current-membership logic is a strong example of why an intermediate model deserves its own name.
- `payment_state` is a good example of business logic that becomes much easier to review in a fact model than inside a procedure.
- the final `delete` + `insert` is the easiest contrast point for showing how dbt materializations replace procedural load patterns.

## Suggested follow-up artifacts

If you want to make the demo tighter, the next useful files are:

- `models/staging/sources.yml`
- `models/staging/stg_orders.sql`
- `models/staging/stg_order_items.sql`
- `models/staging/stg_payments.sql`
- `models/staging/stg_customers.sql`
- `models/staging/stg_guild_memberships.sql`
- `models/staging/stg_shops.sql`
- `models/intermediate/int_order_item_rollup.sql`
- `models/intermediate/int_payments_rollup.sql`
- `models/intermediate/int_memberships_current.sql`
- `models/marts/fct_order_profitability.sql`
- supporting `schema.yml` tests
