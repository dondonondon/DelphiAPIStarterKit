# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- English README with setup, database import, MySQL client library, endpoint extension, and security notes.
- Indonesian README link via `README.id.md`.
- `config.example.ini` for application secret and database settings.
- Open-source contribution and security policy documents.
- API documentation and Postman collection publishing path.
- Project navigation maps under `docs/ai`.

### Changed

- Database connection values now come from environment variables or `config.ini`.
- HMAC signature secret now comes from environment variables or `config.ini`.
- Reset password now generates a temporary password instead of using a hardcoded default.
- `compile.bat` is portable, configurable, and CI-friendlier.
- Protected API resources now require access token validation.
- Runtime route and image-serving behavior hardened.

### Removed

- Tracked MySQL client DLL and runtime sample file from Git tracking.
- Hardcoded local `VendorHome` path from the data module.
- Unused raw SQL helper methods.
- Unused SQL parameter expansion helper.

### Security

- Access token validation is enforced for `User`, `Product`, `Category`, and `Customer` resources.
- `Auth` remains public for login, logout, and refresh.
- Password hashing limitation is documented for production review.
