# Materialization

How each layer is built in the warehouse, and when to change it. Set per folder in `dbt_project.yml`; override per model with `{{ config(materialized=...) }}` only when you can say why.

| Layer | Default | Why |
| --- | --- | --- |
| Bronze | `view` | Rarely queried directly, must always match the source, costs nothing to build. |
| Silver | `table` | Read by several gold models. Databricks recommends silver tables so validation runs once and downstream reads are cheap. |
| Gold | `table` | Read often, by people and tools that expect fast answers. Both dbt and Databricks recommend building marts as tables. |

dbt's rule of thumb ([materialization best practices](https://docs.getdbt.com/best-practices/materializations/5-best-practices)):

> Start with models as views, when they take too long to query, make them tables, when the tables take too long to build, make them incremental.

Bronze starts and usually stays at the first step. Silver and gold start at the second, because they're read more than they're built.

## When to go incremental

A full `table` rebuild reads everything every run. Switch a model to [incremental](https://docs.getdbt.com/docs/build/incremental-models) when the rebuild is too slow or too expensive, and not before: incremental models are harder to reason about and can drift from a full rebuild.

The usual candidates are large facts, like `fct_sales` once it holds years of history. When you convert one:

- Pick a `unique_key` that matches the grain, and an `incremental_strategy` your warehouse supports (`merge` on Snowflake, BigQuery and Databricks; `delete+insert` on several others).
- Filter new rows with a lookback window, not an exact high-water mark, so late-arriving rows get picked up.
- Rebuild from scratch on a schedule (monthly is common) in dev or CI and compare totals, so drift gets caught.
- Set [`full_refresh: false`](https://docs.getdbt.com/reference/resource-configs/full_refresh) on any model that mints IDs or holds history that can't be rebuilt. A tag or a comment saying "don't" enforces nothing.

## Snapshots

[Snapshots](https://docs.getdbt.com/docs/build/snapshots) record slowly changing history (see [modeling.md](modeling.md#slowly-changing-dimensions)). They are tables dbt appends to, never rebuilds, so:

- Exactly one job writes each snapshot. Two concurrent writers produce duplicate rows. The `prod` concurrency group in `deploy.yml` keeps a merge and the schedule from overlapping.
- Back them up. A dropped snapshot can't be rebuilt from source. See [operations.md](operations.md#backups).

## Views on top of gold

If a consumer needs a different shape (renamed columns for a BI tool, a filtered subset for one team), add a view over the gold tables rather than another table. It costs nothing to build and can't drift from the star.

## Warehouse-specific options

Each adapter has performance settings that belong in model config, not in SQL:

- **Databricks**: liquid clustering (`liquid_clustered_by`), `tblproperties`, and Unity Catalog options. See [dbt-databricks configs](https://docs.getdbt.com/reference/resource-configs/databricks-configs).
- **Snowflake**: `cluster_by` for very large tables, `transient` for tables that don't need Time Travel.
- **BigQuery**: `partition_by` and `cluster_by`. Partitioning large facts by date is the biggest single cost lever.
- **Fabric**: keep thread counts low (see `profiles/fabric/profiles.yml`); DDL takes catalog locks.

Add them when a model is measurably slow or expensive, and note the measurement in the PR.
