# Modeling

How data moves through the layers, and why gold is a star schema. This follows the published guidance from [dbt Labs](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview) and [Databricks](https://docs.databricks.com/aws/en/lakehouse/medallion). Where the two use different words for the same thing, the table below maps them.

## The layers

| Layer | dbt's name | Holds | Keys | Materialized as |
| --- | --- | --- | --- | --- |
| Raw | [source](https://docs.getdbt.com/docs/build/sources) | What the loader lands, untouched | Whatever the source sends | Owned by the loader |
| Bronze | [staging](https://docs.getdbt.com/best-practices/how-we-structure/2-staging) | One view per raw table: renamed and cast | Natural keys, as sent | View |
| Silver | [intermediate](https://docs.getdbt.com/best-practices/how-we-structure/3-intermediate) | Cleaned, validated, deduplicated, conformed entities | Natural keys, conformed | Table |
| Gold | [marts](https://docs.getdbt.com/best-practices/how-we-structure/4-marts) | Dimensions, facts and aggregate marts | Surrogate keys | Table |

Databricks summarizes it as bronze (raw), silver (validated) and gold (enriched), with gold as the place for "dimensional modeling and aggregation". dbt puts the same work in marts. Both agree that the dimensional model is what end users read, so it lives in gold.

### Bronze: rename and cast, nothing else

One view per raw table. Rename columns to `snake_case`, cast to real types, and stop. No filters, joins, deduplication or business rules. If the raw file changes shape, the bronze tests in `_bronze.yml` fail first, and the fix goes in the bronze model or the source contract, not further down.

Bronze is a view because nobody should query it directly and it must always match the source ([dbt: staging views](https://docs.getdbt.com/best-practices/materializations/5-best-practices)).

### Silver: clean, validate, conform

Silver is where the data becomes trustworthy, at source grain. Databricks' rule is that silver "should always include at least one validated, non-aggregated representation of each record."

What happens here:

- **Deduplicate.** `silver__sales` drops exact duplicate rows (a re-exported file) and aggregates rows that legitimately share a grain.
- **Conform.** Trim, fix case, standardize codes, so the same SKU looks the same in every table. `silver__products` and `silver__sales` both upper-case and trim `sku`, which is what lets them join.
- **Validate.** Grain tests, not-null and range tests, relationships between silver entities.
- **Join sources** that describe the same entity, when there is more than one.

Silver keeps natural keys. It doesn't mint surrogate keys or shape data into facts and dimensions; that is gold's job.

### Gold: the dimensional model

Gold is a [Kimball](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/) star schema built from silver, plus aggregate marts for the questions asked most often. It is what people, dashboards and agents read, so every column is documented and every key is tested.

## Dimensional modeling in brief

Ralph Kimball's method splits analytic data into two kinds of table:

- **Facts** record measurable events: a sale, an inventory count, a shipment. They are long and narrow, mostly numbers and foreign keys.
- **Dimensions** describe the context of those events: which store, which product, which day. They are short and wide, mostly text.

A fact table joined to its dimensions forms a star. Analysts filter and group by dimension attributes and aggregate fact measures. The structure is easy to understand and fast to query on every modern warehouse. For deeper reading: the [Kimball Group's technique index](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/), [dbt's guide to dimensional modeling](https://www.getdbt.com/blog/guide-to-dimensional-modeling), and Databricks' three-part series on [implementing a dimensional warehouse](https://www.databricks.com/blog/implementing-dimensional-data-warehouse-databricks-sql-part-1) ([part 2](https://www.databricks.com/blog/implementing-dimensional-data-warehouse-databricks-sql-part-2), [part 3](https://www.databricks.com/blog/implementing-dimensional-data-warehouse-databricks-sql-part-3)).

The four-step design process, from Kimball:

1. **Pick the business process.** Selling, counting inventory, shipping. One fact table per process.
2. **Declare the grain.** One row per what? "Per store, SKU and day." Decide this before choosing columns. It is the contract, and it goes in the model's `-- Grain:` comment and its `unique_grain` test.
3. **Identify the dimensions.** Everything that describes a row at that grain.
4. **Identify the facts.** The numbers measured at that grain.

### In this project

| Model | Type | Grain |
| --- | --- | --- |
| `dim_store` | Dimension | One row per store, plus an unknown member |
| `dim_product` | Dimension | One row per SKU, plus an unknown member |
| `dim_date` | Dimension | One row per calendar day |
| `fct_sales` | Transaction fact, rolled up to the day | One row per store, SKU and day |
| `fct_inventory_snapshot` | Periodic snapshot fact | One row per store, SKU and count date |
| `store_performance` | Aggregate mart | One row per store |

### Keys

- **Natural key**: the identifier the source system uses (`store_number`, `sku`). Kept on the dimension so people can look things up.
- **Surrogate key**: a key the warehouse owns (`store_key`, `product_key`). Facts join to dimensions on it. Here it is a hash of the natural key, from [`dbt_utils.generate_surrogate_key`](https://github.com/dbt-labs/dbt-utils#generate_surrogate_key-source), so it is stable across rebuilds and works the same on every warehouse. Databricks' series uses identity columns instead; a hash avoids keeping a sequence in sync and lets any model compute the key.
- **Degenerate dimension**: an identifier kept on the fact with no dimension table behind it. `fct_sales.sku` stays on the fact so a sale of an unknown product can still be traced.

### The unknown member

Facts sometimes arrive with a natural key the dimension doesn't have: a new SKU sold before the product file caught up. Dropping the row loses money from every total; a null key breaks joins. Kimball's answer, and Databricks' too, is an **unknown member**: one row in each dimension with a fixed key (`'-1'` here, from the `unknown_key()` macro) that facts point at when the lookup fails.

The seed data includes one such sale (SKU `GC-900`). It lands on the unknown product, its net sales count in every total, and its margin is null because the cost is unknown. The reconciliation test proves no dollars went missing.

### Additivity

- **Additive** measures sum across every dimension: units sold, net sales.
- **Semi-additive** measures sum across some dimensions but not time: units on hand. Sum stores and products on one count date; never sum count dates.
- **Non-additive** measures don't sum at all: rates and ratios. Store the numerator and denominator and compute the ratio after aggregating. `store_performance.gross_margin_rate` sums margin and sales first, then divides, through the macros in `macros/metrics.sql`.

### Slowly changing dimensions

Dimension attributes change. A store moves region; a product changes category. Two common responses:

- **Type 1, overwrite.** The dimension always shows the current value, and history is restated. Simple; right when nobody needs the old value. `dim_store` and `dim_product` are Type 1.
- **Type 2, keep history.** Each change adds a new row with `valid_from` and `valid_to` dates, and facts join to the row that was current when the event happened. Right when reports must show the world as it was.

In dbt, Type 2 history comes from [snapshots](https://docs.getdbt.com/docs/build/snapshots). To make `dim_product` Type 2:

1. Add a snapshot over the products source with a `check` strategy on the attributes that matter.
2. Build `dim_product` from the snapshot. The surrogate key becomes a hash of `sku` and `dbt_valid_from`.
3. In `fct_sales`, join on `sku` and `sale_date >= valid_from and (sale_date < valid_to or valid_to is null)`.

Snapshots capture history only from the day they start running, and a missed run can't be recovered later. Decide early which dimensions need history.

### Conformed dimensions

When two facts share a dimension (sales and inventory both use `dim_store` and `dim_product`), it must be the same table with the same keys. That is what lets someone compare sales with stock on hand without reconciling two versions of "store". Build each dimension once, in gold, and have every fact reference it.

### Bridge tables

When a fact relates to many members of a dimension (a sale credited to several sales reps, a patient with several diagnoses), a direct key won't do. A bridge table holds one row per fact and member pair, often with an allocation weight so totals still add up. Add one only when the many-to-many is real; most are a sign the grain needs another look.

## Where definitions live

A metric used in more than one place (gross margin rate, sell-through) is defined once, in `macros/metrics.sql`, and every model calls the macro. When the project outgrows macros, the [dbt Semantic Layer](https://docs.getdbt.com/best-practices/how-we-build-our-metrics/semantic-layer-1-intro) is the next step: metrics defined in YAML on top of the gold star, queried the same way by dashboards and agents.

## Further reading

- dbt: [How we structure our dbt projects](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview)
- dbt: [Dimensional modeling](https://docs.getdbt.com/terms/dimensional-modeling)
- Databricks: [What is the medallion lakehouse architecture?](https://docs.databricks.com/aws/en/lakehouse/medallion)
- Databricks: [Data warehouse modeling techniques on the lakehouse](https://www.databricks.com/blog/2022/06/24/data-warehousing-modeling-techniques-and-their-implementation-on-the-databricks-lakehouse-platform.html)
- Kimball Group: [Dimensional modeling techniques](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/)
- Ralph Kimball and Margy Ross, *The Data Warehouse Toolkit*, 3rd edition (Wiley, 2013). The reference text.
