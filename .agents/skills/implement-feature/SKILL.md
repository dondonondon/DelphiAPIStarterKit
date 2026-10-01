---
name: implement-feature
description: Implement a requested DelphiAPIStarterKit API or backend feature within the existing feature-first WebBroker architecture, including affected contracts and validation. Use for new behavior; use fix-bug for defects and code-review for read-only reviews.
---

# Implement Feature

Follow [the feature workflow](../../../docs/workflows/implement-feature.md) and [the shared execution contract](../../../.ai/ORCHESTRATOR.md). Use [the project map](../../../project-map.md) to locate the affected module and inspect existing helper signatures.

Require a concrete behavior, request/response expectations, allowed scope, and acceptance checks. Infer routine implementation choices from source. Ask only for missing domain or compatibility decisions that prevent a correct implementation, while continuing independent work.

Extend the existing flat feature module incrementally. Update affected endpoint, validator, DTO, service, repository, registration, and project references. Update API Markdown and Postman together when the public API changes; update migrations and mapping when affected. Do not execute production database mutations under a feature implementation request.

Use [delphi-build](../delphi-build/SKILL.md) for compilation and [code-review](../code-review/SKILL.md) for change inspection. Acceptance requires actual observable outcomes for the changed behavior. Report unexecuted checks with their reason; continue independent implementation instead of stopping at a plan.

Return a concise Indonesian report of the implemented behavior, changed files, validation, and material limitations. Preserve unrelated edits, avoid extra artifacts, and keep raw logs and redundant diffs out of the response.
