-- Schema initialization for mock data tables

-- Extensions (optional)
-- create extension if not exists "uuid-ossp";

-- ACCOUNTS (renamed from clients conceptually)
create table if not exists public.accounts (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  name text check (length(name) <= 255),
  slug text,
  industry text,
  naics int check (naics >= 0),
  email text check (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
  phone text check (phone ~ '^\+?[1-9]\d{1,14}$'),
  address_line text,
  address_city text,
  address_state text check (length(address_state) = 2),
  address_postal text check (address_postal ~ '^\d{5}(-\d{4})?$'),
  founded_year int,
  employees int check (employees >= 0),
  metadata jsonb,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

create index if not exists accounts_tenant_idx on public.accounts(tenant_id);

-- POLICIES
create table if not exists public.policies (
  id uuid primary key,
  tenant_id text not null,

  account text,
  account_lookup_code uuid,

  product text,
  product_lines text,
  policy_number text,

  revenue_billed numeric(14,2),
  premium_billed numeric(14,2),
  commission_billed numeric(14,2),

  revenue_ennabl numeric(14,2),
  premium_ennabl numeric(14,2),
  commission_ennabl numeric(14,2),

  revenue_ams numeric(14,2),
  premium_ams numeric(14,2),
  commission_ams numeric(14,2),

  revenue_prod_credit numeric(14,2),
  premium_prod_credit numeric(14,2),
  production_credit numeric(14,2),

  effective_date date,
  expiration_date date,

  am_best_rating text,
  financial_size text,

  producer text,
  account_manager text,
  account_executives jsonb,

  market text,
  issuing_paper text,
  pay_to text,
  intermediary text,

  policy_status_ennabl text,
  policy_status_ams text,
  renewal_status text,

  product_segment text,
  industry text,
  industry_subgroup text,

  naics int,
  naics_2_digits int,
  naics_4_digits int,

  city text,
  state text,
  zip text,
  biz_org text
);

create index if not exists policies_tenant_idx on public.policies(tenant_id);

do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_schema='public' and table_name='policies' and constraint_name='policies_account_lookup_fkey'
  ) then
    alter table public.policies
      add constraint policies_account_lookup_fkey
      foreign key (account_lookup_id) references public.accounts(id) on delete set null;
  end if;
end $$;

-- RENEWALS
create table if not exists public.renewals (
  id uuid primary key,
  tenant_id text not null,

  policy_id uuid,
  account text,
  policy_number text,

  renewal_status text,
  due_date date,
  premium_quoted numeric(14,2),
  premium_prior numeric(14,2),
  commission_quoted numeric(14,2),

  notes jsonb
);

create index if not exists renewals_tenant_idx on public.renewals(tenant_id);

alter table public.renewals
  add constraint if not exists renewals_policy_fkey
  foreign key (policy_id) references public.policies(id) on delete set null;

-- RLS and policies (allow anon for mock purposes)
alter table public.clients enable row level security;
alter table public.policies enable row level security;
alter table public.renewals enable row level security;

-- INDUSTRIES
create table if not exists public.industries (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  name text,
  lifetime_value numeric(18,2),
  gross_margin_pct numeric(6,2),
  annual_costs numeric(18,2),
  accounts_count int,
  policies_count int,
  avg_policy_tenure numeric(6,2),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists industries_tenant_idx on public.industries(tenant_id);
alter table public.industries enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='industries' and policyname='industries_read_authenticated'
  ) then
    create policy industries_read_authenticated on public.industries for select to authenticated using (true);
  end if;
end $$;
grant select on table public.industries to authenticated, anon;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'clients' and policyname = 'clients_all_anon') then
    create policy clients_all_anon on public.clients for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'policies' and policyname = 'policies_all_anon') then
    create policy policies_all_anon on public.policies for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'renewals' and policyname = 'renewals_all_anon') then
    create policy renewals_all_anon on public.renewals for all using (true) with check (true);
  end if;
end $$;

grant all on table public.clients to anon;
grant all on table public.policies to anon;
grant all on table public.renewals to anon;

-- ACCOUNT EXECUTIVES
create table if not exists public.account_executives (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  name text,
  email text,
  phone text,
  region text,
  accounts_count int,
  policies_count int,
  premium_total numeric(18,2),
  revenue_total numeric(18,2),
  commission_total numeric(18,2),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists account_executives_tenant_idx on public.account_executives(tenant_id);
alter table public.account_executives enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='account_executives' and policyname='ae_read_authenticated'
  ) then
    create policy ae_read_authenticated on public.account_executives for select to authenticated using (true);
  end if;
end $$;
grant select on table public.account_executives to authenticated, anon;

-- ACCOUNT MANAGERS
create table if not exists public.account_managers (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  name text,
  email text,
  phone text,
  region text,
  accounts_count int,
  policies_count int,
  premium_total numeric(18,2),
  revenue_total numeric(18,2),
  commission_total numeric(18,2),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists account_managers_tenant_idx on public.account_managers(tenant_id);
alter table public.account_managers enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='account_managers' and policyname='am_read_authenticated'
  ) then
    create policy am_read_authenticated on public.account_managers for select to authenticated using (true);
  end if;
end $$;
grant select on table public.account_managers to authenticated, anon;

-- PRODUCERS
create table if not exists public.producers (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  name text,
  email text,
  phone text,
  region text,
  accounts_count int,
  policies_count int,
  premium_total numeric(18,2),
  revenue_total numeric(18,2),
  commission_total numeric(18,2),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists producers_tenant_idx on public.producers(tenant_id);
alter table public.producers enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='producers' and policyname='producers_read_authenticated'
  ) then
    create policy producers_read_authenticated on public.producers for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producers to authenticated, anon;
-- EFFORTS (activities)
create table if not exists public.efforts (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  code text,
  description text,
  value int,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists efforts_tenant_idx on public.efforts(tenant_id);
alter table public.efforts enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='efforts' and policyname='efforts_read_authenticated'
  ) then
    create policy efforts_read_authenticated on public.efforts for select to authenticated using (true);
  end if;
end $$;
grant select on table public.efforts to authenticated, anon;

-- ACTIVITIES SUMMARY/LEADERBOARD/OVERDUE
create table if not exists public.activities_leaderboard (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  employee_name text,
  total_work_efforts int,
  clients_with_efforts int,
  overdue_activities int,
  scope text
);
create index if not exists activities_leaderboard_tenant_idx on public.activities_leaderboard(tenant_id);
alter table public.activities_leaderboard enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='activities_leaderboard' and policyname='activities_leaderboard_read') then
    create policy activities_leaderboard_read on public.activities_leaderboard for select to authenticated using (true);
  end if;
end $$;
grant select on table public.activities_leaderboard to authenticated, anon;

create table if not exists public.activities_summary (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  period_start date,
  period_end date,
  total_work_efforts int,
  clients_with_efforts int,
  avg_efforts_per_client numeric(10,1),
  overdue_activities int,
  productivity_change_pct numeric(10,1)
);
create index if not exists activities_summary_tenant_idx on public.activities_summary(tenant_id);
alter table public.activities_summary enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='activities_summary' and policyname='activities_summary_read') then
    create policy activities_summary_read on public.activities_summary for select to authenticated using (true);
  end if;
end $$;
grant select on table public.activities_summary to authenticated, anon;

create table if not exists public.overdue_activities (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  bucket text,
  count int,
  percentage numeric(10,1)
);
create index if not exists overdue_activities_tenant_idx on public.overdue_activities(tenant_id);
alter table public.overdue_activities enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='overdue_activities' and policyname='overdue_activities_read') then
    create policy overdue_activities_read on public.overdue_activities for select to authenticated using (true);
  end if;
end $$;
grant select on table public.overdue_activities to authenticated, anon;

-- RETENTION SUMMARY
create table if not exists public.retention_summary (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  period_start date,
  period_end date,
  policies_retention_pct numeric(6,2),
  accounts_retention_pct numeric(6,2),
  premium_retention_pct numeric(6,2),
  revenue_retention_pct numeric(6,2),
  prior_policies int,
  current_policies int,
  prior_accounts int,
  current_accounts int,
  prior_premium numeric(18,2),
  current_premium numeric(18,2),
  prior_revenue numeric(18,2),
  current_revenue numeric(18,2),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists retention_summary_tenant_idx on public.retention_summary(tenant_id);
alter table public.retention_summary enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='retention_summary' and policyname='retention_summary_read_authenticated'
  ) then
    create policy retention_summary_read_authenticated on public.retention_summary for select to authenticated using (true);
  end if;
end $$;
grant select on table public.retention_summary to authenticated, anon;

-- RETENTION INSIGHTS
create table if not exists public.retention_insights (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  category text,
  name text,
  retention_pct numeric(6,2),
  from_count int,
  to_count int,
  delta int,
  view_by text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists retention_insights_tenant_idx on public.retention_insights(tenant_id);
alter table public.retention_insights enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='retention_insights' and policyname='retention_insights_read_authenticated'
  ) then
    create policy retention_insights_read_authenticated on public.retention_insights for select to authenticated using (true);
  end if;
end $$;
grant select on table public.retention_insights to authenticated, anon;

-- RENEWALS PRODUCTS (summary by product)
create table if not exists public.renewals_products (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  product text,
  placement text,
  premium_billed numeric(18,2),
  revenue_billed numeric(18,2),
  premium_ennabl numeric(18,2),
  revenue_ennabl numeric(18,2),
  producer text,
  account_manager text,
  market text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists renewals_products_tenant_idx on public.renewals_products(tenant_id);
alter table public.renewals_products enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='renewals_products' and policyname='renewals_products_read_authenticated'
  ) then
    create policy renewals_products_read_authenticated on public.renewals_products for select to authenticated using (true);
  end if;
end $$;
grant select on table public.renewals_products to authenticated, anon;

-- AE ANALYTICS TABLES
create table if not exists public.ae_avg_account_size (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_executive_id bigint references public.account_executives(id) on delete cascade,
  band text,
  accounts_count int,
  premium_total numeric(18,2)
);
create index if not exists ae_avg_account_size_tenant_idx on public.ae_avg_account_size(tenant_id);
alter table public.ae_avg_account_size enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ae_avg_account_size' and policyname='ae_avg_account_size_read') then
    create policy ae_avg_account_size_read on public.ae_avg_account_size for select to authenticated using (true);
  end if;
end $$;
grant select on table public.ae_avg_account_size to authenticated, anon;

create table if not exists public.ae_avg_products (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_executive_id bigint references public.account_executives(id) on delete cascade,
  product_name text,
  avg_products numeric(10,1)
);
create index if not exists ae_avg_products_tenant_idx on public.ae_avg_products(tenant_id);
alter table public.ae_avg_products enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ae_avg_products' and policyname='ae_avg_products_read') then
    create policy ae_avg_products_read on public.ae_avg_products for select to authenticated using (true);
  end if;
end $$;
grant select on table public.ae_avg_products to authenticated, anon;

create table if not exists public.ae_by_industry (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_executive_id bigint references public.account_executives(id) on delete cascade,
  industry text,
  premium numeric(18,2),
  accounts_count int
);
create index if not exists ae_by_industry_tenant_idx on public.ae_by_industry(tenant_id);
alter table public.ae_by_industry enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ae_by_industry' and policyname='ae_by_industry_read') then
    create policy ae_by_industry_read on public.ae_by_industry for select to authenticated using (true);
  end if;
end $$;
grant select on table public.ae_by_industry to authenticated, anon;

create table if not exists public.ae_by_product (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_executive_id bigint references public.account_executives(id) on delete cascade,
  product text,
  premium numeric(18,2),
  accounts_count int
);
create index if not exists ae_by_product_tenant_idx on public.ae_by_product(tenant_id);
alter table public.ae_by_product enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ae_by_product' and policyname='ae_by_product_read') then
    create policy ae_by_product_read on public.ae_by_product for select to authenticated using (true);
  end if;
end $$;
grant select on table public.ae_by_product to authenticated, anon;

create table if not exists public.ae_commissions (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_executive_id bigint references public.account_executives(id) on delete cascade,
  product text,
  commission numeric(18,2),
  premium numeric(18,2)
);
create index if not exists ae_commissions_tenant_idx on public.ae_commissions(tenant_id);
alter table public.ae_commissions enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ae_commissions' and policyname='ae_commissions_read') then
    create policy ae_commissions_read on public.ae_commissions for select to authenticated using (true);
  end if;
end $$;
grant select on table public.ae_commissions to authenticated, anon;

create table if not exists public.ae_growth (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_executive_id bigint references public.account_executives(id) on delete cascade,
  premium_total numeric(18,2),
  revenue_total numeric(18,2),
  accounts_count int,
  policies_count int,
  growth_rate numeric(10,2),
  snapshot_date date
);
create index if not exists ae_growth_tenant_idx on public.ae_growth(tenant_id);
alter table public.ae_growth enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ae_growth' and policyname='ae_growth_read') then
    create policy ae_growth_read on public.ae_growth for select to authenticated using (true);
  end if;
end $$;
grant select on table public.ae_growth to authenticated, anon;

create table if not exists public.ae_leaderboard (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_executive_id bigint references public.account_executives(id) on delete cascade,
  metric text,
  rank int,
  value numeric(18,2)
);
create index if not exists ae_leaderboard_tenant_idx on public.ae_leaderboard(tenant_id);
alter table public.ae_leaderboard enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ae_leaderboard' and policyname='ae_leaderboard_read') then
    create policy ae_leaderboard_read on public.ae_leaderboard for select to authenticated using (true);
  end if;
end $$;
grant select on table public.ae_leaderboard to authenticated, anon;

create table if not exists public.ae_metrics (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_executive_id bigint references public.account_executives(id) on delete cascade,
  metric_name text,
  value int,
  period text
);
create index if not exists ae_metrics_tenant_idx on public.ae_metrics(tenant_id);
alter table public.ae_metrics enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ae_metrics' and policyname='ae_metrics_read') then
    create policy ae_metrics_read on public.ae_metrics for select to authenticated using (true);
  end if;
end $$;
grant select on table public.ae_metrics to authenticated, anon;

create table if not exists public.ae_policies (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_executive_id bigint references public.account_executives(id) on delete cascade,
  policy_type text,
  premium numeric(18,2),
  status text
);
create index if not exists ae_policies_tenant_idx on public.ae_policies(tenant_id);
alter table public.ae_policies enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='ae_policies' and policyname='ae_policies_read') then
    create policy ae_policies_read on public.ae_policies for select to authenticated using (true);
  end if;
end $$;
grant select on table public.ae_policies to authenticated, anon;

-- ACCOUNT MANAGER ANALYTICS TABLES
create table if not exists public.am_account_size (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_manager_id bigint references public.account_managers(id) on delete cascade,
  band text,
  accounts_count int,
  premium_total numeric(18,2)
);
create index if not exists am_account_size_tenant_idx on public.am_account_size(tenant_id);
alter table public.am_account_size enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_account_size' and policyname='am_account_size_read') then
    create policy am_account_size_read on public.am_account_size for select to authenticated using (true);
  end if;
end $$;
grant select on table public.am_account_size to authenticated, anon;

create table if not exists public.am_by_carrier (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_manager_id bigint references public.account_managers(id) on delete cascade,
  carrier text,
  premium numeric(18,2),
  accounts_count int
);
create index if not exists am_by_carrier_tenant_idx on public.am_by_carrier(tenant_id);
alter table public.am_by_carrier enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_by_carrier' and policyname='am_by_carrier_read') then
    create policy am_by_carrier_read on public.am_by_carrier for select to authenticated using (true);
  end if;
end $$;
grant select on table public.am_by_carrier to authenticated, anon;

create table if not exists public.am_by_industry (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_manager_id bigint references public.account_managers(id) on delete cascade,
  industry text,
  premium numeric(18,2),
  accounts_count int
);
create index if not exists am_by_industry_tenant_idx on public.am_by_industry(tenant_id);
alter table public.am_by_industry enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_by_industry' and policyname='am_by_industry_read') then
    create policy am_by_industry_read on public.am_by_industry for select to authenticated using (true);
  end if;
end $$;
grant select on table public.am_by_industry to authenticated, anon;

create table if not exists public.am_by_product (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_manager_id bigint references public.account_managers(id) on delete cascade,
  product text,
  premium numeric(18,2),
  accounts_count int
);
create index if not exists am_by_product_tenant_idx on public.am_by_product(tenant_id);
alter table public.am_by_product enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_by_product' and policyname='am_by_product_read') then
    create policy am_by_product_read on public.am_by_product for select to authenticated using (true);
  end if;
end $$;
grant select on table public.am_by_product to authenticated, anon;

create table if not exists public.am_growth (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_manager_id bigint references public.account_managers(id) on delete cascade,
  premium_total numeric(18,2),
  revenue_total numeric(18,2),
  accounts_count int,
  policies_count int,
  growth_rate numeric(10,2),
  snapshot_date date
);
create index if not exists am_growth_tenant_idx on public.am_growth(tenant_id);
alter table public.am_growth enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_growth' and policyname='am_growth_read') then
    create policy am_growth_read on public.am_growth for select to authenticated using (true);
  end if;
end $$;
grant select on table public.am_growth to authenticated, anon;

create table if not exists public.am_leaderboard (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_manager_id bigint references public.account_managers(id) on delete cascade,
  metric text,
  rank int,
  value numeric(18,2)
);
create index if not exists am_leaderboard_tenant_idx on public.am_leaderboard(tenant_id);
alter table public.am_leaderboard enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_leaderboard' and policyname='am_leaderboard_read') then
    create policy am_leaderboard_read on public.am_leaderboard for select to authenticated using (true);
  end if;
end $$;
grant select on table public.am_leaderboard to authenticated, anon;

create table if not exists public.am_metrics (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_manager_id bigint references public.account_managers(id) on delete cascade,
  metric_name text,
  value int,
  period text
);
create index if not exists am_metrics_tenant_idx on public.am_metrics(tenant_id);
alter table public.am_metrics enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_metrics' and policyname='am_metrics_read') then
    create policy am_metrics_read on public.am_metrics for select to authenticated using (true);
  end if;
end $$;
grant select on table public.am_metrics to authenticated, anon;

create table if not exists public.am_producers (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_manager_id bigint references public.account_managers(id) on delete cascade,
  producer_name text,
  premium_total numeric(18,2),
  policies_count int
);
create index if not exists am_producers_tenant_idx on public.am_producers(tenant_id);
alter table public.am_producers enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_producers' and policyname='am_producers_read') then
    create policy am_producers_read on public.am_producers for select to authenticated using (true);
  end if;
end $$;
grant select on table public.am_producers to authenticated, anon;

create table if not exists public.am_upcoming_renewals (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_manager_id bigint references public.account_managers(id) on delete cascade,
  renewal_month text,
  policies_count int,
  premium_total numeric(18,2)
);
create index if not exists am_upcoming_renewals_tenant_idx on public.am_upcoming_renewals(tenant_id);
alter table public.am_upcoming_renewals enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='am_upcoming_renewals' and policyname='am_upcoming_renewals_read') then
    create policy am_upcoming_renewals_read on public.am_upcoming_renewals for select to authenticated using (true);
  end if;
end $$;
grant select on table public.am_upcoming_renewals to authenticated, anon;

-- PRODUCER ANALYTICS TABLES
create table if not exists public.producer_avg_account_size (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  producer_id bigint references public.producers(id) on delete cascade,
  band text,
  accounts_count int,
  premium_total numeric(18,2)
);
create index if not exists producer_avg_account_size_tenant_idx on public.producer_avg_account_size(tenant_id);
alter table public.producer_avg_account_size enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='producer_avg_account_size' and policyname='producer_avg_account_size_read') then
    create policy producer_avg_account_size_read on public.producer_avg_account_size for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producer_avg_account_size to authenticated, anon;

create table if not exists public.producer_avg_products (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  producer_id bigint references public.producers(id) on delete cascade,
  product_name text,
  avg_products numeric(10,1)
);
create index if not exists producer_avg_products_tenant_idx on public.producer_avg_products(tenant_id);
alter table public.producer_avg_products enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='producer_avg_products' and policyname='producer_avg_products_read') then
    create policy producer_avg_products_read on public.producer_avg_products for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producer_avg_products to authenticated, anon;

create table if not exists public.producer_by_industry (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  producer_id bigint references public.producers(id) on delete cascade,
  industry text,
  premium numeric(18,2),
  accounts_count int
);
create index if not exists producer_by_industry_tenant_idx on public.producer_by_industry(tenant_id);
alter table public.producer_by_industry enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='producer_by_industry' and policyname='producer_by_industry_read') then
    create policy producer_by_industry_read on public.producer_by_industry for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producer_by_industry to authenticated, anon;

create table if not exists public.producer_by_product (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  producer_id bigint references public.producers(id) on delete cascade,
  product text,
  premium numeric(18,2),
  accounts_count int
);
create index if not exists producer_by_product_tenant_idx on public.producer_by_product(tenant_id);
alter table public.producer_by_product enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='producer_by_product' and policyname='producer_by_product_read') then
    create policy producer_by_product_read on public.producer_by_product for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producer_by_product to authenticated, anon;

create table if not exists public.producer_commissions (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  producer_id bigint references public.producers(id) on delete cascade,
  product text,
  commission numeric(18,2),
  premium numeric(18,2)
);
create index if not exists producer_commissions_tenant_idx on public.producer_commissions(tenant_id);
alter table public.producer_commissions enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='producer_commissions' and policyname='producer_commissions_read') then
    create policy producer_commissions_read on public.producer_commissions for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producer_commissions to authenticated, anon;

create table if not exists public.producer_growth (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  producer_id bigint references public.producers(id) on delete cascade,
  premium_total numeric(18,2),
  revenue_total numeric(18,2),
  accounts_count int,
  policies_count int,
  growth_rate numeric(10,2),
  snapshot_date date
);
create index if not exists producer_growth_tenant_idx on public.producer_growth(tenant_id);
alter table public.producer_growth enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='producer_growth' and policyname='producer_growth_read') then
    create policy producer_growth_read on public.producer_growth for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producer_growth to authenticated, anon;

create table if not exists public.producer_leaderboard (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  producer_id bigint references public.producers(id) on delete cascade,
  metric text,
  rank int,
  value numeric(18,2)
);
create index if not exists producer_leaderboard_tenant_idx on public.producer_leaderboard(tenant_id);
alter table public.producer_leaderboard enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='producer_leaderboard' and policyname='producer_leaderboard_read') then
    create policy producer_leaderboard_read on public.producer_leaderboard for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producer_leaderboard to authenticated, anon;

create table if not exists public.producer_metrics (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  producer_id bigint references public.producers(id) on delete cascade,
  metric_name text,
  value int,
  period text
);
create index if not exists producer_metrics_tenant_idx on public.producer_metrics(tenant_id);
alter table public.producer_metrics enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='producer_metrics' and policyname='producer_metrics_read') then
    create policy producer_metrics_read on public.producer_metrics for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producer_metrics to authenticated, anon;

create table if not exists public.producer_opportunities (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  producer_id bigint references public.producers(id) on delete cascade,
  product text,
  opportunities_count int,
  premium numeric(18,2)
);
create index if not exists producer_opportunities_tenant_idx on public.producer_opportunities(tenant_id);
alter table public.producer_opportunities enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='producer_opportunities' and policyname='producer_opportunities_read') then
    create policy producer_opportunities_read on public.producer_opportunities for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producer_opportunities to authenticated, anon;

create table if not exists public.producer_policies (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  producer_id bigint references public.producers(id) on delete cascade,
  policy_type text,
  premium numeric(18,2),
  status text
);
create index if not exists producer_policies_tenant_idx on public.producer_policies(tenant_id);
alter table public.producer_policies enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='producer_policies' and policyname='producer_policies_read') then
    create policy producer_policies_read on public.producer_policies for select to authenticated using (true);
  end if;
end $$;
grant select on table public.producer_policies to authenticated, anon;

-- INDUSTRY ANALYTICS TABLES
create table if not exists public.avg_account_size (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  industry_id bigint references public.industries(id) on delete cascade,
  band text,
  accounts_count int,
  premium_total numeric(18,2)
);
create index if not exists avg_account_size_tenant_idx on public.avg_account_size(tenant_id);
alter table public.avg_account_size enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='avg_account_size' and policyname='avg_account_size_read') then
    create policy avg_account_size_read on public.avg_account_size for select to authenticated using (true);
  end if;
end $$;
grant select on table public.avg_account_size to authenticated, anon;

create table if not exists public.avg_products_per_account (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  industry_id bigint references public.industries(id) on delete cascade,
  product_name text,
  avg_products numeric(10,1)
);
create index if not exists avg_products_per_account_tenant_idx on public.avg_products_per_account(tenant_id);
alter table public.avg_products_per_account enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='avg_products_per_account' and policyname='avg_products_per_account_read') then
    create policy avg_products_per_account_read on public.avg_products_per_account for select to authenticated using (true);
  end if;
end $$;
grant select on table public.avg_products_per_account to authenticated, anon;

create table if not exists public.industry_accounts (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  industry_id bigint references public.industries(id) on delete cascade,
  account_name text,
  active_policies int,
  lost_policies int,
  premium numeric(18,2),
  revenue numeric(18,2)
);
create index if not exists industry_accounts_tenant_idx on public.industry_accounts(tenant_id);
alter table public.industry_accounts enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='industry_accounts' and policyname='industry_accounts_read') then
    create policy industry_accounts_read on public.industry_accounts for select to authenticated using (true);
  end if;
end $$;
grant select on table public.industry_accounts to authenticated, anon;

create table if not exists public.industry_by_carrier (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  industry_id bigint references public.industries(id) on delete cascade,
  carrier text,
  accounts_count int,
  premium numeric(18,2)
);
create index if not exists industry_by_carrier_tenant_idx on public.industry_by_carrier(tenant_id);
alter table public.industry_by_carrier enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='industry_by_carrier' and policyname='industry_by_carrier_read') then
    create policy industry_by_carrier_read on public.industry_by_carrier for select to authenticated using (true);
  end if;
end $$;
grant select on table public.industry_by_carrier to authenticated, anon;

create table if not exists public.industry_by_product (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  industry_id bigint references public.industries(id) on delete cascade,
  product text,
  accounts_count int,
  premium numeric(18,2)
);
create index if not exists industry_by_product_tenant_idx on public.industry_by_product(tenant_id);
alter table public.industry_by_product enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='industry_by_product' and policyname='industry_by_product_read') then
    create policy industry_by_product_read on public.industry_by_product for select to authenticated using (true);
  end if;
end $$;
grant select on table public.industry_by_product to authenticated, anon;

create table if not exists public.industry_commissions (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  industry_id bigint references public.industries(id) on delete cascade,
  product text,
  commission numeric(18,2),
  premium numeric(18,2),
  sort_by text
);
create index if not exists industry_commissions_tenant_idx on public.industry_commissions(tenant_id);
alter table public.industry_commissions enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='industry_commissions' and policyname='industry_commissions_read') then
    create policy industry_commissions_read on public.industry_commissions for select to authenticated using (true);
  end if;
end $$;
grant select on table public.industry_commissions to authenticated, anon;

create table if not exists public.industry_growth (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  industry_id bigint references public.industries(id) on delete cascade,
  premium_total numeric(18,2),
  revenue_total numeric(18,2),
  policies_count int,
  accounts_count int,
  growth_rate numeric(10,2),
  snapshot_date date
);
create index if not exists industry_growth_tenant_idx on public.industry_growth(tenant_id);
alter table public.industry_growth enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='industry_growth' and policyname='industry_growth_read') then
    create policy industry_growth_read on public.industry_growth for select to authenticated using (true);
  end if;
end $$;
grant select on table public.industry_growth to authenticated, anon;

create table if not exists public.industry_leaderboard (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  industry_id bigint references public.industries(id) on delete cascade,
  account_name text,
  premium numeric(18,2),
  rank int
);
create index if not exists industry_leaderboard_tenant_idx on public.industry_leaderboard(tenant_id);
alter table public.industry_leaderboard enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='industry_leaderboard' and policyname='industry_leaderboard_read') then
    create policy industry_leaderboard_read on public.industry_leaderboard for select to authenticated using (true);
  end if;
end $$;
grant select on table public.industry_leaderboard to authenticated, anon;

create table if not exists public.industry_opportunities (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  industry_id bigint references public.industries(id) on delete cascade,
  product text,
  opportunities_count int,
  premium numeric(18,2)
);
create index if not exists industry_opportunities_tenant_idx on public.industry_opportunities(tenant_id);
alter table public.industry_opportunities enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='industry_opportunities' and policyname='industry_opportunities_read') then
    create policy industry_opportunities_read on public.industry_opportunities for select to authenticated using (true);
  end if;
end $$;
grant select on table public.industry_opportunities to authenticated, anon;

create table if not exists public.industry_policies (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  industry_id bigint references public.industries(id) on delete cascade,
  type text,
  premium numeric(18,2),
  revenue numeric(18,2),
  commission numeric(18,2),
  status text
);
create index if not exists industry_policies_tenant_idx on public.industry_policies(tenant_id);
alter table public.industry_policies enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='industry_policies' and policyname='industry_policies_read') then
    create policy industry_policies_read on public.industry_policies for select to authenticated using (true);
  end if;
end $$;
grant select on table public.industry_policies to authenticated, anon;

-- MARKETS ANALYTICS TABLES
create table if not exists public.conversions (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  market_id bigint references public.markets(id) on delete cascade,
  account_name text,
  product text,
  conversion_rate numeric(10,2),
  premium numeric(18,2)
);
create index if not exists conversions_tenant_idx on public.conversions(tenant_id);
alter table public.conversions enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='conversions' and policyname='conversions_read') then
    create policy conversions_read on public.conversions for select to authenticated using (true);
  end if;
end $$;
grant select on table public.conversions to authenticated, anon;

create table if not exists public.growth (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  market_id bigint references public.markets(id) on delete cascade,
  premium_total numeric(18,2),
  revenue_total numeric(18,2),
  policies_count int,
  accounts_count int,
  growth_rate numeric(10,2),
  snapshot_date date
);
create index if not exists growth_tenant_idx on public.growth(tenant_id);
alter table public.growth enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='growth' and policyname='growth_read') then
    create policy growth_read on public.growth for select to authenticated using (true);
  end if;
end $$;
grant select on table public.growth to authenticated, anon;

create table if not exists public.leaderboard (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  market_id bigint references public.markets(id) on delete cascade,
  account_name text,
  premium numeric(18,2),
  rank int
);
create index if not exists leaderboard_tenant_idx on public.leaderboard(tenant_id);
alter table public.leaderboard enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='leaderboard' and policyname='leaderboard_read') then
    create policy leaderboard_read on public.leaderboard for select to authenticated using (true);
  end if;
end $$;
grant select on table public.leaderboard to authenticated, anon;

create table if not exists public.markets_by_industry (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  market_id bigint references public.markets(id) on delete cascade,
  industry text,
  accounts_count int,
  premium numeric(18,2)
);
create index if not exists markets_by_industry_tenant_idx on public.markets_by_industry(tenant_id);
alter table public.markets_by_industry enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='markets_by_industry' and policyname='markets_by_industry_read') then
    create policy markets_by_industry_read on public.markets_by_industry for select to authenticated using (true);
  end if;
end $$;
grant select on table public.markets_by_industry to authenticated, anon;

create table if not exists public.markets_by_product (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  market_id bigint references public.markets(id) on delete cascade,
  product text,
  accounts_count int,
  premium numeric(18,2)
);
create index if not exists markets_by_product_tenant_idx on public.markets_by_product(tenant_id);
alter table public.markets_by_product enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='markets_by_product' and policyname='markets_by_product_read') then
    create policy markets_by_product_read on public.markets_by_product for select to authenticated using (true);
  end if;
end $$;
grant select on table public.markets_by_product to authenticated, anon;

create table if not exists public.premium_flow (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  market_id bigint references public.markets(id) on delete cascade,
  "from" text,
  "to" text,
  value numeric(18,2)
);
create index if not exists premium_flow_tenant_idx on public.premium_flow(tenant_id);
alter table public.premium_flow enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='premium_flow' and policyname='premium_flow_read') then
    create policy premium_flow_read on public.premium_flow for select to authenticated using (true);
  end if;
end $$;
grant select on table public.premium_flow to authenticated, anon;

create table if not exists public.premium_outflow (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  market_id bigint references public.markets(id) on delete cascade,
  carrier text,
  premium numeric(18,2),
  outflow numeric(18,2),
  inflow numeric(18,2)
);
create index if not exists premium_outflow_tenant_idx on public.premium_outflow(tenant_id);
alter table public.premium_outflow enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='premium_outflow' and policyname='premium_outflow_read') then
    create policy premium_outflow_read on public.premium_outflow for select to authenticated using (true);
  end if;
end $$;
grant select on table public.premium_outflow to authenticated, anon;

create table if not exists public.premium_size (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  market_id bigint references public.markets(id) on delete cascade,
  size_band text,
  accounts_count int,
  premium_total numeric(18,2)
);
create index if not exists premium_size_tenant_idx on public.premium_size(tenant_id);
alter table public.premium_size enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='premium_size' and policyname='premium_size_read') then
    create policy premium_size_read on public.premium_size for select to authenticated using (true);
  end if;
end $$;
grant select on table public.premium_size to authenticated, anon;

create table if not exists public.rankings (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  market_id bigint references public.markets(id) on delete cascade,
  source text,
  rank int,
  accounts_count int,
  premium_total numeric(18,2)
);
create index if not exists rankings_tenant_idx on public.rankings(tenant_id);
alter table public.rankings enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='rankings' and policyname='rankings_read') then
    create policy rankings_read on public.rankings for select to authenticated using (true);
  end if;
end $$;
grant select on table public.rankings to authenticated, anon;

-- ACCOUNTS DETAIL TABLES
create table if not exists public.accounts_contacts (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_id bigint references public.accounts(id) on delete cascade,
  scope text,
  name text,
  email text,
  phone text
);
create index if not exists accounts_contacts_tenant_idx on public.accounts_contacts(tenant_id);
alter table public.accounts_contacts enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='accounts_contacts' and policyname='accounts_contacts_read') then
    create policy accounts_contacts_read on public.accounts_contacts for select to authenticated using (true);
  end if;
end $$;
grant select on table public.accounts_contacts to authenticated, anon;

create table if not exists public.accounts_executives (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_id bigint references public.accounts(id) on delete cascade,
  name text,
  title text,
  email text,
  phone text,
  source text
);
create index if not exists accounts_executives_tenant_idx on public.accounts_executives(tenant_id);
alter table public.accounts_executives enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='accounts_executives' and policyname='accounts_executives_read') then
    create policy accounts_executives_read on public.accounts_executives for select to authenticated using (true);
  end if;
end $$;
grant select on table public.accounts_executives to authenticated, anon;

create table if not exists public.accounts_activities (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_id bigint references public.accounts(id) on delete cascade,
  policy_id bigint references public.policies(id) on delete set null,
  action text,
  code text,
  created_by text,
  created_at date
);
create index if not exists accounts_activities_tenant_idx on public.accounts_activities(tenant_id);
alter table public.accounts_activities enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='accounts_activities' and policyname='accounts_activities_read') then
    create policy accounts_activities_read on public.accounts_activities for select to authenticated using (true);
  end if;
end $$;
grant select on table public.accounts_activities to authenticated, anon;

create table if not exists public.accounts_alerts (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_id bigint references public.accounts(id) on delete cascade,
  category text,
  title text,
  description text,
  level text,
  created_at date
);
create index if not exists accounts_alerts_tenant_idx on public.accounts_alerts(tenant_id);
alter table public.accounts_alerts enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='accounts_alerts' and policyname='accounts_alerts_read') then
    create policy accounts_alerts_read on public.accounts_alerts for select to authenticated using (true);
  end if;
end $$;
grant select on table public.accounts_alerts to authenticated, anon;

create table if not exists public.accounts_forms_5500 (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_id bigint references public.accounts(id) on delete cascade,
  plan_name text,
  participants int,
  received_date date,
  filing_year int,
  download_url text
);
create index if not exists accounts_forms_5500_tenant_idx on public.accounts_forms_5500(tenant_id);
alter table public.accounts_forms_5500 enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='accounts_forms_5500' and policyname='accounts_forms_5500_read') then
    create policy accounts_forms_5500_read on public.accounts_forms_5500 for select to authenticated using (true);
  end if;
end $$;
grant select on table public.accounts_forms_5500 to authenticated, anon;

create table if not exists public.accounts_opportunities (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_id bigint references public.accounts(id) on delete cascade,
  product text,
  purchase_likelihood_pct int,
  suggestion text
);
create index if not exists accounts_opportunities_tenant_idx on public.accounts_opportunities(tenant_id);
alter table public.accounts_opportunities enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='accounts_opportunities' and policyname='accounts_opportunities_read') then
    create policy accounts_opportunities_read on public.accounts_opportunities for select to authenticated using (true);
  end if;
end $$;
grant select on table public.accounts_opportunities to authenticated, anon;

create table if not exists public.accounts_policies (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_id bigint references public.accounts(id) on delete cascade,
  type text,
  carrier text,
  product text,
  effective_date date,
  expiration_date date,
  renewal_date date,
  status text,
  premium numeric(18,2),
  revenue numeric(18,2),
  commission numeric(18,2),
  market text,
  pay_to text
);
create index if not exists accounts_policies_tenant_idx on public.accounts_policies(tenant_id);
alter table public.accounts_policies enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='accounts_policies' and policyname='accounts_policies_read') then
    create policy accounts_policies_read on public.accounts_policies for select to authenticated using (true);
  end if;
end $$;
grant select on table public.accounts_policies to authenticated, anon;

create table if not exists public.accounts_renewals (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  policy_id bigint references public.policies(id) on delete set null,
  account_id bigint references public.accounts(id) on delete cascade,
  renewal_date date,
  window_bucket text,
  status text
);
create index if not exists accounts_renewals_tenant_idx on public.accounts_renewals(tenant_id);
alter table public.accounts_renewals enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='accounts_renewals' and policyname='accounts_renewals_read') then
    create policy accounts_renewals_read on public.accounts_renewals for select to authenticated using (true);
  end if;
end $$;
grant select on table public.accounts_renewals to authenticated, anon;

create table if not exists public.accounts_source_unification (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_id bigint references public.accounts(id) on delete cascade,
  system text,
  account_name text,
  account_id_external int
);
create index if not exists accounts_source_unification_tenant_idx on public.accounts_source_unification(tenant_id);
alter table public.accounts_source_unification enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='accounts_source_unification' and policyname='accounts_source_unification_read') then
    create policy accounts_source_unification_read on public.accounts_source_unification for select to authenticated using (true);
  end if;
end $$;
grant select on table public.accounts_source_unification to authenticated, anon;

create table if not exists public.accounts_account_kpis (
  id bigint primary key generated always as identity,
  tenant_id text not null,
  account_id bigint references public.accounts(id) on delete cascade,
  policies_count int,
  premium_total numeric(18,2),
  revenue_total numeric(18,2),
  lifetime_value numeric(18,2),
  markets int,
  snapshot_date date
);
create index if not exists accounts_account_kpis_tenant_idx on public.accounts_account_kpis(tenant_id);
alter table public.accounts_account_kpis enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='accounts_account_kpis' and policyname='accounts_account_kpis_read') then
    create policy accounts_account_kpis_read on public.accounts_account_kpis for select to authenticated using (true);
  end if;
end $$;
grant select on table public.accounts_account_kpis to authenticated, anon;
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_schema='public' and table_name='policies' and constraint_name='policies_account_lookup_fkey'
  ) then
    alter table public.policies
      add constraint policies_account_lookup_fkey
      foreign key (account_lookup_id) references public.clients(id) on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where table_schema='public' and table_name='renewals' and constraint_name='renewals_policy_fkey'
  ) then
    alter table public.renewals
      add constraint renewals_policy_fkey
      foreign key (policy_id) references public.policies(id) on delete set null;
  end if;
end $$;

create policy if not exists clients_insert_anon on public.clients for insert to anon with check (true);
create policy if not exists policies_insert_anon on public.policies for insert to anon with check (true);
create policy if not exists renewals_insert_anon on public.renewals for insert to anon with check (true);


