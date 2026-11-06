---
name: adding-a-source
description: Bring a new raw table into this project end to end, through bronze, silver and gold, with a synthetic seed and tests. Use when asked to add, onboard or model a new source, file, table or feed.
---

# Adding a source

One source goes all the way through before the next one starts. Read `docs/modeling.md` first if you haven't this session.

1. **Agree the grain.** Before any SQL, write down what one row of the raw table means, and what one row of each silver and gold model you'll touch will mean. Confirm it with the user.
2. **Seed.** Add a synthetic file to `seeds/raw/` with the same column headers as the real source. Synthetic values only, never real data. Include at least one exact duplicate row and one value that needs cleaning, so the tests have something to catch. Add each new header to the `+column_types` list in `dbt_project.yml` using `*text`.
3. **Source.** Add the table to `models/bronze/_sources.yml`.
4. **Bronze.** One view, `bronze__<entity>.sql`: rename to `snake_case` with `adapter.quote()` on the raw names, cast with `dbt.type_*()` macros. No filters, joins or dedupe. Add key and accepted-value tests to `_bronze.yml`.
5. **Silver.** `silver__<entity>.sql`: trim, conform case and codes so keys match other silver models, deduplicate, validate. Open with a `-- Grain:` comment; add `unique_grain` on exactly those columns in `_silver.yml`, plus relationships to other silver entities.
6. **Gold.** Decide whether the source is a new dimension, a new fact, or new attributes on an existing one. Follow the `adding-a-dimension-or-fact` skill.
7. **Reconcile.** Add or extend a test in `tests/` that compares a gold total with the same total computed from bronze.
8. **Build and lint.** `dbt build` and `sqlfluff lint models tests` must pass. Then break the new silver model on purpose (remove the dedupe) and confirm a test fails. Put it back.
9. **Document.** Every new gold column gets a description in `_gold.yml`.
