-- Enable extensions
create extension if not exists "pgcrypto";

-- Tables
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

-- Indexes
create index if not exists idx_business_members_business on business_members(business_id);
create index if not exists idx_products_business on products(business_id);
create index if not exists idx_credit_accounts_business on business_credit_accounts(business_id);
create index if not exists idx_orders_business on orders(business_id);
create index if not exists idx_order_items_business on order_items(business_id);
create index if not exists idx_credit_ledger_business on credit_ledger(business_id);

create index if not exists idx_orders_business_created on orders(business_id, created_at);
create index if not exists idx_orders_business_due_at on orders(business_id, due_at);
create index if not exists idx_order_items_business_order on order_items(business_id, order_id);
create index if not exists idx_credit_ledger_business_created on credit_ledger(business_id, created_at);

-- RLS
alter table business_members enable row level security;
alter table products enable row level security;
alter table business_credit_accounts enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table credit_ledger enable row level security;

create or replace function is_business_member(bid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select (auth.role() = 'service_role') or exists (
    select 1
    from business_members bm
    where bm.business_id = bid
      and bm.user_id = auth.uid()
  );
$$;

-- Policies
create policy business_members_select on business_members
  for select using (is_business_member(business_id));

create policy business_members_insert on business_members
  for insert with check (auth.uid() = user_id and is_business_member(business_id));

create policy business_members_update on business_members
  for update using (is_business_member(business_id))
  with check (is_business_member(business_id));

create policy business_members_delete on business_members
  for delete using (is_business_member(business_id));

create policy products_select on products
  for select using (is_business_member(business_id));

create policy products_insert on products
  for insert with check (is_business_member(business_id));

create policy products_update on products
  for update using (is_business_member(business_id))
  with check (is_business_member(business_id));

create policy products_delete on products
  for delete using (is_business_member(business_id));

create policy credit_accounts_select on business_credit_accounts
  for select using (is_business_member(business_id));

create policy credit_accounts_insert on business_credit_accounts
  for insert with check (is_business_member(business_id));

create policy credit_accounts_update on business_credit_accounts
  for update using (is_business_member(business_id))
  with check (is_business_member(business_id));

create policy credit_accounts_delete on business_credit_accounts
  for delete using (is_business_member(business_id));

create policy orders_select on orders
  for select using (is_business_member(business_id));

create policy orders_insert on orders
  for insert with check (is_business_member(business_id));

create policy orders_update on orders
  for update using (is_business_member(business_id))
  with check (is_business_member(business_id));

create policy orders_delete on orders
  for delete using (is_business_member(business_id));

create policy order_items_select on order_items
  for select using (is_business_member(business_id));

create policy order_items_insert on order_items
  for insert with check (is_business_member(business_id));

create policy order_items_update on order_items
  for update using (is_business_member(business_id))
  with check (is_business_member(business_id));

create policy order_items_delete on order_items
  for delete using (is_business_member(business_id));

create policy credit_ledger_select on credit_ledger
  for select using (is_business_member(business_id));

create policy credit_ledger_insert on credit_ledger
  for insert with check (is_business_member(business_id));

create policy credit_ledger_update on credit_ledger
  for update using (is_business_member(business_id))
  with check (is_business_member(business_id));

create policy credit_ledger_delete on credit_ledger
  for delete using (is_business_member(business_id));

-- RPC: process_purchase
create or replace function process_purchase(
  p_business_id uuid,
  p_idempotency_key uuid,
  p_items jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id uuid;
  v_total_cents bigint := 0;
  v_credit business_credit_accounts%rowtype;
  v_item_count int := 0;
  v_found_count int := 0;
  v_invalid_qty_count int := 0;
  v_insufficient_count int := 0;
begin
  if not is_business_member(p_business_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  select o.id
    into v_order_id
  from orders o
  where o.business_id = p_business_id
    and o.idempotency_key = p_idempotency_key;

  if v_order_id is not null then
    return v_order_id;
  end if;

  create temporary table _items_norm (
    product_id uuid not null,
    qty integer not null
  ) on commit drop;

  insert into _items_norm (product_id, qty)
  select product_id, sum(qty) as qty
  from (
    select (value->>'product_id')::uuid as product_id,
           (value->>'qty')::int as qty
    from jsonb_array_elements(p_items)
  ) items
  group by product_id;

  select count(*) into v_item_count from _items_norm;

  if v_item_count = 0 then
    raise exception 'items must be a non-empty array';
  end if;

  select count(*) into v_invalid_qty_count from _items_norm where qty <= 0;

  if v_invalid_qty_count > 0 then
    raise exception 'invalid quantity in items';
  end if;

  select count(*) into v_found_count
  from _items_norm i
  join products p
    on p.id = i.product_id
   and p.business_id = p_business_id;

  if v_found_count <> v_item_count then
    raise exception 'invalid product in items';
  end if;

  -- Lock credit account first, then products in deterministic order
  select *
    into v_credit
  from business_credit_accounts bca
  where bca.business_id = p_business_id
  for update;

  if not found then
    raise exception 'credit account not found';
  end if;

  perform 1
  from products p
  join _items_norm i
    on i.product_id = p.id
  where p.business_id = p_business_id
  order by p.id
  for update;

  select count(*) into v_insufficient_count
  from products p
  join _items_norm i
    on i.product_id = p.id
  where p.business_id = p_business_id
    and p.stock < i.qty;

  if v_insufficient_count > 0 then
    raise exception 'insufficient stock';
  end if;

  select coalesce(sum(p.price_cents * i.qty), 0)
    into v_total_cents
  from products p
  join _items_norm i
    on i.product_id = p.id
  where p.business_id = p_business_id;

  if v_total_cents <= 0 then
    raise exception 'invalid total';
  end if;

  if v_credit.balance_cents + v_total_cents > v_credit.credit_limit_cents then
    raise exception 'credit limit exceeded';
  end if;

  begin
    insert into orders (
      id,
      business_id,
      idempotency_key,
      status,
      total_cents,
      paid_cents,
      created_at,
      due_at
    ) values (
      gen_random_uuid(),
      p_business_id,
      p_idempotency_key,
      'posted',
      v_total_cents::int,
      0,
      now(),
      now() + interval '30 days'
    )
    returning id into v_order_id;
  exception
    when unique_violation then
      select o.id
        into v_order_id
      from orders o
      where o.business_id = p_business_id
        and o.idempotency_key = p_idempotency_key;

      return v_order_id;
  end;

  insert into order_items (
    id,
    business_id,
    order_id,
    product_id,
    qty,
    unit_price_cents
  )
  select
    gen_random_uuid(),
    p_business_id,
    v_order_id,
    p.id,
    i.qty,
    p.price_cents
  from products p
  join _items_norm i
    on i.product_id = p.id
  where p.business_id = p_business_id;

  update products p
  set stock = p.stock - i.qty
  from _items_norm i
  where p.id = i.product_id
    and p.business_id = p_business_id;

  update business_credit_accounts
  set balance_cents = balance_cents + v_total_cents::int
  where business_id = p_business_id;

  insert into credit_ledger (
    id,
    business_id,
    order_id,
    entry_type,
    amount_cents
  ) values (
    gen_random_uuid(),
    p_business_id,
    v_order_id,
    'charge',
    v_total_cents::int
  );

  return v_order_id;
end;
$$;

revoke all on function process_purchase(uuid, uuid, jsonb) from public;
grant execute on function process_purchase(uuid, uuid, jsonb) to authenticated;

-- RPC: get_overdue_summary
create or replace function get_overdue_summary(p_business_id uuid)
returns table (
  business_id uuid,
  overdue_cents bigint,
  oldest_due_at timestamptz,
  overdue_orders bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    o.business_id,
    sum(o.total_cents - o.paid_cents) as overdue_cents,
    min(o.due_at) as oldest_due_at,
    count(*) as overdue_orders
  from orders o
  where o.business_id = p_business_id
    and o.status = 'posted'
    and (o.total_cents - o.paid_cents) > 0
    and o.due_at < now() - interval '30 days'
  group by o.business_id
  order by overdue_cents desc;
$$;

revoke all on function get_overdue_summary(uuid) from public;
grant execute on function get_overdue_summary(uuid) to authenticated;