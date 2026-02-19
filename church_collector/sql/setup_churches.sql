-- Church Collector database setup
-- Run this in Supabase SQL Editor for project: https://qnypbqghgsqwfeytcmna.supabase.co

create extension if not exists pgcrypto;

create table if not exists public.churches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  latitude double precision not null,
  longitude double precision not null
);

create unique index if not exists churches_lat_lng_unique
  on public.churches (latitude, longitude);

alter table public.churches enable row level security;

-- Single-admin policy (replace with your exact admin email)
drop policy if exists churches_admin_select on public.churches;
drop policy if exists churches_admin_insert on public.churches;
drop policy if exists churches_admin_update on public.churches;

create policy churches_admin_select
on public.churches
for select
to authenticated
using ((auth.jwt()->>'email') = 'YOUR_ADMIN_EMAIL_HERE');

create policy churches_admin_insert
on public.churches
for insert
to authenticated
with check ((auth.jwt()->>'email') = 'YOUR_ADMIN_EMAIL_HERE');

create policy churches_admin_update
on public.churches
for update
to authenticated
using ((auth.jwt()->>'email') = 'YOUR_ADMIN_EMAIL_HERE')
with check ((auth.jwt()->>'email') = 'YOUR_ADMIN_EMAIL_HERE');
