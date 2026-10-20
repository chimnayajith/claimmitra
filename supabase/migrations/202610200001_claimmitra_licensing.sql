-- ClaimMitra licence records. Access is restricted to trusted Edge Functions.
create extension if not exists pgcrypto;

create table if not exists public.licenses (
  id uuid primary key default gen_random_uuid(),
  key_hash text not null unique,
  key_last4 text not null,
  customer_name text not null,
  customer_email text,
  status text not null default 'active' check (status in ('active', 'revoked')),
  machine_hash text,
  activated_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.licenses enable row level security;
-- Intentionally create no anon/authenticated policies. Only Edge Functions using
-- the service-role key may read or modify these records.
revoke all on table public.licenses from anon, authenticated;
