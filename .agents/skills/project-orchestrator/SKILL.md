---
name: project-orchestrator
description: Coordinate scoped DelphiAPIStarterKit feature work, bug fixes, reviews, and existing remediation waves through implementation, validation, and resumable checkpoints. Use for dependent tasks or continued project execution; handle a simple isolated edit directly.
---

# Project Orchestrator

Use [the execution contract](../../../.ai/ORCHESTRATOR.md) as the shared workflow authority. Read [the project map](../../../project-map.md) to locate actual source and build boundaries. Apply root AGENTS.md when available; if it is unavailable, use the project rules in the execution contract and disclose the missing local instructions.

## Intake and execution

1. Establish the user's objective, allowed files, compatibility constraints, and acceptance checks. Inspect Git status and affected source before editing. Creating this package does not authorize executing the existing remediation backlog.
2. Classify the request as feature, bug fix, review, or a named wave. Read only the relevant workflow and task documents. Use [the task index](../../../.ai/TASK-INDEX.md) to locate existing work; it does not override task scope or status.
3. Reuse an active checkpoint for the same objective through [the resume procedure](../../../.ai/RESUME.md). Verify source identity and prior results before trusting them.
4. Work serially in the current chat. Planning, coding, and review are responsibilities the active agent can perform. Delegate only when the user or applicable instructions authorize delegation; never create a new user-owned chat as an internal subtask.
5. Implement a complete, reviewable slice and validate its observable behavior. Continue authorized independent slices when an external check is blocked. Resolve blocking review findings before completing the task.
6. Update the existing task acceptance and result files when required. For multi-step work, maintain one local checkpoint using [the run-state template](../../../.ai/templates/RUN-STATE.md); do not generate duplicate reports for ordinary edits.

## Related skills

- For new behavior, use [implement-feature](../implement-feature/SKILL.md).
- For a regression or remediation finding, use [fix-bug](../fix-bug/SKILL.md).
- For a requested review or final change inspection, use [code-review](../code-review/SKILL.md).
- For Delphi compilation, use [delphi-build](../delphi-build/SKILL.md). Inspect the process-termination gate before executing the existing build scripts.

## Output and failure handling

Report the implemented outcome, affected files, validation actually run, and concrete remaining blockers in Indonesian. Show the first actionable failure and its minimum corrective action; keep full logs local and omit redundant source/diffs after direct edits. Give concise decision summaries without private chain-of-thought. Never promote source inspection, a mock, or a cross-build into live API, database, or deployed Linux acceptance.
