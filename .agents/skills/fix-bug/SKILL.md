---
name: fix-bug
description: Diagnose and repair DelphiAPIStarterKit defects or existing remediation findings with source-backed root cause and relevant regression evidence. Use for faulty behavior; use implement-feature for new requirements and code-review for review without edits.
---

# Fix Bug

Follow [the bug-fix workflow](../../../docs/workflows/fix-bug.md) and [the shared execution contract](../../../.ai/ORCHESTRATOR.md). Locate existing task/finding owners through [the task index](../../../.ai/TASK-INDEX.md), then verify the current source instead of relying on historical line numbers.

Require a failing behavior or concrete code defect, expected behavior, affected platform, and allowed scope. Read actual callers, ownership, exception paths, and persistence behavior before changing code. Distinguish a directly visible defect from one dependent on deployment or consumer behavior.

Implement the smallest complete correction that addresses the cause. Keep public compatibility and unrelated dirty work. A dependency slice remains owned by its original task; do not mark the entire dependency task complete when only one acceptance is closed.

Use [delphi-build](../delphi-build/SKILL.md) after Delphi changes and [code-review](../code-review/SKILL.md) for the final change. Verify the original failing outcome and a relevant adjacent regression. If runtime reproduction is unavailable, identify what source/build evidence proves and record the missing check as BLOCKED or NOT_RUN; never claim a runtime fix from compilation alone.

Report the correction, changed files, regression evidence, and concrete blocker/reopening conditions in Indonesian. Save result files only when the selected task requires them; keep raw logs local and avoid redundant diffs.
