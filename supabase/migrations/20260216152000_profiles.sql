-- Users insert policy + user_profiles table (idempotent)

-- Allow owners to insert into public.users (needed when using auth.uid())
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Users insert own row'
    ) THEN
        CREATE POLICY "Users insert own row" ON public.users
            FOR INSERT WITH CHECK (auth.uid() = id);
    END IF;
END $$;

-- user_profiles table
CREATE TABLE IF NOT EXISTS public.user_profiles (
    user_id    uuid PRIMARY KEY REFERENCES public.users (id) ON DELETE CASCADE,
    name       text NOT NULL,
    phone      text NOT NULL,
    tier       text NOT NULL,
    promo_code text,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'user_profiles' AND policyname = 'Profiles owner insert'
    ) THEN
        CREATE POLICY "Profiles owner insert" ON public.user_profiles
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'user_profiles' AND policyname = 'Profiles owner select'
    ) THEN
        CREATE POLICY "Profiles owner select" ON public.user_profiles
            FOR SELECT USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'user_profiles' AND policyname = 'Profiles owner update'
    ) THEN
        CREATE POLICY "Profiles owner update" ON public.user_profiles
            FOR UPDATE USING (auth.uid() = user_id);
    END IF;
END $$;
