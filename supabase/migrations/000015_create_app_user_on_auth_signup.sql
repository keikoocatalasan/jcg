-- 000015: Keep APP_USER in sync with Supabase Auth signups.

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.APP_USER (user_id, auth_user_id)
  VALUES (NEW.id, NEW.id)
  ON CONFLICT (auth_user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

INSERT INTO public.APP_USER (user_id, auth_user_id)
SELECT id, id
FROM auth.users
ON CONFLICT (auth_user_id) DO NOTHING;
