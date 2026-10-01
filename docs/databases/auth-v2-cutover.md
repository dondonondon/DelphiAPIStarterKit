# Auth-v2 numeric clone migration and client cutover

WAVE-01 implements a versioned shadow upgrade for the numeric auth schema at HEAD
`358db33b95724f654db00e39fd4f35dc26c0d12c`. It was executed only on disposable `wave01_clone_numeric`,
MariaDB 11.4.9/InnoDB/utf8mb4, explicit verified source offset `+00:00`. No production database was modified.
[Evidence and reopening gates](../bugs/wave-01-result.md) remain authoritative.

## Fresh setup

Import exactly one of `assets/databases/demo_delphirest.sql` (DDL only) or the complete
`demo_delphirest_withdatasample.sql` (DDL + role/permission/business demo data) into a fresh empty DB.
Both have identical auth DDL, FK/CHECK/unique constraints and no seeded user/password/session/token.
Never run either on an existing schema. Bootstrap operator-selected admin offline as described in [Auth](../api/auth.md).
Provider/bitness/config must be ready before starting auth source. SQL and old Pascal source are incompatible.

## Upgrade rehearsal

Take and verify an offline clone backup first; stop writers/listener for the maintenance window.
The clone-only driver [migrate-auth-v2-clone.py](../../scripts/migrate-auth-v2-clone.py) deliberately refuses
any database name outside `wave01_clone_*`. Production deployment is a separate T11/T10 reviewed gate.
Use process-only WAVE01_DB_HOST/PORT/USER/PASSWORD variables. Never put passwords in arguments/evidence.
Example non-secret command, after injecting those variables:

```text
py -3 scripts/migrate-auth-v2-clone.py --database wave01_clone_rehearsal --source-time-zone +00:00 --policy role-policy.json --dependencies <isolated-python-dependencies>
```

`role-policy.json` is an explicit object mapping legacy numeric role IDs (string keys) to arrays of
known permission codes. No inferred superadmin bypass/grant. Operator must verify source timezone and
role delegation plan. PyMySQL is an isolated migration/test tool, not an application dependency.

The script verifies numeric/unsigned IDs, signed application bounds, UUID lowercase ASCII, username/hash
shape, flags and role references, refuses prior migration state, then executes the dedicated
[auth-v2-upgrade-numeric-20261001.sql](../../assets/databases/auth-v2-upgrade-numeric-20261001.sql).
It does not import a fresh baseline. It creates `auth_v2_*` shadow tables, backfills public/internal IDs,
role_code `legacy_role_<id>`, UTC dates, password_changed_at and must_change_password=1. Existing HMAC
hashes remain version-detectable; no SQL hash conversion. It adds the 20 permission catalog and approved
role grants, verifies counts, commits legacy access/session revocation, then atomically RENAMEs old four
auth tables to `legacy_auth_*` and shadow tables to target names. New session/access/refresh/recovery
credential tables start empty. All clients must log in again.

Rehearsal proved target auth DDL equals fresh baseline/sample (constraint names may have v2_ prefix),
FK/CHECK/unique/cross-session successor enforcement, backfill/login rehash/restricted session and atomic
archive restore/re-cutover with legacy credentials still revoked. No FOREIGN_KEY_CHECKS suppression.
A failed preflight does not mutate source; failure after DDL may leave shadow tables for inspection.
Do not rerun/drop archives blindly. This is not a general migration engine or a claim about GUID schemas,
third-party inbound foreign keys, MySQL 8.x, production dataset or business-schema reconciliation.

## Cutover/rollback gates

Deploy source + target schema + updated client atomically under maintenance, using protected pinned
Argon2 library/dependencies and an explicit finite LegacyHashDeadline + original HMACSecret for accounts
not migrated through recovery. No deadline/secret means old hash login is denied. Remove legacy verifier
only after account reconciliation; do not log hashes/key. Legacy login performs Argon2 rehash but remains
restricted until password change. Offline archive rollback is allowed only under maintenance and must
keep all old credentials revoked; do not expose old insecure HTTP source as a fallback.
Production backup/restore, grants/audit retention, schema inventory, original-key availability, timezone,
provider package/TLS/native dependency profile and client storage/MFA require actual staging evidence.

Client changes are intentional: single-flight rotating refresh_token, logout access/refresh credential,
no session_id/device_id-only fallback, integer expiry, restricted-password routing, one-time setup/reset
redemption, no temporary_password, generic PUT password denied, typed flags and no request echo.
FMX/browser implementation and rollout evidence are unavailable here; do not claim client cutover complete.

Maintenance `--auth-cleanup` removes at most 100 old families/recovery rows per invocation after 7-day
expiry retention. Schedule/deployment policy remains T10/T04; active refresh reuse evidence is retained.
Legacy archives contain old password hashes and must be protected/retained/deleted according to the
approved production rollback window; WAVE-01 does not delete them or production data.
