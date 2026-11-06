---
name: reconciling-a-number
description: Check whether a number in gold is right by tying it to an independent total. Use when someone asks if a figure is correct, a dashboard disagrees with a report, or before quoting a number from this warehouse.
---

# Reconciling a number

A number is checked when it matches a total you didn't compute the same way (`CLAUDE.md` rule 7).

1. **Pin the number down.** Which gold model and column, which filters, which dates. Get it with `dbt show --inline "select ... from {{ ref('<model>') }} ..."`.
2. **Find an independent total.** In order of preference:
   - The source system's own report for the same period and filters.
   - A count or sum straight from bronze, deduplicated the way silver deduplicates.
   - A hand count of a small slice (one store, one day).
3. **Compare layer by layer** if they differ: bronze, silver, fact, mart. The first layer where totals diverge holds the problem. Common causes: a join that fans out, an inner join that drops unknown members, a filter applied in one place and not the other, a duplicate silver didn't catch, a date boundary that differs.
4. **Report** both numbers, the difference, and where it comes from. If the gap is explained and acceptable (the source report includes returns and gold doesn't, say), state exactly that.
5. **Make it permanent.** If the check was worth doing once, add it to `tests/` as a reconciliation test so it runs on every build.
