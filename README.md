# medallion-dbt-starter

A dbt starter for a raw → bronze → silver → gold warehouse, with tests, CI and deploy wired in. Runs locally on DuckDB with synthetic data. Connects to Fabric, Snowflake, BigQuery or Databricks with one repo variable.

- **[QUICKSTART.md](QUICKSTART.md)**: run it, understand the layers, connect a warehouse
- **[CLAUDE.md](CLAUDE.md)**: rules for Claude Code and other coding agents

```bash
pip install -r requirements.txt && export DBT_PROFILES_DIR=.
dbt seed && dbt build --exclude resource_type:seed
```
