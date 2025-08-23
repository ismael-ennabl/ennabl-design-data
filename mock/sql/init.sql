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


