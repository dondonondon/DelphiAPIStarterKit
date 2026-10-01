# Code Review Workflow

Use [code-review](../../.agents/skills/code-review/SKILL.md) for actual source or a requested diff. Inputs are the review scope, relevant requirements/contracts, current source and available validation evidence. A review request remains read-only unless the user also authorizes fixes.

1. Read applicable root/project rules when available, [the map](../../project-map.md), and actual changed files/callers. Name missing rules visibly. If no reviewable code exists, stop the review with a precise missing-source report.
2. Check security and auth boundaries, secret exposure, input limits/validation, and parameterized SQL.
3. Inspect JSON/stream/object ownership, AV paths, transactions, datasets/connections, concurrent state, and shutdown/background exception behavior where relevant.
4. Check actual HTTP status against the JSON envelope, public route/DTO compatibility, affected API docs/Postman, and config/schema/platform assumptions. Review architecture drift after higher runtime risks.
5. Describe each actionable finding with severity, file/line, risk, cause, and CONFIRMED or CONTEXT-DEPENDENT. Distinguish an observed defect from unavailable runtime evidence.
6. Report findings first in Indonesian with concise evidence and residual limitations. State explicitly when no significant findings exist. During an authorized implementation workflow, inspect corrections before completing that workflow.

Use read-only file/search/diff tools and existing evidence. Run additional read-only validation only when useful and safe; compilation follows [the build gate](../../.agents/skills/delphi-build/SKILL.md). Do not mutate source or databases for a review alone, dump raw logs/diffs, or describe a sequential self-review as independent review.
