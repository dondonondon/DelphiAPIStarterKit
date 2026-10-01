---
name: delphi-build
description: Build DelphiAPIStarterKit using its actual compile.bat, explicit Windows or Linux64 target, toolchain prerequisites, and process-termination safety gate. Use for Delphi build validation; documentation-only skill edits use the package validator.
---

# Delphi Build

Inspect [compile.bat](../../../compile.bat), [CloseApp.bat](../../../CloseApp.bat), and [the Delphi project](../../../DelphiAPIStarterKit.dproj) before execution. Read [T10](../../../docs/bugs/task-10-hosting-build-dan-deployment.md) when its T10.a/F34 gate or hosting acceptance applies.

## Preconditions

- Verify the active build path, including DPROJ pre/post-build events, cannot terminate unrelated processes by executable name. At package creation, compile.bat uses taskkill by image name and Windows project events call CloseApp.bat; this is an unresolved F34 baseline. Recheck current source on each run.
- If the requested application change includes the F34 prerequisite, implement the authorized minimum fix and verify it before compilation. Otherwise record the concrete blocker and continue available checks; this skill alone does not authorize repairing unrelated build logic or killing processes.
- Require an existing DelphiAPIStarterKit.dproj and a valid Delphi environment. Use DELPHI_RSVARS or BDS through the existing script; never hardcode a developer-specific installation into new files.
- Select BUILD_CONFIG and BUILD_PLATFORM explicitly when required. compile.bat defaults to Debug / Win32, while the current DPROJ default is Linux64. Supported project targets include Win32, Win64, and Linux64; inspect current project/platform support before assuming a target is installed.

## Execution and evidence

After the gate is satisfied, invoke compile.bat from the repository root. In PowerShell, use environment overrides as needed:

```powershell
$env:BUILD_CONFIG = 'Debug'
$env:BUILD_PLATFORM = 'Win32'
& .\compile.bat
$buildExitCode = $LASTEXITCODE
```

Restore prior environment values when setting overrides only for one validation run. Record the command, selected target/configuration, actual exit code, source identity, and produced artifact. Inspect the first actionable error and enough context to find its cause. A non-zero exit, missing environment, or missing artifact cannot be reported as success.

Compile affected target(s) after Delphi changes; broaden or repeat builds only for new changes or unresolved failures. A Linux64 cross-build does not prove Linux listener, native library, database, or service deployment behavior. Keep those gates separate.

For package Markdown, metadata, and validator changes that do not alter Delphi source/project files, run [validate-orchestrator.ps1](../../../scripts/validate-orchestrator.ps1) and scoped Git checks. Report explicitly that Delphi compilation was not performed. Return concise evidence in Indonesian and keep complete compiler output local unless requested.
