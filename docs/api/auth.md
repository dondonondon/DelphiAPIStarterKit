# Auth API

Base URL: `/api/v1/Auth`

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

---

## POST /api/v1/Auth/Login

Authenticate a user and create a new session with access token.

### Request

```json
{
  "username": "string (required)",
  "password": "string (required)",
  "device_id": "string (required)",
  "device_name": "string (optional)",
  "user_agent": "string (optional)",
  "ip_address": "string (optional)"
}
```

### Response — 200 OK

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [
    {
      "access_token": "a1b2c3d4e5f6...",
      "expires_in": "1800",
      "session_id": "550e8400-e29b-41d4-a716-446655440000"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Username required` | `username` missing or empty |
| 400 | `Password required` | `password` missing or empty |
| 400 | `Device ID required` | `device_id` missing or empty |
| 401 | `Invalid username or password` | Credentials do not match |
| 403 | `User inactive` | Account is deactivated |
| 500 | `Internal server error.` | Unhandled exception |

### Notes

- Password is hashed with HMAC-SHA256 and compared against the stored hash.
- A new login revokes all active sessions for the same user + device combination.
- Session expires after 7 days. Access token expires after 30 minutes (1800 seconds).
- If `user_agent` or `ip_address` are empty, they are auto-filled from the request.

---

## POST /api/v1/Auth/Logout

Revoke an active session.

### Request

```json
{
  "session_id": "string (required)",
  "device_id": "string (required)"
}
```

### Response — 200 OK

```json
{
  "status": 200,
  "messages": "Logged out",
  "servertime": "1780962999",
  "data": []
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Session ID and Device ID required` | `session_id` or `device_id` missing |
| 500 | `Internal server error.` | Unhandled exception |

---

## POST /api/v1/Auth/Refresh

Issue a new access token for an existing active session.

### Request

```json
{
  "session_id": "string (required)",
  "device_id": "string (required)"
}
```

### Response — 200 OK

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [
    {
      "access_token": "f7e8d9c0b1a2...",
      "expires_in": "1800"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Session ID and Device ID required` | `session_id` or `device_id` missing |
| 401 | `Session expired or invalid` | Session not found or already revoked |
| 500 | `Internal server error.` | Unhandled exception |

### Notes

- Does not create a new session — only issues a new access token for the existing session.
- The old access token remains valid until it expires naturally.
