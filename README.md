# Supabase Backend (Business-as-Customer)

Backend-only Next.js API project using hosted Supabase Postgres with RLS and RPCs.

## Setup

1) Install dependencies

```bash
npm install
```

2) Create `.env` from `.env.example` and paste your hosted Supabase values

```bash
copy .env.example .env
```

3) Apply migrations to your hosted Supabase project

Option A: Supabase SQL editor
- Open `supabase/migrations/0001_init.sql`
- Paste into the SQL editor and run
- (Optional) Run `supabase/seed.sql` to load sample data

Option B: Supabase CLI (linked project)

```bash
supabase link --project-ref <your-project-ref>
npm run db:push
npm run db:seed
```

Option C: Scripted (Windows PowerShell, linked project)

```bash
npm run db:setup
```

`db:seed` uses the service role key from `.env` to insert sample rows.

## Run

```bash
npm run dev
```

## API Usage

POST `/api/businesses`

```bash
curl -X POST http://localhost:3000/api/businesses \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Acme Supply Co",
    "creditLimitCents": 500000
  }'
```

POST `/api/products`

```bash
curl -X POST http://localhost:3000/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "businessId": "7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11",
    "sku": "SKU-NEW-01",
    "name": "New Widget",
    "stock": 25,
    "priceCents": 1200
  }'
```

PATCH `/api/products/:productId`

```bash
curl -X PATCH http://localhost:3000/api/products/3e5a9b2c-1d4f-4b7a-8c9d-1e2f3a4b5c6d \
  -H "Content-Type: application/json" \
  -d '{
    "businessId": "7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11",
    "stock": 90,
    "priceCents": 1600
  }'
```

POST `/api/purchase`

```bash
curl -X POST http://localhost:3000/api/purchase \
  -H "Content-Type: application/json" \
  -d '{
    "businessId": "7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11",
    "idempotencyKey": "1b2c3d4e-5f60-4a7b-8c9d-0e1f2a3b4c5d",
    "items": [
      {"product_id": "3e5a9b2c-1d4f-4b7a-8c9d-1e2f3a4b5c6d", "qty": 2},
      {"product_id": "6f7a8b9c-0d1e-4f2a-8b3c-4d5e6f7a8b9c", "qty": 1}
    ]
  }'
```

GET `/api/overdue?businessId=...`

```bash
curl "http://localhost:3000/api/overdue?businessId=7d8f8c6b-5d2f-4e0a-9c1a-1d4f2c7a3b11"
```

GET `/api/overdue-businesses`

```bash
curl "http://localhost:3000/api/overdue-businesses?page=1&pageSize=20"
```

## Notes

### Atomicity
Purchases run inside a single Postgres function (`process_purchase`), so stock checks, order creation, and ledger updates commit together or not at all.

### Concurrency safety
`process_purchase` uses `FOR UPDATE` locks on the credit account and all products (in deterministic product ID order) and enforces idempotency with a unique constraint on `(business_id, idempotency_key)`.

### Tenant isolation
Every table is scoped by `business_id`, with RLS policies that require membership via `is_business_member`. API routes use the service role key for server-side testing, but RLS and policies are still present and correct.

## Seeding and membership
`supabase/seed.sql` uses placeholder UUIDs for `business_members.user_id`. Replace these with real Supabase Auth user IDs if you want to test RLS as an authenticated user.
