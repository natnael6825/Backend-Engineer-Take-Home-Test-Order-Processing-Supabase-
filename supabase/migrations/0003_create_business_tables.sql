-- Ensure business-as-customer tables exist (for projects with previous migrations)
create extension if not exists "pgcrypto";

create table if not exists businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists business_members (
  business_id uuid not null references businesses(id) on delete cascade,
  user_id uuid not null,
  role text not null,
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  sku text not null,
  name text not null,
  stock integer not null check (stock >= 0),
  price_cents integer not null check (price_cents >= 0),
  created_at timestamptz not null default now(),
  unique (business_id, sku)
);

create table if not exists business_credit_accounts (
  business_id uuid primary key references businesses(id) on delete cascade,
  credit_limit_cents integer not null check (credit_limit_cents >= 0),
  balance_cents integer not null default 0 check (balance_cents >= 0),
  created_at timestamptz not null default now()
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  idempotency_key uuid not null,
  status text not null default 'posted',
  total_cents integer not null check (total_cents >= 0),
  paid_cents integer not null default 0 check (paid_cents >= 0),
  created_at timestamptz not null default now(),
  due_at timestamptz not null default (now() + interval '30 days'),
  unique (business_id, idempotency_key)
);

create table if not exists order_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  order_id uuid not null references orders(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  qty integer not null check (qty > 0),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  line_total_cents integer generated always as (qty * unit_price_cents) stored
);

create table if not exists credit_ledger (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  order_id uuid references orders(id) on delete set null,
  entry_type text not null,
  amount_cents integer not null,
  created_at timestamptz not null default now()
);