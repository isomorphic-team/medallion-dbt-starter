# medallion-dbt-starter

A dbt starter for a raw → bronze → silver → gold warehouse, with tests, CI and deploy wired in. Runs locally on DuckDB with synthetic data. Connects to Fabric, Snowflake, BigQuery or Databricks with one repo variable.

- **[QUICKSTART.md](QUICKSTART.md)**: run it, understand the layers, connect a warehouse
- **[docs/](docs/)**: the reasoning, with links to dbt's and Databricks' own guidance
  - [modeling.md](docs/modeling.md): medallion layers, Kimball dimensional modeling, keys, slowly changing dimensions
  - [materialization.md](docs/materialization.md): views, tables, incremental, snapshots
  - [testing.md](docs/testing.md): grain, relationships, unit and reconciliation tests, severity, freshness
  - [conventions.md](docs/conventions.md): naming, SQL style, the PR review checklist
  - [operations.md](docs/operations.md): environments, access, secrets, scheduling, cost, backups
  - [agents.md](docs/agents.md): skills, and how coding and data agents should use the warehouse
- **[CLAUDE.md](CLAUDE.md)**: rules for Claude Code and other coding agents

```bash
pip install -r requirements.txt && export DBT_PROFILES_DIR=.
dbt deps && dbt seed && dbt build --exclude resource_type:seed
```
