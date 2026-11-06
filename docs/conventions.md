# Conventions

Naming, layout and review. Based on dbt's [How we structure our dbt projects](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview) and [How we style our dbt projects](https://docs.getdbt.com/best-practices/how-we-style/0-how-we-style-our-dbt-projects).

## Model names

| Layer | Pattern | Example |
| --- | --- | --- |
| Bronze | `bronze__<entity>` (one per raw table) | `bronze__sales` |
| Silver | `silver__<entity>` | `silver__sales` |
| Gold dimension | `dim_<entity>`, singular | `dim_store` |
| Gold fact | `fct_<process>` | `fct_sales`, `fct_inventory_snapshot` |
| Gold aggregate mart | plain name for the question it answers | `store_performance` |
| Gold bridge | `bridge_<fact>_<dimension>` | `bridge_sale_rep` |

Bronze and silver carry the layer prefix because only engineers read them, and the prefix makes lineage obvious. Gold names are plain because people and tools read them: `gold.dim_store`, not `gold.gold__dim_store`. This follows dbt's advice to name marts by entity and Databricks' use of `dim` and `fact` prefixes for star schemas.

When there are several sources, put the source in bronze names, `bronze__<source>__<entity>`, as dbt does for staging (`stg_stripe__payments`).

## Column names

- `snake_case`, everywhere, from bronze on.
- Surrogate keys end in `_key` (`store_key`). Natural keys keep their business name (`store_number`, `sku`).
- Booleans start with `is_` or `has_`.
- Dates end in `_date` or `_on`, timestamps in `_at`. Store timestamps in UTC.
- Money columns say what they are: `gross_sales`, `discount_amount`, `net_sales`. Not `amount`.
- Rates and ratios end in `_rate` or name the ratio (`sell_through`), and are defined in `macros/metrics.sql`.

## Folders

```
models/bronze/   _sources.yml, _bronze.yml, one view per raw table
models/silver/   _silver.yml, one model per conformed entity
models/gold/     _gold.yml, dimensions, facts and aggregate marts
```

When a layer holds more than about ten models, group by source in bronze and by business area in silver and gold (`gold/finance/`, `gold/merchandising/`). Don't build the same concept twice for two teams; dbt calls `finance_orders` and `marketing_orders` an anti-pattern.

## SQL style

- Lowercase keywords, trailing commas, one column per line.
- CTEs over subqueries. Name each CTE for what it holds.
- Always alias joined tables, and qualify every column in a join.
- `union all`, never bare `union`, unless removing duplicates is the point (then say so in a comment).
- `sqlfluff lint models tests` is the gate. Layout rules are switched off in `.sqlfluff`; correctness rules stay on.

## Reviewing a pull request

The PR template is the checklist. Beyond it, a reviewer checks:

**Grain and joins**
- Does each changed model's `-- Grain:` comment match its `unique_grain` test?
- Could any new join match more than one row? If so, what stops it?
- Does every fact join to its dimensions with a `coalesce` to the unknown key?

**Definitions**
- Is any metric computed inline that belongs in `macros/metrics.sql`?
- Are ratios computed after aggregation, not averaged?

**Tests**
- Does a new model have grain, key and relationship tests?
- Was any test removed, loosened or set to `warn`? Does the PR say why?
- Has someone seen the new tests fail?

**Numbers**
- Is at least one changed number checked against a total from outside the change?
- Do the reconciliation tests still cover the new path?

**Operations**
- Does anything need `full_refresh: false`?
- Is a new source or snapshot covered by freshness and backup? See [operations.md](operations.md).
