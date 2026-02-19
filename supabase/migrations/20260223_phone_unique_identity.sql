-- Enforce phone number uniqueness across accounts (normalized digits-only comparison).

-- Optional hygiene: trim phone whitespace.
update public.user_profiles
set phone = trim(phone)
where phone is not null;

-- Enforce one account per normalized phone.
-- If this fails due to existing duplicates, resolve duplicate rows first, then re-run migration.
create unique index if not exists user_profiles_phone_unique_norm_idx
  on public.user_profiles (public.normalize_phone(phone));
