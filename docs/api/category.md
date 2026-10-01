# Category API

Base URL: `/api/v1/Category`

All endpoints return the standard JSON envelope:

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": []
}
```

For error responses (HTTP status outside 200-299), `data` is `[{}]` and the error message is in `messages`.

## Authentication

All `Category` endpoints require a valid access token.

Recommended header:

```text
Authorization: Bearer <token>
```

Token is also accepted from `x-api-token` or `access-token`.

## GET /api/v1/Category

List all categories.

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [
    {
      "category_id": "550e8400-e29b-41d4-a716-446655440000",
      "category_name": "Electronics",
      "description": "Electronic devices and accessories",
      "is_active": 1,
      "created_at": "2026-06-19 10:00:00"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 404 | `Category not found` | No categories exist in the database |
| 500 | `Internal server error.` | Unhandled exception |

## GET /api/v1/Category/{category_id}

Get a single category by public category ID.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `category_id` | string (UUID) | URL path | Yes |

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [
    {
      "category_id": "550e8400-e29b-41d4-a716-446655440000",
      "category_name": "Electronics",
      "description": "Electronic devices and accessories",
      "is_active": 1,
      "created_at": "2026-06-19 10:00:00"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 404 | `Category not found` | No category with the given ID |
| 500 | `Internal server error.` | Unhandled exception |

## POST /api/v1/Category

Create a new category.

### Request

```json
{
  "category_name": "Electronics",
  "description": "Electronic devices and accessories",
  "is_active": 1
}
```

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `category_name` | string | Yes | - | Maximum 50 characters |
| `description` | string | No | `""` | Maximum 150 characters |
| `is_active` | integer | No | `1` | `0` = inactive, `1` = active |

### Response - 201 Created

```json
{
  "status": 201,
  "messages": "Category created",
  "servertime": "1780962999",
  "data": [
    {
      "category_id": "550e8400-e29b-41d4-a716-446655440000",
      "category_name": "Electronics",
      "description": "Electronic devices and accessories",
      "is_active": 1
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Category name required` | `category_name` missing or empty |
| 400 | `Category name too long` | `category_name` exceeds 50 characters |
| 400 | `Description too long` | `description` exceeds 150 characters |
| 400 | `Invalid is_active value` | `is_active` is not `0` or `1` |
| 409 | `Category name already exists` | Another active category uses the same name |
| 500 | `Internal server error.` | Unhandled exception |

## PUT /api/v1/Category/{category_id}

Update an existing category. All fields are optional, but at least one editable field must be supplied.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `category_id` | string (UUID) | URL path | Yes |

```json
{
  "category_name": "Office Supplies",
  "description": "Updated category description",
  "is_active": 1
}
```

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "Category updated",
  "servertime": "1780962999",
  "data": [
    {
      "category_id": "550e8400-e29b-41d4-a716-446655440000",
      "category_name": "Office Supplies",
      "description": "Updated category description",
      "is_active": 1
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Category ID required` | `category_id` missing from URL |
| 400 | `Invalid category ID` | `category_id` exceeds 36 characters |
| 400 | `Category ID cannot be changed` | `category_id` field present in body |
| 400 | `Category name required` | `category_name` field present but empty |
| 400 | `Category name too long` | `category_name` exceeds 50 characters |
| 400 | `Description too long` | `description` exceeds 150 characters |
| 400 | `Invalid is_active value` | `is_active` is not `0` or `1` |
| 400 | `No data to update` | No editable fields provided |
| 404 | `Category not found` | No category with the given ID |
| 409 | `Category name already exists` | Another active category uses the same name |
| 500 | `Internal server error.` | Unhandled exception |

## DELETE /api/v1/Category/{category_id}

Soft-delete a category by setting `is_active = 0` and `deleted_at = NOW()`.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `category_id` | string (UUID) | URL path | Yes |

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "Category deleted",
  "servertime": "1780962999",
  "data": []
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Category ID required` | `category_id` missing from URL |
| 400 | `Invalid category ID` | `category_id` exceeds 36 characters |
| 404 | `Category not found` | No category with the given ID |
| 500 | `Internal server error.` | Unhandled exception |
