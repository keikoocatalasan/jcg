-- 000017: Allow authenticated users to resolve their APP_USER row.

GRANT SELECT ON public.APP_USER TO authenticated;
