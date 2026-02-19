-- Subscription + device enforcement schema and RPC

-- Enum types
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
        CREATE TYPE public.subscription_status AS ENUM ('active', 'expired', 'cancelled');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'device_status') THEN
        CREATE TYPE public.device_status AS ENUM ('active', 'blocked');
    END IF;
END $$;

-- Users table (mirrors auth.users id, keeps app metadata)
CREATE TABLE IF NOT EXISTS public.users (
    id          uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    status              subscription_status NOT NULL DEFAULT 'active',
    current_period_end  timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS subscriptions_user_id_idx ON public.subscriptions (user_id);
CREATE INDEX IF NOT EXISTS subscriptions_status_idx ON public.subscriptions (status);

-- Devices table (enforces single active device)
CREATE TABLE IF NOT EXISTS public.devices (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    device_id    text NOT NULL UNIQUE,
    status       device_status NOT NULL DEFAULT 'active',
    device_info  jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS devices_user_id_idx ON public.devices (user_id);
CREATE INDEX IF NOT EXISTS devices_status_idx ON public.devices (status);

-- Payments table (simple status tracking)
CREATE TABLE IF NOT EXISTS public.payments (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    subscription_id uuid REFERENCES public.subscriptions (id) ON DELETE CASCADE,
    amount          numeric,
    currency        text,
    status          text NOT NULL CHECK (status IN ('pending', 'completed', 'failed')),
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payments_user_id_idx ON public.payments (user_id);
CREATE INDEX IF NOT EXISTS payments_subscription_id_idx ON public.payments (subscription_id);

-- RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- RLS policies
DO $$
BEGIN
    -- users
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Users select own row'
    ) THEN
        CREATE POLICY "Users select own row" ON public.users
            FOR SELECT USING (auth.uid() = id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Users update own row'
    ) THEN
        CREATE POLICY "Users update own row" ON public.users
            FOR UPDATE USING (auth.uid() = id);
    END IF;

    -- subscriptions
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'subscriptions' AND policyname = 'Subscriptions owner select'
    ) THEN
        CREATE POLICY "Subscriptions owner select" ON public.subscriptions
            FOR SELECT USING (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'subscriptions' AND policyname = 'Subscriptions owner insert'
    ) THEN
        CREATE POLICY "Subscriptions owner insert" ON public.subscriptions
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'subscriptions' AND policyname = 'Subscriptions owner update'
    ) THEN
        CREATE POLICY "Subscriptions owner update" ON public.subscriptions
            FOR UPDATE USING (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'subscriptions' AND policyname = 'Subscriptions owner delete'
    ) THEN
        CREATE POLICY "Subscriptions owner delete" ON public.subscriptions
            FOR DELETE USING (auth.uid() = user_id);
    END IF;

    -- devices
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'devices' AND policyname = 'Devices owner select'
    ) THEN
        CREATE POLICY "Devices owner select" ON public.devices
            FOR SELECT USING (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'devices' AND policyname = 'Devices owner insert'
    ) THEN
        CREATE POLICY "Devices owner insert" ON public.devices
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'devices' AND policyname = 'Devices owner update'
    ) THEN
        CREATE POLICY "Devices owner update" ON public.devices
            FOR UPDATE USING (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'devices' AND policyname = 'Devices owner delete'
    ) THEN
        CREATE POLICY "Devices owner delete" ON public.devices
            FOR DELETE USING (auth.uid() = user_id);
    END IF;

    -- payments
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'payments' AND policyname = 'Payments owner select'
    ) THEN
        CREATE POLICY "Payments owner select" ON public.payments
            FOR SELECT USING (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'payments' AND policyname = 'Payments owner insert'
    ) THEN
        CREATE POLICY "Payments owner insert" ON public.payments
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'payments' AND policyname = 'Payments owner update'
    ) THEN
        CREATE POLICY "Payments owner update" ON public.payments
            FOR UPDATE USING (auth.uid() = user_id);
    END IF;
END $$;

-- RPC: allow_device_login
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
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
        RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '28000';
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
