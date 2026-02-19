-- Screenshots bucket, table, RLS, and RPC update (idempotent)

-- Create storage bucket (private by default)
INSERT INTO storage.buckets (id, name, public)
VALUES ('screenshots', 'screenshots', false)
ON CONFLICT (id) DO NOTHING;

-- Table for screenshot metadata
CREATE TABLE IF NOT EXISTS public.screenshots (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    file_path   text NOT NULL,
    approved    boolean NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.screenshots ENABLE ROW LEVEL SECURITY;

-- Policies for screenshots table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'screenshots' AND policyname = 'Screenshots owner insert'
    ) THEN
        CREATE POLICY "Screenshots owner insert" ON public.screenshots
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'screenshots' AND policyname = 'Screenshots owner select'
    ) THEN
        CREATE POLICY "Screenshots owner select" ON public.screenshots
            FOR SELECT USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'screenshots' AND policyname = 'Screenshots admin approve'
    ) THEN
        CREATE POLICY "Screenshots admin approve" ON public.screenshots
            FOR UPDATE USING (auth.role() = 'service_role')
            WITH CHECK (auth.role() = 'service_role');
    END IF;
END $$;

-- Update RPC to require an approved screenshot
CREATE OR REPLACE FUNCTION public.allow_device_login(
    p_user_id uuid,
    p_device_id text,
    p_device_info jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    active_sub     public.subscriptions;
    existing_dev   public.devices;
    active_count   integer;
    payment_ok     boolean;
    has_screenshot boolean;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '28000';
    END IF;

    -- Require at least one approved screenshot
    SELECT EXISTS (
        SELECT 1 FROM public.screenshots s
        WHERE s.user_id = p_user_id
          AND s.approved = true
    ) INTO has_screenshot;

    IF NOT has_screenshot THEN
        RETURN jsonb_build_object('allowed', false, 'reason', 'screenshot_not_approved', 'payment_confirmed', false);
    END IF;

    SELECT s.*
      INTO active_sub
      FROM public.subscriptions s
     WHERE s.user_id = p_user_id
       AND s.status = 'active'
       AND (s.current_period_end IS NULL OR s.current_period_end > now())
     ORDER BY s.current_period_end DESC NULLS LAST
     LIMIT 1;

    IF active_sub.id IS NULL THEN
        RETURN jsonb_build_object('allowed', false, 'reason', 'no_active_subscription', 'payment_confirmed', false);
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.payments p
         WHERE p.user_id = p_user_id
           AND (p.subscription_id = active_sub.id OR p.subscription_id IS NULL)
           AND p.status = 'completed'
    ) INTO payment_ok;

    SELECT * INTO existing_dev
      FROM public.devices d
     WHERE d.user_id = p_user_id
       AND d.device_id = p_device_id
     LIMIT 1;

    IF existing_dev.id IS NOT NULL THEN
        IF existing_dev.status = 'blocked' THEN
            RETURN jsonb_build_object('allowed', false, 'reason', 'device_blocked', 'payment_confirmed', payment_ok);
        END IF;

        UPDATE public.devices SET updated_at = now() WHERE id = existing_dev.id;
        RETURN jsonb_build_object('allowed', true, 'reason', NULL, 'payment_confirmed', payment_ok);
    END IF;

    SELECT count(*) INTO active_count
      FROM public.devices d
     WHERE d.user_id = p_user_id
       AND d.status = 'active';

    IF active_count >= 1 THEN
        RETURN jsonb_build_object('allowed', false, 'reason', 'device_limit_reached', 'payment_confirmed', payment_ok);
    END IF;

    INSERT INTO public.devices (user_id, device_id, status, device_info)
    VALUES (p_user_id, p_device_id, 'active', coalesce(p_device_info, '{}'::jsonb));

    RETURN jsonb_build_object('allowed', true, 'reason', NULL, 'payment_confirmed', payment_ok);
END;
$$;

GRANT EXECUTE ON FUNCTION public.allow_device_login(uuid, text, jsonb) TO authenticated;
