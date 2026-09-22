-- Follow-up for the nutritionist rollout.
-- Keep app-user resolution schema-qualified so authenticated RLS policies and
-- report submission work even when the caller's search_path is restricted.
CREATE OR REPLACE FUNCTION public.get_app_user_id()
RETURNS UUID
LANGUAGE SQL
STABLE
SET search_path = public
AS $$
  SELECT user_id
  FROM public.app_user
  WHERE auth_user_id = auth.uid()::UUID;
$$;

-- SECURITY DEFINER SQL functions that return no rows can make an unauthorized
-- admin call look successful. Return an explicit authorization error instead.
CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS TABLE(
  user_id UUID,
  auth_user_id UUID,
  email TEXT,
  nickname TEXT,
  role_id SMALLINT,
  role_code TEXT,
  role_name TEXT,
  account_status_id SMALLINT,
  status_code TEXT,
  status_name TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can list users';
  END IF;

  RETURN QUERY
  SELECT
    au.user_id,
    au.auth_user_id,
    auth_user.email::TEXT,
    profile.nickname,
    role.role_id,
    role.role_code,
    role.role_name,
    status.account_status_id,
    status.status_code,
    status.status_name,
    au.created_at
  FROM public.app_user au
  JOIN public.role role ON role.role_id = au.role_id
  JOIN public.account_status status
    ON status.account_status_id = au.account_status_id
  LEFT JOIN public.user_profile profile ON profile.user_id = au.user_id
  LEFT JOIN auth.users auth_user ON auth_user.id = au.auth_user_id
  ORDER BY au.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.get_app_user_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_app_user_id() TO authenticated;
REVOKE ALL ON FUNCTION public.admin_list_users() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_users() TO authenticated;
