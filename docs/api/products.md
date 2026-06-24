# Products API

Base URL: `/api/v1/Product`

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

All `Product` endpoints require a valid access token.

Recommended header:

```text
Authorization: Bearer <token>
```

Token is also accepted from `x-api-token` or `access-token`.

## GET /api/v1/Product

List all products.

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [
    {
      "product_id": "550e8400-e29b-41d4-a716-446655440000",
      "product_name": "Sample Product",
      "description": "Sample description",
      "price": 12500.00,
      "stock": 25,
      "category_id": "550e8400-e29b-41d4-a716-446655440111",
      "category_name": "Electronics",
      "is_active": 1,
      "created_at": "2026-06-19 10:00:00"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 404 | `Product not found` | No products exist in the database |
| 500 | `Internal server error.` | Unhandled exception |

## GET /api/v1/Product/{product_id}

Get a single product by public product ID.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `product_id` | string (UUID) | URL path | Yes |

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": [
    {
      "product_id": "550e8400-e29b-41d4-a716-446655440000",
      "product_name": "Sample Product",
      "description": "Sample description",
      "price": 12500.00,
      "stock": 25,
      "category_id": "550e8400-e29b-41d4-a716-446655440111",
      "category_name": "Electronics",
      "is_active": 1,
      "created_at": "2026-06-19 10:00:00"
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 404 | `Product not found` | No product with the given ID |
| 500 | `Internal server error.` | Unhandled exception |

## POST /api/v1/Product

Create a new product.

### Request

```json
{
  "product_name": "Sample Product",
  "description": "Sample description",
  "price": 12500.00,
  "stock": 25,
  "category_id": "550e8400-e29b-41d4-a716-446655440111",
  "is_active": 1
}
```

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `product_name` | string | Yes | - | Maximum 100 characters |
| `description` | string | No | `""` | Product description |
| `price` | decimal | No | `0.00` | Must be zero or greater |
| `stock` | integer | No | `0` | Must be zero or greater |
| `category_id` | string (UUID) | No | `""` | Public category ID. If omitted or empty, product has no category |
| `is_active` | integer | No | `1` | `0` = inactive, `1` = active |

### Response - 201 Created

```json
{
  "status": 201,
  "messages": "Product created",
  "servertime": "1780962999",
  "data": [
    {
      "product_id": "550e8400-e29b-41d4-a716-446655440000",
      "product_name": "Sample Product",
      "description": "Sample description",
      "price": 12500.00,
      "stock": 25,
      "category_id": "550e8400-e29b-41d4-a716-446655440111",
      "category_name": "Electronics",
      "is_active": 1
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Product name required` | `product_name` missing or empty |
| 400 | `Product name too long` | `product_name` exceeds 100 characters |
| 400 | `Invalid category ID` | `category_id` exceeds 36 characters |
| 400 | `Invalid price value` | `price` is not valid or less than zero |
| 400 | `Invalid stock value` | `stock` is not valid or less than zero |
| 400 | `Invalid is_active value` | `is_active` is not `0` or `1` |
| 404 | `Category not found` | `category_id` does not reference an existing category |
| 500 | `Internal server error.` | Unhandled exception |

## PUT /api/v1/Product/{product_id}

Update an existing product. All fields are optional, but at least one editable field must be supplied.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `product_id` | string (UUID) | URL path | Yes |

```json
{
  "product_name": "Updated Product",
  "description": "Updated description",
  "price": 15000.00,
  "stock": 30,
  "category_id": "550e8400-e29b-41d4-a716-446655440111",
  "is_active": 1
}
```

Send `"category_id": ""` to clear the category relation.

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "Product updated",
  "servertime": "1780962999",
  "data": [
    {
      "product_id": "550e8400-e29b-41d4-a716-446655440000",
      "product_name": "Updated Product",
      "description": "Updated description",
      "price": 15000.00,
      "stock": 30,
      "category_id": "550e8400-e29b-41d4-a716-446655440111",
      "category_name": "Electronics",
      "is_active": 1
    }
  ]
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Product ID required` | `product_id` missing from URL |
| 400 | `Invalid product ID` | `product_id` exceeds 36 characters |
| 400 | `Product ID cannot be changed` | `product_id` field present in body |
| 400 | `Product name required` | `product_name` field present but empty |
| 400 | `Product name too long` | `product_name` exceeds 100 characters |
| 400 | `Invalid category ID` | `category_id` exceeds 36 characters |
| 400 | `Invalid price value` | `price` is not valid or less than zero |
| 400 | `Invalid stock value` | `stock` is not valid or less than zero |
| 400 | `Invalid is_active value` | `is_active` is not `0` or `1` |
| 400 | `No data to update` | No editable fields provided |
| 404 | `Category not found` | `category_id` does not reference an existing category |
| 404 | `Product not found` | No product with the given ID |
| 500 | `Internal server error.` | Unhandled exception |

## DELETE /api/v1/Product/{product_id}

Soft-delete a product by setting `is_active = 0` and `deleted_at = NOW()`.

### Request

| Parameter | Type | Location | Required |
|---|---|---|---|
| `product_id` | string (UUID) | URL path | Yes |

### Response - 200 OK

```json
{
  "status": 200,
  "messages": "Product deleted",
  "servertime": "1780962999",
  "data": []
}
```

### Errors

| Status | Message | Condition |
|---|---|---|
| 400 | `Product ID required` | `product_id` missing from URL |
| 400 | `Invalid product ID` | `product_id` exceeds 36 characters |
| 404 | `Product not found` | No product with the given ID |
| 500 | `Internal server error.` | Unhandled exception |
