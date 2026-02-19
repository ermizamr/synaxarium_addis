-- Reassert latest auth/access RPC logic after older migration reapplications.
-- Keeps active-account recovery independent of screenshot rows, and enforces phone-bound device login.

create or replace function public.claim_account_by_phone(
  p_phone text,
  p_device_id text,
  p_device_info jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_user_id uuid := auth.uid();
  v_old_user_id uuid;
  v_active_sub boolean;
  v_device_blocked boolean;
  v_device_exists boolean;
  v_active_count int := 0;
  v_max_devices int := 1;
begin
  if v_new_user_id is null then
    return jsonb_build_object('recovered', false, 'reason', 'unauthorized');
  end if;

  select up.user_id
    into v_old_user_id
  from public.user_profiles up
  where public.normalize_phone(up.phone) = public.normalize_phone(p_phone)
  order by up.created_at asc
  limit 1;

  if v_old_user_id is null then
    return jsonb_build_object('recovered', false, 'reason', 'not_found');
  end if;

  if v_old_user_id = v_new_user_id then
    return jsonb_build_object('recovered', true, 'reason', 'same_account');
  end if;

  select exists (
    select 1
    from public.subscriptions s
    where s.user_id = v_old_user_id
      and s.status = 'active'
      and (s.current_period_end is null or s.current_period_end > now())
  ) into v_active_sub;

  if not v_active_sub then
    return jsonb_build_object('recovered', false, 'reason', 'no_active_subscription');
  end if;

  select exists (
    select 1 from public.devices d
    where d.user_id = v_old_user_id and d.device_id = p_device_id and d.status = 'blocked'
  ) into v_device_blocked;

  if v_device_blocked then
    return jsonb_build_object('recovered', false, 'reason', 'device_blocked');
  end if;

  select exists (
    select 1 from public.devices d
    where d.user_id = v_old_user_id and d.device_id = p_device_id and d.status = 'active'
  ) into v_device_exists;

  select count(*)
    into v_active_count
  from public.devices d
  where d.user_id = v_old_user_id and d.status = 'active';

  select coalesce(public.get_max_devices_for_user(v_old_user_id), 1)
    into v_max_devices;

  if (not v_device_exists) and v_active_count >= v_max_devices then
    return jsonb_build_object('recovered', false, 'reason', 'device_limit_reached');
  end if;

  insert into public.users (id)
  values (v_new_user_id)
  on conflict (id) do nothing;

  update public.user_profiles set user_id = v_new_user_id where user_id = v_old_user_id;
  update public.submissions set user_id = v_new_user_id where user_id = v_old_user_id;
  update public.subscriptions set user_id = v_new_user_id where user_id = v_old_user_id;
  update public.screenshots set user_id = v_new_user_id where user_id = v_old_user_id;
  update public.devices set user_id = v_new_user_id where user_id = v_old_user_id;
  update public.payments set user_id = v_new_user_id where user_id = v_old_user_id;

  insert into public.devices (user_id, device_id, status, device_info, updated_at)
  values (v_new_user_id, p_device_id, 'active', coalesce(p_device_info, '{}'::jsonb), now())
  on conflict (user_id, device_id) do update
    set status = 'active',
        device_info = excluded.device_info,
        updated_at = now();

  delete from public.users where id = v_old_user_id;

  return jsonb_build_object('recovered', true, 'reason', 'ok', 'user_id', v_new_user_id);
end;
$$;

revoke all on function public.claim_account_by_phone(text, text, jsonb) from public;
grant execute on function public.claim_account_by_phone(text, text, jsonb) to authenticated;

create or replace function public.allow_device_login(
  p_user_id uuid,
  p_device_id text,
  p_device_info jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  has_approved boolean;
  sub_active boolean;
  device_count int;
  max_devices int := 1;
  provided_phone text;
  registered_phone text;
begin
  if auth.uid() is distinct from p_user_id then
    return jsonb_build_object('allowed', false, 'reason', 'unauthorized');
  end if;

  provided_phone := nullif(trim(coalesce(p_device_info->>'phone', '')), '');

  if provided_phone is null then
    return jsonb_build_object('allowed', false, 'reason', 'phone_required');
  end if;

  select coalesce(
    (
      select up.phone
      from public.user_profiles up
      where up.user_id = p_user_id
      limit 1
    ),
    (
      select s.phone
      from public.submissions s
      where s.user_id = p_user_id
      order by s.created_at desc
      limit 1
    )
  ) into registered_phone;

  if registered_phone is not null and
     public.normalize_phone(registered_phone) <> public.normalize_phone(provided_phone) then
    return jsonb_build_object('allowed', false, 'reason', 'phone_mismatch');
  end if;

  select exists (
    select 1 from public.subscriptions sb
    where sb.user_id = p_user_id
      and sb.status = 'active'
      and (sb.current_period_end is null or sb.current_period_end > now())
  ) into sub_active;

  select exists (
    select 1 from public.screenshots s
    where s.user_id = p_user_id and s.approved = true
  ) into has_approved;

  if not sub_active then
    if not has_approved then
      return jsonb_build_object('allowed', false, 'reason', 'screenshot_not_approved');
    end if;
    return jsonb_build_object('allowed', false, 'reason', 'no_active_subscription');
  end if;

  select public.get_max_devices_for_user(p_user_id) into max_devices;
  if max_devices is null or max_devices < 1 then
    max_devices := 1;
  end if;

  if exists (
    select 1 from public.devices d
    where d.user_id = p_user_id and d.device_id = p_device_id and d.status = 'blocked'
  ) then
    return jsonb_build_object('allowed', false, 'reason', 'device_blocked');
  end if;

  select count(*) into device_count
  from public.devices d
  where d.user_id = p_user_id and d.status = 'active';

  if device_count >= max_devices and not exists (
    select 1
    from public.devices d
    where d.user_id = p_user_id and d.device_id = p_device_id and d.status = 'active'
  ) then
    return jsonb_build_object('allowed', false, 'reason', 'device_limit_reached');
  end if;

  insert into public.devices (user_id, device_id, status, device_info, updated_at)
  values (p_user_id, p_device_id, 'active', p_device_info, now())
  on conflict (user_id, device_id) do update
    set status = 'active',
        device_info = excluded.device_info,
        updated_at = now();

  return jsonb_build_object('allowed', true, 'reason', 'ok');
end;
$$;

revoke all on function public.allow_device_login(uuid, text, jsonb) from public;
grant execute on function public.allow_device_login(uuid, text, jsonb) to authenticated;
