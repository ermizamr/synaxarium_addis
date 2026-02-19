-- Make submissions the source for profile fields and provide phone identity lookup.

-- Normalize phone helper (digits only)
create or replace function public.normalize_phone(p_phone text)
returns text
language sql
immutable
as $$
  select regexp_replace(coalesce(p_phone, ''), '\\D', '', 'g');
$$;

-- Lookup user by phone (security definer so mobile app can check cross-user uniqueness)
create or replace function public.get_user_id_by_phone(p_phone text)
returns uuid
language sql
security definer
set search_path = public
as $$
  select up.user_id
  from public.user_profiles up
  where public.normalize_phone(up.phone) = public.normalize_phone(p_phone)
  order by up.created_at asc
  limit 1;
$$;

revoke all on function public.get_user_id_by_phone(text) from public;
grant execute on function public.get_user_id_by_phone(text) to authenticated;

-- Keep user_profiles in sync from submissions (submission is source of truth for intake fields)
create or replace function public.sync_user_profile_from_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_profiles (user_id, name, phone, tier, promo_code)
  values (new.user_id, new.name, new.phone, new.tier, new.promo_code)
  on conflict (user_id) do update
  set
    name = excluded.name,
    phone = excluded.phone,
    tier = excluded.tier,
    promo_code = excluded.promo_code;

  return new;
end;
$$;

drop trigger if exists trg_sync_user_profile_from_submission on public.submissions;
create trigger trg_sync_user_profile_from_submission
after insert or update on public.submissions
for each row
execute function public.sync_user_profile_from_submission();
