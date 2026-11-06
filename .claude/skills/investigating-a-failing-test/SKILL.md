---
name: investigating-a-failing-test
description: Diagnose why a dbt test failed in this project and fix the cause, not the test. Use when dbt build or dbt test shows a FAIL or ERROR, or CI goes red.
---

# Investigating a failing test

The goal is to find out why the data or the logic is wrong. Weakening the test is not a fix (`CLAUDE.md` rule 5).

1. **Read the failure.** `dbt build` names the test and the model. Find the compiled test SQL in `target/compiled/` and run it with `dbt show --inline "<sql>"` to see the failing rows.
2. **Place it in the layer.**
   - Bronze test: the source changed. Compare the raw data with what the bronze model expects. The fix is in the bronze model, or a conversation with whoever owns the source.
   - `unique_grain`: duplicates, or a join that fans out. Find two rows that share the grain, see which column differs, and trace which join or source produced them.
   - `relationships` on a fact: a join missing its `coalesce` to `unknown_key()`, or a dimension missing its unknown member.
   - `not_null` or `non_negative`: trace the column back with `dbt show -s <parent>` until you find where the bad value appears.
   - Unit test: compare expected with actual. Decide whether the logic or the expectation is wrong, and say which.
   - Reconciliation: money was dropped or doubled. Compare totals layer by layer (bronze, silver, gold) to find where they diverge.
3. **Fix the cause** in the model where it starts, then `dbt build -s +<model>+` to rebuild it and everything downstream.
4. **Explain.** Tell the user what was wrong, where, and why the fix is right. If you believe the test itself is wrong, say so and why, and ask before changing it.
