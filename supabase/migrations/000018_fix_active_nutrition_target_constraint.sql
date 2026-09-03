-- Allow one active target with no end date; inactive historical targets may end.
ALTER TABLE public.nutrition_target
  DROP CONSTRAINT IF EXISTS one_active_target_per_user;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.nutrition_target'::regclass
      AND conname = 'active_target_dates_are_consistent'
  ) THEN
    ALTER TABLE public.nutrition_target
      ADD CONSTRAINT active_target_dates_are_consistent
      CHECK (NOT is_active OR effective_to IS NULL);
  END IF;
END;
$$;
