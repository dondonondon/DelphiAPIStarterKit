# Bug Fix Workflow

Apply [the execution contract](../../.ai/ORCHESTRATOR.md) and [fix-bug](../../.agents/skills/fix-bug/SKILL.md). Inputs are observed faulty behavior or a concrete code defect, expected behavior, affected target, and authorized task scope. Use [the task index](../../.ai/TASK-INDEX.md) for existing findings, without changing their owners or acceptance.

1. Inspect current source, callers, Git baseline, and failure evidence. Reproduce the failure where practical; distinguish current observations from old review snapshots and context-dependent claims.
2. Trace the cause across endpoint, validator, service, repository, and helper/infrastructure boundaries. Inspect memory ownership, exception paths, auth policy, transaction state, and thread sharing as affected.
3. Select the smallest complete corrective slice. Implement prerequisites only as necessary and retain their original task owner and remaining scope.
4. Apply the correction with existing public names, feature-first structure, and unit style. Update API/Postman, schema/config compatibility, and mapping when the change affects them.
5. Use [delphi-build](../../.agents/skills/delphi-build/SKILL.md) for Delphi changes after the F34 gate. Verify the original failed outcome and a meaningful adjacent regression; compilation alone does not establish runtime correctness.
6. Apply [code-review](../../.agents/skills/code-review/SKILL.md), correct blockers, and rerun affected checks. Record resource/decision blockers with reopening conditions while continuing independent work.
7. Update the selected task's existing acceptance/result outputs when required. Close only proven criteria and report correction, changed files, evidence, and unresolved limits in Indonesian.

Use repository inspection and permitted CLI/runtime/database tools. Migration/state-changing tests use authorized clones/test resources. Do not execute other waves automatically, claim a fix from static inspection alone, or produce duplicate reports and full logs. Resume through [RESUME.md](../../.ai/RESUME.md) for interrupted multi-step work.
