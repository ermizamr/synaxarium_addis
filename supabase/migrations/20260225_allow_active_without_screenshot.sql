-- Allow active subscribed users to keep access even if screenshot rows are deleted after approval.
-- Screenshot approval remains required only before subscription activation.

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
begin
  if auth.uid() is distinct from p_user_id then
    return jsonb_build_object('allowed', false, 'reason', 'unauthorized');
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

  if device_count >= max_devices then
    return jsonb_build_object('allowed', false, 'reason', 'device_limit_reached');
  end if;

  insert into public.devices (user_id, device_id, status, device_info, updated_at)
  values (p_user_id, p_device_id, 'active', p_device_info, now())
  on conflict (device_id) do update
    set status = 'active',
        device_info = excluded.device_info,
        updated_at = now();

  return jsonb_build_object('allowed', true, 'reason', 'ok');
end;
$$;

revoke all on function public.allow_device_login(uuid, text, jsonb) from public;
grant execute on function public.allow_device_login(uuid, text, jsonb) to authenticated;
