-- Storage policies for screenshots bucket (no ALTER RLS)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Screenshots objects insert own'
    ) THEN
        CREATE POLICY "Screenshots objects insert own" ON storage.objects
            FOR INSERT TO authenticated
            WITH CHECK (
                bucket_id = 'screenshots'
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Screenshots objects select own'
    ) THEN
        CREATE POLICY "Screenshots objects select own" ON storage.objects
            FOR SELECT TO authenticated
            USING (
                bucket_id = 'screenshots'
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;
END $$;
