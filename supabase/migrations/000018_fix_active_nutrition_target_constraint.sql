-- Allow one active target with no end date; inactive historical targets may end.
ALTER TABLE public.nutrition_target
  DROP CONSTRAINT IF EXISTS one_active_target_per_user;

ALTER TABLE public.nutrition_target
  ADD CONSTRAINT active_target_dates_are_consistent
  CHECK (NOT is_active OR effective_to IS NULL);
