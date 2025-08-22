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


