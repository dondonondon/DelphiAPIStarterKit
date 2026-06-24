# Open Source Finalization Tasks

Dokumen ini berisi checklist final sebelum `DelphiAPIStarterKit` dipublish sebagai project open source di GitHub.

## Status

- Review date: 2026-06-24
- Publish readiness: Almost ready; pending final Git staging review
- Target readiness: Public starter kit, not production deployment template

## Priority 1 - Must Fix Before Push

- [x] Remove tracked MySQL binary package from repository.
  - File: `bin/lib/libmysql.zip`
  - Reason: binary from third-party DLL mirror is not ideal for redistribution and may create license/security risk.
  - Replacement: document official MySQL client installation or provide a link to the official vendor source.

- [x] Review whether `bin/lib/libmysql.dll` is tracked or only ignored locally.
  - If tracked, remove it from Git history/staging.
  - Keep only `bin/lib/README.txt` or replace it with dependency setup documentation.
  - Resolved on 2026-06-24: removed `bin/lib/libmysql.dll` from Git tracking; local DLL remains ignored by `/bin/lib/*.dll`.

- [x] Remove hardcoded HMAC signature secret. (2026-06-24)
  - File: `sources/shared/helpers/BFA.Helper.Strings.pas`
  - Removed `SIGNATUREAPPS` hardcoded secret.
  - `TGlobalFunction.HashHMAC256` now reads from `DELPHI_API_HMAC_SECRET` first.
  - Fallback: `[Security] HMACSecret` in `config.ini`.
  - Added `config.example.ini` with a placeholder secret value.
  - If no secret is configured, hashing raises a clear configuration exception.

- [x] Remove hardcoded default reset password. (2026-06-24)
  - File: `sources/modules/users/User.Service.pas`
  - Removed `DEFAULT_PASSWORD`.
  - Reset password now generates a per-request temporary password.
  - Request confirmation field changed from `force_default` to `confirm_reset`.
  - Response message changed from `Password reset to default` to `Password reset`.
  - Response now returns `temporary_password` once for the administrator to communicate to the target user.

- [x] Protect or disable legacy DataSnap demo authentication. (2026-06-24)
  - ~~File: `sources/app/App.Server.pas`~~ → **Deleted.**
  - **Resolved by full DataSnap removal:**
    - `App.Server.pas` + `.dfm` deleted (TDSServer, TDSAuthenticationManager, TDSServerClass).
    - `Methods.Sample.pas` and `Methods.Report.pas` deleted.
    - `DSHTTPWebDispatcher1`, `DSProxyGenerator1`, `DSServerMetaDataProvider1`, `DSProxyDispatcher1` removed from App.WebModule.
    - `Datasnap.DSSession`, `App.Server`, `Methods.Sample` removed from `.dpr`.
    - Route `datasnap*` eliminated.
    - `TerminateThreads` no longer references `TDSSessionManager`.

- [x] Remove absolute local path from data module. (2026-06-24)
  - File: `uDM.dfm`
  - Removed `VendorHome = 'D:\Documentation\DatasnapLinux\Win64\Release\'`.
  - Runtime still sets `FDPhysMySQLDriverLink.VendorHome` from startup code.

- [x] Move database connection values out of source code. (2026-06-24)
  - File: `sources/infrastructure/database/DB.ConnectionFactory.pas`
  - Removed hardcoded `localhost`, `demo_delphirest`, `root`, and password from the connection factory.
  - Server, database, and user are required from `DELPHI_API_DB_SERVER`, `DELPHI_API_DB_DATABASE`, `DELPHI_API_DB_USER`, or `[Database]` in `config.ini`.
  - Password is read from `DELPHI_API_DB_PASSWORD` or `[Database] Password`; empty password remains allowed for local development.
  - Fallback: `[Database]` section in `config.ini`.
  - Updated `config.example.ini`, `README.md`, and `README.id.md`.

- [x] Require access token for protected API resources. (2026-06-24)
  - File: `sources/core/BFA.Core.Endpoint.pas`
  - Protected routes now validate access tokens against `access_token`, `user_session`, and active `users` records.
  - Applied to `User`, `Product`, `Category`, and `Customer` routes.
  - `Auth` endpoints remain public for login, logout, and token refresh.
  - Updated README, API docs, and Postman collection.

## Priority 2 - Repository Hygiene

- [x] Decide whether documentation should be published. (2026-06-24)
  - Current `.gitignore` excludes `/docs`.
  - Resolved: `/docs` is no longer ignored.
  - Publish API docs, information docs, database notes, and task docs because they are useful for open-source onboarding and project navigation.
  - Keep local AI/editor instruction docs out of GitHub: `.github/`, `AGENTS.md`, `docs/ai/`, and `docs/task/task.md`.

- [x] Review generated/proxy folders before public release. (2026-06-24)
  - Current ignored folders: `/proxy`, `/bin/proxy`
  - Confirmed generated DataSnap proxy output exists in both folders.
  - Keep `/proxy/` and `/bin/proxy/` ignored.

- [x] Keep build artifacts out of Git. (2026-06-24)
  - Confirm these remain untracked: `Win32`, `Win64`, `*.exe`, `*.dll`, `*.dcu`, `*.local`, `*.identcache`.
  - Added `/bin/files/` and `/bin/lib/*.dll` ignore rules for runtime storage and local MySQL client DLLs.
  - Removed tracked `bin/lib/libmysql.dll` and tracked runtime sample image from Git.

- [x] Review large `.dproj` diff before committing. (2026-06-24)
  - Current local diff is mostly project metadata/format churn.
  - Current working tree has no `.dproj` diff.
  - No project metadata cleanup needed in this task.

- [x] Normalize line endings for SQL/script files if needed. (2026-06-24)
  - Current warning: `assets/databases/demo_delphirest.sql` LF will be replaced by CRLF.
  - Added `.gitattributes` to normalize text files, keep SQL/JSON as LF, keep Windows scripts as CRLF, and mark common binary files as binary.

## Priority 3 - Build and Setup Experience

- [x] Make `compile.bat` portable. (2026-06-24)
  - Current issues:
    - Hardcoded Delphi path: `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat`
    - Hardcoded project path: `D:\Github\DelphiAPIStarterKit`
    - Interactive `pause`
  - Target:
    - Use `%~dp0` for project directory.
    - Allow configurable Delphi version/path.
    - Avoid forced pause for CI/script usage.
  - Resolved: project directory uses `%~dp0`, `rsvars.bat` is read from `DELPHI_RSVARS` or `%BDS%\bin\rsvars.bat`, `BUILD_CONFIG` and `BUILD_PLATFORM` can override defaults, and `pause` was removed.

- [x] Add setup instructions to `README.md`. (2026-06-24)
  - Include Delphi version.
  - Include required components: WebBroker, DataSnap, FireDAC, MySQL driver.
  - Include database creation/import steps.
  - Include how to configure database connection.
  - Include how to run and test endpoints.
  - Resolved in `README.md` and `README.id.md`.

- [x] Add API quickstart documentation. (2026-06-24)
  - Recommended content:
    - Base URL format.
    - Response envelope format.
    - Auth/login flow.
    - Example request/response.
    - Postman collection location.
  - Added base URL, Postman collection path, login curl example, and bearer token note.

- [x] Add MySQL setup notes. (2026-06-24)
  - Include `assets/databases/demo_delphirest.sql`.
  - Mention MySQL/MariaDB compatibility assumptions.
  - Mention required user permissions.
  - Added MySQL/MariaDB InnoDB and `utf8mb4` notes plus setup/runtime permission guidance.

- [x] Add production safety warning. (2026-06-24)
  - State that defaults are for local development.
  - State that secrets, DB credentials, CORS, HTTPS, logging, and auth policy must be reviewed before production use.
  - Existing security notes were kept and README now clearly states the project is not production-ready without security review.

## Priority 4 - Runtime Safety Improvements

- [x] Validate API route parts before indexing. (2026-06-24)
  - File: `sources/app/App.WebModule.pas`
  - Current risk: `LParts[1]` and `LParts[2]` can raise an exception for malformed paths.
  - Resolved: `/api/v1/*` dispatch validates route parts before indexing and returns a standardized 404 JSON response for malformed API routes.

- [x] Review image/file serving endpoint. (2026-06-24)
  - File: `sources/app/App.WebModule.pas`
  - Route `/image` now accepts `GET` only.
  - Filename is required and must be a plain filename, not a path.
  - Image extension is restricted to `.jpg`, `.jpeg`, `.png`, and `.bmp`.
  - Content type is based on the file extension.
  - File stream is released after `SendResponse`.
  - Request counter increment now uses `TInterlocked.Increment`.

- [x] Review old dynamic SQL helper usage. (2026-06-24)
  - File: `sources/core/BFA.Core.Request.pas`
  - Current methods: `GetValue`, `GetToken`, `GetUserID`
  - Risk: builds SQL from table/field/where strings.
  - Removed unused `GetValue`, `GetToken`, `GetUserID`, and raw-SQL `GetData`.

- [x] Review `ExpandSQLWithParams`. (2026-06-24)
  - File: `sources/core/BFA.Core.Response.pas`
  - Risk: can expose SQL and sensitive values if used for logging.
  - Removed unused `ExpandSQLWithParams`.

- [x] Review request counter thread safety. (2026-06-24)
  - File: `sources/core/BFA.Core.Config.pas`
  - Current item: global `COUNTER_HIT_REQUEST`
  - Increment now uses `TInterlocked.Increment` in the image endpoint.

- [x] Review password hashing strategy. (2026-06-24)
  - Current behavior: HMAC-SHA256 with static app secret.
  - Target for real apps: use strong password hashing such as bcrypt/Argon2/PBKDF2 with per-user salt.
  - Kept for starter simplicity and documented the production limitation in `README.md` and `README.id.md`.

## Priority 5 - Documentation and Project Positioning

- [x] Expand `README.md`. (2026-06-24)
  - Current README is very short.
  - Add features, requirements, setup, database import, run instructions, API docs, security notes, license, contribution guidance.
  - Resolved: `README.md` and `README.id.md` include setup, DB import, MySQL client, build/run, API quickstart, endpoint extension guide, security notes, license, contributing, security policy, and changelog links.

- [x] Add `CONTRIBUTING.md`. (2026-06-24)
  - Include coding standards, branch/PR expectations, build validation, and documentation update rules.

- [x] Add `SECURITY.md`. (2026-06-24)
  - Include vulnerability reporting process.
  - Include warning not to report demo credentials as production secrets.

- [x] Add sample configuration file. (2026-06-24)
  - Suggested file: `config.example.ini` or `.env.example`
  - Added `config.example.ini` with `[Security] HMACSecret` placeholder.

- [x] Add changelog or release notes. (2026-06-24)
  - Suggested file: `CHANGELOG.md`
  - Useful once GitHub releases start.

- [x] Keep local AI project maps updated but unpublished. (2026-06-24)
  - Files: `docs/ai/PROJECT_MAP.md`, `docs/ai/UNIT_MAP.md`, or equivalent.
  - Keep concise and navigation-focused.
  - Updated `PROJECT_MAP.md`, `UNIT_MAP.md`, `FEATURE_MAP.md`, `DEPENDENCY_MAP.md`, and `project-map.json`.
  - Removed stale DataSnap, hardcoded credential, and default-password references.
  - Decision on 2026-06-24: `docs/ai/` remains local-only and is ignored by Git.

- [x] Refresh stale project information docs. (2026-06-24)
  - Files: `docs/information/structure.md`, `docs/information/information.md`.
  - Removed stale DataSnap references: `App.Server`, `Methods.Sample`, `Methods.Report`, and `sources/legacy/datasnap`.
  - Updated folder maps to match the current WebBroker REST API structure.

## Build Validation

- [x] Stop running `DelphiAPIStarterKit.exe` before build. (2026-06-24)
  - ~~Previous build failed because `bin\DelphiAPIStarterKit.exe` was locked and `taskkill` returned access denied.~~
  - Resolved: manually deleted `bin\DelphiAPIStarterKit.exe` before recompilation.

- [x] Run `compile.bat` after cleanup. (2026-06-24)
  - Result: **COMPILE SUCCESS**. 244 lines, 0.78s, 5863948 bytes code, 268472 bytes data.

- [x] If `compile.bat` is changed, test it from a fresh shell. (2026-06-24)
  - Result: **COMPILE SUCCESS** using `DELPHI_RSVARS` from a fresh `cmd /c` invocation.

- [x] Optional: add a CI-friendly build command note for users with Delphi installed. (2026-06-24)
  - `compile.bat` now exits with the MSBuild error code and no longer blocks on `pause`.

## Suggested Commit Order

1. Repository cleanup: remove risky binaries and fix `.gitignore`.
2. Configuration cleanup: DB config, secrets, default password, local paths.
3. Runtime hardening: DataSnap auth, route validation, file endpoint.
4. Documentation: README, API docs inclusion, setup guide, security notes.
5. Final build validation and release tag.

## Final Publish Gate

- [x] No real credentials or reusable secrets in source. (2026-06-24)
  - `DB.ConnectionFactory.pas`: DB credentials from env vars (`DELPHI_API_DB_*`) or `config.ini`.
  - `BFA.Helper.Strings.pas`: HMAC secret from `DELPHI_API_HMAC_SECRET` or `config.ini`.
  - `config.example.ini`: placeholder values only (`change-this-to-a-long-random-secret`).
  - `postman.collection.json`: `demo_admin`/`demo_admin` documented as demo-only sample.
  - No hardcoded production passwords, API keys, or internal secrets found.

- [x] No questionable third-party binaries tracked. (2026-06-24)
  - `bin/lib/libmysql.dll` removed from Git tracking.
  - `bin/files/image/*.png` removed from Git tracking.
  - Only first-party project files tracked: `DelphiAPIStarterKit.res`, `Server.res`.
  - `.gitignore` blocks `*.exe`, `*.dll`, `*.dcu`, `*.bpl`, `*.zip`, `*.local`, `*.identcache`.

- [x] Build succeeds locally. (2026-06-24)
  - Delphi 12.x (37.0), Debug/Win32.
  - **COMPILE SUCCESS**. 244 lines, 0.77s, 5868580 bytes code, 268472 bytes data.

- [x] README can guide a new developer from clone to running API. (2026-06-24)
  - Features list, requirements, project structure diagram.
  - Database setup: env vars/config.ini, MySQL CLI, phpMyAdmin.
  - HMAC secret setup.
  - MySQL client library installation guide (official sources only).
  - Build instructions (`compile.bat`, MSBuild).
  - Run instructions, API quickstart, route patterns, endpoint extension guide.
  - `x-api-token` header documented consistently with code and Postman collection.
  - Indonesian translation available in `README.id.md`.

- [x] API docs/Postman collection are available or linked. (2026-06-24)
  - `/docs/api/auth.md`, `users.md`, `products.md`, `category.md`, `customers.md`.
  - `/docs/api/postman.collection.json` with `x-api-token` header on protected endpoints.
  - Postman collection path documented in README.

- [x] Demo-only security limitations are clearly documented. (2026-06-24)
  - `SECURITY.md`: "Demo and Local Development Values" section lists all sample values.
  - `README.md`: explicit "not a production-ready deployment template" warning.
  - `README.id.md`: same warning in Indonesian.
  - Password hashing limitation (HMAC-SHA256 vs bcrypt/Argon2) documented in README.
  - Auth bypasses removed (DataSnap deletion).

- [x] Git diff is reviewed and contains only intentional changes. (2026-06-24)
  - Modified: `.gitignore`, `.pas` source files, `.dfm`, `compile.bat`, `postman.collection.json`, `README.md`, `README.id.md`.
  - Deleted: `bin/lib/libmysql.dll`, `bin/files/image/*.png`, DataSnap units.
  - New publish files: `.gitattributes`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `config.example.ini`, and non-AI `docs/` content.
  - Local-only ignored files: `.github/`, `AGENTS.md`, `docs/ai/`, and `docs/task/task.md`.
  - All changes traceable to: DataSnap removal, credential cleanup, runtime hardening, documentation expansion.

## Priority 6 - Final Git Publish Checklist

- [x] Stage all intended open-source files before pushing. (2026-06-24)
  - Required new files currently include `.gitattributes`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `config.example.ini`, and non-AI `docs/`.
  - Do not stage `.github/`, `AGENTS.md`, `docs/ai/`, or `docs/task/task.md`.
  - Without staging these files, the GitHub repository will miss README-linked docs and setup/security material.
  - Resolved: `git add -A` completed after ignore rules were updated; local AI/editor files were not staged.

- [x] Confirm staged binary removals are intentional. (2026-06-24)
  - `bin/lib/libmysql.dll` must stay removed from Git tracking.
  - `bin/files/image/a2bf9ff03e85462cb96e6e1cf0f0bcd3.png` must stay removed from Git tracking.
  - Local runtime files may remain on disk, but must stay ignored.
  - Resolved: both removals are present in `git diff --cached --name-status`.

- [x] Run final staged diff checks after `git add`. (2026-06-24)
  - `git diff --cached --check`
  - `git diff --cached --name-status`
  - `git status --short`
  - Result: `git diff --cached --check` passed.

- [x] Confirm no required publish files remain untracked. (2026-06-24)
  - `git status --short` should not show required README-linked docs as `??`.
  - Runtime-only files and local AI/editor instruction files may remain untracked if they are intentionally ignored.
  - Resolved: local-only files are ignored, including `.github/`, `AGENTS.md`, `docs/ai/`, `docs/task/task.md`, and `bin/config.example.ini`.

- [x] Confirm AI/editor instruction files are not included in the commit. (2026-06-24)
  - `git diff --cached --name-status` must not include `.github/`, `AGENTS.md`, `docs/ai/`, or `docs/task/task.md`.
  - `.gitignore` must keep these paths ignored.
  - Result: staged diff contains no AI/editor instruction paths.

- [ ] Create the initial open-source commit and push.
  - Recommended commit scope: repository cleanup, security hardening, runtime safety, and documentation.
  - After push, verify GitHub renders `README.md` correctly and all relative documentation links work.
