# Working with agents

Coding agents such as Claude Code are good at writing dbt. Checking that the result is right takes as long as it always did. This page covers how agents work in this repo, and how agents should read the warehouse it builds.

## What an agent reads

| File | Purpose |
| --- | --- |
| `CLAUDE.md` | The rulebook: layers, commands, and the rules an agent must not break. Keep it short and current. |
| `docs/` | The reasoning behind the rules. Agents read these when a task touches modeling, tests or operations. |
| `.claude/skills/` | Step-by-step procedures for this project's common tasks (below). |

## Skills

Skills are folders of instructions an agent loads when a task matches ([Claude Code: skills](https://code.claude.com/docs/en/skills)). There are two sets.

### dbt Labs' general skills

[dbt-labs/dbt-agent-skills](https://github.com/dbt-labs/dbt-agent-skills) is dbt Labs' official collection: building models, unit tests, documentation coverage, the semantic layer, running dbt commands, troubleshooting job failures, and upgrades. Use it rather than copying it, so it stays current.

Each person installs it once, in Claude Code:

```
/plugin marketplace add dbt-labs/dbt-agent-skills
/plugin install dbt@dbt-agent-marketplace
```

This repo doesn't register the marketplace for you in `.claude/settings.json`. Installing third-party agent code should be each person's own choice, and a team that wants it on by default can add the setting deliberately ([Claude Code: plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)).

For other agents (Cursor, Codex, Copilot and others), see the install options in the [dbt-agent-skills README](https://github.com/dbt-labs/dbt-agent-skills#installation).

### This project's skills

In `.claude/skills/`. They encode this project's conventions on top of dbt Labs' general ones.

| Skill | Use when |
| --- | --- |
| `adding-a-source` | Bringing a new raw table through bronze, silver and gold |
| `adding-a-dimension-or-fact` | Extending the gold star schema |
| `investigating-a-failing-test` | A `dbt build` goes red |
| `reconciling-a-number` | Someone asks whether a number is right |
| `reviewing-a-pr` | Reviewing a change against `CLAUDE.md` and `docs/conventions.md` |

Add a skill when the same instructions get typed into a prompt for the second time.

## A working loop

1. Ask for a plan before any edit. Check the grain it proposes.
2. Let the agent edit on a branch and run `dbt build` itself. It should read the failures and fix them.
3. Read the diff. Ask it to explain any join you didn't expect.
4. Check one number against a total you know from somewhere else.
5. Open the PR and let CI be the second reviewer.

Agents produce SQL that runs cleanly and returns the wrong number. Grain tests, relationship tests, reconciliation tests and CI exist to catch that. Point the agent at them; don't let it weaken them.

## Agents reading the warehouse

The same split applies to agents as to people:

- **Builders** (analytics engineers and their coding agents) work in this repo with the dbt CLI, on dev schemas.
- **Readers** (business users, BI tools, data agents) query `gold` only, read-only. They never get the dbt CLI or write access.

Give reading agents the gold star schema and its documentation, not raw SQL access to every layer. The column descriptions in `_gold.yml` are what an agent uses to pick the right table, so write them for that reader. As the project grows:

- [Persist docs](https://docs.getdbt.com/reference/resource-configs/persist_docs) to the warehouse, so table and column comments are visible to the warehouse's own tools and agents.
- Define metrics once in the [dbt Semantic Layer](https://docs.getdbt.com/best-practices/how-we-build-our-metrics/semantic-layer-1-intro), so a reading agent asks for "gross margin rate by region" instead of writing its own SQL for it.
- Prototype a data agent over the local DuckDB build first. In production, prefer the warehouse's own data agent or MCP server, scoped to `gold`.

Numbers come from the warehouse; judgment and context come from elsewhere (docs, a knowledge base). Keep them separate, and have agents cite the gold table a number came from.
