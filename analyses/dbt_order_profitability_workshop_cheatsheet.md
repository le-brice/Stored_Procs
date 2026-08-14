# Workshop cheatsheet: migrating `sp_load_order_profitability` to dbt

Use these prompts in order during the workshop. Each one is self-contained, so it also works as a recovery point when a participant gets off track.

## Workshop assumptions

- The legacy procedure is documented in `analyses/legacy_sp_load_order_profitability.sql`.
- The intended migration design is documented in `analyses/legacy_sp_load_order_profitability_migration_plan.md`.
- `raw_orders`, `raw_order_items`, `raw_payments`, `raw_customers`, `raw_guild_memberships`, and `raw_shops` are existing **raw warehouse tables**. They are not dbt seeds in this project.
- The target is Snowflake.
- The output contract is one row per `order_id` in `fct_order_profitability`.
- Preserve the legacy output columns and business logic until a parity comparison is complete.

## 1. Orient to the project and legacy logic

**Goal:** Understand the project conventions and the stored procedure before editing anything.

```text
Review `dbt_project.yml`, the existing models directory structure, `models/staging/_merlinco_sources.yml`, and `analyses/legacy_sp_load_order_profitability.sql`.

I am migrating the Snowflake procedure `sp_load_order_profitability` to dbt. The raw inputs are existing warehouse tables, not seeds. Do not make changes yet.

Summarize:
1. the current project conventions and configured paths;
2. every raw input relation and its role;
3. each temporary-table transformation and its grain;
4. the final fact model grain, output columns, joins, and business rules;
5. any behavior that needs an explicit decision before migration, especially current-versus-as-of-order membership semantics, null rollup behavior, numeric precision, and `loaded_at`.
```

**Expected checkpoint:** A proposed DAG with six staging models, three intermediate models, and `fct_order_profitability`.

## 2. Declare raw warehouse tables as dbt sources

**Goal:** Create a trusted, documented entry point for raw relations.

```text
Update the existing source YAML at `models/staging/_merlinco_sources.yml` to declare these existing Snowflake warehouse tables as dbt sources: `raw_orders`, `raw_order_items`, `raw_payments`, `raw_customers`, `raw_guild_memberships`, and `raw_shops`.

These are warehouse tables, not seeds, so downstream models must use `source()` rather than `ref()`.

First read the current YAML and dbt documentation for source YAML syntax. Preserve existing naming conventions, source definitions, and YAML style. Add concise descriptions that explain each source's business grain. Do not invent database or schema names; use the configuration already present in the project or ask me for the missing source location.

Validate the YAML with `dbt parse` after editing.
```

**Expected checkpoint:** All six raw relations resolve through `source()` and `dbt parse` passes.

## 3. Build the staging models

**Goal:** Move raw cleanup into one model per source entity, retaining source grain.

```text
Implement the staging layer for the order profitability migration.

First inspect the declared sources, existing staging conventions, and the legacy procedure in `analyses/legacy_sp_load_order_profitability.sql`. Then create or update staging models for `orders`, `order_items`, `payments`, `customers`, `guild_memberships`, and `shops` under the configured model path.

Requirements:
- Read every warehouse input through `source()`.
- Use clear CTEs and explicit column lists.
- Preserve the source grain in each staging model; do not aggregate or deduplicate here.
- Move the legacy casts, trimming, casing, and regional normalization into the appropriate staging model.
- Retain source identifiers needed later, including `membership_id` in `stg_guild_memberships` for deterministic current-record tie-breaking.
- Filter null `order_id` values in `stg_orders`, matching the procedure.
- Do not invent columns not present in the source or legacy procedure.

Before editing each SQL file, inspect its upstream source columns. Add or update schema YAML with model and key-column descriptions plus high-value tests. Validate the changed staging models with `dbt build --select +<changed_model>+` and use `dbt show` to inspect representative output.
```

**Expected checkpoint:** Six staging models exist, source data cleanup is centralized, and each model remains at raw-entity grain.

## 4. Build order-item rollup

**Goal:** Create one reliable order-grain item aggregate.

```text
Create `int_order_item_rollup` from `stg_order_items` for the order profitability migration.

Read the staging model, its schema YAML, and the legacy procedure first. The required grain is exactly one row per `order_id`.

Match the procedure's calculations:
- total item quantity;
- gross revenue in copper;
- gross revenue in gold;
- line count;
- count of distinct potion SKUs.

Use `ref('stg_order_items')`, explicit CTEs, and an explicit output column list. Preserve the existing numeric behavior initially so we can complete a parity comparison before making a precision migration.

Add `unique` and `not_null` tests on `order_id`, document the model and output columns, inspect results with `dbt show`, and validate with `dbt build --select +int_order_item_rollup+`.
```

**Expected checkpoint:** `int_order_item_rollup` is one row per order and its sums match the procedure.

## 5. Build payments rollup

**Goal:** Centralize successful-payment logic at order grain.

```text
Create `int_payments_rollup` from `stg_payments` for the order profitability migration.

Read the staging model, schema YAML, and legacy procedure first. The model must have exactly one row per `order_id` and preserve these procedure rules:
- sum payment amounts only when normalized payment status is `success`;
- calculate successful paid amounts in copper and gold;
- retain the latest parsed `paid_at` timestamp;
- flag whether any successful payment exists;
- count all payment attempts.

Use `ref('stg_payments')`, CTEs, and explicit output columns. Do not move payment-state classification into this model; that belongs in the final fact.

Add `unique` and `not_null` tests on `order_id`, document the business logic, inspect the output with `dbt show`, and validate with `dbt build --select +int_payments_rollup+`.
```

**Expected checkpoint:** Payment attempts cannot multiply order rows downstream.

## 6. Build current-membership logic

**Goal:** Isolate and test the highest-risk legacy business rule.

```text
Create `int_memberships_current` from `stg_guild_memberships`.

Read the staging model and the legacy procedure first. Preserve the procedure's exact rule: return one membership row per `customer_id`, selected with `row_number()` ordered by:
1. `valid_to`, treating null/open-ended memberships as `2999-12-31`, descending;
2. `valid_from`, descending;
3. `membership_id`, descending.

The output should contain `customer_id`, `guild_id`, `guild_tier`, `valid_from`, and `valid_to`; it must be one row per customer.

Add `unique` and `not_null` tests on `customer_id`. Also add a dbt unit test that proves the tie-breaking behavior for an open-ended membership and memberships with the same dates. Load the dbt unit-test skill before writing the unit test. Validate with `dbt build --select +int_memberships_current+` and inspect a few customer results with `dbt show`.
```

**Expected checkpoint:** The current-membership definition is explicit, deterministic, and independently tested.

> **Facilitator note:** The legacy procedure joins each order to the customer's current membership, not necessarily their membership at `ordered_at`. Preserve that behavior for parity. Treat an as-of-order join as a deliberate later business change.

## 7. Build the profitability fact

**Goal:** Replace imperative `delete` + `insert` logic with a declarative dbt fact model.

```text
Create `fct_order_profitability` using the completed staging and intermediate models.

First read all upstream SQL and YAML plus `analyses/legacy_sp_load_order_profitability.sql`. The model must produce exactly one row per `order_id` and preserve the legacy final output column set and names.

Requirements:
- Use only `ref()` calls to upstream dbt models; do not directly read raw tables.
- Start with `materialized='table'` to match the legacy full-replacement behavior.
- Preserve the procedure's left joins and calculations for gross revenue, discounts, net revenue, payment amounts, `payment_state`, and `is_home_region_order`.
- Keep current-membership semantics for parity.
- Keep the procedure's null behavior for missing item/payment rollups unless you clearly flag a proposed intentional change.
- Treat `loaded_at` as a model build timestamp with `current_timestamp()` only if it is part of the required output contract; call out that it cannot match historical procedure-run values during parity testing.
- Do not use manual `delete`, `insert`, temporary tables, or hard-coded database relations.

Document the fact model and key fields in schema YAML. Add `unique` and `not_null` tests for `order_id`; add relationships from `customer_id` to `stg_customers.customer_id` and `shop_id` to `stg_shops.shop_id` if the source data is expected to be referentially complete; add accepted values for `payment_state`.

Validate with `dbt build --select +fct_order_profitability+`, then inspect output using `dbt show`.
```

**Expected checkpoint:** A dbt table replaces all temporary tables and the final DML block.

## 8. Validate data quality and grain

**Goal:** Confirm the DAG is safe before comparing it to the legacy output.

```text
Review the completed order profitability DAG for grain and data-quality risks.

Inspect the SQL and schema YAML for every staging, intermediate, and fact model. Confirm that:
- all raw inputs use `source()`;
- all internal dependencies use `ref()`;
- staging models retain entity grain;
- item and payment rollups are one row per `order_id`;
- current memberships are one row per `customer_id`;
- the fact model is one row per `order_id`;
- joins cannot multiply fact rows;
- primary-key, relationship, and accepted-values tests are appropriate;
- no model silently drops columns or invents source fields.

Run the narrowest `dbt build` selector that builds and tests the full fact lineage. Report failures with the specific model/test and the likely root cause. Make targeted fixes and rerun validation.
```

**Expected checkpoint:** The fact DAG builds cleanly and tests the key model contracts.

## 9. Cast the audit spell: install and preview `audit_helper`

**Goal:** Set up `dbt-labs/audit_helper` and use `compare_and_classify_query_results` to classify procedure-versus-dbt differences before cutover.

```text
The order profitability DAG is built and its grain tests pass. Set up the `dbt-labs/audit_helper` package for a parity audit, but do not edit any generated or vendored files.

First inspect the project root for `packages.yml` and `dependencies.yml`, read `dbt_project.yml`, and read dbt package documentation. There is currently no dependency file unless one has since been added.

Add a project-owned package declaration for `dbt-labs/audit_helper` using the latest stable dbt Hub version that is compatible with dbt Fusion. Pin it to a compatible minor-version range. Keep any existing package declarations intact. Run `dbt deps`, then `dbt parse`.

Next, inspect the installed package documentation or macro source only to verify the exact signature and output columns for `audit_helper.compare_and_classify_query_results`. Do not guess its arguments.

Create a project-owned preview audit query in the configured `analyses/` path. It must compare the legacy procedure output relation `analytics.mart.fct_order_profitability` with the new dbt `fct_order_profitability` model using `audit_helper.compare_and_classify_query_results`.

Requirements:
- use `ref('fct_order_profitability')` for the dbt relation;
- use the confirmed legacy relation only after verifying its database, schema, and identifier;
- compare only business columns; exclude `loaded_at` because it is execution-time metadata;
- include `order_id` as the primary key in the macro invocation if the verified signature supports it;
- run the analysis as a preview with `dbt show --favor-state` and a bounded result limit;
- explain the macro's classifications, with special attention to rows that exist only on one side and rows whose business values differ.

Do not change transformation logic solely to make the preview look clean. Identify the first model/column responsible for each unexpected class, then fix and re-run the preview.
```

**Expected checkpoint:** The audit package is version-pinned and installed; the preview classifies parity differences without comparing `loaded_at`.

> **Facilitator note:** `audit_helper` is a microscope, not an amnesia charm. Use it to make mismatches explainable; preserve legacy semantics until the team deliberately agrees to change them.

## 10. Fortify the DAG with tests

**Goal:** Turn the grain, integrity, and business rules discovered during parity work into durable dbt tests.

```text
The parity preview has identified the important contracts for `fct_order_profitability`. Review the completed staging, intermediate, and fact models plus their schema YAML. Then implement the smallest high-value dbt test suite that guards those contracts.

First read current dbt documentation for schema YAML and follow this project's existing `tests:` or `data_tests:` convention exactly. Do not rename existing keys as part of this task.

Add or confirm:
- `unique` and `not_null` on `stg_orders.order_id`, each order-grain intermediate model's `order_id`, and `fct_order_profitability.order_id`;
- `unique` and `not_null` on `int_memberships_current.customer_id`;
- foreign-key relationships from fact `customer_id` and `shop_id` to their staging models only if orphaned keys are invalid in the source domain;
- accepted values on `fct_order_profitability.payment_state`: `paid`, `cancelled`, and `unpaid`;
- a targeted test for nonnegative net revenue only after confirming refunds, credits, and over-discounting are not valid business cases;
- a unit test for the membership tie-break rule if it has not already been implemented;
- a singular test or monitor query for orders missing an item rollup, if null item measures indicate an ingestion defect rather than a valid state.

Document why each non-obvious test exists. Run `dbt parse`, then `dbt build --select +fct_order_profitability+`. For failed tests, inspect the offending records with `dbt show`; do not weaken a test until you have established that its assumption is wrong.
```

**Expected checkpoint:** The finished DAG protects its primary keys, joins, payment classification, and most consequential legacy rules.

> **Facilitator note:** Tests are warding runes around a model contract. Prefer a few rules that catch expensive mistakes over a wall of low-signal checks.

## 11. Enchant the fact with Semantic Layer metrics

**Goal:** Expose governed order-profitability metrics from `fct_order_profitability` using the current Fusion Semantic Layer specification.

```text
Add a Semantic Layer definition for `fct_order_profitability` after the fact model, tests, and parity checks are stable.

First load the dbt Semantic Layer guidance. Inspect all project YAML files for an existing semantic-layer convention. If a `semantic_model:` block is nested under a model, preserve and extend the latest specification. If top-level `semantic_models:` exists, identify it as legacy configuration and use the established project convention unless the workshop explicitly includes a migration. If no semantic layer exists, use the latest Fusion-compatible model-level specification.

Read `fct_order_profitability` SQL and its schema YAML before editing. Confirm that its grain is one row per `order_id`, then define:
- `order` as the primary entity using `order_id`;
- `customer` and `shop` as foreign entities using `customer_id` and `shop_id`;
- `ordered_date` as the default day-grain time dimension;
- categorical dimensions useful for analysis: `order_status`, `order_channel`, `payment_state`, `home_region`, `shop_region`, `guild_tier`, and `favored_discipline`;
- simple metrics with business-friendly labels and descriptions: order count, gross revenue gold, discount gold, net revenue gold, paid amount gold, item quantity, and distinct potions.

Define metrics only from columns and semantics already validated in the fact. Do not add a profitability percentage, payment rate, or cumulative metric until the numerator, denominator, time spine, and treatment of nulls/refunds have been explicitly agreed.

Document the metric business definition, grain, and exclusions. Validate YAML with `dbt parse`, then run `dbt sl validate` when the environment supports it. If semantic validation is unavailable locally, say so clearly and leave the configuration ready for validation in the deployed dbt platform environment.
```

**Expected checkpoint:** Analysts can consistently query the workshop's core order and revenue measures by validated order, customer, shop, date, and categorical dimensions.

> **Facilitator note:** A metric is a named spell the whole kingdom can reuse. Keep the first spellbook small and trustworthy; add advanced ratios and cumulative metrics once their business definitions are settled.

## 12. Prepare cutover and retirement


**Goal:** Shift scheduled ownership to dbt without a risky big-bang change.

```text
Prepare a cutover plan from the legacy Snowflake procedure `analytics.util.sp_load_order_profitability` to the dbt model `fct_order_profitability`.

Review the completed model configuration, tests, parity evidence, and the existing dbt job configuration. Do not trigger or modify production jobs yet.

Produce a concise operational plan covering:
- the dbt command/selector that builds and tests the fact and its lineage;
- required job ordering and upstream dependencies;
- target schema/database expectations;
- whether the dbt table will replace the existing consumer relation or require a temporary compatibility layer;
- a rollback path to the procedure;
- an observation period and monitoring checks;
- criteria for safely retiring the procedure.

Call out any unresolved ownership, permissions, naming, or downstream-consumer decisions that require human input.
```

**Expected checkpoint:** A reversible, production-ready cutover plan.

## Recovery prompts

### A model build fails with a missing upstream relation

```text
This dbt build failed because an upstream relation is missing. Reproduce the failure with `dbt build`, inspect the failed model's `ref()`/`source()` dependencies and project DAG, then identify whether the issue is a missing source declaration, an incorrect relation location, or an upstream model not included in the selector.

Do not change SQL until you have verified the actual upstream columns and relation configuration. Apply the smallest source-controlled fix, then rerun `dbt build --select +<failed_model>+`.
```

### The fact has duplicate `order_id` values

```text
`fct_order_profitability` has duplicate `order_id` values. Investigate the model grain before changing logic.

Inspect each upstream model's grain and test results, especially `int_order_item_rollup`, `int_payments_rollup`, `int_memberships_current`, and all joins into the fact. Use `dbt show` to profile duplicate keys at each layer. Identify the first layer that produces multiple rows for its stated key, fix the grain there, add or strengthen its uniqueness test, then rebuild the fact lineage.
```

### Parity differs only for financial amounts

```text
The dbt fact does not match the legacy procedure for financial fields. Compare the procedure and dbt calculation paths column by column, beginning with raw casts, null handling, aggregation grain, and copper-to-gold conversion.

Use `dbt show` to inspect a small set of mismatched order IDs through staging, intermediate rollups, and the final fact. Preserve the legacy behavior until the parity check is complete. Report the first divergent transformation and make only the targeted fix needed to restore parity.
```

### Participants want to make the fact incremental

```text
Assess whether `fct_order_profitability` is ready to become incremental. Do not implement it yet.

Review raw data arrival patterns and determine a reliable change-detection strategy for orders, order items, payments, customers, shops, and memberships. Explicitly address late-arriving payments/items and dimension changes that could alter historical facts. Recommend a table until a stable watermark, lookback policy, unique key, and backfill strategy are defined. If the requirements are sufficient, propose the exact incremental strategy and validation plan.
```

### The audit preview reports unexplained differences

```text
The `audit_helper.compare_and_classify_query_results` preview shows unexpected differences between the legacy procedure output and `fct_order_profitability`.

Do not change the fact model yet. First group results by the macro's classification and identify whether the difference is:
- a key that appears only in the legacy output;
- a key that appears only in dbt output;
- a row with a different business value;
- an expected execution-time or representation difference, such as excluded `loaded_at` or an explicitly agreed numeric rounding rule.

For a small sample of each unexpected class, trace `order_id` backwards through `stg_orders`, `int_order_item_rollup`, `int_payments_rollup`, `int_memberships_current`, and the final fact using `dbt show`. Find the first divergent model and column, verify the legacy rule, make the narrowest source-controlled correction, rebuild `+fct_order_profitability+`, and rerun the audit preview with `--favor-state`.
```
