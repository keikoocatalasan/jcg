-- 000011: RLS policies - data isolation and access control

-- Helper function to get app_user_id from auth.uid()
-- Maps Supabase Auth user ID to APP_USER.user_id
CREATE OR REPLACE FUNCTION get_app_user_id()
RETURNS UUID
LANGUAGE SQL STABLE
AS $$
  SELECT user_id FROM APP_USER WHERE auth_user_id = auth.uid()::UUID;
$$;

-- Helper: check if current user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE SQL STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM APP_USER
    WHERE auth_user_id = auth.uid()::UUID
    AND role_id = (SELECT role_id FROM ROLE WHERE role_code = 'admin')
  );
$$;

-- ===== APP_USER =====
ALTER TABLE APP_USER ENABLE ROW LEVEL SECURITY;

-- Supabase Preview may replay this baseline against a branch that already has
-- the schema. Remove only the policies owned by this migration before
-- recreating them below; this keeps the migration repeatable without touching
-- policies for tables introduced later.
DO $$
DECLARE
  existing_policy RECORD;
BEGIN
  FOR existing_policy IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY (ARRAY[
        'app_user', 'user_profile', 'medical_disclaimer_acceptance',
        'user_allergy', 'user_dietary_restriction', 'nutrition_target',
        'daily_target_snapshot', 'food_item', 'food_serving',
        'food_nutrition_profile', 'food_price', 'food_change_log',
        'meal_log', 'water_log', 'weight_log', 'meal_plan',
        'recommendation_session', 'recommendation_item', 'ai_scan',
        'ai_scan_prediction', 'ai_scan_confirmation', 'chat_session',
        'chat_message', 'chat_message_context', 'community_post',
        'community_comment', 'community_like', 'community_report',
        'moderation_action', 'device', 'sync_queue', 'role',
        'account_status', 'sex', 'activity_level', 'fitness_goal',
        'meal_type', 'log_source', 'meal_plan_status', 'allergy',
        'dietary_restriction', 'food_category', 'data_source',
        'nutrition_formula_version', 'ai_scan_status', 'chat_role',
        'chat_safety_status', 'chat_delivery_status', 'report_reason',
        'report_status', 'moderation_action_type', 'sync_entity_type',
        'sync_operation_type', 'sync_status'
      ])
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      existing_policy.policyname,
      existing_policy.schemaname,
      existing_policy.tablename
    );
  END LOOP;
END;
$$;

CREATE POLICY app_user_select_own ON APP_USER
  FOR SELECT USING (auth_user_id = auth.uid()::UUID);

CREATE POLICY app_user_update_own ON APP_USER
  FOR UPDATE USING (auth_user_id = auth.uid()::UUID);

-- Admin can read/update all users
CREATE POLICY app_user_admin_select ON APP_USER
  FOR SELECT USING (is_admin());

CREATE POLICY app_user_admin_update ON APP_USER
  FOR UPDATE USING (is_admin());

-- ===== USER_PROFILE =====
ALTER TABLE USER_PROFILE ENABLE ROW LEVEL SECURITY;

CREATE POLICY profile_select_own ON USER_PROFILE
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY profile_insert_own ON USER_PROFILE
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY profile_update_own ON USER_PROFILE
  FOR UPDATE USING (user_id = get_app_user_id());

CREATE POLICY profile_admin_all ON USER_PROFILE
  FOR ALL USING (is_admin());

-- ===== MEDICAL_DISCLAIMER_ACCEPTANCE =====
ALTER TABLE MEDICAL_DISCLAIMER_ACCEPTANCE ENABLE ROW LEVEL SECURITY;

CREATE POLICY med_disclaimer_select_own ON MEDICAL_DISCLAIMER_ACCEPTANCE
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY med_disclaimer_insert_own ON MEDICAL_DISCLAIMER_ACCEPTANCE
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY med_disclaimer_admin_all ON MEDICAL_DISCLAIMER_ACCEPTANCE
  FOR ALL USING (is_admin());

-- ===== USER_ALLERGY =====
ALTER TABLE USER_ALLERGY ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_allergy_select_own ON USER_ALLERGY
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY user_allergy_insert_own ON USER_ALLERGY
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY user_allergy_delete_own ON USER_ALLERGY
  FOR DELETE USING (user_id = get_app_user_id());

CREATE POLICY user_allergy_admin_all ON USER_ALLERGY
  FOR ALL USING (is_admin());

-- ===== USER_DIETARY_RESTRICTION =====
ALTER TABLE USER_DIETARY_RESTRICTION ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_restriction_select_own ON USER_DIETARY_RESTRICTION
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY user_restriction_insert_own ON USER_DIETARY_RESTRICTION
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY user_restriction_delete_own ON USER_DIETARY_RESTRICTION
  FOR DELETE USING (user_id = get_app_user_id());

CREATE POLICY user_restriction_admin_all ON USER_DIETARY_RESTRICTION
  FOR ALL USING (is_admin());

-- ===== NUTRITION_TARGET =====
ALTER TABLE NUTRITION_TARGET ENABLE ROW LEVEL SECURITY;

CREATE POLICY nutrition_target_select_own ON NUTRITION_TARGET
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY nutrition_target_insert_own ON NUTRITION_TARGET
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY nutrition_target_update_own ON NUTRITION_TARGET
  FOR UPDATE USING (user_id = get_app_user_id());

CREATE POLICY nutrition_target_admin_all ON NUTRITION_TARGET
  FOR ALL USING (is_admin());

-- ===== DAILY_TARGET_SNAPSHOT =====
ALTER TABLE DAILY_TARGET_SNAPSHOT ENABLE ROW LEVEL SECURITY;

CREATE POLICY daily_target_snapshot_select_own ON DAILY_TARGET_SNAPSHOT
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY daily_target_snapshot_insert_own ON DAILY_TARGET_SNAPSHOT
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY daily_target_snapshot_update_own ON DAILY_TARGET_SNAPSHOT
  FOR UPDATE USING (user_id = get_app_user_id());

-- ===== FOOD_ITEM =====
ALTER TABLE FOOD_ITEM ENABLE ROW LEVEL SECURITY;

-- Users can read active official foods and their own custom foods
CREATE POLICY food_item_select ON FOOD_ITEM
  FOR SELECT USING (
    (is_official = TRUE AND is_active = TRUE)
    OR (owner_user_id = get_app_user_id())
    OR is_admin()
  );

-- Users can insert custom foods
CREATE POLICY food_item_insert_custom ON FOOD_ITEM
  FOR INSERT WITH CHECK (
    (owner_user_id = get_app_user_id() AND is_official = FALSE)
    OR is_admin()
  );

-- Users can update their own custom foods
CREATE POLICY food_item_update_custom ON FOOD_ITEM
  FOR UPDATE USING (
    (owner_user_id = get_app_user_id() AND is_official = FALSE)
    OR is_admin()
  );

-- Users can soft-delete their own custom foods; admin handles official
CREATE POLICY food_item_delete_custom ON FOOD_ITEM
  FOR DELETE USING (
    (owner_user_id = get_app_user_id() AND is_official = FALSE)
    OR is_admin()
  );

-- ===== FOOD_SERVING =====
ALTER TABLE FOOD_SERVING ENABLE ROW LEVEL SECURITY;

CREATE POLICY food_serving_select ON FOOD_SERVING
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM FOOD_ITEM WHERE food_id = FOOD_SERVING.food_id AND (is_active = TRUE OR is_admin()))
  );

CREATE POLICY food_serving_admin_all ON FOOD_SERVING
  FOR ALL USING (is_admin());

-- ===== FOOD_NUTRITION_PROFILE =====
ALTER TABLE FOOD_NUTRITION_PROFILE ENABLE ROW LEVEL SECURITY;

CREATE POLICY food_nutrition_select ON FOOD_NUTRITION_PROFILE
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM FOOD_ITEM WHERE food_id = FOOD_NUTRITION_PROFILE.food_id AND (is_active = TRUE OR is_admin()))
  );

CREATE POLICY food_nutrition_admin_all ON FOOD_NUTRITION_PROFILE
  FOR ALL USING (is_admin());

-- ===== FOOD_PRICE =====
ALTER TABLE FOOD_PRICE ENABLE ROW LEVEL SECURITY;

CREATE POLICY food_price_select ON FOOD_PRICE
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM FOOD_ITEM WHERE food_id = FOOD_PRICE.food_id AND (is_active = TRUE OR is_admin()))
  );

CREATE POLICY food_price_admin_all ON FOOD_PRICE
  FOR ALL USING (is_admin());

-- ===== FOOD_CHANGE_LOG =====
ALTER TABLE FOOD_CHANGE_LOG ENABLE ROW LEVEL SECURITY;

CREATE POLICY food_change_log_admin_all ON FOOD_CHANGE_LOG
  FOR ALL USING (is_admin());

CREATE POLICY food_change_log_select ON FOOD_CHANGE_LOG
  FOR SELECT USING (is_admin());

-- ===== MEAL_LOG =====
ALTER TABLE MEAL_LOG ENABLE ROW LEVEL SECURITY;

CREATE POLICY meal_log_select_own ON MEAL_LOG
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY meal_log_insert_own ON MEAL_LOG
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY meal_log_update_own ON MEAL_LOG
  FOR UPDATE USING (user_id = get_app_user_id());

CREATE POLICY meal_log_delete_own ON MEAL_LOG
  FOR DELETE USING (user_id = get_app_user_id());

CREATE POLICY meal_log_admin_all ON MEAL_LOG
  FOR ALL USING (is_admin());

-- ===== WATER_LOG =====
ALTER TABLE WATER_LOG ENABLE ROW LEVEL SECURITY;

CREATE POLICY water_log_select_own ON WATER_LOG
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY water_log_insert_own ON WATER_LOG
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY water_log_delete_own ON WATER_LOG
  FOR DELETE USING (user_id = get_app_user_id());

CREATE POLICY water_log_admin_all ON WATER_LOG
  FOR ALL USING (is_admin());

-- ===== WEIGHT_LOG =====
ALTER TABLE WEIGHT_LOG ENABLE ROW LEVEL SECURITY;

CREATE POLICY weight_log_select_own ON WEIGHT_LOG
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY weight_log_insert_own ON WEIGHT_LOG
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY weight_log_delete_own ON WEIGHT_LOG
  FOR DELETE USING (user_id = get_app_user_id());

CREATE POLICY weight_log_admin_all ON WEIGHT_LOG
  FOR ALL USING (is_admin());

-- ===== MEAL_PLAN =====
ALTER TABLE MEAL_PLAN ENABLE ROW LEVEL SECURITY;

CREATE POLICY meal_plan_select_own ON MEAL_PLAN
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY meal_plan_insert_own ON MEAL_PLAN
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY meal_plan_update_own ON MEAL_PLAN
  FOR UPDATE USING (user_id = get_app_user_id());

CREATE POLICY meal_plan_delete_own ON MEAL_PLAN
  FOR DELETE USING (user_id = get_app_user_id());

CREATE POLICY meal_plan_admin_all ON MEAL_PLAN
  FOR ALL USING (is_admin());

-- ===== RECOMMENDATION_SESSION =====
ALTER TABLE RECOMMENDATION_SESSION ENABLE ROW LEVEL SECURITY;

CREATE POLICY rec_session_select_own ON RECOMMENDATION_SESSION
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY rec_session_insert_own ON RECOMMENDATION_SESSION
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY rec_session_admin_all ON RECOMMENDATION_SESSION
  FOR ALL USING (is_admin());

-- ===== RECOMMENDATION_ITEM =====
ALTER TABLE RECOMMENDATION_ITEM ENABLE ROW LEVEL SECURITY;

CREATE POLICY rec_item_select_own ON RECOMMENDATION_ITEM
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM RECOMMENDATION_SESSION WHERE session_id = RECOMMENDATION_ITEM.session_id AND user_id = get_app_user_id())
  );

CREATE POLICY rec_item_insert_own ON RECOMMENDATION_ITEM
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM RECOMMENDATION_SESSION WHERE session_id = RECOMMENDATION_ITEM.session_id AND user_id = get_app_user_id())
  );

CREATE POLICY rec_item_update_own ON RECOMMENDATION_ITEM
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM RECOMMENDATION_SESSION WHERE session_id = RECOMMENDATION_ITEM.session_id AND user_id = get_app_user_id())
  );

CREATE POLICY rec_item_admin_all ON RECOMMENDATION_ITEM
  FOR ALL USING (is_admin());

-- ===== AI_SCAN =====
ALTER TABLE AI_SCAN ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_scan_select_own ON AI_SCAN
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY ai_scan_insert_own ON AI_SCAN
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY ai_scan_update_own ON AI_SCAN
  FOR UPDATE USING (user_id = get_app_user_id());

CREATE POLICY ai_scan_admin_all ON AI_SCAN
  FOR ALL USING (is_admin());

-- ===== AI_SCAN_PREDICTION =====
ALTER TABLE AI_SCAN_PREDICTION ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_scan_prediction_select_own ON AI_SCAN_PREDICTION
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM AI_SCAN WHERE scan_id = AI_SCAN_PREDICTION.scan_id AND user_id = get_app_user_id())
  );

CREATE POLICY ai_scan_prediction_admin_all ON AI_SCAN_PREDICTION
  FOR ALL USING (is_admin());

-- ===== AI_SCAN_CONFIRMATION =====
ALTER TABLE AI_SCAN_CONFIRMATION ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_scan_confirmation_select_own ON AI_SCAN_CONFIRMATION
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM AI_SCAN WHERE scan_id = AI_SCAN_CONFIRMATION.scan_id AND user_id = get_app_user_id())
  );

CREATE POLICY ai_scan_confirmation_insert_own ON AI_SCAN_CONFIRMATION
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM AI_SCAN WHERE scan_id = AI_SCAN_CONFIRMATION.scan_id AND user_id = get_app_user_id())
  );

CREATE POLICY ai_scan_confirmation_admin_all ON AI_SCAN_CONFIRMATION
  FOR ALL USING (is_admin());

-- ===== CHAT_SESSION =====
ALTER TABLE CHAT_SESSION ENABLE ROW LEVEL SECURITY;

CREATE POLICY chat_session_select_own ON CHAT_SESSION
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY chat_session_insert_own ON CHAT_SESSION
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY chat_session_update_own ON CHAT_SESSION
  FOR UPDATE USING (user_id = get_app_user_id());

CREATE POLICY chat_session_admin_all ON CHAT_SESSION
  FOR ALL USING (is_admin());

-- ===== CHAT_MESSAGE =====
ALTER TABLE CHAT_MESSAGE ENABLE ROW LEVEL SECURITY;

CREATE POLICY chat_message_select_own ON CHAT_MESSAGE
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM CHAT_SESSION WHERE chat_session_id = CHAT_MESSAGE.chat_session_id AND user_id = get_app_user_id())
  );

CREATE POLICY chat_message_insert_own ON CHAT_MESSAGE
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM CHAT_SESSION WHERE chat_session_id = CHAT_MESSAGE.chat_session_id AND user_id = get_app_user_id())
  );

CREATE POLICY chat_message_update_own ON CHAT_MESSAGE
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM CHAT_SESSION WHERE chat_session_id = CHAT_MESSAGE.chat_session_id AND user_id = get_app_user_id())
  );

CREATE POLICY chat_message_admin_all ON CHAT_MESSAGE
  FOR ALL USING (is_admin());

-- ===== CHAT_MESSAGE_CONTEXT =====
ALTER TABLE CHAT_MESSAGE_CONTEXT ENABLE ROW LEVEL SECURITY;

CREATE POLICY chat_context_select_own ON CHAT_MESSAGE_CONTEXT
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM CHAT_MESSAGE cm JOIN CHAT_SESSION cs ON cm.chat_session_id = cs.chat_session_id WHERE cm.chat_message_id = CHAT_MESSAGE_CONTEXT.chat_message_id AND cs.user_id = get_app_user_id())
  );

CREATE POLICY chat_context_admin_all ON CHAT_MESSAGE_CONTEXT
  FOR ALL USING (is_admin());

-- ===== COMMUNITY_POST =====
ALTER TABLE COMMUNITY_POST ENABLE ROW LEVEL SECURITY;

-- All authenticated users can see visible posts
CREATE POLICY community_post_select_visible ON COMMUNITY_POST
  FOR SELECT USING (
    (is_hidden = FALSE AND is_deleted = FALSE)
    OR user_id = get_app_user_id()
    OR is_admin()
  );

CREATE POLICY community_post_insert_own ON COMMUNITY_POST
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

-- Users can update (delete) their own posts
CREATE POLICY community_post_update_own ON COMMUNITY_POST
  FOR UPDATE USING (user_id = get_app_user_id());

CREATE POLICY community_post_delete_own ON COMMUNITY_POST
  FOR DELETE USING (user_id = get_app_user_id());

CREATE POLICY community_post_admin_all ON COMMUNITY_POST
  FOR ALL USING (is_admin());

-- ===== COMMUNITY_COMMENT =====
ALTER TABLE COMMUNITY_COMMENT ENABLE ROW LEVEL SECURITY;

CREATE POLICY community_comment_select_visible ON COMMUNITY_COMMENT
  FOR SELECT USING (
    (is_hidden = FALSE AND is_deleted = FALSE)
    OR user_id = get_app_user_id()
    OR is_admin()
  );

CREATE POLICY community_comment_insert_own ON COMMUNITY_COMMENT
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY community_comment_delete_own ON COMMUNITY_COMMENT
  FOR DELETE USING (user_id = get_app_user_id());

CREATE POLICY community_comment_admin_all ON COMMUNITY_COMMENT
  FOR ALL USING (is_admin());

-- ===== COMMUNITY_LIKE =====
ALTER TABLE COMMUNITY_LIKE ENABLE ROW LEVEL SECURITY;

CREATE POLICY community_like_select_own ON COMMUNITY_LIKE
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM COMMUNITY_POST WHERE post_id = COMMUNITY_LIKE.post_id AND is_hidden = FALSE AND is_deleted = FALSE)
    OR user_id = get_app_user_id()
    OR is_admin()
  );

CREATE POLICY community_like_insert_own ON COMMUNITY_LIKE
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY community_like_delete_own ON COMMUNITY_LIKE
  FOR DELETE USING (user_id = get_app_user_id());

CREATE POLICY community_like_admin_all ON COMMUNITY_LIKE
  FOR ALL USING (is_admin());

-- ===== COMMUNITY_REPORT =====
ALTER TABLE COMMUNITY_REPORT ENABLE ROW LEVEL SECURITY;

CREATE POLICY community_report_select_admin ON COMMUNITY_REPORT
  FOR SELECT USING (is_admin());

CREATE POLICY community_report_insert_own ON COMMUNITY_REPORT
  FOR INSERT WITH CHECK (reporter_user_id = get_app_user_id());

CREATE POLICY community_report_update_admin ON COMMUNITY_REPORT
  FOR UPDATE USING (is_admin());

CREATE POLICY community_report_admin_all ON COMMUNITY_REPORT
  FOR ALL USING (is_admin());

-- ===== MODERATION_ACTION =====
ALTER TABLE MODERATION_ACTION ENABLE ROW LEVEL SECURITY;

CREATE POLICY moderation_action_admin_all ON MODERATION_ACTION
  FOR ALL USING (is_admin());

-- ===== DEVICE =====
ALTER TABLE DEVICE ENABLE ROW LEVEL SECURITY;

CREATE POLICY device_select_own ON DEVICE
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY device_insert_own ON DEVICE
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY device_update_own ON DEVICE
  FOR UPDATE USING (user_id = get_app_user_id());

CREATE POLICY device_admin_all ON DEVICE
  FOR ALL USING (is_admin());

-- ===== SYNC_QUEUE =====
ALTER TABLE SYNC_QUEUE ENABLE ROW LEVEL SECURITY;

CREATE POLICY sync_queue_select_own ON SYNC_QUEUE
  FOR SELECT USING (user_id = get_app_user_id());

CREATE POLICY sync_queue_insert_own ON SYNC_QUEUE
  FOR INSERT WITH CHECK (user_id = get_app_user_id());

CREATE POLICY sync_queue_update_own ON SYNC_QUEUE
  FOR UPDATE USING (user_id = get_app_user_id());

CREATE POLICY sync_queue_delete_own ON SYNC_QUEUE
  FOR DELETE USING (user_id = get_app_user_id());

CREATE POLICY sync_queue_admin_all ON SYNC_QUEUE
  FOR ALL USING (is_admin());

-- ===== LOOKUP TABLES - Public Read, Admin Write =====
-- These are reference tables; all authenticated users can read them
-- Only admin can modify them

DO $$
DECLARE
  lookup_tables TEXT[] := ARRAY[
    'role', 'account_status', 'sex', 'activity_level', 'fitness_goal',
    'meal_type', 'log_source', 'meal_plan_status', 'allergy',
    'dietary_restriction', 'food_category', 'data_source',
    'nutrition_formula_version', 'ai_scan_status', 'chat_role',
    'chat_safety_status', 'chat_delivery_status', 'report_reason',
    'report_status', 'moderation_action_type', 'sync_entity_type',
    'sync_operation_type', 'sync_status'
  ];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY lookup_tables
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('
      CREATE POLICY %I_select ON %I
        FOR SELECT USING (true);',
      lower(t) || '_select', t);
    EXECUTE format('
      CREATE POLICY %I_admin_all ON %I
        FOR ALL USING (is_admin());',
      lower(t) || '_admin_all', t);
  END LOOP;
END;
$$;
