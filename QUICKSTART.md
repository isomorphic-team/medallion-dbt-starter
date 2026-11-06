# Quick start

A dbt starter for a medallion warehouse (raw, bronze, silver, gold) with tests, CI and deploy already wired. It runs on your laptop in about ten minutes against synthetic data, with no warehouse account. When you're ready, one repo variable points it at Fabric, Snowflake, BigQuery or Databricks.

The example domain is retail inventory sell-down: deals, stores, SKUs, daily sales, and a recovery rate per deal. Replace it with your own sources once the pattern is familiar.

## 1. Run it

You need Python 3.11+ and git.

```bash
git clone <this repo> && cd medallion-dbt-starter
python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
export DBT_PROFILES_DIR=.                            # Windows: set DBT_PROFILES_DIR=.

dbt seed                                   # land the synthetic raw files
dbt build --exclude resource_type:seed     # build every layer and run every test
```

Expect `PASS=49`. Then look at what you built:

```bash
dbt show -s gold__deal_recovery
```

Your schemas are prefixed with your username (`dev_<you>_silver` and so on), so nobody collides.

## 2. The layers

| Layer | Holds | Rule | dbt's name for it |
| --- | --- | --- | --- |
| **Raw** | Whatever the loader lands: files, exports, API pulls | Owned by the loader. dbt never writes it in prod. | source |
| **Bronze** | One view per raw table | Rename and cast. No filters, joins or business rules. | staging |
| **Silver** | Entities at a stated grain: deal, store, SKU, day | Dedupe, conform, join. Business definitions live here. | intermediate |
| **Gold** | Marts that people, dashboards and agents read | Every column documented and tested. | marts |

Two habits carry most of the weight:

- **Every silver and gold model states its grain** in a `-- Grain:` comment and enforces it with a `unique_grain` test. Most wrong numbers are grain errors: a join that fans out, or a duplicate that slips through.
- **Definitions live once,** in `macros/metrics.sql`. Recovery rate means the same thing in every mart because every mart calls the same macro.

## 3. Make a change

```bash
git checkout -b add-category-mart
# edit or add a model under models/silver or models/gold
dbt build -s +your_model        # your model and everything it depends on
sqlfluff lint models tests
git push -u origin add-category-mart   # open a PR
```

The PR runs `.github/workflows/ci.yml`: lint, then the full build and test suite on DuckDB. Once a warehouse is connected, it runs the same build there in a schema named for the PR (`ci_pr_42_gold`), and `cleanup.yml` drops those schemas when the PR closes. Merging to `main` runs `deploy.yml`, which builds prod. Protect `main` so the CI check is required.

## 4. Testing

| Kind | Where | Catches |
| --- | --- | --- |
| Source checks | `models/bronze/_bronze.yml` | The sender changed a column, a status value or a key |
| Grain and relationships | `models/silver/_silver.yml`, `models/gold/_gold.yml` | Fan-out joins, duplicates, orphaned keys |
| Unit tests | `unit_tests:` in the same files | Logic on hand-built inputs: dedupe, divide-by-zero, no-sales deals |
| Reconciliation | `tests/` | Dollars lost or doubled between bronze and gold |

Tests fail the build by default (`+severity: error`). Lower one only on purpose, and say why in the PR.

Check the tests themselves. Break the model on purpose (remove the `distinct` in `silver__sales_daily`) and confirm something goes red. A test that can't fail tells you nothing.

## 5. Connect a warehouse

1. Create a service identity with write access to its own schemas and read access to raw. Nothing broader.
2. In the GitHub repo, set **Variables**: `DBT_ADAPTER` (the name of a folder under `profiles/`: `fabric`, `snowflake`, `bigquery` or `databricks`), plus whichever of `DBT_HOST`, `DBT_HTTP_PATH`, `DBT_ACCOUNT`, `DBT_DATABASE`, `DBT_WAREHOUSE`, `DBT_CI_ROLE`, `DBT_PROD_ROLE` your adapter uses. See `profiles/<adapter>/profiles.yml`.
3. Set **Secrets**: `DBT_CLIENT_ID`, `DBT_CLIENT_SECRET`, `DBT_TENANT_ID` (Fabric), `DBT_CLIENT_ID`, `DBT_CLIENT_SECRET` (Databricks service principal), or `DBT_USER`, `DBT_PRIVATE_KEY` (Snowflake). BigQuery uses workload identity through the `GCP_*` variables.
4. Create a `production` environment under Settings → Environments. Add required reviewers if a human should approve each prod build.

Until `DBT_ADAPTER` is set, the warehouse jobs skip and only the DuckDB build runs.

For a different warehouse:

1. Copy one of the `profiles/` folders and swap the adapter in its `profiles.yml` and `requirements.txt`. The folder name is what `DBT_ADAPTER` takes.
2. If its profile needs an environment variable the workflows don't pass yet, add it to the `env:` blocks in `ci.yml`, `deploy.yml` and `cleanup.yml`.
3. If its driver needs a system package (Fabric needs ODBC), add the install step to `.github/actions/setup-dbt/action.yml`.
4. Check its text type in the seed `+column_types` in `dbt_project.yml`. Unlisted adapters get plain `varchar`, which is wrong on some warehouses.

## 6. Bring in real sources

1. Point your loader (dlt, Fivetran, a file drop) at a schema called `raw`, or set `raw_schema` in `dbt_project.yml` vars.
2. Add the tables to `models/bronze/_sources.yml` and write one bronze view per table.
3. Add a synthetic seed with the same columns to `seeds/raw/`, so CI can build without production data.

CI runs on synthetic data on purpose. Pointing CI or dev at real customer data is a decision for the data owner and security, made once, in writing.

**Build one source end to end before starting the second.** One source through bronze, silver and gold, a gold mart someone uses, and a green deploy. The second source should reuse the pattern without redesign. If it can't, fix the pattern first.

## 7. Working with Claude Code

`CLAUDE.md` is the agent's rulebook: layer rules, commands and the ten things it must not do. Keep it current. It is the cheapest guardrail you have.

A working loop that holds up:

1. Ask for a plan before any edit. Check the grain it proposes.
2. Let it edit on a branch and run `dbt build` itself. It should read the failures and fix them.
3. Read the diff. Ask it to explain any join you didn't expect.
4. Check one number against a total you know from somewhere else.
5. Open the PR and let CI be the second reviewer.

AI speeds up writing SQL. Checking it takes as long as it did before. The tests, the reconciliation and CI are where your attention goes.

## 8. Rules learned the hard way

From production dbt warehouses that hit each of these:

- **Severity is a blast-radius decision.** A one-row error test on a table at the head of the nightly chain stopped every downstream job for a day, monitoring included. The opposite failure happened too: loose `warn_if` thresholds let small corruption pass as green for days. Set severity per model, based on what sits downstream.
- **A test that compares a column with itself passes forever.** One did for months, then caught its first real defect the day the columns finally diverged.
- **Tags don't enforce anything.** A model tagged "never full refresh" was full-refreshed by an ad-hoc command whose `+` selector pulled in its ancestors, and every ID it minted was reissued. Use `full_refresh=false` in config.
- **One writer per table.** A merge build and the scheduled build ran snapshots at the same moment and planted duplicate rows. The `prod` concurrency group in `deploy.yml` prevents it.
- **A skipped snapshot day can't be recovered.** If snapshots gate on upstream success, you're choosing between a day of possibly bad data and a permanent gap in history. Choose deliberately.
- **Stored test failures add up.** `store_failures` on every test created a table per test per run. The count grew into the thousands and slowed every CI clone. Turn it on for the tests where you'll actually read the failures.
- **Verify the instrument.** A recovery-watch script reported "no run yet" for two hours while the job was succeeding, because of a timestamp format mismatch. When the data and the tooling disagree, check the tooling.

## Layout

```
models/bronze/      sources + one view per raw table
models/silver/      conformed entities, grain tests, unit tests
models/gold/        marts, documented and tested
macros/             schema naming, metric definitions, generic tests, CI cleanup
seeds/raw/          synthetic raw files for dev and CI (disabled in prod)
tests/              reconciliation and other one-off checks
profiles.yml        dev and ci targets (DuckDB)
profiles/<adapter>/ warehouse targets for CI and prod
.github/            CI, deploy, cleanup, PR template
CLAUDE.md           rules for coding agents
```
