-- Align authenticated Flutter retry sync with the FastAPI feedback contract.
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.ai_scan_feedback TO authenticated;

DROP POLICY IF EXISTS ai_scan_feedback_insert_own
  ON public.ai_scan_feedback;
CREATE POLICY ai_scan_feedback_insert_own ON public.ai_scan_feedback
  FOR INSERT WITH CHECK (user_id = public.get_app_user_id());

DROP POLICY IF EXISTS ai_scan_feedback_update_own
  ON public.ai_scan_feedback;
CREATE POLICY ai_scan_feedback_update_own ON public.ai_scan_feedback
  FOR UPDATE
  USING (user_id = public.get_app_user_id())
  WITH CHECK (user_id = public.get_app_user_id());

DROP POLICY IF EXISTS ai_scan_feedback_delete_own
  ON public.ai_scan_feedback;
CREATE POLICY ai_scan_feedback_delete_own ON public.ai_scan_feedback
  FOR DELETE USING (user_id = public.get_app_user_id());
