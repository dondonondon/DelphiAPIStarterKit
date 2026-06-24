# Customers API

Base URL: `/api/v1/Customer`

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

All `Customer` endpoints require a valid access token.

Recommended header:

```text
Authorization: Bearer <token>
```

Token is also accepted from `x-api-token` or `access-token`.

## GET /api/v1/Customer

List all customers.

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [
    {
      "customer_id": "550e8400-e29b-41d4-a716-446655440000",
      "customer_name": "John Doe",
      "email": "john.doe@example.com",
      "phone_number": "+62-812-3456-7890",
      "address_line1": "Jl. Merdeka No. 10",
      "address_line2": "",
      "city": "Jakarta",
      "state": "DKI Jakarta",
      "postal_code": "10110",
      "country": "Indonesia",
      "notes": "Priority customer",
      "is_active": 1,
      "created_at": "2026-06-19 10:00:00"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 404 | `Customer not found` | No customers exist in the database |
| 500 | `Internal server error.` | Unhandled exception |

## GET /api/v1/Customer/{customer_id}

Get a single customer by public customer ID.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `customer_id` | string (UUID) | URL path | Yes |

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [
    {
      "customer_id": "550e8400-e29b-41d4-a716-446655440000",
      "customer_name": "John Doe",
      "email": "john.doe@example.com",
      "phone_number": "+62-812-3456-7890",
      "address_line1": "Jl. Merdeka No. 10",
      "address_line2": "",
      "city": "Jakarta",
      "state": "DKI Jakarta",
      "postal_code": "10110",
      "country": "Indonesia",
      "notes": "Priority customer",
      "is_active": 1,
      "created_at": "2026-06-19 10:00:00"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 404 | `Customer not found` | No customer with the given ID |
| 500 | `Internal server error.` | Unhandled exception |

## POST /api/v1/Customer

Create a new customer.

### Request

```json
{
  "customer_name": "John Doe",
  "email": "john.doe@example.com",
  "phone_number": "+62-812-3456-7890",
  "address_line1": "Jl. Merdeka No. 10",
  "address_line2": "",
  "city": "Jakarta",
  "state": "DKI Jakarta",
  "postal_code": "10110",
  "country": "Indonesia",
  "notes": "Priority customer",
  "is_active": 1
}
```

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `customer_name` | string | Yes | - | Maximum 100 characters |
| `email` | string | No | `""` | Maximum 100 characters, must be a valid email format if supplied |
| `phone_number` | string | No | `""` | Maximum 30 characters |
| `address_line1` | string | No | `""` | Maximum 150 characters |
| `address_line2` | string | No | `""` | Maximum 150 characters |
| `city` | string | No | `""` | Maximum 100 characters |
| `state` | string | No | `""` | Maximum 100 characters |
| `postal_code` | string | No | `""` | Maximum 20 characters |
| `country` | string | No | `""` | Maximum 100 characters |
| `notes` | string | No | `""` | Free text notes |
| `is_active` | integer | No | `1` | `0` = inactive, `1` = active |

### Response - 201 Created

```json
{
  "status": 201,
  "messages": "Customer created",
  "servertime": "1780962999",
  "data": [
    {
      "customer_id": "550e8400-e29b-41d4-a716-446655440000",
      "customer_name": "John Doe",
      "email": "john.doe@example.com",
      "phone_number": "+62-812-3456-7890",
      "address_line1": "Jl. Merdeka No. 10",
      "address_line2": "",
      "city": "Jakarta",
      "state": "DKI Jakarta",
      "postal_code": "10110",
      "country": "Indonesia",
      "notes": "Priority customer",
      "is_active": 1
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Customer name required` | `customer_name` missing or empty |
| 400 | `Customer name too long` | `customer_name` exceeds 100 characters |
| 400 | `Email too long` | `email` exceeds 100 characters |
| 400 | `Invalid email value` | `email` format is invalid |
| 400 | `Phone number too long` | `phone_number` exceeds 30 characters |
| 400 | `Address line 1 too long` | `address_line1` exceeds 150 characters |
| 400 | `Address line 2 too long` | `address_line2` exceeds 150 characters |
| 400 | `City too long` | `city` exceeds 100 characters |
| 400 | `State too long` | `state` exceeds 100 characters |
| 400 | `Postal code too long` | `postal_code` exceeds 20 characters |
| 400 | `Country too long` | `country` exceeds 100 characters |
| 400 | `Invalid is_active value` | `is_active` is not `0` or `1` |
| 500 | `Internal server error.` | Unhandled exception |

## PUT /api/v1/Customer/{customer_id}

Update an existing customer. All fields are optional, but at least one editable field must be supplied.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `customer_id` | string (UUID) | URL path | Yes |

```json
{
  "customer_name": "John Doe",
  "email": "john.updated@example.com",
  "phone_number": "+62-812-0000-1111",
  "city": "Bandung",
  "notes": "Updated note",
  "is_active": 1
}
```

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "Customer updated",
  "servertime": "1780962999",
  "data": [
    {
      "customer_id": "550e8400-e29b-41d4-a716-446655440000",
      "customer_name": "John Doe",
      "email": "john.updated@example.com",
      "phone_number": "+62-812-0000-1111",
      "address_line1": "Jl. Merdeka No. 10",
      "address_line2": "",
      "city": "Bandung",
      "state": "DKI Jakarta",
      "postal_code": "10110",
      "country": "Indonesia",
      "notes": "Updated note",
      "is_active": 1
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Customer ID required` | `customer_id` missing from URL |
| 400 | `Invalid customer ID` | `customer_id` exceeds 36 characters |
| 400 | `Customer ID cannot be changed` | `customer_id` field present in body |
| 400 | `Customer name required` | `customer_name` field present but empty |
| 400 | `Customer name too long` | `customer_name` exceeds 100 characters |
| 400 | `Email too long` | `email` exceeds 100 characters |
| 400 | `Invalid email value` | `email` format is invalid |
| 400 | `Phone number too long` | `phone_number` exceeds 30 characters |
| 400 | `Address line 1 too long` | `address_line1` exceeds 150 characters |
| 400 | `Address line 2 too long` | `address_line2` exceeds 150 characters |
| 400 | `City too long` | `city` exceeds 100 characters |
| 400 | `State too long` | `state` exceeds 100 characters |
| 400 | `Postal code too long` | `postal_code` exceeds 20 characters |
| 400 | `Country too long` | `country` exceeds 100 characters |
| 400 | `Invalid is_active value` | `is_active` is not `0` or `1` |
| 400 | `No data to update` | No editable fields provided |
| 404 | `Customer not found` | No customer with the given ID |
| 500 | `Internal server error.` | Unhandled exception |

## DELETE /api/v1/Customer/{customer_id}

Soft-delete a customer by setting `is_active = 0` and `deleted_at = NOW()`.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `customer_id` | string (UUID) | URL path | Yes |

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "Customer deleted",
  "servertime": "1780962999",
  "data": []
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Customer ID required` | `customer_id` missing from URL |
| 400 | `Invalid customer ID` | `customer_id` exceeds 36 characters |
| 404 | `Customer not found` | No customer with the given ID |
| 500 | `Internal server error.` | Unhandled exception |
