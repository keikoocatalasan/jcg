-- 000035: Keep moderation timestamps consistent and protect the last admin.

CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id UUID,
  p_status_code TEXT,
  p_details TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_user_id UUID;
  v_post_id UUID;
  v_status_id SMALLINT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can resolve reports';
  END IF;

  IF p_status_code NOT IN ('dismissed', 'reviewed') THEN
    RAISE EXCEPTION 'Unsupported report status: %', p_status_code;
  END IF;

  SELECT user_id INTO v_admin_user_id
  FROM public.app_user
  WHERE auth_user_id = auth.uid()::UUID;

  SELECT post_id INTO v_post_id
  FROM public.community_report
  WHERE report_id = p_report_id;

  IF v_post_id IS NULL THEN
    RAISE EXCEPTION 'Report not found';
  END IF;

  SELECT status_id INTO v_status_id
  FROM public.report_status
  WHERE status_code = p_status_code;

  IF v_status_id IS NULL THEN
    RAISE EXCEPTION 'Report status is not configured: %', p_status_code;
  END IF;

  UPDATE public.community_report
  SET status_id = v_status_id,
      reviewed_at = NOW()
  WHERE report_id = p_report_id;

  INSERT INTO public.moderation_audit_log (
    admin_user_id, action_code, report_id, post_id, details
  ) VALUES (
    v_admin_user_id,
    p_status_code,
    p_report_id,
    v_post_id,
    COALESCE(p_details, 'Report status updated')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_user_role(
  p_target_user_id UUID,
  p_new_role_id SMALLINT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_user_id UUID;
  v_old_role_id SMALLINT;
  v_admin_role_id SMALLINT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can change user roles';
  END IF;

  SELECT user_id INTO v_admin_user_id
  FROM public.app_user
  WHERE auth_user_id = auth.uid()::UUID;

  SELECT role_id INTO v_old_role_id
  FROM public.app_user
  WHERE user_id = p_target_user_id;

  IF v_old_role_id IS NULL THEN
    RAISE EXCEPTION 'Target user not found';
  END IF;

  SELECT role_id INTO v_admin_role_id
  FROM public.role
  WHERE role_code = 'admin';

  IF NOT EXISTS (
    SELECT 1 FROM public.role WHERE role_id = p_new_role_id
  ) THEN
    RAISE EXCEPTION 'Role is not configured: %', p_new_role_id;
  END IF;

  IF v_admin_user_id = p_target_user_id THEN
    RAISE EXCEPTION 'Administrators cannot change their own role';
  END IF;

  IF v_old_role_id = v_admin_role_id
     AND p_new_role_id <> v_admin_role_id
     AND NOT EXISTS (
       SELECT 1
       FROM public.app_user
       WHERE role_id = v_admin_role_id
         AND user_id <> p_target_user_id
     ) THEN
    RAISE EXCEPTION 'The last administrator cannot be demoted';
  END IF;

  IF v_old_role_id = p_new_role_id THEN
    RETURN;
  END IF;

  UPDATE public.app_user
  SET role_id = p_new_role_id
  WHERE user_id = p_target_user_id;

  INSERT INTO public.admin_role_audit (
    changed_by, target_user, old_role_id, new_role_id
  ) VALUES (
    v_admin_user_id, p_target_user_id, v_old_role_id, p_new_role_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_report(uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, smallint)
  TO authenticated;
