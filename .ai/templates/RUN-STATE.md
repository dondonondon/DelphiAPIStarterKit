# Run State Template

Copy this template to one local file under .ai/runs/ for a multi-step run. Replace the instructional values with actual observations; remove unused rows. This template is not evidence that any task has started or passed. Do not record secrets, sensitive payloads, or private chain-of-thought.

## Identity and authorization

- Run ID and update time with timezone:
- User objective and authorized scope:
- Workflow and task/wave/finding IDs:
- State: IN_PROGRESS, COMPLETE, BLOCKED, or user-requested PAUSED
- Branch and HEAD:
- Pre-existing dirty/untracked files:
- Files/hunks changed by this run:
- Input identity: content hashes for relevant files; task/config/schema/environment revision without secret values

## Acceptance and evidence

| Acceptance / owner | Observable check | Evidence layer | Result | Input identity | Command / target / exit / artifact |
|---|---|---|---|---|---|
| Record actual criterion | Record actual outcome checked | SOURCE / BUILD / RUNTIME_WINDOWS / RUNTIME_LINUX / DATABASE / DEPLOYMENT | PASS / FAIL / BLOCKED / NOT_RUN / STALE | Relevant file hashes and configuration | Command, platform/provider, exit, and redacted evidence location |

Keep one row per acceptance/check when outcomes differ. Build or mock evidence cannot close a runtime/database/deployment criterion. NOT_APPLICABLE needs its concrete scope reason. Add a timestamp and preserve historical results when marking them STALE.

## Decisions and compatibility

- Concise decisions and confirmed assumptions:
- Public API/config/schema changes and migration compatibility:
- Prerequisite slices implemented and original owners:
- Review findings and correction evidence:

## Pending operations and blockers

| Operation / criterion | Actual state / evidence | Missing resource or decision | Reopening condition / safe retry |
|---|---|---|---|
| Record a remaining operation | Include session/process identity and uncertain side effects when relevant | Concrete missing dependency | Exact input/state change required |

## Continuation

- Last verified completed action:
- Next concrete authorized action and affected files:
- Checks invalidated by subsequent changes:
- Independent work that remains executable:
- Required task/result/status updates:

On resume, follow [RESUME.md](../RESUME.md) before executing pending actions. Local checkpoints/logs are ignored by Git; required task acceptance/result documents remain versionable.
