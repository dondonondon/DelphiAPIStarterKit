# Existing Task Navigation

The current remediation definitions are [the task index](../docs/bugs/review-tasks-windows-linux-2026-10-01.md) and [the wave index](../docs/bugs/waves-windows-linux-2026-10-01.md). Read their current status and detailed acceptance before execution. This navigation adds no duplicate status ledger and does not authorize starting any wave.

| Authorized wave | Execution prompt | Internal order | Task definitions |
|---|---|---|---|
| Wave 01 | [Prompt](../docs/bugs/prompt-execute-wave-01.md) | T01 -> T02 -> T03 | [Authorization](../docs/bugs/task-01-authorization-dan-permission.md), [Authentication](../docs/bugs/task-02-authentication-password-dan-session.md), [HTTP boundary](../docs/bugs/task-03-http-routing-dan-error-boundary.md) |
| Wave 02 | [Prompt](../docs/bugs/prompt-execute-wave-02.md) | T04 -> T05 -> T06 | [Logging](../docs/bugs/task-04-logging-dan-observability.md), [JSON/time](../docs/bugs/task-05-request-response-json-dan-waktu.md), [Database/domain](../docs/bugs/task-06-database-transaksi-dan-validasi-domain.md) |
| Wave 03 | [Prompt](../docs/bugs/prompt-execute-wave-03.md) | T09 -> T08 -> T07 | [Config](../docs/bugs/task-09-config-path-dan-persistence.md), [Storage](../docs/bugs/task-08-storage-upload-dan-stream.md), [Pagination](../docs/bugs/task-07-collection-pagination-dan-kapasitas.md) |
| Wave 04 | [Prompt](../docs/bugs/prompt-execute-wave-04.md) | T10 -> T11 -> T12 | [Hosting/build](../docs/bugs/task-10-hosting-build-dan-deployment.md), [Migration](../docs/bugs/task-11-schema-migration-dan-kompatibilitas.md), [Architecture](../docs/bugs/task-12-architecture-dan-centralization.md) |

Before any application build, inspect T10.a/F34 and the current build scripts/events. Necessary slices from another task keep their original finding owner and remain partial until all mandatory acceptance for that task is satisfied. Preserve existing result/checkpoint paths required by each wave.

For new feature requests or bugs outside this backlog, apply [the execution contract](ORCHESTRATOR.md) and the appropriate workflow without inventing a new backlog or automatically starting these waves.
