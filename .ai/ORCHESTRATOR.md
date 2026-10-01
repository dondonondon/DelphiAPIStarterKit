# DelphiAPIStarterKit Execution Contract

This is the shared execution contract for [project-orchestrator](../.agents/skills/project-orchestrator/SKILL.md) and its supporting skills. It coordinates authorized work; installing or reading the package does not start the remediation backlog.

## Authority and scope

Follow the current user request and applicable agent instructions. Root AGENTS.md contains the local consolidated project rules when available. Read the relevant existing .github instructions when available, and disclose missing local rules rather than inventing them. Use [the project map](../project-map.md), [source layout](../docs/information/structure.md), and actual source to resolve technical questions.

Existing task files own their scope, acceptance, status, finding IDs, and result outputs. [The task index](TASK-INDEX.md) only provides navigation. A named wave remains limited to that wave plus necessary prerequisite slices. Run subsequent waves only if the user authorized their scope. Continue authorized work without routine permission requests, but never infer permission for production mutations, deployment, publishing, or messages to other people from this package.

## Project rules

- Preserve feature-first flat modules under sources/modules/<feature>. Keep HTTP extraction in endpoint/WebModule units, validation in validators, business rules in services, and database access in repositories/infrastructure.
- Preserve public names and existing architecture. Inspect real helper signatures and call sites before using them. Register new units/classes in the actual DPR/router locations and update [the map](../project-map.md).
- Add no Pascal comments, TODOs, or incomplete implementations. Follow compact control-flow blocks, early guards, explicit ownership, and try/finally cleanup using the current unit style.
- Validate untrusted inputs and identifiers. Use parameterized SQL and explicit write transactions. Keep database connections, queries, datasets, and transactions isolated per request/thread.
- Keep actual HTTP status and JSON status consistent. Responses contain status, messages, Unix timestamp string servertime, and array data. Non-2xx responses use data: [{}]; internal exceptions return a safe 500 response and are logged without secrets.
- Update [API documentation and Postman](../docs/api/) when an endpoint contract changes. Preserve populated local environments and credentials. Describe schema/provider compatibility and validate state-changing database operations on authorized test/clone resources.
- Preserve unrelated dirty files. Record the Git baseline and inspect hunks before edits. Do not use reset/clean, alter temp-file, overwrite runtime configuration, or treat generated build folders as source.

## Execution lifecycle

1. **Intake:** Establish objective, scope, compatibility, dependencies, and acceptance. For a trivial isolated edit, proceed directly without an artificial task plan or checkpoint.
2. **Evidence:** Read relevant units and actual failures. Inspect Git/toolchain state and selected task documents. Distinguish current observations from historical reviews and assumptions.
3. **Plan:** Select a small dependency-ordered implementation slice. State architectural impact briefly when routing, response, auth, config, or connection lifecycle changes. The user's implementation request already authorizes routine implementation choices.
4. **Implementation:** Apply complete changes within scope. Resolve prerequisites only to the extent needed, retaining their original owner and remaining acceptance. Continue independent work when another slice needs an external resource.
5. **Validation:** Map each acceptance to an observable check and evidence identity. Apply [the build skill](../.agents/skills/delphi-build/SKILL.md), relevant behavior/database checks, and API/Postman verification. Do not invoke the unsafe F34 build baseline blindly.
6. **Review and correction:** Inspect the changed behavior and ownership/security/contracts. Correct blocking issues and rerun only invalidated checks. Label independent review only when a separately authorized reviewer actually performed it.
7. **Completion:** Close only acceptance supported by current evidence. Report remaining blocked/unexecuted checks explicitly, keep existing task/wave statuses consistent, and give a concrete next action.

Use [feature](../docs/workflows/implement-feature.md), [bug-fix](../docs/workflows/fix-bug.md), or [review](../docs/workflows/code-review.md) workflow details as applicable.

## Evidence and terminal states

Record SOURCE, BUILD, RUNTIME_WINDOWS, RUNTIME_LINUX, DATABASE, and DEPLOYMENT separately when relevant. For each check record PASS, FAIL, BLOCKED, NOT_RUN, or STALE; optional NOT_APPLICABLE requires a concrete reason. Keep command exit codes and configuration/provider/platform identity. Invalidate evidence when its source, task contract, config, schema, or environment inputs change.

Use COMPLETE only when every mandatory acceptance in the authorized scope is satisfied. Use IN_PROGRESS for remaining executable work, BLOCKED for remaining mandatory work requiring missing resources/decisions, and PAUSED only on user request. A blocked check does not stop independent slices, does not count as passed, and does not justify closing a whole task. A read-only review can complete while describing unverified runtime areas.

## Durable execution and delegation

For multi-step or interrupted work, maintain one local run record under .ai/runs/ using [the template](templates/RUN-STATE.md). Save it after meaningful implementation/validation transitions, before risky operations, and before context compaction. Keep user-required task results in their existing versionable locations; local raw logs/checkpoints are ignored by Git. Use [RESUME.md](RESUME.md) after interruption.

Execute serially by default. Use subagents only when authorized by the user or applicable instructions. Give each delegated task objective, allowed files, constraints, acceptance, current evidence, and concise output limits. Shared core files/build outputs require a single writer or an isolated workspace. The orchestrator must reconcile changed files, verify actual evidence, and resolve conflicting results; delegation never transfers completion responsibility or expands external permissions.

## WAT and TAO

WAT defines the selected workflow, the responsible role, and allowed tools. The active agent can perform planning, coding, and review roles sequentially. Use repository file/search tools and actual CLI validation; use IDE or external tools only when the current task requires and authorizes them.

TAO is an internal decision/action/observation discipline: select the next scoped action from actual evidence, execute it, inspect the result, and record the observable outcome. Provide concise decision summaries only; do not expose private chain-of-thought.

## Reporting

Explain outcomes in Indonesian. Report concrete changes, key files, validation performed, and material limitations. Keep full logs local and show only the first actionable failure with the minimum corrective step. Avoid duplicate summaries, unrequested artifacts, complete source dumps, and redundant diffs after direct edits.
