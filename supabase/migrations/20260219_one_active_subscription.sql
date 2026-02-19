-- Ensure only one active subscription per user
-- Remove any extra active subscriptions, keeping one per user
DELETE FROM public.subscriptions s
USING (
  SELECT ctid
  FROM (
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY ctid) AS rn
    FROM public.subscriptions
    WHERE status = 'active'
  ) t
  WHERE rn > 1
) dup
WHERE s.ctid = dup.ctid;

-- Enforce only one active subscription per user
CREATE UNIQUE INDEX IF NOT EXISTS subscriptions_one_active_per_user_idx
  ON public.subscriptions (user_id)
  WHERE status = 'active';
