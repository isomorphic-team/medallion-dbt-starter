---
name: adding-a-dimension-or-fact
description: Add or change a dimension, fact or aggregate mart in the gold star schema, following this project's key, unknown-member and testing conventions. Use when asked to add a dim_, fct_ or mart model, a new measure, or a new attribute to gold.
---

# Adding a dimension or fact

Gold is a Kimball star schema built from silver. See `docs/modeling.md` for the reasoning and `docs/conventions.md` for names.

## Decide what it is

- Describes context (who, what, where, when): a **dimension**, `dim_<entity>`.
- Records a measurable event or a periodic count: a **fact**, `fct_<process>`.
- Answers one frequent question by pre-aggregating facts: an **aggregate mart**, plain name.
- A new attribute of an existing entity: add a column to the existing dimension. Don't make a second dimension for the same entity.

State the grain and confirm it with the user before writing SQL.

## Dimensions

- Build from silver, one row per natural key.
- Surrogate key: `{{ dbt_utils.generate_surrogate_key(['<natural key>']) }} as <entity>_key`.
- Keep the natural key as a column.
- `union all` one unknown member: key `{{ unknown_key() }}`, natural key `'unknown'`, readable labels, typed nulls (`cast(null as {{ dbt.type_string() }})`) for the rest.
- Tests: `unique` and `not_null` on the key, `unique_grain` on the natural key.
- Type 1 by default. If the user needs history, follow the Type 2 steps in `docs/modeling.md`.

## Facts

- Build from silver at the declared grain.
- `left join` each dimension on its natural key and `coalesce(<dim>.<key>, {{ unknown_key() }})`. Never an inner join: it drops rows silently.
- Date keys are the date itself. Check the range is inside the `calendar_start` and `calendar_end` vars.
- Keep the source identifier as a degenerate dimension if rows could land on an unknown member.
- Store additive measures. Compute ratios in marts after aggregating, through `macros/metrics.sql`.
- Tests: `unique_grain`, `not_null` plus `relationships` on every key, `non_negative` where it applies.
- Extend the reconciliation test in `tests/` so the new fact's totals tie back to bronze.

## Aggregate marts

- Aggregate facts in CTEs, then join to dimensions. Joining first and aggregating after fans out.
- Ratios use the macros in `macros/metrics.sql`. If the definition you need isn't there, add it there.
- Add a unit test for zero denominators and for rows with no activity.

## Finish

Describe every column in `_gold.yml`, then run `dbt build` and `sqlfluff lint models tests`.
