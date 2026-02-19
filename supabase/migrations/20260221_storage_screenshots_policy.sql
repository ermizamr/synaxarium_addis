-- Storage policies to allow users to write/read their own screenshot objects.
-- Assumes object path format: <user_id>/<filename>

drop policy if exists "screenshots_user_write" on storage.objects;

create policy "screenshots_user_write"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'screenshots'
    and auth.uid() = (storage.foldername(name))[1]::uuid
  );

drop policy if exists "screenshots_user_read" on storage.objects;

create policy "screenshots_user_read"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'screenshots'
    and auth.uid() = (storage.foldername(name))[1]::uuid
  );
