-- Remove duplicates, keeping the first row per user.
DELETE FROM public.submissions s
USING public.submissions dup
WHERE s.user_id = dup.user_id
  AND s.ctid > dup.ctid;

-- Enforce one submission per user
ALTER TABLE public.submissions
  ADD CONSTRAINT submissions_user_unique UNIQUE (user_id);
