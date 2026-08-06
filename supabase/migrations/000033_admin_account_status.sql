-- 000033: audited admin account-status management

CREATE TABLE IF NOT EXISTS public.admin_account_status_audit (
  audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  changed_by UUID NOT NULL REFERENCES public.app_user(user_id),
  target_user UUID NOT NULL REFERENCES public.app_user(user_id),
  old_status_id SMALLINT REFERENCES public.account_status(account_status_id),
  new_status_id SMALLINT NOT NULL REFERENCES public.account_status(account_status_id),
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_account_status_audit_target
  ON public.admin_account_status_audit(target_user);
CREATE INDEX IF NOT EXISTS idx_admin_account_status_audit_changed_by
  ON public.admin_account_status_audit(changed_by);

ALTER TABLE public.admin_account_status_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_account_status_audit_select
  ON public.admin_account_status_audit;
CREATE POLICY admin_account_status_audit_select
  ON public.admin_account_status_audit
  FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS admin_account_status_audit_insert
  ON public.admin_account_status_audit;
CREATE POLICY admin_account_status_audit_insert
  ON public.admin_account_status_audit
  FOR INSERT WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public.admin_set_account_status(
  p_target_user_id UUID,
  p_new_account_status_id SMALLINT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_user_id UUID;
  v_old_status_id SMALLINT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can change account status';
  END IF;

  SELECT user_id INTO v_admin_user_id
  FROM public.app_user
  WHERE auth_user_id = auth.uid()::UUID;

  SELECT account_status_id INTO v_old_status_id
  FROM public.app_user
  WHERE user_id = p_target_user_id;

  IF v_old_status_id IS NULL THEN
    RAISE EXCEPTION 'Target user not found';
  END IF;

  IF v_admin_user_id = p_target_user_id THEN
    RAISE EXCEPTION 'Administrators cannot change their own account status';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.account_status
    WHERE account_status_id = p_new_account_status_id
  ) THEN
    RAISE EXCEPTION 'Account status is not configured: %', p_new_account_status_id;
  END IF;

  IF v_old_status_id = p_new_account_status_id THEN
    RETURN;
  END IF;

  UPDATE public.app_user
  SET account_status_id = p_new_account_status_id
  WHERE user_id = p_target_user_id;

  INSERT INTO public.admin_account_status_audit (
    changed_by, target_user, old_status_id, new_status_id
  ) VALUES (
    v_admin_user_id, p_target_user_id, v_old_status_id, p_new_account_status_id
  );
END;
$$;

GRANT SELECT ON public.admin_account_status_audit TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_account_status(uuid, smallint)
  TO authenticated;
