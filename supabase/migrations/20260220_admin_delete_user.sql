-- Admin-only function to delete a user and related rows.
-- NOTE: This does not remove storage objects; run storage cleanup separately if needed.

create or replace function admin_delete_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Delete dependent rows first to satisfy FK/RLS ordering.
  delete from devices where user_id = p_user_id;
  delete from screenshots where user_id = p_user_id;
  delete from submissions where user_id = p_user_id;
  delete from payments where user_id = p_user_id;
  delete from subscriptions where user_id = p_user_id;
  delete from user_profiles where user_id = p_user_id;
  delete from users where id = p_user_id;
end;
$$;

-- Lock down: not callable by anon/authenticated.
revoke all on function admin_delete_user(uuid) from public;
