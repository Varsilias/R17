# Creator Card API

A lightweight microservice for creating and sharing public creator profile cards — think link-in-bio cards with attached service rate sheets. Built with Node.js, Express, and MongoDB.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/creator-cards` | Create a new creator card |
| `GET` | `/creator-cards/:slug` | Retrieve a card by slug |
| `DELETE` | `/creator-cards/:slug` | Delete a card by slug |

No authentication required. All endpoints are public.

---

## Getting Started

### Prerequisites

- Node.js 18+
- A MongoDB connection string (MongoDB Atlas free tier works fine)

### Setup

```bash
git clone <repo-url>
cd creator-card-api
npm install
cp .env.example .env
# Fill in MONGODB_URI in .env
npm run dev
```

The server starts on port `8811` by default. Override with `PORT` in `.env`.

---

## API Reference

### Create a Creator Card

```
POST /creator-cards
```

**Request body**

```json
{
  "title": "George Cooks",
  "description": "A weekly cooking podcast by Chef George AmadiObi",
  "slug": "george-cooks",
  "creator_reference": "crt_8f2k1m9x4p7w3q5z",
  "links": [
    { "title": "YouTube", "url": "https://youtube.com/@georgecooks" },
    { "title": "Instagram", "url": "https://instagram.com/georgecooks" }
  ],
  "service_rates": {
    "currency": "NGN",
    "rates": [
      { "name": "IG Story Post", "description": "One story mention", "amount": 5000000 },
      { "name": "Recipe Feature", "description": "Featured podcast segment", "amount": 15000000 }
    ]
  },
  "status": "published",
  "access_type": "public"
}
```

**Field reference**

| Field | Required | Rules |
|-------|----------|-------|
| `title` | Yes | 3–100 characters |
| `description` | No | Max 500 characters |
| `slug` | No | 5–50 chars; letters, numbers, hyphens, underscores; must be unique. Auto-generated from title if omitted |
| `creator_reference` | Yes | Exactly 20 characters |
| `links[].title` | Yes (if links present) | 1–100 characters |
| `links[].url` | Yes (if links present) | Max 200 chars; must start with `http://` or `https://` |
| `service_rates.currency` | Yes (if service_rates present) | `NGN` `USD` `GBP` `GHS` |
| `service_rates.rates[].name` | Yes | 3–100 characters |
| `service_rates.rates[].amount` | Yes | Positive integer (minor units — kobo, cents, pence, pesewas) |
| `service_rates.rates[].description` | No | Max 250 characters |
| `status` | Yes | `draft` or `published` |
| `access_type` | No | `public` (default) or `private` |
| `access_code` | Conditional | Required when `access_type` is `private`; exactly 6 alphanumeric characters. Must not be set on public cards |

**Success response — 200**

```json
{
  "status": "success",
  "message": "Creator Card Created Successfully.",
  "data": {
    "id": "01JG8XYZA2B3C4D5E6F7G8H9J0",
    "title": "George Cooks",
    "slug": "george-cooks",
    "creator_reference": "crt_8f2k1m9x4p7w3q5z",
    "links": [{ "title": "YouTube", "url": "https://youtube.com/@georgecooks" }],
    "service_rates": { "currency": "NGN", "rates": [{ "name": "IG Story Post", "amount": 5000000 }] },
    "status": "published",
    "access_type": "public",
    "access_code": null,
    "created": 1767052800000,
    "updated": 1767052800000,
    "deleted": null
  }
}
```

---

### Retrieve a Creator Card

```
GET /creator-cards/:slug
```

For private cards, pass the access code as a query parameter:

```
GET /creator-cards/george-cooks?access_code=A1B2C3
```

Draft cards are never publicly retrievable. The `access_code` field is never exposed in retrieval responses.

**Success response — 200**

```json
{
  "status": "success",
  "message": "Creator Card Retrieved Successfully.",
  "data": {
    "id": "01JG8XYZA2B3C4D5E6F7G8H9J0",
    "title": "George Cooks",
    "slug": "george-cooks",
    "status": "published",
    "access_type": "public",
    "created": 1767052800000,
    "updated": 1767052800000,
    "deleted": null
  }
}
```

---

### Delete a Creator Card

```
DELETE /creator-cards/:slug
```

**Request body**

```json
{
  "creator_reference": "crt_8f2k1m9x4p7w3q5z"
}
```

Returns the deleted card in full. Once deleted, the card returns 404 on all subsequent GET requests.

---

## Error Codes

All error responses follow the same shape:

```json
{
  "status": "error",
  "message": "Human-readable description",
  "code": "ERROR_CODE"
}
```

| Code | HTTP | Condition |
|------|------|-----------|
| `SL02` | 400 | Provided slug is already taken |
| `AC01` | 400 | `access_code` is required when `access_type` is `private` |
| `AC05` | 400 | `access_code` must not be set on public cards |
| `NF01` | 404 | No card found for the given slug (or card has been deleted) |
| `NF02` | 404 | Card exists but is in `draft` status |
| `AC03` | 403 | Card is private — `access_code` query param is required |
| `AC04` | 403 | Supplied `access_code` does not match |

Field-level validation failures (wrong types, missing required fields, length violations, invalid enum values) return **HTTP 400** without a custom code.

---

## Slug Auto-Generation

When `slug` is omitted, the service generates one from the title:

1. Lowercase the title
2. Replace whitespace with hyphens
3. Strip any characters that are not letters, numbers, hyphens, or underscores
4. If the result is shorter than 5 characters or already taken, a random 6-character alphanumeric suffix is appended

If you supply a slug and it is already taken, the request fails with `SL02` — the service never silently modifies a client-provided slug.

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MONGODB_URI` | Yes | MongoDB connection string |
| `PORT` | No | Server port (default: `8811`) |
| `LOG_APP_REQUEST` | No | Set to `1` to log all incoming requests |

---

## Scripts

```bash
npm run dev    # Start locally (reads .env, skips AWS Secrets Manager)
npm start      # Production entry point
```
