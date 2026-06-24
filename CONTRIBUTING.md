# Contributing

Thank you for considering a contribution to DelphiAPIStarterKit.

This project is a Delphi WebBroker REST API starter kit. Keep contributions generic, reusable, and suitable for an open-source backend template.

## Development Setup

1. Install Delphi with WebBroker, FireDAC, FireDAC MySQL driver, and the standard Indy/WebBroker bridge units.
2. Install MySQL or MariaDB.
3. Import `assets/databases/demo_delphirest.sql`.
4. Copy `config.example.ini` to `config.ini` or configure the equivalent environment variables.
5. Set `DELPHI_RSVARS` if you are not using a Delphi command prompt.
6. Run `compile.bat`.

## Coding Standards

- Keep WebBroker modules thin.
- Put business logic in services.
- Put database access in repositories.
- Validate request data before business logic.
- Use parameterized SQL only.
- Keep response format consistent with the standard JSON envelope.
- Do not commit real credentials, local `config.ini`, private keys, certificates, or vendor DLLs.
- Do not add unnecessary third-party dependencies.
- Update API docs and the Postman collection when changing endpoints.

## Branch and Pull Request Expectations

- Use a focused branch per change.
- Keep unrelated refactors out of feature or bugfix pull requests.
- Include a short summary of behavior changes.
- Mention database schema changes clearly.
- Include validation results from `compile.bat`.

## Build Validation

From a normal terminal:

```bat
set DELPHI_RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
compile.bat
```

Optional overrides:

```bat
set BUILD_CONFIG=Release
set BUILD_PLATFORM=Win64
compile.bat
```

## Documentation Rules

Update these files when relevant:

- `README.md`
- `README.id.md`
- `docs/api/*.md`
- `docs/api/postman.collection.json`
- `docs/ai/PROJECT_MAP.md`
- `docs/ai/UNIT_MAP.md`
- `docs/task/task-finalization.md`

## Security

Do not report demo placeholders or documented local setup examples as production secrets. Real vulnerabilities should be reported through the process in `SECURITY.md`.
