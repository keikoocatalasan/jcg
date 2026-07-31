-- 000031: Repair admin metric RPCs against the current schema.

CREATE OR REPLACE FUNCTION admin_dashboard_kpis()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_users BIGINT;
  v_active_users BIGINT;
  v_total_meal_logs BIGINT;
  v_total_ai_scans BIGINT;
  v_report_count BIGINT;
  v_pending_post_reports BIGINT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only administrators can view dashboard KPIs';
  END IF;

  SELECT COUNT(*) INTO v_total_users FROM APP_USER;
  SELECT COUNT(*) INTO v_active_users
  FROM APP_USER u
  WHERE EXISTS (
    SELECT 1 FROM MEAL_LOG m
    WHERE m.user_id = u.user_id
      AND m.is_deleted = FALSE
      AND m.logged_at >= NOW() - INTERVAL '30 days'
  );
  SELECT COUNT(*) INTO v_total_meal_logs FROM MEAL_LOG WHERE is_deleted = FALSE;
  SELECT COUNT(*) INTO v_total_ai_scans FROM AI_SCAN;
  SELECT COUNT(*) INTO v_report_count FROM COMMUNITY_REPORT;
  SELECT COUNT(*) INTO v_pending_post_reports
  FROM COMMUNITY_REPORT
  WHERE status_id = (
    SELECT status_id FROM REPORT_STATUS WHERE status_code = 'pending'
  );

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

CREATE OR REPLACE FUNCTION admin_analytics_snapshot(p_range_days INT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start DATE := CURRENT_DATE - GREATEST(p_range_days, 1);
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only administrators can view analytics';
  END IF;

  RETURN json_build_object(
    'user_growth', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT day::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) day
        LEFT JOIN (
          SELECT created_at::DATE AS date, COUNT(*) AS cnt
          FROM APP_USER GROUP BY date
        ) c ON day::DATE = c.date ORDER BY day
      ) d
    ),
    'meal_logs', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT day::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) day
        LEFT JOIN (
          SELECT logged_at::DATE AS date, COUNT(*) AS cnt
          FROM MEAL_LOG WHERE is_deleted = FALSE GROUP BY date
        ) c ON day::DATE = c.date ORDER BY day
      ) d
    ),
    'hydration_logs', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT day::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) day
        LEFT JOIN (
          SELECT logged_at::DATE AS date, COUNT(*) AS cnt
          FROM WATER_LOG GROUP BY date
        ) c ON day::DATE = c.date ORDER BY day
      ) d
    ),
    'weight_logs', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT day::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) day
        LEFT JOIN (
          SELECT logged_at::DATE AS date, COUNT(*) AS cnt
          FROM WEIGHT_LOG GROUP BY date
        ) c ON day::DATE = c.date ORDER BY day
      ) d
    ),
    'ai_scans', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT day::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) day
        LEFT JOIN (
          SELECT created_at::DATE AS date, COUNT(*) AS cnt
          FROM AI_SCAN GROUP BY date
        ) c ON day::DATE = c.date ORDER BY day
      ) d
    ),
    'posts_created', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT day::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) day
        LEFT JOIN (
          SELECT created_at::DATE AS date, COUNT(*) AS cnt
          FROM COMMUNITY_POST GROUP BY date
        ) c ON day::DATE = c.date ORDER BY day
      ) d
    ),
    'reports_filed', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT day::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) day
        LEFT JOIN (
          SELECT created_at::DATE AS date, COUNT(*) AS cnt
          FROM COMMUNITY_REPORT GROUP BY date
        ) c ON day::DATE = c.date ORDER BY day
      ) d
    ),
    'total_foods', (SELECT COUNT(*) FROM FOOD_ITEM WHERE is_active = TRUE),
    'total_official_foods', (
      SELECT COUNT(*) FROM FOOD_ITEM
      WHERE is_official = TRUE AND is_active = TRUE
    ),
    'report_resolution_rate', (
      SELECT CASE WHEN t.total = 0 THEN 0
        ELSE ROUND(r.resolved::NUMERIC / t.total * 100) END
      FROM (SELECT COUNT(*) AS total FROM COMMUNITY_REPORT) t,
           (SELECT COUNT(*) AS resolved FROM COMMUNITY_REPORT
            WHERE status_id != (
              SELECT status_id FROM REPORT_STATUS WHERE status_code = 'pending'
            )) r
    )
  );
END;
$$;
