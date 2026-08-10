-- ============================================================================
-- Ms Beau Ave — Phase 2: B2B credit engine (Spec.md §3.3, §3.5, §6.1)
--
-- Resellers with tiers, invoices/AR, and the §6.1 hard rules enforced by the
-- database, not by people:
--   * auto-block new orders on any past-due invoice OR credit-limit breach
--   * auto-demote one tier on two late payments within a rolling quarter
--   * 2/10 net 30 early-payment discount auto-applied at payment recording
--   * exposure cap view flagging resellers holding > 15% of total AR
-- Tier 1 (New) is prepayment-only: invoices fall due at placement and orders
-- cannot be fulfilled until fully paid.
--
-- The Phase 1 order engine calls into this module through three hooks:
-- check_reseller_can_order, create_invoice_for_order, check_order_fulfillable,
-- void_invoice_for_order.
-- ============================================================================

create table if not exists resellers (
  id                 bigint generated always as identity primary key,
  name               text not null,
  email              text,
  tier               int  not null default 1 check (tier in (1, 2, 3)),
  credit_limit       numeric(12,2) not null default 0 check (credit_limit >= 0),
  payment_terms_days int  not null default 0 check (payment_terms_days >= 0),
  status             text not null default 'PENDING'
                     check (status in ('PENDING','ACTIVE','SUSPENDED')),
  docs_verified      boolean not null default false,
  avg_monthly_order  numeric(12,2) not null default 0,
  blocked            boolean not null default false,
  blocked_reason     text,
  created_at         timestamptz not null default now()
);

drop trigger if exists trg_resellers_audit on resellers;
create trigger trg_resellers_audit
  after insert or update or delete on resellers
  for each row execute function audit_row();

-- Tier changes, blocks, demotions — the reseller agreement record (§6.5)
create table if not exists reseller_events (
  id           bigint generated always as identity primary key,
  reseller_id  bigint not null references resellers (id),
  event_type   text   not null,   -- AUTO_BLOCK | UNBLOCK | AUTO_DEMOTE | TIER_CHANGE | DOCS_VERIFIED | ...
  details      jsonb,
  actor        text   not null default app_actor(),
  ts           timestamptz not null default now()
);

-- Onboarding document uploads with admin verification queue (§3.3)
create table if not exists reseller_documents (
  id           bigint generated always as identity primary key,
  reseller_id  bigint not null references resellers (id),
  doc_type     text   not null,   -- BUSINESS_LICENSE | TAX_DOCUMENT | AGREEMENT | ...
  file_ref     text   not null,
  uploaded_at  timestamptz not null default now(),
  verified     boolean not null default false,
  verified_by  text,
  verified_at  timestamptz
);

create table if not exists invoices (
  id                bigint generated always as identity primary key,
  order_id          bigint not null unique references orders (id),
  reseller_id       bigint not null references resellers (id),
  issued_at         date not null default current_date,
  due_date          date not null,
  amount            numeric(12,2) not null check (amount >= 0),
  paid_amount       numeric(12,2) not null default 0 check (paid_amount >= 0),
  discount_applied  numeric(12,2) not null default 0 check (discount_applied >= 0),
  status            text not null default 'OPEN' check (status in ('OPEN','PAID','VOID')),
  paid_at           date
);

create index if not exists invoices_reseller_idx on invoices (reseller_id, status);

drop trigger if exists trg_invoices_audit on invoices;
create trigger trg_invoices_audit
  after insert or update or delete on invoices
  for each row execute function audit_row();

create table if not exists payments (
  id          bigint generated always as identity primary key,
  invoice_id  bigint not null references invoices (id),
  amount      numeric(12,2) not null check (amount > 0),
  paid_on     date not null default current_date,
  recorded_by text not null default app_actor(),
  ts          timestamptz not null default now()
);

-- Orders placed before this migration may carry no reseller FK; attach it now.
alter table orders
  drop constraint if exists orders_reseller_fk,
  add constraint orders_reseller_fk
    foreign key (reseller_id) references resellers (id);

-- ---------------------------------------------------------------------------
-- Outstanding AR per reseller (OPEN invoices, net of payments/discounts)
-- ---------------------------------------------------------------------------
create or replace function reseller_outstanding(p_reseller_id bigint)
returns numeric language sql stable security definer as $$
  select coalesce(sum(amount - paid_amount - discount_applied), 0)
    from invoices
   where reseller_id = p_reseller_id and status = 'OPEN';
$$;

create or replace function reseller_has_past_due(p_reseller_id bigint)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from invoices
     where reseller_id = p_reseller_id
       and status = 'OPEN'
       and due_date < current_date);
$$;

-- ---------------------------------------------------------------------------
-- §6.1 order gate — called by place_order for every B2B order.
-- No human override without OWNER_ADMIN + audit (see admin_unblock_reseller).
-- ---------------------------------------------------------------------------
create or replace function check_reseller_can_order(
  p_reseller_id bigint,
  p_order_total numeric
) returns void
language plpgsql security definer as $$
declare
  v_r resellers%rowtype;
begin
  select * into v_r from resellers where id = p_reseller_id for update;
  if not found then
    raise exception 'unknown reseller %', p_reseller_id;
  end if;

  if v_r.status <> 'ACTIVE' or not v_r.docs_verified then
    raise exception 'RESELLER_NOT_ELIGIBLE: reseller % is % (docs verified: %)',
      p_reseller_id, v_r.status, v_r.docs_verified using errcode = 'P0004';
  end if;

  -- Hard rule: any past-due invoice auto-blocks new orders. This is a live
  -- check — raising here rolls back the whole order transaction, so the
  -- sticky flag/event is persisted separately by refresh_reseller_blocks()
  -- (the AR job / dashboard path), never inside the failing order.
  if reseller_has_past_due(p_reseller_id) then
    raise exception 'RESELLER_BLOCKED: reseller % has past-due invoice(s)', p_reseller_id
      using errcode = 'P0003';
  end if;

  if v_r.blocked then
    raise exception 'RESELLER_BLOCKED: reseller % is blocked (%)',
      p_reseller_id, coalesce(v_r.blocked_reason, 'unspecified') using errcode = 'P0003';
  end if;

  -- Hard rule: credit-limit breach blocks the order. Tier 1 is prepayment-only
  -- (₱0 credit exposure) — orders are allowed but fall due immediately and
  -- ship only after payment (check_order_fulfillable).
  if v_r.tier >= 2
     and reseller_outstanding(p_reseller_id) + coalesce(p_order_total, 0) > v_r.credit_limit then
    raise exception
      'CREDIT_LIMIT_EXCEEDED: reseller % outstanding % + order % exceeds limit %',
      p_reseller_id, reseller_outstanding(p_reseller_id)::numeric(12,2),
      coalesce(p_order_total, 0)::numeric(12,2), v_r.credit_limit
      using errcode = 'P0003';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Persist the auto-block state (§6.1). Run by the daily AR job and by the
-- portal/agent backend whenever an order bounces with RESELLER_BLOCKED —
-- it commits independently of any failed order transaction.
-- ---------------------------------------------------------------------------
create or replace function refresh_reseller_blocks(p_reseller_id bigint default null)
returns int
language plpgsql security definer as $$
declare
  v_count int := 0;
  v_id bigint;
begin
  perform assert_role('OWNER_ADMIN','HR_FINANCE','B2B_AGENT');
  for v_id in
    select r.id from resellers r
     where (p_reseller_id is null or r.id = p_reseller_id)
       and not r.blocked
       and reseller_has_past_due(r.id)
  loop
    update resellers
       set blocked = true, blocked_reason = 'PAST_DUE_INVOICE'
     where id = v_id;
    insert into reseller_events (reseller_id, event_type, details)
    values (v_id, 'AUTO_BLOCK', jsonb_build_object('reason', 'PAST_DUE_INVOICE'));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Invoice raised at order placement. Tier 1: due immediately (prepayment).
-- ---------------------------------------------------------------------------
create or replace function create_invoice_for_order(p_order_id bigint) returns void
language plpgsql security definer as $$
declare
  v_order orders%rowtype;
  v_terms int;
begin
  select * into v_order from orders where id = p_order_id;
  if v_order.channel <> 'B2B' or v_order.reseller_id is null then
    return;
  end if;

  select case when tier = 1 then 0 else payment_terms_days end
    into v_terms from resellers where id = v_order.reseller_id;

  insert into invoices (order_id, reseller_id, due_date, amount)
  values (p_order_id, v_order.reseller_id,
          current_date + v_terms, v_order.total)
  on conflict (order_id) do nothing;
end;
$$;

-- Tier 1 prepayment gate, called by fulfill_order.
create or replace function check_order_fulfillable(p_order_id bigint) returns void
language plpgsql stable security definer as $$
declare
  v_inv invoices%rowtype;
  v_tier int;
begin
  select i.* into v_inv from invoices i where i.order_id = p_order_id;
  if not found then return; end if;

  select tier into v_tier from resellers where id = v_inv.reseller_id;
  if v_tier = 1 and v_inv.status <> 'PAID' then
    raise exception
      'PREPAYMENT_REQUIRED: Tier 1 reseller % must pay invoice % before fulfilment',
      v_inv.reseller_id, v_inv.id using errcode = 'P0005';
  end if;
end;
$$;

create or replace function void_invoice_for_order(p_order_id bigint) returns void
language plpgsql security definer as $$
begin
  update invoices set status = 'VOID'
   where order_id = p_order_id and status = 'OPEN' and paid_amount = 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- Payment recording (§6.1):
--   * 2/10 net 30 — 2% discount auto-applied when a Net-30 invoice is settled
--     within 10 days of issue
--   * late payment detection feeds the auto-demotion rule (two lates within a
--     rolling quarter → one tier down)
--   * curing all past-due invoices auto-lifts a PAST_DUE_INVOICE block
-- ---------------------------------------------------------------------------
create or replace function record_payment(
  p_invoice_id bigint,
  p_amount     numeric,
  p_paid_on    date default current_date
) returns void
language plpgsql security definer as $$
declare
  v_inv   invoices%rowtype;
  v_r     resellers%rowtype;
  v_disc  numeric(12,2) := 0;
  v_late  boolean;
  v_lates int;
  v_since timestamptz;
begin
  perform assert_role('OWNER_ADMIN','HR_FINANCE','B2B_AGENT');
  if p_amount <= 0 then
    raise exception 'payment amount must be positive';
  end if;

  select * into v_inv from invoices where id = p_invoice_id for update;
  if not found then
    raise exception 'unknown invoice %', p_invoice_id;
  end if;
  if v_inv.status <> 'OPEN' then
    raise exception 'invoice % is % — cannot record payment', p_invoice_id, v_inv.status;
  end if;

  select * into v_r from resellers where id = v_inv.reseller_id for update;

  insert into payments (invoice_id, amount, paid_on)
  values (p_invoice_id, p_amount, p_paid_on);

  -- Early-payment discount: 2/10 net 30, applied when the payment settles the
  -- discounted balance within the 10-day window.
  if v_r.payment_terms_days = 30
     and p_paid_on <= v_inv.issued_at + 10
     and v_inv.paid_amount + p_amount >= round(v_inv.amount * 0.98, 2) - v_inv.discount_applied
  then
    v_disc := round(v_inv.amount * 0.02, 2) - v_inv.discount_applied;
    if v_disc < 0 then v_disc := 0; end if;
  end if;

  update invoices
     set paid_amount      = paid_amount + p_amount,
         discount_applied = discount_applied + v_disc
   where id = p_invoice_id
   returning * into v_inv;

  if v_inv.paid_amount + v_inv.discount_applied >= v_inv.amount then
    update invoices set status = 'PAID', paid_at = p_paid_on
     where id = p_invoice_id
     returning * into v_inv;

    v_late := p_paid_on > v_inv.due_date;
    if v_late then
      insert into reseller_events (reseller_id, event_type, details)
      values (v_inv.reseller_id, 'LATE_PAYMENT',
              jsonb_build_object('invoice_id', v_inv.id,
                                 'due_date', v_inv.due_date, 'paid_at', p_paid_on));

      -- Auto-demote: two late payments within a rolling quarter, counting only
      -- lates since the last demotion so one streak demotes once.
      select coalesce(max(ts), '-infinity'::timestamptz) into v_since
        from reseller_events
       where reseller_id = v_inv.reseller_id and event_type = 'AUTO_DEMOTE';

      select count(*) into v_lates
        from reseller_events
       where reseller_id = v_inv.reseller_id
         and event_type = 'LATE_PAYMENT'
         and ts > v_since
         and ts > now() - interval '90 days';

      if v_lates >= 2 and v_r.tier > 1 then
        update resellers set tier = v_r.tier - 1 where id = v_r.id;
        insert into reseller_events (reseller_id, event_type, details)
        values (v_r.id, 'AUTO_DEMOTE',
                jsonb_build_object('from_tier', v_r.tier, 'to_tier', v_r.tier - 1,
                                   'late_payments_in_quarter', v_lates));
      end if;
    end if;

    -- Cure: lifting a past-due auto-block once nothing is past due any more.
    if v_r.blocked and v_r.blocked_reason = 'PAST_DUE_INVOICE'
       and not reseller_has_past_due(v_r.id) then
      update resellers set blocked = false, blocked_reason = null where id = v_r.id;
      insert into reseller_events (reseller_id, event_type, details)
      values (v_r.id, 'UNBLOCK', jsonb_build_object('reason', 'PAST_DUE_CURED'));
    end if;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin actions — the only human override path, always audited (§6.1)
-- ---------------------------------------------------------------------------
create or replace function admin_unblock_reseller(p_reseller_id bigint, p_note text)
returns void language plpgsql security definer as $$
begin
  perform assert_role('OWNER_ADMIN');
  update resellers set blocked = false, blocked_reason = null where id = p_reseller_id;
  insert into reseller_events (reseller_id, event_type, details)
  values (p_reseller_id, 'UNBLOCK', jsonb_build_object('note', p_note, 'by', app_actor()));
end;
$$;

create or replace function admin_set_tier(
  p_reseller_id bigint, p_tier int, p_credit_limit numeric, p_terms_days int
) returns void language plpgsql security definer as $$
begin
  perform assert_role('OWNER_ADMIN');
  insert into reseller_events (reseller_id, event_type, details)
  select id, 'TIER_CHANGE',
         jsonb_build_object('from_tier', tier, 'to_tier', p_tier,
                            'credit_limit', p_credit_limit, 'terms_days', p_terms_days)
    from resellers where id = p_reseller_id;
  update resellers
     set tier = p_tier, credit_limit = p_credit_limit, payment_terms_days = p_terms_days
   where id = p_reseller_id;
end;
$$;

create or replace function admin_verify_reseller(p_reseller_id bigint)
returns void language plpgsql security definer as $$
begin
  perform assert_role('OWNER_ADMIN');
  update resellers set docs_verified = true, status = 'ACTIVE'
   where id = p_reseller_id;
  insert into reseller_events (reseller_id, event_type, details)
  values (p_reseller_id, 'DOCS_VERIFIED', jsonb_build_object('by', app_actor()));
end;
$$;

-- ---------------------------------------------------------------------------
-- AR aging & exposure (§3.5, §6.1)
-- ---------------------------------------------------------------------------
create or replace view ar_aging as
select r.id as reseller_id, r.name, r.tier,
       sum(case when i.due_date >= current_date
                then i.amount - i.paid_amount - i.discount_applied else 0 end) as current_due,
       sum(case when current_date - i.due_date between 1 and 30
                then i.amount - i.paid_amount - i.discount_applied else 0 end) as overdue_1_30,
       sum(case when current_date - i.due_date between 31 and 60
                then i.amount - i.paid_amount - i.discount_applied else 0 end) as overdue_31_60,
       sum(case when current_date - i.due_date > 60
                then i.amount - i.paid_amount - i.discount_applied else 0 end) as overdue_60_plus,
       sum(i.amount - i.paid_amount - i.discount_applied) as total_outstanding
  from resellers r
  join invoices i on i.reseller_id = r.id and i.status = 'OPEN'
 group by r.id, r.name, r.tier;

-- Exposure cap alert (§6.1): any reseller holding more than 15% of total AR.
create or replace view ar_exposure as
with totals as (
  select coalesce(sum(amount - paid_amount - discount_applied), 0) as total_ar
    from invoices where status = 'OPEN')
select r.id as reseller_id, r.name,
       reseller_outstanding(r.id) as outstanding,
       t.total_ar,
       case when t.total_ar > 0
            then round(reseller_outstanding(r.id) / t.total_ar, 4) else 0 end as share,
       (t.total_ar > 0 and reseller_outstanding(r.id) / t.total_ar > 0.15) as flagged
  from resellers r cross join totals t
 where reseller_outstanding(r.id) > 0;

-- ---------------------------------------------------------------------------
-- RLS: resellers see only themselves; finance/admin see everything (§2, §8)
-- ---------------------------------------------------------------------------
alter table resellers          enable row level security;
alter table reseller_events    enable row level security;
alter table reseller_documents enable row level security;
alter table invoices           enable row level security;
alter table payments           enable row level security;

create policy resellers_staff_read on resellers for select
  using (app_role() in ('OWNER_ADMIN','B2B_AGENT','HR_FINANCE'));
create policy resellers_self_read on resellers for select
  using (app_role() = 'RESELLER' and id = app_reseller_id());

create policy reseller_events_staff_read on reseller_events for select
  using (app_role() in ('OWNER_ADMIN','B2B_AGENT','HR_FINANCE'));

create policy reseller_docs_staff on reseller_documents for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE'));
create policy reseller_docs_self on reseller_documents for select
  using (app_role() = 'RESELLER' and reseller_id = app_reseller_id());
create policy reseller_docs_upload on reseller_documents for insert
  with check (app_role() = 'RESELLER' and reseller_id = app_reseller_id()
              or app_role() = 'OWNER_ADMIN');

create policy invoices_staff_read on invoices for select
  using (app_role() in ('OWNER_ADMIN','B2B_AGENT','HR_FINANCE'));
create policy invoices_self_read on invoices for select
  using (app_role() = 'RESELLER' and reseller_id = app_reseller_id());

create policy payments_staff_read on payments for select
  using (app_role() in ('OWNER_ADMIN','B2B_AGENT','HR_FINANCE'));

grant select on all tables in schema public to app_client;
grant select, insert on reseller_documents to app_client;
grant execute on all functions in schema public to app_client;
