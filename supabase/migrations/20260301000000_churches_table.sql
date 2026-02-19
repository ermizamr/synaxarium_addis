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

drop policy if exists churches_authenticated_select on public.churches;
drop policy if exists churches_authenticated_insert on public.churches;
drop policy if exists churches_authenticated_update on public.churches;

create policy churches_authenticated_select
on public.churches
for select
to authenticated
using (true);

create policy churches_authenticated_insert
on public.churches
for insert
to authenticated
with check (true);

create policy churches_authenticated_update
on public.churches
for update
to authenticated
using (true)
with check (true);
