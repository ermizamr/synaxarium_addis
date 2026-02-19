-- Submissions table to capture user-entered info + screenshot path

CREATE TABLE IF NOT EXISTS public.submissions (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    name            text NOT NULL,
    phone           text NOT NULL,
    tier            text NOT NULL,
    promo_code      text,
    screenshot_path text,
    created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'submissions' AND policyname = 'Submissions owner insert'
    ) THEN
        CREATE POLICY "Submissions owner insert" ON public.submissions
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'submissions' AND policyname = 'Submissions owner select'
    ) THEN
        CREATE POLICY "Submissions owner select" ON public.submissions
            FOR SELECT USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'submissions' AND policyname = 'Submissions admin select'
    ) THEN
        CREATE POLICY "Submissions admin select" ON public.submissions
            FOR SELECT TO service_role USING (true);
    END IF;
END $$;
