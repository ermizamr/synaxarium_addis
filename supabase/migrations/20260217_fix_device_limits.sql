-- Helper: max devices by tier from user_profiles.user_id (drop first to avoid arg-name conflict)
DROP FUNCTION IF EXISTS public.get_max_devices_for_user(uuid);
CREATE OR REPLACE FUNCTION public.get_max_devices_for_user(p_user_id uuid)
RETURNS int
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tier text;
BEGIN
  SELECT lower(coalesce(tier, '')) INTO v_tier
  FROM public.user_profiles
  WHERE user_id = p_user_id
  LIMIT 1;

  IF v_tier IN ('vip', 'familiar') THEN
    RETURN 2;
  ELSE
    RETURN 1; -- regular/normal/unknown
  END IF;
END;
$$;

-- RPC: enforce auth match, approved screenshot, active sub, per-tier device limit
CREATE OR REPLACE FUNCTION public.allow_device_login(
  p_user_id uuid,
  p_device_id text,
  p_device_info jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  has_approved boolean;
  sub_active boolean;
  device_count int;
  max_devices int := 1;
BEGIN
  -- Caller must match auth.uid
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'unauthorized');
  END IF;

  -- Approved screenshot required
  SELECT EXISTS (
    SELECT 1 FROM public.screenshots s
    WHERE s.user_id = p_user_id AND s.approved = true
  ) INTO has_approved;
  IF NOT has_approved THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'screenshot_not_approved');
  END IF;

  -- Active subscription required
  SELECT EXISTS (
    SELECT 1 FROM public.subscriptions sb
    WHERE sb.user_id = p_user_id
      AND sb.status = 'active'
      AND (sb.current_period_end IS NULL OR sb.current_period_end > now())
  ) INTO sub_active;
  IF NOT sub_active THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'no_active_subscription');
  END IF;

  -- Per-tier device limit
  SELECT public.get_max_devices_for_user(p_user_id) INTO max_devices;
  IF max_devices IS NULL OR max_devices < 1 THEN
    max_devices := 1;
  END IF;

  -- Blocked device check
  IF EXISTS (
    SELECT 1 FROM public.devices d
    WHERE d.user_id = p_user_id AND d.device_id = p_device_id AND d.status = 'blocked'
  ) THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'device_blocked');
  END IF;

  -- Count active devices
  SELECT count(*) INTO device_count
  FROM public.devices d
  WHERE d.user_id = p_user_id AND d.status = 'active';

  IF device_count >= max_devices THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'device_limit_reached');
  END IF;

  -- Upsert device
  INSERT INTO public.devices (user_id, device_id, status, device_info, updated_at)
  VALUES (p_user_id, p_device_id, 'active', p_device_info, now())
  ON CONFLICT (device_id) DO UPDATE
    SET status = 'active',
        device_info = excluded.device_info,
        updated_at = now();

  RETURN jsonb_build_object('allowed', true, 'reason', 'ok');
END;
$$;

-- Permissions
REVOKE ALL ON FUNCTION public.get_max_devices_for_user(uuid) FROM public;
REVOKE ALL ON FUNCTION public.allow_device_login(uuid, text, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.get_max_devices_for_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.allow_device_login(uuid, text, jsonb) TO authenticated;
