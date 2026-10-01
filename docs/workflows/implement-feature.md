# Feature Implementation Workflow

Apply [the execution contract](../../.ai/ORCHESTRATOR.md) and [implement-feature](../../.agents/skills/implement-feature/SKILL.md) for requested new behavior. Required inputs are the concrete behavior, allowed scope, public compatibility, and observable acceptance. The active agent owns all steps unless delegation is authorized.

1. Inspect [the map](../../project-map.md), affected module, router/registration, helpers, and database schema. Record relevant existing dirty work.
2. Define the request/response/error contract and smallest dependency-ordered slice. State material routing/auth/config/response/connection impact briefly, then proceed with authorized implementation.
3. Extend RestAPI.<Feature>, validator, DTO, service, and repository as affected within sources/modules/<feature>. Keep SQL in repositories and inspect ownership/transactions/concurrency.
4. Register new units/classes through the actual DPR/core route registration. Update API Markdown and [Postman](../api/postman.collection.json) together for public changes; update config/migration/map only when affected.
5. Use [delphi-build](../../.agents/skills/delphi-build/SKILL.md) and relevant outcome checks. Test error, validation, auth, and persistence behavior as applicable, using test/clone database resources for state changes.
6. Apply [code-review](../../.agents/skills/code-review/SKILL.md), correct blocking findings, and rerun invalidated checks. Record missing runtime/database/deployment resources separately and continue independent slices.
7. Complete only when mandatory acceptance has current evidence. Report implemented behavior, changed files, validation and concrete blockers in Indonesian; use one local checkpoint only when sustained execution needs it.

Use repository file/search tools and available CLI checks. Do not invent helper signatures, domain policies, production database access, or success responses. Do not create unrelated artifacts or expose raw logs/redundant diffs. Failure handling and resumable evidence follow the shared contract.
