# Users API

Base URL: `/api/v1/User`

All endpoints return the standard JSON envelope:

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [ ... ]
}
```

For error responses (HTTP status outside 200-299), `data` is `[{}]` and the error message is in `messages`.

## Authentication

All `User` endpoints require a valid access token, except the `Auth` endpoints documented separately.

Recommended header:

```text
Authorization: Bearer <token>
```

Token is also accepted from `x-api-token` or `access-token`.

---

## GET /api/v1/User

List all users.

### Request

No request body.

### Response — 200 OK

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [
    {
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "username": "john_doe",
      "fullname": "John Doe",
      "is_active": "1",
      "role_id": "2",
      "created_at": "2026-06-18 10:00:00"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 404 | `User not found` | No users exist in the database |
| 500 | `Internal server error.` | Unhandled exception |

### Notes

- Results are ordered by `created_at DESC, username ASC`.

---

## GET /api/v1/User/{user_id}

Get a single user by ID.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `user_id` | string (UUID) | URL path | Yes |

### Response — 200 OK

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [
    {
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "username": "john_doe",
      "fullname": "John Doe",
      "is_active": "1",
      "role_id": "2",
      "created_at": "2026-06-18 10:00:00"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 404 | `User not found` | No user with the given ID |
| 500 | `Internal server error.` | Unhandled exception |

---

## POST /api/v1/User

Create a new user.

### Request

```json
{
  "username": "string (required)",
  "password": "string (required)",
  "fullname": "string (optional)",
  "is_active": "integer (optional, default: 1)",
  "role_id": "integer (optional)"
}
```

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `username` | string | Yes | — | Must be unique |
| `password` | string | Yes | — | Hashed with HMAC-SHA256 before storage |
| `fullname` | string | No | `""` | Display name |
| `is_active` | integer | No | `1` | `0` = inactive, `1` = active |
| `role_id` | integer | No | — | Role identifier |

### Response — 201 Created

```json
{
  "status": 201,
  "messages": "User created",
  "servertime": "1780962999",
  "data": [
    {
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "username": "john_doe",
      "fullname": "John Doe",
      "is_active": "1",
      "role_id": "2"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Username required` | `username` missing or empty |
| 400 | `Password required` | `password` missing or empty |
| 400 | `Invalid is_active value` | `is_active` not `0` or `1` |
| 400 | `Invalid role_id value` | `role_id` not a valid integer |
| 409 | `Username already exists` | Duplicate `username` |
| 500 | `Internal server error.` | Unhandled exception |

---

## PUT /api/v1/User/{user_id}

Update an existing user. All fields are optional — only provided fields are updated.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `user_id` | string (UUID) | URL path | Yes |

```json
{
  "password": "string (optional)",
  "fullname": "string (optional)",
  "is_active": "integer (optional)",
  "role_id": "integer (optional)"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `password` | string | No | Hashed with HMAC-SHA256 before storage |
| `fullname` | string | No | Display name |
| `is_active` | integer | No | `0` = inactive, `1` = active |
| `role_id` | integer | No | Role identifier |

### Response — 200 OK

```json
{
  "status": 200,
  "messages": "User updated",
  "servertime": "1780962999",
  "data": [
    {
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "username": "john_doe",
      "fullname": "John Doe Updated",
      "is_active": "1",
      "role_id": "2"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `User ID required` | `user_id` missing from URL |
| 400 | `Invalid user ID` | `user_id` exceeds 36 characters |
| 400 | `Username cannot be changed` | `username` field present in body |
| 400 | `Password required` | `password` field present but empty |
| 400 | `Invalid is_active value` | `is_active` not `0` or `1` |
| 400 | `Invalid role_id value` | `role_id` not a valid integer |
| 400 | `No data to update` | No optional fields provided |
| 404 | `User not found` | No user with the given ID |
| 500 | `Internal server error.` | Unhandled exception |

---

## DELETE /api/v1/User/{user_id}

Soft-delete a user (sets `is_active = 0`).

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `user_id` | string (UUID) | URL path | Yes |

### Response — 200 OK

```json
{
  "status": 200,
  "messages": "User deleted",
  "servertime": "1780962999",
  "data": []
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `User ID required` | `user_id` missing from URL |
| 400 | `Invalid user ID` | `user_id` exceeds 36 characters |
| 404 | `User not found` | No user with the given ID |
| 500 | `Internal server error.` | Unhandled exception |

### Notes

- This is a soft delete — the row remains in the database with `is_active = 0`.

---

## POST /api/v1/User/ChangePassword

Change the authenticated user's own password. Requires a valid access token.

### Authentication

Token is extracted from headers in this priority order:
1. `x-api-token`
2. `access-token`
3. `Authorization: Bearer <token>`

### Request

```json
{
  "old_password": "string (required)",
  "new_password": "string (required)"
}
```

### Response — 200 OK

```json
{
  "status": 200,
  "messages": "Password updated",
  "servertime": "1780962999",
  "data": []
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Old password required` | `old_password` missing or empty |
| 400 | `New password required` | `new_password` missing or empty |
| 400 | `New password must be different` | New password equals old password |
| 401 | `Session expired or invalid` | Token missing, expired, or invalid |
| 401 | `Old password invalid` | Old password does not match |
| 404 | `User not found` | Authenticated user no longer exists |
| 500 | `Internal server error.` | Unhandled exception |

---

## POST /api/v1/User/ResetPassword

Admin reset of another user's password to a generated temporary password. Requires a valid access token.

### Authentication

Same token extraction as ChangePassword.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `user_id` | string (UUID) | URL path | Yes |

```json
{
  "confirm_reset": "string (required, must be 'true')"
}
```

### Response — 200 OK

```json
{
  "status": 200,
  "messages": "Password reset",
  "servertime": "1780962999",
  "data": [
    {
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "reset_by": "660e8400-e29b-41d4-a716-446655440001",
      "temporary_password": "d78a0c18d8f64c6aa64f4d28"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `User ID required` | `user_id` missing from URL |
| 400 | `Invalid user ID` | `user_id` exceeds 36 characters |
| 400 | `confirm_reset required` | `confirm_reset` missing or empty |
| 400 | `confirm_reset must be true` | `confirm_reset` is not `"true"` or `"1"` |
| 401 | `Session expired or invalid` | Token missing, expired, or invalid |
| 404 | `User not found` | Target user does not exist |
| 500 | `Internal server error.` | Unhandled exception |

### Notes

- Resets the target user's password to a generated temporary password.
- The temporary password is returned once in the response and should be changed by the user after login.
- The authenticated user (requester) ID is recorded in the response as `reset_by`.
