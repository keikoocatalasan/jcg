-- 000016: Allow authenticated API access to community tables.

GRANT SELECT ON public.USER_PROFILE TO authenticated;
GRANT SELECT ON public.REPORT_REASON TO authenticated;

GRANT SELECT, INSERT, UPDATE ON public.COMMUNITY_POST TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.COMMUNITY_COMMENT TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.COMMUNITY_LIKE TO authenticated;
GRANT INSERT ON public.COMMUNITY_REPORT TO authenticated;
