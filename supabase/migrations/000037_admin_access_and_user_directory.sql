-- 000037: Make admin RLS checks non-recursive and expose a safe user directory.

-- APP_USER's admin policy calls is_admin(). The old helper queried APP_USER
-- through that same policy, which can recurse for admin reads. A security
-- definer helper reads the role mapping without inheriting caller RLS.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.app_user u
    JOIN public.role r ON r.role_id = u.role_id
    WHERE u.auth_user_id = auth.uid()::UUID
      AND r.role_code = 'admin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- auth.users is intentionally only exposed through this admin-gated function;
-- client code never receives service-role credentials or direct auth-table
-- access.
CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS TABLE (
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
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
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
  WHERE public.is_admin()
  ORDER BY au.created_at DESC
  LIMIT 200;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_users() TO authenticated;
