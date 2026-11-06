# Operations

Running the project for real: who can do what, where it runs, what it costs, and how to recover. QUICKSTART §5 gets a warehouse connected. This page covers running it day to day.

## Environments

| Environment | Target | Where | Data | Who writes |
| --- | --- | --- | --- | --- |
| Dev | `dev` | Local DuckDB, schemas `dev_<you>_*` | Synthetic seeds | You |
| CI (local) | `ci` | DuckDB on the runner | Synthetic seeds | `ci.yml`, every PR |
| CI (warehouse) | `ci_warehouse` | Your warehouse, schemas `ci_pr_<n>_*` | Synthetic seeds | `ci.yml`, every PR, once `DBT_ADAPTER` is set |
| Prod | `prod` | Your warehouse, schemas `bronze`, `silver`, `gold` | What the loader lands | `deploy.yml` only |

`macros/generate_schema_name.sql` produces those schema names. `cleanup.yml` drops a PR's schemas when it closes.

Pointing dev or CI at real data is a decision for the data owner and security, made once and written down. The default is synthetic data everywhere except prod.

## Identities and access

Use separate service identities for CI and prod, and give each the least it needs.

| Identity | Reads | Writes | Never |
| --- | --- | --- | --- |
| Loader | Sources | `raw` | Anything dbt owns |
| CI | `raw` (if it reads real sources at all) | `ci_pr_*` schemas | `bronze`, `silver`, `gold` |
| Prod (dbt) | `raw` | `bronze`, `silver`, `gold` | `raw` |
| Analysts, BI tools, agents | `gold` | Nothing | `raw`, `bronze` |

Readers get `gold` only. Engineers may need `silver` to debug. Nobody outside the data team needs `bronze` or `raw`.

Grant access in dbt so it is versioned and reapplied on every build ([dbt: grants](https://docs.getdbt.com/reference/resource-configs/grants)):

```yaml
# dbt_project.yml
models:
  medallion:
    gold:
      +grants:
        select: ["{{ env_var('DBT_GOLD_READERS', '') }}"]
```

How roles work differs by warehouse:

- **Databricks**: Unity Catalog privileges on catalog, schema and table. Grant `USE CATALOG`, `USE SCHEMA` and `SELECT` on `gold` to reader groups. See [Unity Catalog privileges](https://docs.databricks.com/aws/en/data-governance/unity-catalog/manage-privileges/).
- **Snowflake**: one role per identity above; the warehouse is granted to the role.
- **BigQuery**: IAM on datasets. `roles/bigquery.dataViewer` on the gold dataset for readers.
- **Fabric**: workspace roles plus SQL `GRANT` on schemas in the warehouse.

## Secrets and configuration

- Everything a profile needs comes from environment variables (`env_var()` in `profiles/<adapter>/profiles.yml`). No credential is ever committed.
- GitHub **Variables** hold non-secret settings (host, catalog, warehouse name). **Secrets** hold credentials. QUICKSTART §5 lists which.
- Prefer federated auth over long-lived keys where the warehouse supports it: workload identity on BigQuery, OAuth service principals on Databricks and Fabric, key-pair auth on Snowflake.
- Rotate credentials on a schedule, and when anyone with access leaves.

## Protecting main

`main` deploys to prod, so treat a merge as a release.

- Require the `lint and build (DuckDB)` check, and the warehouse check once it runs, before merging.
- Require at least one review.
- Add required reviewers to the `production` environment if a person should approve each prod build.

## Scheduling

`deploy.yml` builds prod on merge and once a day. One run at a time: the `prod` concurrency group queues a second run instead of overlapping, so a merge and the schedule never write the same tables at once.

Run `dbt source freshness` before the build once sources have a load timestamp (see [testing.md](testing.md#source-freshness)), so a stale load fails loudly instead of producing a green build of old numbers.

## Monitoring and alerts

- A failed `deploy` run is the primary alert. Route GitHub Actions failure notifications to a channel someone watches.
- `target/run_results.json` is uploaded as an artifact on every run. Use it to see which model or test failed and how long each step took.
- When a monitor and the warehouse disagree, check the monitor first. Alerting code has bugs too, and a broken monitor looks exactly like a quiet day.

## Cost

- Size warehouses for the build, not the peak query load. Small, auto-suspending compute is usually enough for dbt.
- Partition or cluster large facts by date (see [materialization.md](materialization.md#warehouse-specific-options)). It is the biggest single lever on scan cost.
- Go incremental only when a full rebuild is measurably too slow or expensive.
- Tag queries so cost can be traced to the model. The Snowflake profile sets `query_tag`; Databricks and BigQuery have equivalents.
- Review cost monthly. A model whose cost doubled is usually a join that started to fan out.

## Backups

Most of the warehouse can be rebuilt from `raw` with `dbt build`. Two things can't:

- **`raw` itself**, if the source system doesn't keep history. That is the loader's responsibility, but confirm someone owns it.
- **Snapshots**, which hold history captured over time. A dropped snapshot is gone.

Back up snapshot tables on a schedule using the warehouse's own tools: zero-copy clones on Snowflake, Delta `CLONE` or time travel on Databricks, table snapshots on BigQuery. Test a restore before you need one.

## Snapshot ownership

Each snapshot has exactly one writer: the prod deploy. Two jobs writing the same snapshot at once produce duplicate history rows that are hard to unpick. If a second job needs to run snapshots, it joins the `prod` concurrency group or it doesn't run them.

Decide for each snapshot what happens when upstream tests fail. Skipping the snapshot protects it from bad data but leaves a gap in history that can never be filled; running it anyway keeps history continuous but may record a bad value. Neither is always right, so choose and write it down.

## Upgrading dbt

- Pin dbt and adapter versions with a range (`requirements.txt`, `profiles/<adapter>/requirements.txt`), and upgrade on purpose.
- Read the [dbt upgrade guides](https://docs.getdbt.com/docs/dbt-versions/core-upgrade) for each minor version you cross. The `upgrading-dbt` skill from dbt Labs (see [agents.md](agents.md)) walks through it.
- Upgrade in a PR. CI on DuckDB plus the warehouse build is the test.
