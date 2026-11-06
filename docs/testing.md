# Testing

A dbt project that compiles and runs can still be wrong. Tests are how you find out before someone quotes the number. `dbt build` runs every test right after the model it covers, and a failure stops everything downstream ([dbt: data tests](https://docs.getdbt.com/docs/build/data-tests)).

## What each kind of test is for

| Kind | Where | Catches |
| --- | --- | --- |
| Source checks | `models/bronze/_bronze.yml` | The sender changed a column, a code or a key |
| [Source freshness](https://docs.getdbt.com/docs/build/sources#source-data-freshness) | `models/bronze/_sources.yml` | The loader stopped landing data |
| Grain | `unique_grain` on every silver and gold model | Duplicates and fan-out joins |
| Relationships | Every fact key in `models/gold/_gold.yml` | Orphaned keys, a dimension missing its unknown member |
| Range and nullness | `not_null`, `non_negative`, `accepted_values` | Bad values that pass a type check |
| [Unit tests](https://docs.getdbt.com/docs/build/unit-tests) | `unit_tests:` next to the model | Logic on hand-built inputs: dedupe, divide-by-zero, missing rows |
| Reconciliation | `tests/` | Money lost or doubled between bronze and gold |

### Grain tests

Most wrong numbers are grain errors. A join that matches two rows instead of one doubles a measure, and nothing errors. Every silver and gold model states its grain in a `-- Grain:` comment and enforces exactly those columns with `unique_grain` (in `macros/tests/`). If the test fails, the grain claim is wrong or a join fans out; find out which before changing either.

### Relationship tests

Every foreign key on a fact gets a `relationships` test to its dimension. With an unknown member in each dimension (see [modeling.md](modeling.md#the-unknown-member)), these should never fail: a fact that can't find its dimension row points at `'-1'`. A failure means a model joined without the `coalesce` to the unknown key.

### Unit tests

A unit test feeds hand-written rows to one model and checks the output. Use them for logic that the seed data doesn't exercise: a zero denominator, a store with no sales, a duplicate that should collapse. Keep inputs to the columns the logic needs; dbt fills the rest with nulls.

### Reconciliation tests

A reconciliation test compares a total in gold with the same total computed independently from an earlier layer, and returns rows only when they disagree. `tests/assert_gold_net_sales_reconciles_to_bronze.sql` checks that every dollar of deduplicated bronze sales lands in `fct_sales`. Better still: reconcile against a number from outside the warehouse, such as the source system's own report.

### Source freshness

Add `loaded_at_field` and `freshness` thresholds to each source in production, and run `dbt source freshness` before the build. A stale source otherwise produces a green build of yesterday's numbers.

```yaml
sources:
  - name: raw
    loaded_at_field: _loaded_at
    freshness:
      warn_after: {count: 12, period: hour}
      error_after: {count: 24, period: hour}
```

The synthetic seeds have no load timestamp, so this starter leaves freshness off.

## Severity

Tests fail the build by default (`+severity: error` in `dbt_project.yml`). Lower one only on purpose, one at a time, with the reason in the PR ([dbt: severity](https://docs.getdbt.com/reference/resource-configs/severity)).

Severity is a blast-radius decision. A strict test on a model at the head of the daily run stops everything below it, including any monitoring built on top. A loose `warn_if` threshold lets small corruption ride through as green. Set it per model, based on what sits downstream and how bad a wrong number would be compared with a late one.

## Tests that prove nothing

- **A test that compares a value with itself.** If two columns come from the same expression, a test that they match always passes. Make sure something real could make it fail.
- **A test you've never seen fail.** Break the model on purpose (remove the `distinct` in `silver__sales`) and confirm something goes red. Then put it back.
- **Stored failures nobody reads.** [`store_failures`](https://docs.getdbt.com/reference/resource-configs/store_failures) creates a table per test per run. Turn it on only for tests whose failures someone will look at.

## Running tests

```bash
dbt build                                   # everything, in dependency order
dbt build -s +fct_sales                     # one model, its parents and their tests
dbt test -s test_type:unit                  # unit tests only
dbt test -s store_performance               # tests on one model, without rebuilding
dbt source freshness                        # once freshness is configured
```

## More

- [dbt-utils](https://github.com/dbt-labs/dbt-utils) adds generic tests such as `expression_is_true`, `recency` and `unique_combination_of_columns`. It is already a dependency.
- [Model contracts](https://docs.getdbt.com/docs/mesh/govern/model-contracts) enforce column names and types on gold models at build time. Worth adding once other teams or agents depend on gold.
