-- Overdue businesses with pagination and optional date filtering
create or replace function get_overdue_businesses(
  p_due_before timestamptz default null,
  p_due_after timestamptz default null,
  p_limit int default 20,
  p_offset int default 0
)
returns table (
  business_id uuid,
  name text,
  overdue_cents bigint,
  oldest_due_at timestamptz,
  overdue_orders bigint,
  total_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with overdue as (
    select
      o.business_id,
      sum(o.total_cents - o.paid_cents) as overdue_cents,
      min(o.due_at) as oldest_due_at,
      count(*) as overdue_orders
    from orders o
    where o.status = 'posted'
      and (o.total_cents - o.paid_cents) > 0
      and o.due_at < coalesce(p_due_before, now() - interval '30 days')
      and (p_due_after is null or o.due_at >= p_due_after)
    group by o.business_id
  ), counted as (
    select
      ob.business_id,
      b.name,
      ob.overdue_cents,
      ob.oldest_due_at,
      ob.overdue_orders,
      count(*) over () as total_count
    from overdue ob
    join businesses b on b.id = ob.business_id
  )
  select *
  from counted
  order by overdue_cents desc
  limit p_limit
  offset p_offset;
$$;

revoke all on function get_overdue_businesses(timestamptz, timestamptz, int, int) from public;
grant execute on function get_overdue_businesses(timestamptz, timestamptz, int, int) to authenticated;