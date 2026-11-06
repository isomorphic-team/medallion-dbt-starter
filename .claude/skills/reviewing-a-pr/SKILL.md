---
name: reviewing-a-pr
description: Review a dbt change in this project against CLAUDE.md, docs/conventions.md and the PR template. Use when asked to review a branch, diff or pull request in this repo.
---

# Reviewing a PR

1. Read the diff (`git diff main...HEAD` or `gh pr diff <n>`), the PR description, and the models it touches and their parents.
2. Work through the review checklist in `docs/conventions.md` (section "Reviewing a pull request"): grain and joins, definitions, tests, numbers, operations.
3. Check each rule in `CLAUDE.md` the change could break. The ones broken most often: a model without a `-- Grain:` comment and matching `unique_grain` test, a metric re-derived inline, a test loosened without a reason, a fact joined with an inner join.
4. Run `dbt build` and `sqlfluff lint models tests`.
5. Report findings most severe first. For each: the file and line, what is wrong, and a concrete case where it produces a wrong number. Leave out style points the linter already covers.
