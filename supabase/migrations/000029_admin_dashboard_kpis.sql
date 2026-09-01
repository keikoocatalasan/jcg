-- 000029: Admin dashboard KPIs RPC
-- Returns live aggregate counts for the admin dashboard

CREATE OR REPLACE FUNCTION admin_dashboard_kpis()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_users BIGINT;
  v_active_users BIGINT;
  v_total_meal_logs BIGINT;
  v_total_ai_scans BIGINT;
  v_report_count BIGINT;
  v_pending_post_reports BIGINT;
  v_thirty_days TEXT := to_char(NOW() - INTERVAL '30 days', 'YYYY-MM-DD');
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only administrators can view dashboard KPIs';
  END IF;

  SELECT COUNT(*) INTO v_total_users FROM APP_USER;

  SELECT COUNT(*) INTO v_active_users FROM APP_USER
  WHERE EXISTS (
    SELECT 1 FROM MEAL_LOG
    WHERE MEAL_LOG.user_id = APP_USER.user_id
    AND MEAL_LOG.logged_at >= v_thirty_days
  );

  SELECT COUNT(*) INTO v_total_meal_logs FROM MEAL_LOG;

  SELECT COUNT(*) INTO v_total_ai_scans FROM AI_SCAN;

  SELECT COUNT(*) INTO v_report_count FROM COMMUNITY_REPORT;

  SELECT COUNT(*) INTO v_pending_post_reports FROM COMMUNITY_REPORT
  WHERE status_id = (SELECT status_id FROM REPORT_STATUS WHERE status_code = 'pending');

  RETURN json_build_object(
    'total_users', v_total_users,
    'active_users', v_active_users,
    'total_meal_logs', v_total_meal_logs,
    'total_ai_scans', v_total_ai_scans,
    'report_count', v_report_count,
    'pending_post_reports', v_pending_post_reports
  );
END;
$$;
