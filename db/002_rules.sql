-- ============================================================================
-- MS BEAU AVE — the rules
--
-- Receiving and allocation, FEFO picking, atomic stock commitment, the credit
-- gate, counter sales, returns, the blind cash count, and reorder points.
--
-- Everything that moves stock or money is a function here. The application is
-- only allowed to call these, never to touch the tables directly, so the
-- invariants hold no matter who is asking.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- The house allocation split, overridable per product.
-- ---------------------------------------------------------------------------
create or replace function allocation_for(p_sku text)
returns table (pool text, share numeric)
language sql stable as $$
  select unnest(array['b2b','shop','reserve']),
         unnest(array[coalesce(alloc_b2b, 0.70),
                      coalesce(alloc_shop, 0.20),
                      coalesce(alloc_reserve, 0.10)])
    from products where sku = p_sku;
$$;

-- ---------------------------------------------------------------------------
-- Receiving
--
-- Splits the delivery across the three pools. Rounding uses largest-remainder
-- so the parts always add back to exactly what arrived — no unit is ever
-- created or lost by arithmetic.
-- ---------------------------------------------------------------------------
create or replace function receive_stock(
  p_sku      text,
  p_batch_no text,
  p_expiry   date,
  p_qty      int
) returns bigint
language plpgsql security definer as $$
declare
  v_batch  bigint;
  v_pools  text[]    := array['b2b','shop','reserve'];
  v_share  numeric[];
  v_whole  int[];
  v_frac   numeric[];
  v_spare  int;
  i        int;
  v_pick   int;
begin
  perform require_role('admin','warehouse');
  if p_qty <= 0 then
    raise exception 'received quantity must be more than zero';
  end if;
  if p_expiry <= current_date then
    raise exception 'that batch is already expired on arrival (% )', p_expiry;
  end if;
  if not exists (select 1 from products where sku = p_sku and active) then
    raise exception 'no active product with code %', p_sku;
  end if;

  insert into batches (sku, batch_no, expiry, qty_received)
  values (p_sku, p_batch_no, p_expiry, p_qty)
  returning id into v_batch;

  select array_agg(share order by ord) into v_share
    from (select share, row_number() over () as ord from allocation_for(p_sku)) s;

  v_whole := array[floor(p_qty * v_share[1])::int,
                   floor(p_qty * v_share[2])::int,
                   floor(p_qty * v_share[3])::int];
  v_frac  := array[p_qty * v_share[1] - v_whole[1],
                   p_qty * v_share[2] - v_whole[2],
                   p_qty * v_share[3] - v_whole[3]];
  v_spare := p_qty - (v_whole[1] + v_whole[2] + v_whole[3]);

  while v_spare > 0 loop
    v_pick := 1;
    for i in 2..3 loop
      if v_frac[i] > v_frac[v_pick] then v_pick := i; end if;
    end loop;
    v_whole[v_pick] := v_whole[v_pick] + 1;
    v_frac[v_pick]  := -1;              -- each pool takes at most one spare unit
    v_spare := v_spare - 1;
  end loop;

  for i in 1..3 loop
    if v_whole[i] > 0 then
      insert into stock (batch_id, pool, on_hand) values (v_batch, v_pools[i], v_whole[i]);
      insert into movements (batch_id, to_pool, qty, reason)
      values (v_batch, v_pools[i], v_whole[i], 'received');
    end if;
  end loop;

  return v_batch;
end;
$$;

-- ---------------------------------------------------------------------------
-- What a channel is allowed to sell
--
-- The shop can sell anything not yet expired. Resellers will refuse stock
-- with less than their floor of life left, so it is excluded from wholesale
-- entirely — better it clears through the shop than sits until it is waste.
-- ---------------------------------------------------------------------------
create or replace function earliest_usable_expiry(p_pool text, p_sku text)
returns date
language sql stable as $$
  select case when p_pool = 'b2b'
    then (current_date + make_interval(months =>
           coalesce((select reseller_floor_months from products where sku = p_sku), 12)))::date
    else current_date end;
$$;

-- ---------------------------------------------------------------------------
-- FEFO — first expired, first out.
--
-- Always proposes the oldest usable batch first, so the stock closest to
-- becoming waste is the stock that leaves.
-- ---------------------------------------------------------------------------
create or replace function pick_list(p_pool text, p_sku text, p_qty int)
returns table (batch_id bigint, batch_no text, expiry date, take int)
language sql stable security definer as $$
  with available as (
    select s.batch_id, b.batch_no, b.expiry,
           s.on_hand - s.committed as free,
           sum(s.on_hand - s.committed) over (order by b.expiry, b.id) as running
      from stock s
      join batches b on b.id = s.batch_id
     where s.pool = p_pool
       and b.sku = p_sku
       and b.expiry > earliest_usable_expiry(p_pool, p_sku)
       and s.on_hand - s.committed > 0
  )
  select batch_id, batch_no, expiry,
         least(free, p_qty - (running - free))::int
    from available
   where running - free < p_qty
   order by expiry, batch_id;
$$;

-- ---------------------------------------------------------------------------
-- The credit gate (wholesale only)
--
-- Runs before any stock is touched. A past-due invoice or a limit breach
-- stops the order — the system decides, not a person having an awkward
-- conversation.
-- ---------------------------------------------------------------------------
create or replace function amount_outstanding(p_reseller bigint)
returns numeric language sql stable security definer as $$
  select coalesce(sum(amount - paid - discount), 0)
    from invoices where reseller_id = p_reseller and status = 'open';
$$;

create or replace function has_overdue(p_reseller bigint)
returns boolean language sql stable security definer as $$
  select exists (select 1 from invoices
                  where reseller_id = p_reseller and status = 'open'
                    and due_on < current_date);
$$;

create or replace function check_can_order(p_reseller bigint, p_order_value numeric)
returns void
language plpgsql security definer as $$
declare r resellers%rowtype;
begin
  select * into r from resellers where id = p_reseller for update;
  if not found then
    raise exception 'no such reseller (%)', p_reseller;
  end if;

  if r.status <> 'active' or not r.docs_verified then
    raise exception 'ACCOUNT_NOT_READY: the account is % and documents are %',
      r.status, case when r.docs_verified then 'verified' else 'still outstanding' end
      using errcode = 'P0004';
  end if;

  -- Checked live off the invoices, so it is true the moment it is asked,
  -- whether or not the nightly job has run.
  if has_overdue(p_reseller) then
    raise exception 'ACCOUNT_BLOCKED: there is a past-due invoice on this account'
      using errcode = 'P0003';
  end if;

  if r.blocked then
    raise exception 'ACCOUNT_BLOCKED: %', coalesce(r.blocked_reason, 'account on hold')
      using errcode = 'P0003';
  end if;

  -- Tier 1 carries no credit at all: they are allowed to order, but nothing
  -- ships until the invoice is settled (see check_can_ship).
  if r.tier >= 2 and amount_outstanding(p_reseller) + coalesce(p_order_value, 0) > r.credit_limit then
    raise exception 'OVER_CREDIT_LIMIT: % outstanding plus % ordered is beyond the % limit',
      amount_outstanding(p_reseller)::numeric(12,2),
      coalesce(p_order_value, 0)::numeric(12,2), r.credit_limit
      using errcode = 'P0003';
  end if;
end;
$$;

-- Persist the blocked flag. Called by the daily sweep and whenever the
-- dashboard is opened, in its own transaction so a rejected order can never
-- roll the block back.
create or replace function refresh_blocks() returns int
language plpgsql security definer as $$
declare v_id bigint; v_n int := 0;
begin
  perform require_role('admin');
  for v_id in
    select id from resellers r where not r.blocked and has_overdue(r.id)
  loop
    update resellers set blocked = true, blocked_reason = 'past-due invoice' where id = v_id;
    insert into reseller_events (reseller_id, kind, detail)
    values (v_id, 'auto_blocked', jsonb_build_object('reason', 'past-due invoice'));
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- Placing an order — the anti-oversell heart of the system
--
-- Walks the FEFO-ordered ledger rows under a row lock, re-checks what is free
-- while holding it, and commits the units in the same transaction. Two orders
-- racing for the last of something serialise here: one wins, the other is
-- told what is actually left. There is no window in which both can succeed.
-- ---------------------------------------------------------------------------
create or replace function place_order(
  p_channel   text,
  p_lines     jsonb,
  p_reseller  bigint default null
) returns bigint
language plpgsql security definer as $$
declare
  v_pool     text;
  v_order    bigint;
  line       record;
  row_       record;
  v_wanted   int;
  v_take     int;
  v_price    numeric(12,2);
  v_subtotal numeric(12,2) := 0;
  v_cutoff   date;
begin
  if p_channel = 'b2b' then
    perform require_role('admin','reseller');
    if current_role_name() = 'reseller'
       and p_reseller is distinct from current_reseller() then
      raise exception 'FORBIDDEN: an account may only order for itself'
        using errcode = '42501';
    end if;
    v_pool := 'b2b';
    perform check_can_order(p_reseller, (
      select coalesce(sum((l ->> 'qty')::int
             * (select wholesale_price from products where sku = l ->> 'sku')), 0)
        from jsonb_array_elements(p_lines) l));
  elsif p_channel = 'shop' then
    perform require_role('admin','cashier');
    v_pool := 'shop';
  else
    raise exception 'unknown channel %', p_channel;
  end if;

  insert into orders (channel, reseller_id) values (p_channel, p_reseller)
  returning id into v_order;

  -- Ordering the lines by product gives every concurrent order the same lock
  -- order, so two multi-line orders cannot deadlock against each other.
  for line in
    select l ->> 'sku' as sku, (l ->> 'qty')::int as qty
      from jsonb_array_elements(p_lines) l
     order by l ->> 'sku'
  loop
    if line.qty is null or line.qty <= 0 then
      raise exception 'quantity must be more than zero for %', line.sku;
    end if;

    select case when p_channel = 'b2b' then wholesale_price else retail_price end
      into v_price from products where sku = line.sku and active;
    if not found then
      raise exception 'no active product with code %', line.sku;
    end if;

    v_cutoff := earliest_usable_expiry(v_pool, line.sku);
    v_wanted := line.qty;

    for row_ in
      select s.id, s.on_hand, s.committed, s.batch_id
        from stock s
        join batches b on b.id = s.batch_id
       where s.pool = v_pool and b.sku = line.sku and b.expiry > v_cutoff
       order by b.expiry, b.id
         for update of s
    loop
      exit when v_wanted <= 0;
      v_take := least(row_.on_hand - row_.committed, v_wanted);
      if v_take > 0 then
        update stock set committed = committed + v_take where id = row_.id;
        insert into order_lines (order_id, sku, batch_id, qty, unit_price)
        values (v_order, line.sku, row_.batch_id, v_take, v_price);
        v_wanted := v_wanted - v_take;
      end if;
    end loop;

    if v_wanted > 0 then
      raise exception 'NOT_ENOUGH_STOCK: % is short % unit(s)', line.sku, v_wanted
        using errcode = 'P0002';
    end if;

    v_subtotal := v_subtotal + v_price * line.qty;
  end loop;

  update orders set subtotal = v_subtotal, total = v_subtotal where id = v_order;

  if p_channel = 'b2b' then
    perform raise_invoice(v_order);
  end if;
  return v_order;
end;
$$;

-- ---------------------------------------------------------------------------
-- Wholesale invoice, raised when the order is placed. Tier 1 falls due
-- immediately, which is what makes them prepaid in practice.
-- ---------------------------------------------------------------------------
create or replace function raise_invoice(p_order bigint) returns void
language plpgsql security definer as $$
declare o orders%rowtype; v_terms int;
begin
  select * into o from orders where id = p_order;
  if o.channel <> 'b2b' or o.reseller_id is null then return; end if;

  select case when tier = 1 then 0 else terms_days end
    into v_terms from resellers where id = o.reseller_id;

  insert into invoices (order_id, reseller_id, due_on, amount)
  values (p_order, o.reseller_id, current_date + v_terms, o.total)
  on conflict (order_id) do nothing;
end;
$$;

create or replace function check_can_ship(p_order bigint) returns void
language plpgsql stable security definer as $$
declare inv invoices%rowtype; v_tier int;
begin
  select * into inv from invoices where order_id = p_order;
  if not found then return; end if;
  select tier into v_tier from resellers where id = inv.reseller_id;
  if v_tier = 1 and inv.status <> 'paid' then
    raise exception 'PAYMENT_FIRST: this account pays before dispatch'
      using errcode = 'P0005';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fulfilment and cancellation
-- ---------------------------------------------------------------------------
create or replace function start_picking(p_order bigint) returns void
language plpgsql security definer as $$
declare v_status text;
begin
  perform require_role('admin','warehouse');
  select status into v_status from orders where id = p_order for update;
  if not found then raise exception 'no such order (%)', p_order; end if;
  if v_status <> 'placed' then
    raise exception 'that order is already %', v_status;
  end if;
  update orders set status = 'picking' where id = p_order;
end;
$$;

create or replace function fulfil_order(p_order bigint) returns void
language plpgsql security definer as $$
declare o orders%rowtype; line record; v_pool text;
begin
  perform require_role('admin','warehouse','cashier');
  select * into o from orders where id = p_order for update;
  if not found then raise exception 'no such order (%)', p_order; end if;
  if o.status not in ('placed','picking') then
    raise exception 'that order is already %', o.status;
  end if;
  if o.channel = 'b2b' then perform check_can_ship(p_order); end if;

  v_pool := o.channel;                    -- 'b2b' | 'shop' map 1:1 to pools
  for line in
    select batch_id, sum(qty) as qty from order_lines
     where order_id = p_order group by batch_id order by batch_id
  loop
    update stock set on_hand = on_hand - line.qty, committed = committed - line.qty
     where batch_id = line.batch_id and pool = v_pool;
    insert into movements (batch_id, from_pool, qty, reason)
    values (line.batch_id, v_pool, line.qty,
            case when o.channel = 'b2b' then 'shipped' else 'sold' end);
  end loop;

  update orders set status = 'fulfilled' where id = p_order;
end;
$$;

create or replace function cancel_order(p_order bigint) returns void
language plpgsql security definer as $$
declare o orders%rowtype; line record;
begin
  perform require_role('admin','warehouse','cashier','reseller');
  select * into o from orders where id = p_order for update;
  if not found then raise exception 'no such order (%)', p_order; end if;
  if current_role_name() = 'reseller' and o.reseller_id is distinct from current_reseller() then
    raise exception 'FORBIDDEN: that is not your order' using errcode = '42501';
  end if;
  if o.status not in ('placed','picking') then
    raise exception 'that order is already % and cannot be cancelled', o.status;
  end if;

  for line in
    select batch_id, sum(qty) as qty from order_lines
     where order_id = p_order group by batch_id order by batch_id
  loop
    update stock set committed = committed - line.qty
     where batch_id = line.batch_id and pool = o.channel;
  end loop;

  update orders set status = 'cancelled' where id = p_order;
  update invoices set status = 'void'
   where order_id = p_order and status = 'open' and paid = 0;
end;
$$;

create or replace function mark_delivered(p_order bigint) returns void
language plpgsql security definer as $$
declare o orders%rowtype;
begin
  perform require_role('admin','warehouse');
  select * into o from orders where id = p_order for update;
  if not found then raise exception 'no such order (%)', p_order; end if;
  if o.channel <> 'b2b' then
    raise exception 'a counter sale is handed over at the till';
  end if;
  if o.status <> 'fulfilled' then
    raise exception 'that order has not been dispatched yet';
  end if;
  if o.delivered_at is not null then
    raise exception 'that order was already marked delivered on %', o.delivered_at::date;
  end if;
  update orders set delivered_at = now() where id = p_order;
end;
$$;

-- ---------------------------------------------------------------------------
-- Moving stock between pools. Releasing the reserve is an admin decision —
-- that buffer exists precisely so it is not spent casually.
-- ---------------------------------------------------------------------------
create or replace function move_stock(
  p_batch bigint, p_from text, p_to text, p_qty int, p_reason text default 'transfer'
) returns void
language plpgsql security definer as $$
declare s stock%rowtype;
begin
  if p_from = 'reserve' then
    perform require_role('admin');
  else
    perform require_role('admin','warehouse');
  end if;
  if p_qty <= 0 then raise exception 'quantity must be more than zero'; end if;
  if p_from = p_to then raise exception 'those are the same pool'; end if;

  select * into s from stock where batch_id = p_batch and pool = p_from for update;
  if not found or s.on_hand - s.committed < p_qty then
    raise exception 'NOT_ENOUGH_STOCK: that batch has fewer than % free unit(s) in %',
      p_qty, p_from using errcode = 'P0002';
  end if;

  update stock set on_hand = on_hand - p_qty where batch_id = p_batch and pool = p_from;
  insert into stock (batch_id, pool, on_hand) values (p_batch, p_to, p_qty)
  on conflict (batch_id, pool) do update set on_hand = stock.on_hand + excluded.on_hand;

  insert into movements (batch_id, from_pool, to_pool, qty, reason)
  values (p_batch, p_from, p_to, p_qty,
          case when p_from = 'reserve' then 'reserve released' else p_reason end);
end;
$$;

-- ---------------------------------------------------------------------------
-- Restock tasks
-- ---------------------------------------------------------------------------
create or replace function raise_restock(p_sku text, p_note text default null)
returns bigint
language plpgsql security definer as $$
declare v_id bigint;
begin
  perform require_role('admin','warehouse','cashier');
  insert into restock_tasks (sku, note) values (p_sku, p_note)
  on conflict (sku) where status = 'open' do nothing
  returning id into v_id;
  if v_id is null then
    select id into v_id from restock_tasks where sku = p_sku and status = 'open' limit 1;
  end if;
  return v_id;
end;
$$;

create or replace function close_restock(p_id bigint) returns void
language plpgsql security definer as $$
declare n int;
begin
  perform require_role('admin','warehouse');
  update restock_tasks set status = 'done', done_by = current_actor(), done_at = now()
   where id = p_id and status = 'open';
  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'that task is not open — someone may have just closed it';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- The till
--
-- One call takes the money and moves the stock, so a sale can never be half
-- recorded. If the shelf runs out in the process, the restock task raises
-- itself rather than waiting for someone to notice.
-- ---------------------------------------------------------------------------
create or replace function sell(
  p_lines jsonb, p_method text, p_tendered numeric default null
) returns jsonb
language plpgsql security definer as $$
declare
  v_order  bigint;
  v_total  numeric(12,2);
  v_change numeric(12,2);
  v_receipt text;
  v_sku    text;
  v_left   int;
  v_min    int;
begin
  perform require_role('admin','cashier');
  if p_method not in ('cash','gcash','card') then
    raise exception 'payment must be cash, gcash or card';
  end if;

  v_order := place_order('shop', p_lines);
  perform fulfil_order(v_order);
  select total into v_total from orders where id = v_order;

  if p_method = 'cash' then
    if p_tendered is null or p_tendered < v_total then
      raise exception 'SHORT_PAYMENT: % handed over for a % sale',
        coalesce(p_tendered, 0)::numeric(12,2), v_total using errcode = 'P0006';
    end if;
    v_change := p_tendered - v_total;
  else
    p_tendered := v_total;
    v_change := 0;
  end if;

  v_receipt := 'OR-' || to_char(now() at time zone 'Asia/Manila', 'YYYYMMDD')
               || '-' || lpad(nextval('receipt_counter')::text, 5, '0');
  insert into sales (order_id, receipt_no, method, total, tendered, change_due)
  values (v_order, v_receipt, p_method, v_total, p_tendered, v_change);

  for v_sku in select distinct l ->> 'sku' from jsonb_array_elements(p_lines) l loop
    select coalesce(sum(s.on_hand - s.committed), 0)::int, max(p.shelf_min)
      into v_left, v_min
      from products p
      left join batches b on b.sku = p.sku and b.expiry > current_date
      left join stock s on s.batch_id = b.id and s.pool = 'shop'
     where p.sku = v_sku group by p.sku;
    if v_left <= coalesce(v_min, 0) then
      perform raise_restock(v_sku,
        format('shelf down to %s after receipt %s', v_left, v_receipt));
    end if;
  end loop;

  return jsonb_build_object(
    'receipt_no', v_receipt, 'order_id', v_order, 'total', v_total,
    'method', p_method, 'tendered', p_tendered, 'change', v_change,
    'cashier', current_actor(), 'at', now(),
    'lines', (select jsonb_agg(jsonb_build_object(
                'sku', ol.sku, 'name', p.name, 'qty', ol.qty,
                'unit_price', ol.unit_price, 'batch_no', b.batch_no) order by ol.id)
                from order_lines ol
                join products p on p.sku = ol.sku
                join batches b on b.id = ol.batch_id
               where ol.order_id = v_order));
end;
$$;

-- ---------------------------------------------------------------------------
-- Returns: raised against a receipt, held until an admin decides.
-- ---------------------------------------------------------------------------
create or replace function raise_return(
  p_receipt text, p_sku text, p_batch bigint, p_qty int, p_reason text
) returns bigint
language plpgsql security definer as $$
declare v_order bigint; v_sold int; v_used int; v_id bigint;
begin
  perform require_role('admin','cashier');
  select order_id into v_order from sales where receipt_no = p_receipt;
  if not found then raise exception 'no receipt numbered %', p_receipt; end if;

  select coalesce(sum(qty), 0) into v_sold from order_lines
   where order_id = v_order and sku = p_sku and batch_id = p_batch;
  select coalesce(sum(qty), 0) into v_used from returns
   where order_id = v_order and sku = p_sku and batch_id = p_batch
     and status in ('pending','approved');
  if p_qty + v_used > v_sold then
    raise exception 'only % of that line is still returnable', v_sold - v_used;
  end if;

  insert into returns (receipt_no, order_id, sku, batch_id, qty, reason)
  values (p_receipt, v_order, p_sku, p_batch, p_qty, p_reason)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function decide_return(
  p_id bigint, p_approve boolean, p_outcome text default 'restock'
) returns void
language plpgsql security definer as $$
declare r returns%rowtype;
begin
  perform require_role('admin');
  select * into r from returns where id = p_id for update;
  if not found then raise exception 'no such return (%)', p_id; end if;
  if r.status <> 'pending' then raise exception 'that return is already %', r.status; end if;

  if not p_approve then
    update returns set status = 'rejected', decided_by = current_actor(), decided_at = now()
     where id = p_id;
    return;
  end if;

  if p_outcome not in ('restock','damaged','tester') then
    raise exception 'outcome must be restock, damaged or tester';
  end if;

  if p_outcome = 'restock' then
    insert into stock (batch_id, pool, on_hand) values (r.batch_id, 'shop', r.qty)
    on conflict (batch_id, pool) do update set on_hand = stock.on_hand + excluded.on_hand;
    insert into movements (batch_id, to_pool, qty, reason)
    values (r.batch_id, 'shop', r.qty, 'returned to shelf');
  else
    insert into shrinkage (sku, batch_id, qty, reason, signed_by)
    values (r.sku, r.batch_id, r.qty, p_outcome, current_actor());
  end if;

  update returns set status = 'approved', outcome = p_outcome,
                     decided_by = current_actor(), decided_at = now()
   where id = p_id;
end;
$$;

-- Testers and breakages come straight off the shelf, signed for.
create or replace function log_shrinkage(
  p_sku text, p_batch bigint, p_qty int, p_reason text, p_signed_by text
) returns void
language plpgsql security definer as $$
declare s stock%rowtype;
begin
  perform require_role('admin','cashier');
  if p_reason not in ('tester','damaged') then
    raise exception 'reason must be tester or damaged';
  end if;
  select * into s from stock where batch_id = p_batch and pool = 'shop' for update;
  if not found or s.on_hand - s.committed < p_qty then
    raise exception 'NOT_ENOUGH_STOCK: fewer than % free unit(s) on the shelf', p_qty
      using errcode = 'P0002';
  end if;

  update stock set on_hand = on_hand - p_qty where batch_id = p_batch and pool = 'shop';
  insert into movements (batch_id, from_pool, qty, reason)
  values (p_batch, 'shop', p_qty, p_reason);
  insert into shrinkage (sku, batch_id, qty, reason, signed_by)
  values (p_sku, p_batch, p_qty, p_reason, p_signed_by);
end;
$$;

-- ---------------------------------------------------------------------------
-- Payments
--
-- 2/10 net 30: settle a thirty-day invoice within ten days and two percent
-- comes off. Clearing the last overdue invoice lifts the block by itself.
-- ---------------------------------------------------------------------------
create or replace function record_payment(
  p_invoice bigint, p_amount numeric, p_paid_on date default current_date
) returns void
language plpgsql security definer as $$
declare inv invoices%rowtype; r resellers%rowtype; v_discount numeric(12,2) := 0;
begin
  perform require_role('admin');
  if p_amount <= 0 then raise exception 'payment must be more than zero'; end if;

  select * into inv from invoices where id = p_invoice for update;
  if not found then raise exception 'no such invoice (%)', p_invoice; end if;
  if inv.status <> 'open' then
    raise exception 'that invoice is already %', inv.status;
  end if;
  select * into r from resellers where id = inv.reseller_id for update;

  insert into payments (invoice_id, amount, paid_on) values (p_invoice, p_amount, p_paid_on);

  if r.terms_days = 30
     and p_paid_on <= inv.issued_on + 10
     and inv.paid + p_amount >= round(inv.amount * 0.98, 2) - inv.discount then
    v_discount := greatest(round(inv.amount * 0.02, 2) - inv.discount, 0);
  end if;

  update invoices set paid = paid + p_amount, discount = discount + v_discount
   where id = p_invoice returning * into inv;

  if inv.paid + inv.discount >= inv.amount then
    update invoices set status = 'paid', settled_on = p_paid_on
     where id = p_invoice returning * into inv;

    if p_paid_on > inv.due_on then
      insert into reseller_events (reseller_id, kind, detail)
      values (inv.reseller_id, 'paid_late',
              jsonb_build_object('invoice', inv.id, 'due', inv.due_on, 'paid', p_paid_on));
    end if;

    if r.blocked and r.blocked_reason = 'past-due invoice' and not has_overdue(r.id) then
      update resellers set blocked = false, blocked_reason = null where id = r.id;
      insert into reseller_events (reseller_id, kind, detail)
      values (r.id, 'unblocked', jsonb_build_object('reason', 'account brought current'));
    end if;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin actions on an account. An override is always someone's decision on
-- the record, never a silent flag flip.
-- ---------------------------------------------------------------------------
create or replace function create_reseller(
  p_name text, p_contact text, p_email text,
  p_tier int, p_limit numeric, p_days int
) returns bigint
language plpgsql security definer as $$
declare v_id bigint;
begin
  perform require_role('admin');
  if coalesce(trim(p_name), '') = '' then
    raise exception 'the business needs a name';
  end if;
  insert into resellers (name, contact, email, tier, credit_limit, terms_days)
  values (p_name, p_contact, p_email, coalesce(p_tier, 1),
          coalesce(p_limit, 0), coalesce(p_days, 0))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function attach_document(p_reseller bigint, p_kind text, p_reference text)
returns void
language plpgsql security definer as $$
begin
  perform require_role('admin');
  if coalesce(trim(p_reference), '') = '' then
    raise exception 'say where the document is';
  end if;
  insert into reseller_documents (reseller_id, kind, reference, verified)
  values (p_reseller, p_kind, p_reference, true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Sign-ins. The digest is computed by the application; this never sees a
-- password.
-- ---------------------------------------------------------------------------
create or replace function create_login(
  p_username text, p_display text, p_hash text, p_role text, p_reseller bigint default null
) returns bigint
language plpgsql security definer as $$
declare v_id bigint;
begin
  perform require_role('admin');
  insert into app_users (username, display_name, password_hash, role, reseller_id)
  values (p_username, coalesce(nullif(p_display, ''), p_username), p_hash, p_role, p_reseller)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function set_login_active(p_id bigint, p_active boolean) returns void
language plpgsql security definer as $$
declare n int;
begin
  perform require_role('admin');
  update app_users set active = p_active where id = p_id;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'no such sign-in'; end if;
end;
$$;

create or replace function set_login_password(p_id bigint, p_hash text) returns void
language plpgsql security definer as $$
declare n int;
begin
  perform require_role('admin');
  update app_users set password_hash = p_hash where id = p_id;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'no such sign-in'; end if;
end;
$$;

create or replace function approve_reseller(p_id bigint) returns void
language plpgsql security definer as $$
begin
  perform require_role('admin');
  update resellers set docs_verified = true, status = 'active' where id = p_id;
  insert into reseller_events (reseller_id, kind, detail)
  values (p_id, 'approved', jsonb_build_object('by', current_actor()));
end;
$$;

create or replace function set_terms(
  p_id bigint, p_tier int, p_limit numeric, p_days int
) returns void
language plpgsql security definer as $$
begin
  perform require_role('admin');
  insert into reseller_events (reseller_id, kind, detail)
  select id, 'terms_changed',
         jsonb_build_object('from_tier', tier, 'to_tier', p_tier,
                            'limit', p_limit, 'terms_days', p_days)
    from resellers where id = p_id;
  update resellers set tier = p_tier, credit_limit = p_limit, terms_days = p_days
   where id = p_id;
end;
$$;

create or replace function override_block(p_id bigint, p_note text) returns void
language plpgsql security definer as $$
begin
  perform require_role('admin');
  if coalesce(trim(p_note), '') = '' then
    raise exception 'an override needs a reason — it goes on the record';
  end if;
  update resellers set blocked = false, blocked_reason = null where id = p_id;
  insert into reseller_events (reseller_id, kind, detail)
  values (p_id, 'override', jsonb_build_object('note', p_note, 'by', current_actor()));
end;
$$;

-- ---------------------------------------------------------------------------
-- Blind cash count
--
-- The declared figure is written first, then the expected figure is worked
-- out and both are returned together. Until this call returns, nothing in the
-- system will tell a cashier what the drawer should hold.
-- ---------------------------------------------------------------------------
create or replace function close_day(
  p_declared numeric, p_date date default current_date, p_tolerance numeric default 100
) returns jsonb
language plpgsql security definer as $$
declare v_id bigint; v_expected numeric(12,2); v_variance numeric(12,2);
begin
  perform require_role('admin','cashier');
  if p_declared is null or p_declared < 0 then
    raise exception 'enter the counted cash';
  end if;

  insert into cash_counts (business_date, declared) values (p_date, p_declared)
  returning id into v_id;

  select coalesce(sum(s.total), 0) into v_expected
    from sales s join orders o on o.id = s.order_id
   where s.cashier = current_actor() and s.method = 'cash'
     and o.status = 'fulfilled' and s.at::date = p_date;

  v_variance := p_declared - v_expected;
  update cash_counts
     set expected = v_expected, variance = v_variance,
         flagged = abs(v_variance) > p_tolerance
   where id = v_id;

  return jsonb_build_object('declared', p_declared, 'expected', v_expected,
                            'variance', v_variance,
                            'flagged', abs(v_variance) > p_tolerance,
                            'business_date', p_date);
exception when unique_violation then
  raise exception 'the drawer was already counted for %', p_date;
end;
$$;

-- ---------------------------------------------------------------------------
-- Expiry
-- ---------------------------------------------------------------------------
create or replace function write_off_expired(p_batch bigint default null)
returns int
language plpgsql security definer as $$
declare r record; v_units int := 0;
begin
  perform require_role('admin','warehouse');
  for r in
    select s.id, s.batch_id, s.pool, s.on_hand - s.committed as qty
      from stock s join batches b on b.id = s.batch_id
     where b.expiry <= current_date and s.on_hand - s.committed > 0
       and (p_batch is null or s.batch_id = p_batch)
       for update of s
  loop
    update stock set on_hand = on_hand - r.qty where id = r.id;
    insert into movements (batch_id, from_pool, qty, reason)
    values (r.batch_id, r.pool, r.qty, 'expired');
    v_units := v_units + r.qty;
  end loop;
  return v_units;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reorder points
--
--   safety stock = (worst-case daily × worst-case lead) − (usual × usual)
--   reorder at   = (usual daily × usual lead) + safety stock
--
-- The suggestion is capped by shelf life: never order more than can sell
-- before the batch drops below what resellers will accept.
-- ---------------------------------------------------------------------------
create or replace function set_reorder_point(
  p_sku text, p_avg_daily numeric, p_max_daily numeric,
  p_avg_lead numeric, p_max_lead numeric, p_months_cover numeric default 3
) returns reorder_points
language plpgsql security definer as $$
declare v_safety numeric; v_point numeric; out_ reorder_points;
begin
  perform require_role('admin','warehouse');
  v_safety := (p_max_daily * p_max_lead) - (p_avg_daily * p_avg_lead);
  v_point  := (p_avg_daily * p_avg_lead) + v_safety;

  insert into reorder_points (sku, avg_daily, max_daily, avg_lead_days, max_lead_days,
                              months_cover, safety_stock, reorder_at, reviewed_at)
  values (p_sku, p_avg_daily, p_max_daily, p_avg_lead, p_max_lead,
          p_months_cover, v_safety, v_point, now())
  on conflict (sku) do update
    set avg_daily = excluded.avg_daily, max_daily = excluded.max_daily,
        avg_lead_days = excluded.avg_lead_days, max_lead_days = excluded.max_lead_days,
        months_cover = excluded.months_cover, safety_stock = excluded.safety_stock,
        reorder_at = excluded.reorder_at, reviewed_at = now()
  returning * into out_;
  return out_;
end;
$$;

-- Refresh the demand figures from what actually sold. Lead times stay manual:
-- only the supplier knows those.
create or replace function recalc_demand(p_sku text, p_days int default 90)
returns reorder_points
language plpgsql security definer as $$
declare cur reorder_points; v_avg numeric; v_max numeric;
begin
  perform require_role('admin','warehouse');
  select * into cur from reorder_points where sku = p_sku;
  if not found then
    raise exception 'set the lead times for % first', p_sku;
  end if;

  select coalesce(sum(ol.qty), 0)::numeric / p_days into v_avg
    from order_lines ol join orders o on o.id = ol.order_id
   where ol.sku = p_sku and o.status = 'fulfilled'
     and o.placed_at > now() - make_interval(days => p_days);

  select coalesce(max(day_total), 0) into v_max from (
    select sum(ol.qty) as day_total
      from order_lines ol join orders o on o.id = ol.order_id
     where ol.sku = p_sku and o.status = 'fulfilled'
       and o.placed_at > now() - make_interval(days => p_days)
     group by o.placed_at::date) d;

  return set_reorder_point(p_sku, round(v_avg, 2),
                           greatest(round(v_avg, 2), v_max),
                           cur.avg_lead_days, cur.max_lead_days, cur.months_cover);
end;
$$;

create or replace function record_stock_count(p_sku text, p_counted int)
returns stock_counts
language plpgsql security definer as $$
declare v_system int; out_ stock_counts;
begin
  perform require_role('admin','warehouse');
  select coalesce(sum(s.on_hand), 0)::int into v_system
    from batches b join stock s on s.batch_id = b.id where b.sku = p_sku;
  insert into stock_counts (sku, counted, on_system, variance)
  values (p_sku, p_counted, v_system, p_counted - v_system)
  returning * into out_;
  return out_;
end;
$$;

create or replace function classify_abc(p_days int default 90) returns int
language plpgsql security definer as $$
declare n int;
begin
  perform require_role('admin');
  with revenue as (
    select ol.sku, sum(ol.qty * ol.unit_price) as amount
      from order_lines ol join orders o on o.id = ol.order_id
     where o.status = 'fulfilled' and o.placed_at > now() - make_interval(days => p_days)
     group by ol.sku),
  ranked as (
    select sku, sum(amount) over (order by amount desc, sku)
             / nullif(sum(amount) over (), 0) as cumulative
      from revenue),
  graded as (
    select p.sku,
           case when r.cumulative is null then 'C'
                when r.cumulative <= 0.80 then 'A'
                when r.cumulative <= 0.95 then 'B'
                else 'C' end as grade
      from products p left join ranked r on r.sku = p.sku
     where p.active)
  update products p set abc_class = g.grade
    from graded g where g.sku = p.sku and p.abc_class is distinct from g.grade;
  get diagnostics n = row_count;
  return n;
end;
$$;
