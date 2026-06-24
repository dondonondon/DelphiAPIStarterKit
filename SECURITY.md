# Security Policy

## Supported Versions

This repository is currently a starter template. Security fixes are expected to target the default branch unless release branches are introduced later.

## Reporting a Vulnerability

Please do not open a public issue for a sensitive vulnerability.

Report privately using GitHub Security Advisories if available for this repository, or contact the maintainer through the private channel listed in the GitHub repository profile.

Include:

- Affected endpoint or file.
- Steps to reproduce.
- Expected impact.
- Suggested fix if available.

## Demo and Local Development Values

The project includes documented placeholders and local setup examples. These are not production credentials:

- `config.example.ini` placeholder values.
- README examples such as `localhost`, `root`, `demo_delphirest`, and demo request payloads.
- Postman variables and sample request data.

Do report:

- Real committed credentials.
- Auth bypasses.
- SQL injection risks.
- Sensitive data exposure.
- Unsafe file access.
- Token/session validation flaws.

## Production Hardening Reminder

Before production use, review:

- HTTPS termination.
- CORS policy.
- Password hashing strategy.
- Role-based authorization.
- Database account permissions.
- Logging and sensitive data redaction.
- Backup, migration, and deployment procedures.
