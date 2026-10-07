# CLAUDE.md

Instructions for Claude Code and any other agent working in this repo. Humans: start with QUICKSTART.md.

## What this is

A dbt project in three layers. Raw data is owned by the loader; dbt owns everything after it.

| Layer | Folder | Holds | Rule |
| --- | --- | --- | --- |
| Bronze | `models/bronze/` | One view per raw table | Rename and cast only. No filters, joins or business logic. |
| Silver | `models/silver/` | Conformed entities at a stated grain | Business logic lives here. Definitions go in `macros/metrics.sql`. |
| Gold | `models/gold/` | Marts people and agents read | Every column documented and tested. |

## Commands

```bash
dbt seed                                   # load synthetic raw data into your dev schemas
dbt build --exclude resource_type:seed     # build and test everything, fail fast
dbt build -s +my_model                     # one model and what it depends on
sqlfluff lint models tests
```

`DBT_PROFILES_DIR=.` must be set (see QUICKSTART.md). The default target is `dev`, on local DuckDB.

## Rules

1. **Never write to prod from a laptop.** Prod changes only through a merged PR and the deploy workflow. Do not use `--target prod`.
2. **Never pass `--full-refresh` to prod.** Any incremental model or model that mints IDs gets `full_refresh=false` in its config. A tag saying "don't" enforces nothing.
3. **State the grain.** Every silver and gold model opens with a `-- Grain:` comment and carries a `unique_grain` test on exactly those columns. Ask before changing the grain of an existing model.
4. **Use `dbt build`,** not `dbt run` then `dbt test`. A failing test has to stop everything downstream of it.
5. **Don't weaken a test to get green.** If a test fails, find out why. If lowering severity is right, say why in the PR.
6. **No test that compares a value with itself.** If two columns are derived from the same expression, a test comparing them always passes and proves nothing. Make sure something real could make the test fail.
7. **Check numbers against a total you didn't compute,** such as the source system's own report, a reconciliation test or a hand count. Compiling and running is not the same as correct.
8. **Definitions live in one place.** Recovery rate, sell-through and anything like them go in `macros/metrics.sql`. Don't re-derive them inline.
9. **No real data in the repo.** Seeds, unit test fixtures and PR descriptions use synthetic values only.
10. **Cast before dividing.** Integer division truncates on some warehouses. The metric macros already cast; follow the pattern.

## When you're done

Run `dbt build` and `sqlfluff lint`. Both must pass before you open a PR. Fill in the PR template.
