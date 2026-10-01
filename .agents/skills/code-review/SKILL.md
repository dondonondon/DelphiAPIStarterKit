---
name: code-review
description: Review actual DelphiAPIStarterKit source or a scoped diff for security, ownership, concurrency, persistence, and API contract defects. Use for review requests or final inspection of a change; do not modify implementation during a read-only review.
---

# Code Review

Follow [the review workflow](../../../docs/workflows/code-review.md). Read root AGENTS.md and its available project-specific sources, then inspect the requested source/diff and callers using [the project map](../../../project-map.md). If a referenced rules file is absent, show a visible warning naming it and state the review limitation. If no reviewable code exists, report that instead of reviewing assumed code.

Prioritize actual security exposure, data corruption, access violations, races, leaks, and contract breaks. Check JSON/stream/dataset ownership, connection and transaction scope, request validation, authentication/authorization, parameterized SQL, and safe exception responses before style.

For each actionable finding, include severity, file and line, runtime risk, concrete cause, and CONFIRMED or CONTEXT-DEPENDENT. Review a changed public contract against the API Markdown and Postman collection. Treat missing relevant runtime or database evidence as a validation limitation, not an invented defect.

Keep a requested review read-only. During an implementation workflow, return blocking findings to the active implementation responsibility and inspect the corrected diff before completion. Do not describe a sequential self-review as an independent review.

List findings first in Indonesian, then give a short validation summary. If there are no significant findings, state that and identify unverified areas. Do not dump source files, complete diffs, compiler logs, or generic best-practice lists.
