-- 000030: Admin analytics RPC — daily-aggregated snapshot for charts
CREATE OR REPLACE FUNCTION admin_analytics_snapshot(p_range_days INT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start DATE := CURRENT_DATE - p_range_days;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only administrators can view analytics';
  END IF;

  RETURN json_build_object(
    'user_growth', (
      SELECT json_agg(d) FROM (
        SELECT d::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) d
        LEFT JOIN (
          SELECT created_at::DATE AS day, COUNT(*) AS cnt
          FROM APP_USER GROUP BY day
        ) c ON d::DATE = c.day
        ORDER BY d
      ) d
    ),
    'meal_logs', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT d::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) d
        LEFT JOIN (
          SELECT logged_at::DATE AS day, COUNT(*) AS cnt
          FROM MEAL_LOG GROUP BY day
        ) c ON d::DATE = c.day
        ORDER BY d
      ) d
    ),
    'hydration_logs', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT d::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) d
        LEFT JOIN (
          SELECT logged_at::DATE AS day, COUNT(*) AS cnt
          FROM WATER_LOG GROUP BY day
        ) c ON d::DATE = c.day
        ORDER BY d
      ) d
    ),
    'weight_logs', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT d::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) d
        LEFT JOIN (
          SELECT logged_at::DATE AS day, COUNT(*) AS cnt
          FROM WEIGHT_LOG GROUP BY day
        ) c ON d::DATE = c.day
        ORDER BY d
      ) d
    ),
    'ai_scans', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT d::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) d
        LEFT JOIN (
          SELECT created_at::DATE AS day, COUNT(*) AS cnt
          FROM AI_SCAN GROUP BY day
        ) c ON d::DATE = c.day
        ORDER BY d
      ) d
    ),
    'posts_created', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT d::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) d
        LEFT JOIN (
          SELECT created_at::DATE AS day, COUNT(*) AS cnt
          FROM COMMUNITY_POST GROUP BY day
        ) c ON d::DATE = c.day
        ORDER BY d
      ) d
    ),
    'reports_filed', (
      SELECT COALESCE(json_agg(d), '[]'::JSON) FROM (
        SELECT d::TEXT AS date, COALESCE(c.cnt, 0) AS count
        FROM generate_series(v_start, CURRENT_DATE, '1 day'::INTERVAL) d
        LEFT JOIN (
          SELECT created_at::DATE AS day, COUNT(*) AS cnt
          FROM COMMUNITY_REPORT GROUP BY day
        ) c ON d::DATE = c.day
        ORDER BY d
      ) d
    ),
    'total_foods', (SELECT COUNT(*) FROM FOOD_ITEM WHERE is_deleted = FALSE),
    'total_official_foods', (SELECT COUNT(*) FROM FOOD_ITEM WHERE is_official = TRUE AND is_deleted = FALSE),
    'report_resolution_rate', (
      SELECT CASE
        WHEN t.total = 0 THEN 0
        ELSE ROUND(r.resolved::NUMERIC / t.total * 100)
      END
      FROM
        (SELECT COUNT(*) AS total FROM COMMUNITY_REPORT) t,
        (SELECT COUNT(*) AS resolved FROM COMMUNITY_REPORT
          WHERE status_id != (SELECT status_id FROM REPORT_STATUS WHERE status_code = 'pending')) r
    )
  );
END;
$$;
