# Quick start

A dbt starter for a medallion warehouse (raw, bronze, silver, gold) with tests, CI and deploy already wired. It runs on your laptop in about ten minutes against synthetic data, with no warehouse account. When you're ready, one repo variable points it at Fabric, Snowflake, BigQuery or Databricks.

The example domain is a small outdoor-gear retail chain: stores, products, daily sales and inventory counts, modeled as a star schema with sell-through and gross margin per store. Replace it with your own sources once the pattern is familiar.

## 1. Run it

You need Python 3.11+ and git.

```bash
git clone <this repo> && cd medallion-dbt-starter
python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
export DBT_PROFILES_DIR=.                            # Windows: set DBT_PROFILES_DIR=.

dbt deps                                   # install packages (dbt_utils)
dbt seed                                   # land the synthetic raw files
dbt build --exclude resource_type:seed     # build every layer and run every test
```

Expect `PASS=80`. Then look at what you built:

```bash
dbt show -s store_performance
```

Your schemas are prefixed with your username (`dev_<you>_silver` and so on), so nobody collides.

## 2. The layers

| Layer | Holds | Rule | dbt's name for it |
| --- | --- | --- | --- |
| **Raw** | Whatever the loader lands: files, exports, API pulls | Owned by the loader. dbt never writes it in prod. | source |
| **Bronze** | One view per raw table | Rename and cast. No filters, joins or business rules. | staging |
| **Silver** | Cleaned, deduplicated, conformed entities at source grain | Validate and conform. Natural keys. | intermediate |
| **Gold** | A star schema of dimensions and facts, plus aggregate marts | Surrogate keys, every column documented and tested. | marts |

Gold follows [Kimball dimensional modeling](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/), the layout [Databricks](https://docs.databricks.com/aws/en/lakehouse/medallion) and [dbt](https://docs.getdbt.com/best-practices/how-we-structure/4-marts) both recommend for the layer people read: `dim_store`, `dim_product` and `dim_date` describe; `fct_sales` and `fct_inventory_snapshot` measure; `store_performance` answers the common question in one table. [docs/modeling.md](docs/modeling.md) explains the theory and every choice made here.

Two habits carry most of the weight:

- **Every silver and gold model states its grain** in a `-- Grain:` comment and enforces it with a `unique_grain` test. Most wrong numbers are grain errors: a join that fans out, or a duplicate that slips through.
- **Definitions live once,** in `macros/metrics.sql`. Gross margin rate means the same thing everywhere because every model calls the same macro.

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
| Source checks | `models/bronze/_bronze.yml` | The sender changed a column, a code or a key |
| Grain and relationships | `models/silver/_silver.yml`, `models/gold/_gold.yml` | Fan-out joins, duplicates, orphaned keys |
| Unit tests | `unit_tests:` in the same files | Logic on hand-built inputs: dedupe, divide-by-zero, stores with no sales |
| Reconciliation | `tests/` | Dollars lost or doubled between bronze and gold |

Tests fail the build by default (`+severity: error`). Lower one only on purpose, and say why in the PR.

Check the tests themselves. Break the model on purpose (remove the `distinct` in `silver__sales`) and confirm something goes red. A test that can't fail tells you nothing. More in [docs/testing.md](docs/testing.md).

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
4. Conform it in silver, then decide where it lands in the star: a new dimension, a new fact, or new attributes on an existing one.

The `adding-a-source` skill walks an agent through the same steps.

CI runs on synthetic data on purpose. Pointing CI or dev at real data is a decision for the data owner and security, made once, in writing.

**Build one source end to end before starting the second.** One source through bronze, silver and gold, a gold table someone uses, and a green deploy. The second source should reuse the pattern without redesign. If it can't, fix the pattern first.

Running it day to day (access, secrets, scheduling, cost, backups) is in [docs/operations.md](docs/operations.md).

## 7. Working with Claude Code

`CLAUDE.md` is the agent's rulebook: layer rules, commands and the rules it must not break. Keep it current. It is the cheapest guardrail you have.

The project's own skills live in `.claude/skills/`. For dbt Labs' general skills, install their plugin once:

```
/plugin marketplace add dbt-labs/dbt-agent-skills
/plugin install dbt@dbt-agent-marketplace
```

A working loop that holds up:

1. Ask for a plan before any edit. Check the grain it proposes.
2. Let it edit on a branch and run `dbt build` itself. It should read the failures and fix them.
3. Read the diff. Ask it to explain any join you didn't expect.
4. Check one number against a total you know from somewhere else.
5. Open the PR and let CI be the second reviewer.

AI speeds up writing SQL. Checking it takes as long as it did before. The tests, the reconciliation and CI are where your attention goes. More in [docs/agents.md](docs/agents.md).

## 8. Rules worth keeping

- **Severity is a blast-radius decision.** A strict test at the head of the daily run stops everything below it, monitoring included. A loose threshold lets small corruption pass as green. Set severity per model, based on what sits downstream.
- **A test that compares a column with itself passes forever.** Make sure something real could make every test fail.
- **Tags don't enforce anything.** A "never full refresh" tag won't stop a `+` selector from pulling the model into a full refresh. Use `full_refresh: false` in config.
- **One writer per table.** Two jobs building the same snapshot or incremental model at once produce duplicate rows. The `prod` concurrency group in `deploy.yml` prevents it.
- **Snapshot history can't be backfilled.** Decide up front what a snapshot does when upstream tests fail.
- **Store test failures selectively.** `store_failures` on every test creates a table per test per run, and the clutter adds up. Turn it on where someone will read the results.
- **Verify the instrument.** When a monitor and the data disagree, check the monitor before the data.

## Layout

```
models/bronze/      sources + one view per raw table
models/silver/      conformed entities, grain tests, unit tests
models/gold/        dimensions, facts and aggregate marts, documented and tested
macros/             schema naming, surrogate keys, metric definitions, generic tests, CI cleanup
seeds/raw/          synthetic raw files for dev and CI (disabled in prod)
tests/              reconciliation and other one-off checks
profiles.yml        dev and ci targets (DuckDB)
profiles/<adapter>/ warehouse targets for CI and prod
.github/            CI, deploy, cleanup, PR template
docs/               modeling, materialization, testing, conventions, operations, agents
.claude/skills/     project skills for coding agents
CLAUDE.md           rules for coding agents
```
