-- ============================================================================
-- Ms Beau Ave — Phase 5: HRMS & payroll (Spec.md §3.6)
--
--   * Employees + attendance in three modes: BIOMETRIC (device REST punches),
--     POS (tablet shift login), GPS (mobile B2B agents, geofenced to
--     registered reseller locations)
--   * Commission engine, three structures: retail % of own shop sales with
--     brand boosts; B2B tied to assigned resellers' fulfilled volume with a
--     close-to-expiry clearance boost; warehouse hourly + OT + night
--     differential + holiday premiums (computed in payroll)
--   * Philippine statutory compliance as a pluggable locale module: SSS,
--     PhilHealth, Pag-IBIG, withholding tax — all rates/brackets live in
--     effective-dated config rows (statutory_rates), not in code
--   * 13th-month accrual, BIR 2316 annual data (PDF rendering is app-layer)
--   * Digitized 201 files with expiry alerts; LMS gating floor access
--
-- Seeded rates reflect the published 2025 PH schedules (SSS 15% split 5%/10%
-- on MSC ₱5k–₱35k in ₱500 steps; PhilHealth 5% split 50/50, floor ₱10k cap
-- ₱100k; Pag-IBIG 2%/2% capped at ₱10k fund salary; TRAIN monthly WHT table).
-- Update the statutory_rates rows when the agencies revise them.
-- ============================================================================

create table if not exists employees (
  id                 bigint generated always as identity primary key,
  name               text not null,
  actor_name         text unique,     -- links app_actor()/orders.created_by to this employee
  role_type          text not null check (role_type in ('WAREHOUSE','RETAIL','B2B_AGENT','OFFICE')),
  pay_basis          text not null default 'MONTHLY' check (pay_basis in ('MONTHLY','HOURLY')),
  base_pay           numeric(12,2) not null check (base_pay >= 0),  -- monthly or hourly per pay_basis
  commission_plan_id bigint,
  hire_date          date not null default current_date,
  statutory_ids      jsonb not null default '{}',   -- SSS / PhilHealth / Pag-IBIG / TIN numbers
  active             boolean not null default true,
  created_at         timestamptz not null default now()
);

drop trigger if exists trg_employees_audit on employees;
create trigger trg_employees_audit
  after insert or update or delete on employees
  for each row execute function audit_row();

-- B2B agents own reseller accounts; their commissions follow those accounts.
alter table resellers add column if not exists agent_employee_id bigint references employees (id);

-- ---------------------------------------------------------------------------
-- Attendance — three punch modes (§3.6)
-- ---------------------------------------------------------------------------
create table if not exists reseller_locations (
  id          bigint generated always as identity primary key,
  reseller_id bigint not null references resellers (id),
  label       text,
  lat         double precision not null,
  lng         double precision not null,
  radius_m    int not null default 200
);

create table if not exists attendance (
  id          bigint generated always as identity primary key,
  employee_id bigint not null references employees (id),
  clock_in    timestamptz not null,
  clock_out   timestamptz,
  method      text not null check (method in ('BIOMETRIC','POS','GPS')),
  geo_lat     double precision,
  geo_lng     double precision,
  flags       text[] not null default '{}',
  check (clock_out is null or clock_out > clock_in)
);

create index if not exists attendance_emp_idx on attendance (employee_id, clock_in);

create or replace function haversine_m(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
) returns double precision
language sql immutable as $$
  select 2 * 6371000 * asin(sqrt(
    pow(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2)) * pow(sin(radians(lng2 - lng1) / 2), 2)));
$$;

-- One endpoint for every punch source: biometric devices POST here via the
-- device-agnostic REST adapter, POS tablets on shift login, agents' phones
-- with coordinates. An open attendance row is closed; otherwise a new one
-- opens. GPS punches outside every registered reseller geofence are flagged,
-- never rejected — HR reviews the exceptions (§9).
create or replace function punch_clock(
  p_employee_id bigint,
  p_method      text,
  p_ts          timestamptz default now(),
  p_lat         double precision default null,
  p_lng         double precision default null
) returns bigint
language plpgsql security definer as $$
declare
  v_open  attendance%rowtype;
  v_flags text[] := '{}';
  v_id    bigint;
begin
  perform assert_role('OWNER_ADMIN','HR_FINANCE','WAREHOUSE','RETAIL_CASHIER','B2B_AGENT');

  select * into v_open from attendance
   where employee_id = p_employee_id and clock_out is null
   order by clock_in desc limit 1
   for update;

  if found then
    update attendance set clock_out = p_ts where id = v_open.id;
    return v_open.id;
  end if;

  if p_method = 'GPS' then
    if p_lat is null or p_lng is null then
      v_flags := array_append(v_flags, 'GPS_MISSING_COORDS');
    elsif not exists (
      select 1 from reseller_locations rl
       where haversine_m(p_lat, p_lng, rl.lat, rl.lng) <= rl.radius_m) then
      v_flags := array_append(v_flags, 'OUT_OF_GEOFENCE');
    end if;
  end if;

  insert into attendance (employee_id, clock_in, method, geo_lat, geo_lng, flags)
  values (p_employee_id, p_ts, p_method, p_lat, p_lng, v_flags)
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Commission engine (§3.6)
-- ---------------------------------------------------------------------------
create table if not exists commission_plans (
  id        bigint generated always as identity primary key,
  name      text not null,
  role_type text not null check (role_type in ('RETAIL','B2B_AGENT')),
  -- RETAIL: {"rate": 0.02, "brand_boosts": {"BrandX": 0.05}}
  -- B2B:    {"rate": 0.03, "clearance_boost": 0.02, "clearance_window_days": 180}
  config    jsonb not null
);

alter table employees
  drop constraint if exists employees_commission_plan_fk,
  add constraint employees_commission_plan_fk
    foreign key (commission_plan_id) references commission_plans (id);

create table if not exists commission_entries (
  id           bigint generated always as identity primary key,
  employee_id  bigint not null references employees (id),
  period_start date not null,
  period_end   date not null,
  source       text not null,      -- RETAIL_SALES | B2B_VOLUME | B2B_CLEARANCE | MANUAL
  order_id     bigint references orders (id),
  amount       numeric(12,2) not null,
  details      jsonb,
  created_at   timestamptz not null default now(),
  unique (employee_id, period_start, period_end, source, order_id)
);

-- Recompute a period; idempotent (existing computed rows for the period are
-- replaced, MANUAL entries are kept).
create or replace function compute_commissions(p_start date, p_end date) returns int
language plpgsql security definer as $$
declare
  v_count int := 0;
  v_emp   record;
  v_ord   record;
  v_cfg   jsonb;
  v_amt   numeric;
  v_boost numeric;
begin
  perform assert_role('OWNER_ADMIN','HR_FINANCE');

  delete from commission_entries
   where period_start = p_start and period_end = p_end and source <> 'MANUAL';

  -- Retail: % of the employee's own fulfilled shop sales + per-brand boosts.
  for v_emp in
    select e.*, cp.config from employees e
    join commission_plans cp on cp.id = e.commission_plan_id
    where e.active and e.role_type = 'RETAIL' and cp.role_type = 'RETAIL'
  loop
    v_cfg := v_emp.config;
    for v_ord in
      select o.id, o.total,
             coalesce(sum(ol.qty * ol.unit_price - ol.discount), 0) as boosted_value,
             coalesce(max((v_cfg -> 'brand_boosts' ->> p.brand)::numeric), 0) as boost_rate
        from orders o
        left join order_lines ol on ol.order_id = o.id
        left join products p on p.sku = ol.sku
                            and v_cfg -> 'brand_boosts' ? coalesce(p.brand, '')
       where o.channel = 'RETAIL' and o.status = 'FULFILLED'
         and o.created_by = v_emp.actor_name
         and o.created_at >= p_start and o.created_at < p_end + 1
       group by o.id, o.total
    loop
      v_amt := round(v_ord.total * (v_cfg ->> 'rate')::numeric, 2);
      v_boost := 0;
      if v_ord.boost_rate > 0 then
        -- boost applies to lines of boosted brands only
        select coalesce(sum(round(ol.qty * ol.unit_price
                 * (v_cfg -> 'brand_boosts' ->> p.brand)::numeric, 2)), 0)
          into v_boost
          from order_lines ol join products p on p.sku = ol.sku
         where ol.order_id = v_ord.id
           and v_cfg -> 'brand_boosts' ? coalesce(p.brand, '');
      end if;
      insert into commission_entries
        (employee_id, period_start, period_end, source, order_id, amount, details)
      values (v_emp.id, p_start, p_end, 'RETAIL_SALES', v_ord.id, v_amt + v_boost,
              jsonb_build_object('base', v_amt, 'brand_boost', v_boost));
      v_count := v_count + 1;
    end loop;
  end loop;

  -- B2B: % of assigned resellers' fulfilled order volume, plus a clearance
  -- boost on lines picked from close-to-expiry batches (§3.6).
  for v_emp in
    select e.*, cp.config from employees e
    join commission_plans cp on cp.id = e.commission_plan_id
    where e.active and e.role_type = 'B2B_AGENT' and cp.role_type = 'B2B_AGENT'
  loop
    v_cfg := v_emp.config;
    for v_ord in
      select o.id, o.total,
             coalesce((
               select sum(ol.qty * ol.unit_price - ol.discount)
                 from order_lines ol
                 join batches b on b.id = ol.batch_id
                where ol.order_id = o.id
                  and b.expiry_date <= o.created_at::date
                        + coalesce((v_cfg ->> 'clearance_window_days')::int, 180)
             ), 0) as clearance_value
        from orders o
        join resellers r on r.id = o.reseller_id
       where o.channel = 'B2B' and o.status = 'FULFILLED'
         and r.agent_employee_id = v_emp.id
         and o.created_at >= p_start and o.created_at < p_end + 1
    loop
      v_amt := round(v_ord.total * (v_cfg ->> 'rate')::numeric, 2);
      v_boost := round(v_ord.clearance_value
                       * coalesce((v_cfg ->> 'clearance_boost')::numeric, 0), 2);
      insert into commission_entries
        (employee_id, period_start, period_end, source, order_id, amount, details)
      values (v_emp.id, p_start, p_end, 'B2B_VOLUME', v_ord.id, v_amt + v_boost,
              jsonb_build_object('base', v_amt, 'clearance_boost', v_boost));
      v_count := v_count + 1;
    end loop;
  end loop;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Statutory locale module (§3.6): every rate is data, effective-dated.
-- ---------------------------------------------------------------------------
create table if not exists statutory_rates (
  locale         text not null,
  component      text not null,   -- SSS | PHILHEALTH | PAGIBIG | WHT
  effective_from date not null,
  config         jsonb not null,
  primary key (locale, component, effective_from)
);

insert into statutory_rates (locale, component, effective_from, config) values
  ('PH', 'SSS', '2025-01-01',
   '{"ee_rate": 0.05, "er_rate": 0.10, "msc_min": 5000, "msc_max": 35000, "msc_step": 500}'),
  ('PH', 'PHILHEALTH', '2025-01-01',
   '{"rate": 0.05, "ee_share": 0.5, "salary_floor": 10000, "salary_cap": 100000}'),
  ('PH', 'PAGIBIG', '2024-01-01',
   '{"ee_rate": 0.02, "ee_rate_low": 0.01, "low_threshold": 1500, "er_rate": 0.02, "fund_salary_cap": 10000}'),
  ('PH', 'WHT', '2023-01-01',
   '{"brackets": [
      {"over": 0,      "base": 0,         "rate": 0},
      {"over": 20833,  "base": 0,         "rate": 0.15},
      {"over": 33333,  "base": 2500,      "rate": 0.20},
      {"over": 66667,  "base": 9166.67,   "rate": 0.25},
      {"over": 166667, "base": 34166.67,  "rate": 0.30},
      {"over": 666667, "base": 184166.67, "rate": 0.35}]}')
on conflict do nothing;

create or replace function statutory_config(p_locale text, p_component text, p_as_of date)
returns jsonb language sql stable as $$
  select config from statutory_rates
   where locale = p_locale and component = p_component and effective_from <= p_as_of
   order by effective_from desc limit 1;
$$;

create or replace function ph_sss(p_salary numeric, p_as_of date default current_date,
  out ee numeric, out er numeric) returns record
language plpgsql stable as $$
declare c jsonb := statutory_config('PH', 'SSS', p_as_of); v_msc numeric;
begin
  if c is null then raise exception 'no PH SSS rates effective %', p_as_of; end if;
  v_msc := least(greatest(round(p_salary / (c ->> 'msc_step')::numeric)
                            * (c ->> 'msc_step')::numeric,
                          (c ->> 'msc_min')::numeric),
                 (c ->> 'msc_max')::numeric);
  ee := round(v_msc * (c ->> 'ee_rate')::numeric, 2);
  er := round(v_msc * (c ->> 'er_rate')::numeric, 2);
end;
$$;

create or replace function ph_philhealth(p_salary numeric, p_as_of date default current_date,
  out ee numeric, out er numeric) returns record
language plpgsql stable as $$
declare c jsonb := statutory_config('PH', 'PHILHEALTH', p_as_of); v_base numeric; v_total numeric;
begin
  if c is null then raise exception 'no PH PhilHealth rates effective %', p_as_of; end if;
  v_base  := least(greatest(p_salary, (c ->> 'salary_floor')::numeric),
                   (c ->> 'salary_cap')::numeric);
  v_total := v_base * (c ->> 'rate')::numeric;
  ee := round(v_total * (c ->> 'ee_share')::numeric, 2);
  er := round(v_total - ee, 2);
end;
$$;

create or replace function ph_pagibig(p_salary numeric, p_as_of date default current_date,
  out ee numeric, out er numeric) returns record
language plpgsql stable as $$
declare c jsonb := statutory_config('PH', 'PAGIBIG', p_as_of); v_base numeric;
begin
  if c is null then raise exception 'no PH Pag-IBIG rates effective %', p_as_of; end if;
  v_base := least(p_salary, (c ->> 'fund_salary_cap')::numeric);
  ee := round(v_base * case when p_salary <= (c ->> 'low_threshold')::numeric
                            then (c ->> 'ee_rate_low')::numeric
                            else (c ->> 'ee_rate')::numeric end, 2);
  er := round(v_base * (c ->> 'er_rate')::numeric, 2);
end;
$$;

create or replace function ph_wht(p_taxable_monthly numeric, p_as_of date default current_date)
returns numeric
language plpgsql stable as $$
declare
  c jsonb := statutory_config('PH', 'WHT', p_as_of);
  b jsonb; v_best jsonb;
begin
  if c is null then raise exception 'no PH withholding-tax table effective %', p_as_of; end if;
  for b in select * from jsonb_array_elements(c -> 'brackets') loop
    if p_taxable_monthly > (b ->> 'over')::numeric then v_best := b; end if;
  end loop;
  if v_best is null then return 0; end if;
  return round((v_best ->> 'base')::numeric
               + (p_taxable_monthly - (v_best ->> 'over')::numeric)
                 * (v_best ->> 'rate')::numeric, 2);
end;
$$;

-- ---------------------------------------------------------------------------
-- Payroll runs (§3.6). Monthly staff draw base_pay per monthly period;
-- warehouse (HOURLY) staff are paid from attendance: OT ×1.25 past 8h/day,
-- +10% night differential 22:00–06:00, holiday premiums from the calendar.
-- ---------------------------------------------------------------------------
create table if not exists ph_holidays (
  holiday_date date primary key,
  kind         text not null check (kind in ('REGULAR','SPECIAL')),
  name         text not null
);

create table if not exists payroll_runs (
  id           bigint generated always as identity primary key,
  period_start date not null,
  period_end   date not null,
  status       text not null default 'DRAFT' check (status in ('DRAFT','APPROVED','PAID')),
  created_by   text not null default app_actor(),
  approved_by  text,
  created_at   timestamptz not null default now(),
  unique (period_start, period_end)
);

create table if not exists payroll_lines (
  id             bigint generated always as identity primary key,
  run_id         bigint not null references payroll_runs (id) on delete cascade,
  employee_id    bigint not null references employees (id),
  basic_pay      numeric(12,2) not null default 0,
  ot_pay         numeric(12,2) not null default 0,
  night_diff_pay numeric(12,2) not null default 0,
  holiday_pay    numeric(12,2) not null default 0,
  commission_pay numeric(12,2) not null default 0,
  gross          numeric(12,2) not null default 0,
  sss_ee         numeric(12,2) not null default 0,
  sss_er         numeric(12,2) not null default 0,
  philhealth_ee  numeric(12,2) not null default 0,
  philhealth_er  numeric(12,2) not null default 0,
  pagibig_ee     numeric(12,2) not null default 0,
  pagibig_er     numeric(12,2) not null default 0,
  taxable_income numeric(12,2) not null default 0,
  wht            numeric(12,2) not null default 0,
  net_pay        numeric(12,2) not null default 0,
  details        jsonb,
  unique (run_id, employee_id)
);

drop trigger if exists trg_payroll_runs_audit on payroll_runs;
create trigger trg_payroll_runs_audit
  after insert or update or delete on payroll_runs
  for each row execute function audit_row();
drop trigger if exists trg_payroll_lines_audit on payroll_lines;
create trigger trg_payroll_lines_audit
  after insert or update or delete on payroll_lines
  for each row execute function audit_row();

-- Hour-by-hour walk of one attendance row: regular vs OT (>8h/day), night
-- hours (22:00–06:00 Asia/Manila), holiday hours from the calendar.
create or replace function attendance_pay_components(
  p_att attendance, p_hourly_rate numeric,
  out reg_pay numeric, out ot_pay numeric, out night_pay numeric, out holiday_pay numeric)
returns record
language plpgsql stable as $$
declare
  v_cur   timestamptz;
  v_end   timestamptz;
  v_hours numeric := 0;
  v_local timestamptz;
  v_hr    int;
  v_kind  text;
begin
  reg_pay := 0; ot_pay := 0; night_pay := 0; holiday_pay := 0;
  if p_att.clock_out is null then return; end if;

  v_cur := p_att.clock_in;
  v_end := p_att.clock_out;
  while v_cur < v_end loop
    declare v_slice numeric := least(1, extract(epoch from (v_end - v_cur)) / 3600);
    begin
      v_hours := v_hours + v_slice;
      if v_hours <= 8 then
        reg_pay := reg_pay + p_hourly_rate * v_slice;
      else
        ot_pay := ot_pay + p_hourly_rate * 1.25 * v_slice;
      end if;

      v_hr := extract(hour from v_cur at time zone 'Asia/Manila');
      if v_hr >= 22 or v_hr < 6 then
        night_pay := night_pay + p_hourly_rate * 0.10 * v_slice;
      end if;

      select kind into v_kind from ph_holidays
       where holiday_date = (v_cur at time zone 'Asia/Manila')::date;
      if v_kind = 'REGULAR' then
        holiday_pay := holiday_pay + p_hourly_rate * 1.00 * v_slice;  -- 200% total
      elsif v_kind = 'SPECIAL' then
        holiday_pay := holiday_pay + p_hourly_rate * 0.30 * v_slice;  -- 130% total
      end if;

      v_cur := v_cur + make_interval(secs => v_slice * 3600);
    end;
  end loop;

  reg_pay := round(reg_pay, 2); ot_pay := round(ot_pay, 2);
  night_pay := round(night_pay, 2); holiday_pay := round(holiday_pay, 2);
end;
$$;

create or replace function run_payroll(p_start date, p_end date) returns bigint
language plpgsql security definer as $$
declare
  v_run_id bigint;
  v_emp    employees%rowtype;
  v_att    attendance%rowtype;
  v_basic numeric; v_ot numeric; v_night numeric; v_holiday numeric; v_comm numeric;
  v_gross numeric; v_taxable numeric; v_wht numeric;
  v_sss record; v_ph record; v_pi record;
  v_contrib_basis numeric;
  c record;
begin
  perform assert_role('OWNER_ADMIN','HR_FINANCE');

  insert into payroll_runs (period_start, period_end)
  values (p_start, p_end) returning id into v_run_id;

  for v_emp in select * from employees where active loop
    v_basic := 0; v_ot := 0; v_night := 0; v_holiday := 0;

    if v_emp.pay_basis = 'MONTHLY' then
      v_basic := v_emp.base_pay;
    else
      for v_att in
        select * from attendance
         where employee_id = v_emp.id and clock_out is not null
           and clock_in >= p_start and clock_in < p_end + 1
      loop
        select * into c from attendance_pay_components(v_att, v_emp.base_pay);
        v_basic   := v_basic + c.reg_pay;
        v_ot      := v_ot + c.ot_pay;
        v_night   := v_night + c.night_pay;
        v_holiday := v_holiday + c.holiday_pay;
      end loop;
    end if;

    select coalesce(sum(amount), 0) into v_comm
      from commission_entries
     where employee_id = v_emp.id
       and period_start = p_start and period_end = p_end;

    v_gross := v_basic + v_ot + v_night + v_holiday + v_comm;
    if v_gross = 0 then continue; end if;

    -- Contributions are computed on the monthly compensation basis.
    v_contrib_basis := case when v_emp.pay_basis = 'MONTHLY' then v_emp.base_pay
                            else v_basic + v_ot + v_night + v_holiday end;
    select * into v_sss from ph_sss(v_contrib_basis, p_end);
    select * into v_ph  from ph_philhealth(v_contrib_basis, p_end);
    select * into v_pi  from ph_pagibig(v_contrib_basis, p_end);

    v_taxable := v_gross - v_sss.ee - v_ph.ee - v_pi.ee;
    v_wht := ph_wht(v_taxable, p_end);

    insert into payroll_lines
      (run_id, employee_id, basic_pay, ot_pay, night_diff_pay, holiday_pay,
       commission_pay, gross, sss_ee, sss_er, philhealth_ee, philhealth_er,
       pagibig_ee, pagibig_er, taxable_income, wht, net_pay)
    values
      (v_run_id, v_emp.id, v_basic, v_ot, v_night, v_holiday,
       v_comm, v_gross, v_sss.ee, v_sss.er, v_ph.ee, v_ph.er,
       v_pi.ee, v_pi.er, v_taxable, v_wht,
       round(v_taxable - v_wht, 2));
  end loop;

  return v_run_id;
end;
$$;

create or replace function approve_payroll_run(p_run_id bigint) returns void
language plpgsql security definer as $$
begin
  perform assert_role('OWNER_ADMIN');   -- payroll approval is owner-level (§2)
  update payroll_runs
     set status = 'APPROVED', approved_by = app_actor()
   where id = p_run_id and status = 'DRAFT';
  if not found then
    raise exception 'payroll run % not found or not in DRAFT', p_run_id;
  end if;
end;
$$;

-- 13th-month pay (§3.6): 1/12 of basic salary earned in the calendar year.
create or replace function ph_13th_month(p_employee_id bigint, p_year int)
returns numeric
language sql stable security definer as $$
  select round(coalesce(sum(pl.basic_pay), 0) / 12, 2)
    from payroll_lines pl
    join payroll_runs pr on pr.id = pl.run_id
   where pl.employee_id = p_employee_id
     and extract(year from pr.period_start) = p_year;
$$;

-- BIR 2316 annual figures per employee (PDF generation is app-layer, §7).
create or replace view bir_2316_data as
select pl.employee_id, e.name, e.statutory_ids,
       extract(year from pr.period_start)::int as tax_year,
       sum(pl.gross)                          as gross_compensation,
       sum(pl.sss_ee + pl.philhealth_ee + pl.pagibig_ee) as nontaxable_contributions,
       sum(pl.taxable_income)                 as taxable_compensation,
       sum(pl.wht)                            as tax_withheld
  from payroll_lines pl
  join payroll_runs pr on pr.id = pl.run_id
  join employees e on e.id = pl.employee_id
 where pr.status in ('APPROVED','PAID')
 group by pl.employee_id, e.name, e.statutory_ids, extract(year from pr.period_start);

-- ---------------------------------------------------------------------------
-- 201 files & LMS (§3.6)
-- ---------------------------------------------------------------------------
create table if not exists documents_201 (
  id          bigint generated always as identity primary key,
  employee_id bigint not null references employees (id),
  doc_type    text not null,   -- GOVT_ID | MEDICAL_CLEARANCE | LIABILITY_CONTRACT | HAZMAT_CERT | ...
  file_ref    text not null,
  expires_on  date,
  verified    boolean not null default false,
  verified_by text,
  uploaded_at timestamptz not null default now()
);

create or replace view expiring_documents as
select d.*, e.name as employee_name
  from documents_201 d join employees e on e.id = d.employee_id
 where d.expires_on is not null
   and d.expires_on <= current_date + 60
 order by d.expires_on;

create table if not exists training_modules (
  id           bigint generated always as identity primary key,
  name         text not null,
  required_for text[] not null default '{}',   -- role_types gated by this module
  pass_score   int not null default 80
);

create table if not exists training_records (
  id           bigint generated always as identity primary key,
  employee_id  bigint not null references employees (id),
  module_id    bigint not null references training_modules (id),
  score        int not null,
  passed       boolean not null,
  completed_at timestamptz not null default now()
);

create or replace function record_training(
  p_employee_id bigint, p_module_id bigint, p_score int
) returns boolean
language plpgsql security definer as $$
declare v_pass int; v_ok boolean;
begin
  perform assert_role('OWNER_ADMIN','HR_FINANCE','WAREHOUSE','RETAIL_CASHIER','B2B_AGENT');
  select pass_score into v_pass from training_modules where id = p_module_id;
  if not found then raise exception 'unknown training module %', p_module_id; end if;
  v_ok := p_score >= v_pass;
  insert into training_records (employee_id, module_id, score, passed)
  values (p_employee_id, p_module_id, p_score, v_ok);
  return v_ok;
end;
$$;

-- Product-knowledge training is required before floor/reseller access (§3.6).
create or replace function is_training_compliant(p_employee_id bigint)
returns boolean
language sql stable security definer as $$
  select not exists (
    select 1 from training_modules tm
    join employees e on e.id = p_employee_id
   where e.role_type = any (tm.required_for)
     and not exists (
       select 1 from training_records tr
        where tr.employee_id = e.id and tr.module_id = tm.id and tr.passed));
$$;

create or replace view training_compliance as
select e.id as employee_id, e.name, e.role_type,
       is_training_compliant(e.id) as compliant
  from employees e where e.active;

-- ---------------------------------------------------------------------------
-- RLS: HR sees all; employees see their own attendance, commissions
-- (transparent dashboards §3.6), payslips and 201 docs via actor mapping.
-- ---------------------------------------------------------------------------
create or replace function app_employee_id() returns bigint
language sql stable security definer as $$
  select id from employees where actor_name = app_actor();
$$;

alter table employees          enable row level security;
alter table attendance         enable row level security;
alter table commission_plans   enable row level security;
alter table commission_entries enable row level security;
alter table payroll_runs       enable row level security;
alter table payroll_lines      enable row level security;
alter table documents_201      enable row level security;
alter table training_modules   enable row level security;
alter table training_records   enable row level security;
alter table statutory_rates    enable row level security;
alter table ph_holidays        enable row level security;
alter table reseller_locations enable row level security;

create policy hr_all_employees on employees for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE'));
create policy self_employee on employees for select
  using (id = app_employee_id());

create policy hr_attendance on attendance for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE'));
create policy self_attendance on attendance for select
  using (employee_id = app_employee_id());

create policy hr_commissions on commission_entries for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE'));
create policy self_commissions on commission_entries for select
  using (employee_id = app_employee_id());

create policy hr_payroll_runs on payroll_runs for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE'));
create policy hr_payroll_lines on payroll_lines for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE'));
create policy self_payroll_lines on payroll_lines for select
  using (employee_id = app_employee_id()
         and exists (select 1 from payroll_runs pr
                      where pr.id = run_id and pr.status in ('APPROVED','PAID')));

create policy hr_docs on documents_201 for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE'));
create policy self_docs on documents_201 for select
  using (employee_id = app_employee_id());

create policy training_modules_read on training_modules for select using (true);
create policy hr_training on training_records for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE'));
create policy self_training on training_records for select
  using (employee_id = app_employee_id());

create policy plans_read on commission_plans for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE','B2B_AGENT','RETAIL_CASHIER'));
create policy statutory_read on statutory_rates for select using (true);
create policy holidays_read on ph_holidays for select using (true);
create policy reseller_locations_read on reseller_locations for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE','B2B_AGENT'));

grant select on all tables in schema public to app_client;
grant select on expiring_documents, training_compliance, bir_2316_data to app_client;
grant execute on all functions in schema public to app_client;
