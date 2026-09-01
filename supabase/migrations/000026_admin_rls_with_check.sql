-- 000026: Admin RLS policies — add WITH CHECK clauses
-- Existing admin FOR ALL policies had USING (is_admin()) but
-- lacked explicit WITH CHECK, defaulting INSERT/UPDATE checks to TRUE.
-- This closes that gap.

-- APP_USER: admin update needs WITH CHECK
DROP POLICY IF EXISTS app_user_admin_update ON APP_USER;
CREATE POLICY app_user_admin_update ON APP_USER
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());

-- USER_PROFILE: replace FOR ALL with explicit per-operation policies
DROP POLICY IF EXISTS profile_admin_all ON USER_PROFILE;
CREATE POLICY profile_admin_select ON USER_PROFILE
  FOR SELECT USING (is_admin());
CREATE POLICY profile_admin_insert ON USER_PROFILE
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY profile_admin_update ON USER_PROFILE
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY profile_admin_delete ON USER_PROFILE
  FOR DELETE USING (is_admin());

-- MEDICAL_DISCLAIMER_ACCEPTANCE
DROP POLICY IF EXISTS med_disclaimer_admin_all ON MEDICAL_DISCLAIMER_ACCEPTANCE;
CREATE POLICY med_disclaimer_admin_select ON MEDICAL_DISCLAIMER_ACCEPTANCE
  FOR SELECT USING (is_admin());
CREATE POLICY med_disclaimer_admin_insert ON MEDICAL_DISCLAIMER_ACCEPTANCE
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY med_disclaimer_admin_update ON MEDICAL_DISCLAIMER_ACCEPTANCE
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY med_disclaimer_admin_delete ON MEDICAL_DISCLAIMER_ACCEPTANCE
  FOR DELETE USING (is_admin());

-- USER_ALLERGY
DROP POLICY IF EXISTS user_allergy_admin_all ON USER_ALLERGY;
CREATE POLICY user_allergy_admin_select ON USER_ALLERGY
  FOR SELECT USING (is_admin());
CREATE POLICY user_allergy_admin_insert ON USER_ALLERGY
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY user_allergy_admin_update ON USER_ALLERGY
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY user_allergy_admin_delete ON USER_ALLERGY
  FOR DELETE USING (is_admin());

-- USER_DIETARY_RESTRICTION
DROP POLICY IF EXISTS user_restriction_admin_all ON USER_DIETARY_RESTRICTION;
CREATE POLICY user_restriction_admin_select ON USER_DIETARY_RESTRICTION
  FOR SELECT USING (is_admin());
CREATE POLICY user_restriction_admin_insert ON USER_DIETARY_RESTRICTION
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY user_restriction_admin_update ON USER_DIETARY_RESTRICTION
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY user_restriction_admin_delete ON USER_DIETARY_RESTRICTION
  FOR DELETE USING (is_admin());

-- NUTRITION_TARGET
DROP POLICY IF EXISTS nutrition_target_admin_all ON NUTRITION_TARGET;
CREATE POLICY nutrition_target_admin_select ON NUTRITION_TARGET
  FOR SELECT USING (is_admin());
CREATE POLICY nutrition_target_admin_insert ON NUTRITION_TARGET
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY nutrition_target_admin_update ON NUTRITION_TARGET
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY nutrition_target_admin_delete ON NUTRITION_TARGET
  FOR DELETE USING (is_admin());

-- DAILY_TARGET_SNAPSHOT (no existing admin policy — add one)
CREATE POLICY daily_target_snapshot_admin_select ON DAILY_TARGET_SNAPSHOT
  FOR SELECT USING (is_admin());
CREATE POLICY daily_target_snapshot_admin_insert ON DAILY_TARGET_SNAPSHOT
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY daily_target_snapshot_admin_update ON DAILY_TARGET_SNAPSHOT
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());

-- FOOD_SERVING
DROP POLICY IF EXISTS food_serving_admin_all ON FOOD_SERVING;
CREATE POLICY food_serving_admin_select ON FOOD_SERVING
  FOR SELECT USING (is_admin());
CREATE POLICY food_serving_admin_insert ON FOOD_SERVING
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY food_serving_admin_update ON FOOD_SERVING
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY food_serving_admin_delete ON FOOD_SERVING
  FOR DELETE USING (is_admin());

-- FOOD_NUTRITION_PROFILE
DROP POLICY IF EXISTS food_nutrition_admin_all ON FOOD_NUTRITION_PROFILE;
CREATE POLICY food_nutrition_admin_select ON FOOD_NUTRITION_PROFILE
  FOR SELECT USING (is_admin());
CREATE POLICY food_nutrition_admin_insert ON FOOD_NUTRITION_PROFILE
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY food_nutrition_admin_update ON FOOD_NUTRITION_PROFILE
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY food_nutrition_admin_delete ON FOOD_NUTRITION_PROFILE
  FOR DELETE USING (is_admin());

-- FOOD_PRICE
DROP POLICY IF EXISTS food_price_admin_all ON FOOD_PRICE;
CREATE POLICY food_price_admin_select ON FOOD_PRICE
  FOR SELECT USING (is_admin());
CREATE POLICY food_price_admin_insert ON FOOD_PRICE
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY food_price_admin_update ON FOOD_PRICE
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY food_price_admin_delete ON FOOD_PRICE
  FOR DELETE USING (is_admin());

-- FOOD_CHANGE_LOG
DROP POLICY IF EXISTS food_change_log_admin_all ON FOOD_CHANGE_LOG;
CREATE POLICY food_change_log_admin_select ON FOOD_CHANGE_LOG
  FOR SELECT USING (is_admin());
CREATE POLICY food_change_log_admin_insert ON FOOD_CHANGE_LOG
  FOR INSERT WITH CHECK (is_admin());

-- MEAL_LOG
DROP POLICY IF EXISTS meal_log_admin_all ON MEAL_LOG;
CREATE POLICY meal_log_admin_select ON MEAL_LOG
  FOR SELECT USING (is_admin());
CREATE POLICY meal_log_admin_insert ON MEAL_LOG
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY meal_log_admin_update ON MEAL_LOG
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY meal_log_admin_delete ON MEAL_LOG
  FOR DELETE USING (is_admin());

-- WATER_LOG
DROP POLICY IF EXISTS water_log_admin_all ON WATER_LOG;
CREATE POLICY water_log_admin_select ON WATER_LOG
  FOR SELECT USING (is_admin());
CREATE POLICY water_log_admin_insert ON WATER_LOG
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY water_log_admin_update ON WATER_LOG
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY water_log_admin_delete ON WATER_LOG
  FOR DELETE USING (is_admin());

-- WEIGHT_LOG
DROP POLICY IF EXISTS weight_log_admin_all ON WEIGHT_LOG;
CREATE POLICY weight_log_admin_select ON WEIGHT_LOG
  FOR SELECT USING (is_admin());
CREATE POLICY weight_log_admin_insert ON WEIGHT_LOG
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY weight_log_admin_update ON WEIGHT_LOG
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY weight_log_admin_delete ON WEIGHT_LOG
  FOR DELETE USING (is_admin());

-- MEAL_PLAN
DROP POLICY IF EXISTS meal_plan_admin_all ON MEAL_PLAN;
CREATE POLICY meal_plan_admin_select ON MEAL_PLAN
  FOR SELECT USING (is_admin());
CREATE POLICY meal_plan_admin_insert ON MEAL_PLAN
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY meal_plan_admin_update ON MEAL_PLAN
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY meal_plan_admin_delete ON MEAL_PLAN
  FOR DELETE USING (is_admin());

-- COMMUNITY_POST
DROP POLICY IF EXISTS community_post_admin_all ON COMMUNITY_POST;
CREATE POLICY community_post_admin_select ON COMMUNITY_POST
  FOR SELECT USING (is_admin());
CREATE POLICY community_post_admin_insert ON COMMUNITY_POST
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY community_post_admin_update ON COMMUNITY_POST
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());
CREATE POLICY community_post_admin_delete ON COMMUNITY_POST
  FOR DELETE USING (is_admin());

-- COMMUNITY_REPORT — split update and insert
DROP POLICY IF EXISTS community_report_admin_all ON COMMUNITY_REPORT;
DROP POLICY IF EXISTS community_report_update_admin ON COMMUNITY_REPORT;
CREATE POLICY community_report_admin_select ON COMMUNITY_REPORT
  FOR SELECT USING (is_admin());
CREATE POLICY community_report_admin_insert ON COMMUNITY_REPORT
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY community_report_admin_update ON COMMUNITY_REPORT
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());

-- MODERATION_ACTION
DROP POLICY IF EXISTS moderation_action_admin_all ON MODERATION_ACTION;
CREATE POLICY moderation_action_admin_select ON MODERATION_ACTION
  FOR SELECT USING (is_admin());
CREATE POLICY moderation_action_admin_insert ON MODERATION_ACTION
  FOR INSERT WITH CHECK (is_admin());

-- AI_SCAN
DROP POLICY IF EXISTS ai_scan_admin_all ON AI_SCAN;
CREATE POLICY ai_scan_admin_select ON AI_SCAN
  FOR SELECT USING (is_admin());
CREATE POLICY ai_scan_admin_insert ON AI_SCAN
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY ai_scan_admin_update ON AI_SCAN
  FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());

-- AI_SCAN_PREDICTION
DROP POLICY IF EXISTS ai_scan_prediction_admin_all ON AI_SCAN_PREDICTION;
CREATE POLICY ai_scan_prediction_admin_select ON AI_SCAN_PREDICTION
  FOR SELECT USING (is_admin());
CREATE POLICY ai_scan_prediction_admin_insert ON AI_SCAN_PREDICTION
  FOR INSERT WITH CHECK (is_admin());

-- AI_SCAN_CONFIRMATION
DROP POLICY IF EXISTS ai_scan_confirmation_admin_all ON AI_SCAN_CONFIRMATION;
CREATE POLICY ai_scan_confirmation_admin_select ON AI_SCAN_CONFIRMATION
  FOR SELECT USING (is_admin());
CREATE POLICY ai_scan_confirmation_admin_insert ON AI_SCAN_CONFIRMATION
  FOR INSERT WITH CHECK (is_admin());

-- Lookup tables — replace FOR ALL with explicit per-operation
DO $$
DECLARE
  lookup_tables TEXT[] := ARRAY[
    'ROLE', 'ACCOUNT_STATUS', 'SEX', 'ACTIVITY_LEVEL', 'FITNESS_GOAL',
    'MEAL_TYPE', 'LOG_SOURCE', 'MEAL_PLAN_STATUS', 'ALLERGY',
    'DIETARY_RESTRICTION', 'FOOD_CATEGORY', 'DATA_SOURCE',
    'NUTRITION_FORMULA_VERSION', 'AI_SCAN_STATUS', 'CHAT_ROLE',
    'CHAT_SAFETY_STATUS', 'CHAT_DELIVERY_STATUS', 'REPORT_REASON',
    'REPORT_STATUS', 'MODERATION_ACTION_TYPE', 'SYNC_ENTITY_TYPE',
    'SYNC_OPERATION_TYPE', 'SYNC_STATUS'
  ];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY lookup_tables
  LOOP
    -- Drop existing ALL policy
    EXECUTE format('DROP POLICY IF EXISTS %I_admin_all ON %I;',
      lower(t) || '_admin_all', t);
    -- Create explicit per-operation policies
    EXECUTE format('
      CREATE POLICY %I_admin_select ON %I FOR SELECT USING (is_admin());',
      lower(t) || '_admin_select', t);
    EXECUTE format('
      CREATE POLICY %I_admin_insert ON %I FOR INSERT WITH CHECK (is_admin());',
      lower(t) || '_admin_insert', t);
    EXECUTE format('
      CREATE POLICY %I_admin_update ON %I FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());',
      lower(t) || '_admin_update', t);
    EXECUTE format('
      CREATE POLICY %I_admin_delete ON %I FOR DELETE USING (is_admin());',
      lower(t) || '_admin_delete', t);
  END LOOP;
END;
$$;
