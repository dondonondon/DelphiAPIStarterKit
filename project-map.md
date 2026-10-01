# DelphiAPIStarterKit Project Map

This repository is a Delphi WebBroker REST starter hosted by an Indy HTTP bridge. Keep the current feature-first source structure; this map describes navigation and responsibility, not proof that the remediation backlog is complete.

| Area | Current entry point | Responsibility / navigation |
|---|---|---|
| Host / project | [DPR](DelphiAPIStarterKit.dpr), [DPROJ](DelphiAPIStarterKit.dproj) | Console server startup, platform configuration, and explicit unit references |
| HTTP entry | [App.WebModule](sources/app/App.WebModule.pas) | WebBroker actions and SendToCoreAPI request dispatch |
| Route resolution | [BFA.Core.Rest](sources/core/BFA.Core.Rest.pas) | TClassHelper.CallMethodAPI, class/method resolution, RegisterClassAPI |
| Endpoint boundary | [BFA.Core.Endpoint](sources/core/BFA.Core.Endpoint.pas) | THelperEndpoint.ExecuteRoute, authentication and endpoint exception boundary |
| Request / response | [Request](sources/core/BFA.Core.Request.pas), [Response](sources/core/BFA.Core.Response.pas) | Input conversion and shared response creation/serialization |
| Configuration | [Config](sources/core/BFA.Core.Config.pas), [String helpers](sources/shared/helpers/BFA.Helper.Strings.pas) | Existing config/path and legacy technical helpers; inspect callers before extension |
| Database | [Connection factory](sources/infrastructure/database/DB.ConnectionFactory.pas), [Query helper](sources/infrastructure/database/DB.Helper.Query.pas), [uDM](uDM.pas) | FireDAC connection setup, query infrastructure, and legacy data module |
| Token infrastructure | [BFA.Security.Token](sources/infrastructure/security/BFA.Security.Token.pas) | Token operations; verify current security behavior against auth task acceptance |
| Feature modules | [Modules](sources/modules/) | auth, users, products, customers, category, and sample; business units stay flat per feature |
| Shared utilities | [Helpers](sources/shared/helpers/) | Dataset, string, transaction, and validator helpers |
| Database/API contract | [Schemas](assets/databases/), [API docs](docs/api/), [Postman](docs/api/postman.collection.json) | Current schema snapshots and documented public API; support claims must match actual provider evidence |
| Build | [compile.bat](compile.bat), [CloseApp.bat](CloseApp.bat) | Debug / Win32 script default, BUILD_CONFIG/BUILD_PLATFORM overrides, DELPHI_RSVARS/BDS prerequisites |
| Orchestration | [Execution contract](.ai/ORCHESTRATOR.md), [Skill](.agents/skills/project-orchestrator/SKILL.md) | Scoped serial execution, review, evidence, and recovery |
| Existing remediation | [Task navigation](.ai/TASK-INDEX.md) | Four existing waves; task files remain authoritative for status/acceptance |
| Package validation | [Validator](scripts/validate-orchestrator.ps1) | Skills, local Markdown links, script syntax, and Git ignore behavior |

## Boundaries and update rules

The intended responsibility direction is HTTP entry/endpoint -> validator -> service -> repository -> database, with core/shared utilities for technical concerns. API registration currently lives in BFA.Core.Rest.RegisterClassAPI; new module units also need DPR references. Inspect actual route parsing and docs instead of inventing paths.

The project supports Win32, Win64, and Linux64 configurations; compile.bat selects Win32 by default, while the current DPROJ default is Linux64. Linux toolchain/PAServer and native client availability are separate prerequisites. A cross-build is not Linux runtime/deployment evidence. T10.a/F34 no longer performs image-name termination; compile.bat/CloseApp are non-killing. Platform output collision F41 remains T10 scope.

MySQL/MariaDB scripts are the actual schema examples. Firebird/SQL Server friendly coding is a project expectation, not demonstrated provider/runtime coverage. Keep vendor-specific persistence isolated and documented.

Runtime config.ini, upload files, platform outputs, archives, and local .ai/runs checkpoints are not source authority. temp-file is a read-only legacy reference. Root AGENTS.md and .github instructions may be local-only due to Git excludes; the versionable execution contract retains essential project rules for the shared package.

Update this map for new units, helper APIs, routes, dependencies, registration, or workflows. Update the existing [source layout document](docs/information/structure.md) when the source structure changes. Do not add task statuses here.

## Auth-v2 target schema and implementation contract

[Auth-v2 contract](docs/bugs/auth-production-contract-2026-10-01.md) owns the planned permission/session/refresh/recovery/bootstrap
behavior. [Fresh DDL](assets/databases/demo_delphirest.sql) and
[optional full demo import](assets/databases/demo_delphirest_withdatasample.sql) share the target schema;
they are alternatives for an empty database and contain no seeded login credentials. New tables:
m_permission, role_permission, refresh_token, password_reset_token, auth_security_event, auth_rate_limit.
Source/API/Postman implement the auth-v2 cutover. Clone-only versioned numeric upgrade is in scripts/migrate-auth-v2-clone.py
and assets/databases/auth-v2-upgrade-numeric-20261001.sql; production deployment gates remain in the task evidence.

| Auth-v2 authority | Entry / responsibility |
|---|---|
| Actor / permission | sources/modules/auth/Auth.Policy.pas + Auth.Repository.ResolveActor; explicit catalog/delegation/last-admin lock |
| Typed input / config | BFA.Core.Request JSONObject/JSONString/JSONInteger/Codepoints; Auth.Validator; TServerConfig.FileName/ReadValue; Auth.Settings |
| Crypto | BFA.Security.Crypto: OS CSPRNG credentials, canonical token SHA-256, pinned native Argon2id PHC and finite legacy verifier |
| Transport | BFA.Security.Transport.TSecurityHTTPBridge header/body checks; TSecurityTransport Bearer hook/CORS/UTF-8; Core.Helper.InspectRoute whitelist |
| Error logger | BFA.Logger.THelperLogger.Error shared nonthrowing sink/fallback; never logs raw exception message/credential |
| New role module | sources/modules/roles/RestAPI.Role, Role.Validator/Service/Repository; explicit DPR + RegisterClassAPI |
| Offline operations | Auth.Bootstrap --bootstrap-admin; Auth.Repository.Cleanup --auth-cleanup; no HTTP bootstrap |
| Runtime checks | scripts/test-wave01*.py, Wave01CoreTests.dpr; disposable local fixture only; evidence separated by platform |

New registered auth routes: Reauthenticate, LogoutAll, Me, Sessions, DELETE Sessions/{UUID}, CompletePasswordReset;
Role GET and PUT Role/{UUID}/Permissions. Business modules stay feature-first/flat. Auth.DTO legacy TStringList DTO is retained
for source compatibility but has no active auth-v2 consumer and is not the issuance authority. Typed raw validators replace the
old auth/user dataset-based validation signatures intentionally; external source consumers must cut over with auth-v2.
