-- 000025: Admin atomic operations (RPC functions)
-- Replaces non-atomic sequential calls with transactional RPCs
-- All functions are SECURITY DEFINER, gated by is_admin()
-- Status/role codes looked up by name, not hardcoded integers

CREATE OR REPLACE FUNCTION admin_set_food_price(
  p_food_id UUID,
  p_price_php NUMERIC,
  p_source_id SMALLINT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_serving_id UUID;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only administrators can set food prices';
  END IF;

  SELECT serving_id INTO v_serving_id
  FROM FOOD_SERVING
  WHERE food_id = p_food_id AND is_active = TRUE
  ORDER BY is_default DESC
  LIMIT 1;

  IF v_serving_id IS NULL THEN
    RAISE EXCEPTION 'Food item has no active serving';
  END IF;

  UPDATE FOOD_PRICE
  SET is_active = FALSE, effective_to = v_now
  WHERE food_id = p_food_id AND is_active = TRUE;

  INSERT INTO FOOD_PRICE (
    food_id, serving_id, source_id,
    estimated_price_php, is_active, effective_from
  ) VALUES (
    p_food_id, v_serving_id, p_source_id,
    p_price_php, TRUE, v_now
  );
END;
$$;

CREATE OR REPLACE FUNCTION admin_hide_reported_post(
  p_report_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_post_id UUID;
  v_admin_user_id UUID;
  v_action_taken_id SMALLINT;
  v_hide_post_type_id SMALLINT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only administrators can hide reported posts';
  END IF;

  SELECT status_id INTO v_action_taken_id
  FROM REPORT_STATUS WHERE status_code = 'action_taken';

  SELECT action_type_id INTO v_hide_post_type_id
  FROM MODERATION_ACTION_TYPE WHERE action_code = 'hide_post';

  SELECT user_id INTO v_admin_user_id
  FROM APP_USER WHERE auth_user_id = auth.uid()::UUID;

  SELECT post_id INTO v_post_id
  FROM COMMUNITY_REPORT WHERE report_id = p_report_id;

  IF v_post_id IS NULL THEN
    RAISE EXCEPTION 'Report not found';
  END IF;

  UPDATE COMMUNITY_REPORT
  SET status_id = v_action_taken_id
  WHERE report_id = p_report_id;

  UPDATE COMMUNITY_POST
  SET is_hidden = TRUE
  WHERE post_id = v_post_id;

  INSERT INTO MODERATION_ACTION (
    admin_user_id, action_type_id, post_id,
    report_id, reason
  ) VALUES (
    v_admin_user_id, v_hide_post_type_id, v_post_id,
    p_report_id, 'Post hidden after moderation review'
  );
END;
$$;
