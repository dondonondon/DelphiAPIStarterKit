# Resume an Orchestrator Run

Use this procedure after context compaction, interruption, or a request to continue the same objective. Read [the execution contract](ORCHESTRATOR.md) and the relevant local run record before modifying files.

1. Select the checkpoint matching the current user-authorized objective. Never choose a different run solely because its file is newer. If no checkpoint exists, reconstruct state from actual source, Git status, task files, and available outputs.
2. Confirm branch/HEAD, scope, task/finding owner, next action, pre-existing dirty files, and modifications made by the run. Reconcile the latest user instructions with the checkpoint. Do not overwrite another contributor's subsequent edits.
3. Compare recorded content hashes, task revision, build configuration/platform, schema/provider, and environment identity with current inputs. Mark dependent evidence STALE when inputs changed. Preserve historical outcomes without treating them as current acceptance.
4. Inspect an active process/tool session before restarting it. If its session is lost, recover trustworthy exit/output evidence when possible; otherwise record NOT_RUN or STALE and rerun only a safe, scoped check. Never infer success from silence or an existing executable.
5. For a migration, upload, publish, or other external operation with uncertain completion, read actual target state first. Use a safe idempotency mechanism when available; do not repeat a mutation blindly. Stop dependent actions if outcome cannot be established, record the blocker, and continue independent slices.
6. Update the checkpoint with the reconciled state and resume the smallest unfinished authorized slice. Do not restart completed tasks, duplicate a prerequisite implementation, or silently advance to another wave.

Each blocker needs the missing resource/decision, affected acceptance, evidence showing the limitation, and the condition that reopens work. A retry needs a changed input or plausible transient cause; repeated identical failures require a concrete corrective action instead of an endless loop.

Local checkpoints live under .ai/runs/ and are not committed. Keep requested durable acceptance/result evidence in the task's existing documentation. Use [the run-state template](templates/RUN-STATE.md) for a new record.
