-- 000012: Seed all lookup tables

-- ROLE
INSERT INTO ROLE (role_code, role_name) VALUES
  ('user', 'Normal User'),
  ('admin', 'Administrator')
ON CONFLICT DO NOTHING;

-- ACCOUNT_STATUS
INSERT INTO ACCOUNT_STATUS (status_code, status_name) VALUES
  ('active', 'Active'),
  ('disabled', 'Disabled')
ON CONFLICT DO NOTHING;

-- SEX
INSERT INTO SEX (sex_code, sex_name) VALUES
  ('male', 'Male'),
  ('female', 'Female')
ON CONFLICT DO NOTHING;

-- ACTIVITY_LEVEL
INSERT INTO ACTIVITY_LEVEL (activity_code, activity_name, multiplier) VALUES
  ('sedentary', 'Sedentary', 1.20),
  ('light', 'Lightly Active', 1.375),
  ('moderate', 'Moderately Active', 1.55),
  ('active', 'Active', 1.725),
  ('very_active', 'Very Active', 1.90)
ON CONFLICT DO NOTHING;

-- FITNESS_GOAL
INSERT INTO FITNESS_GOAL (goal_code, goal_name, description) VALUES
  ('cutting', 'Cutting', 'Lose fat while preserving muscle mass'),
  ('maintenance', 'Maintenance', 'Maintain current weight and body composition'),
  ('bulking', 'Bulking', 'Build muscle mass with controlled calorie surplus'),
  ('lean', 'Lean Gain', 'Build muscle with minimal fat gain'),
  ('gain_weight', 'Gain Weight', 'Increase overall body weight')
ON CONFLICT DO NOTHING;

-- MEAL_TYPE
INSERT INTO MEAL_TYPE (meal_type_code, meal_type_name) VALUES
  ('breakfast', 'Breakfast'),
  ('lunch', 'Lunch'),
  ('dinner', 'Dinner'),
  ('snack', 'Snack')
ON CONFLICT DO NOTHING;

-- LOG_SOURCE
INSERT INTO LOG_SOURCE (source_code, source_name) VALUES
  ('manual', 'Manual Entry'),
  ('ai_scanner', 'AI Scanner'),
  ('recommendation', 'Recommendation'),
  ('planner', 'Meal Planner')
ON CONFLICT DO NOTHING;

-- MEAL_PLAN_STATUS
INSERT INTO MEAL_PLAN_STATUS (status_code, status_name) VALUES
  ('planned', 'Planned'),
  ('logged', 'Logged'),
  ('skipped', 'Skipped')
ON CONFLICT DO NOTHING;

-- AI_SCAN_STATUS
INSERT INTO AI_SCAN_STATUS (status_code, status_name) VALUES
  ('pending', 'Pending'),
  ('completed', 'Completed'),
  ('failed', 'Failed'),
  ('low_confidence', 'Low Confidence')
ON CONFLICT DO NOTHING;

-- CHAT_ROLE
INSERT INTO CHAT_ROLE (role_code, role_name) VALUES
  ('user', 'User'),
  ('assistant', 'Assistant'),
  ('system', 'System')
ON CONFLICT DO NOTHING;

-- CHAT_SAFETY_STATUS
INSERT INTO CHAT_SAFETY_STATUS (status_code, status_name) VALUES
  ('safe', 'Safe'),
  ('redirected', 'Redirected'),
  ('blocked', 'Blocked')
ON CONFLICT DO NOTHING;

-- CHAT_DELIVERY_STATUS
INSERT INTO CHAT_DELIVERY_STATUS (status_code, status_name) VALUES
  ('local_saved', 'Saved Locally'),
  ('sent_to_api', 'Sent to API'),
  ('assistant_received', 'Assistant Response Received'),
  ('failed', 'Failed to Send'),
  ('blocked', 'Blocked by Safety'),
  ('redirected', 'Redirected by Safety')
ON CONFLICT DO NOTHING;

-- REPORT_REASON
INSERT INTO REPORT_REASON (reason_code, reason_name) VALUES
  ('spam', 'Spam'),
  ('inappropriate', 'Inappropriate Content'),
  ('harassment', 'Harassment'),
  ('misinformation', 'Misinformation'),
  ('other', 'Other')
ON CONFLICT DO NOTHING;

-- REPORT_STATUS
INSERT INTO REPORT_STATUS (status_code, status_name) VALUES
  ('pending', 'Pending'),
  ('reviewed', 'Reviewed'),
  ('dismissed', 'Dismissed'),
  ('action_taken', 'Action Taken')
ON CONFLICT DO NOTHING;

-- MODERATION_ACTION_TYPE
INSERT INTO MODERATION_ACTION_TYPE (action_code, action_name) VALUES
  ('hide_post', 'Hide Post'),
  ('unhide_post', 'Unhide Post'),
  ('hide_comment', 'Hide Comment'),
  ('warn_user', 'Warn User')
ON CONFLICT DO NOTHING;

-- SYNC_ENTITY_TYPE
INSERT INTO SYNC_ENTITY_TYPE (entity_code, entity_name) VALUES
  ('profile', 'User Profile'),
  ('nutrition_target', 'Nutrition Target'),
  ('daily_target_snapshot', 'Daily Target Snapshot'),
  ('custom_food', 'Custom Food'),
  ('meal_log', 'Meal Log'),
  ('water_log', 'Water Log'),
  ('weight_log', 'Weight Log'),
  ('meal_plan', 'Meal Plan'),
  ('recommendation_session', 'Recommendation Session'),
  ('recommendation_item', 'Recommendation Item'),
  ('ai_scan', 'AI Scan'),
  ('ai_scan_prediction', 'AI Scan Prediction'),
  ('ai_scan_feedback', 'AI Scan Feedback'),
  ('chat_session', 'Chat Session'),
  ('chat_message', 'Chat Message')
ON CONFLICT DO NOTHING;

-- SYNC_OPERATION_TYPE
INSERT INTO SYNC_OPERATION_TYPE (operation_code, operation_name) VALUES
  ('create', 'Create'),
  ('update', 'Update'),
  ('delete', 'Delete')
ON CONFLICT DO NOTHING;

-- SYNC_STATUS
INSERT INTO SYNC_STATUS (status_code, status_name) VALUES
  ('pending', 'Pending'),
  ('processing', 'Processing'),
  ('synced', 'Synced'),
  ('failed', 'Failed')
ON CONFLICT DO NOTHING;

-- NUTRITION_FORMULA_VERSION
INSERT INTO NUTRITION_FORMULA_VERSION (version_code, description, is_active) VALUES
  ('mifflin_v1', 'Mifflin-St Jeor Equation v1', TRUE)
ON CONFLICT DO NOTHING;

-- FOOD_CATEGORY (common Filipino food categories)
INSERT INTO FOOD_CATEGORY (category_name, is_active)
SELECT seed.category_name, seed.is_active
FROM (VALUES
  ('Rice and Grains', TRUE),
  ('Meat and Poultry', TRUE),
  ('Seafood', TRUE),
  ('Vegetables', TRUE),
  ('Fruits', TRUE),
  ('Dairy and Eggs', TRUE),
  ('Bread and Pastry', TRUE),
  ('Soups and Porridge', TRUE),
  ('Beverages', TRUE),
  ('Snacks and Desserts', TRUE),
  ('Legumes and Tofu', TRUE),
  ('Condiments and Spreads', TRUE)
) AS seed(category_name, is_active)
WHERE NOT EXISTS (
  SELECT 1 FROM FOOD_CATEGORY existing
  WHERE existing.category_name = seed.category_name
);

-- DATA_SOURCE
INSERT INTO DATA_SOURCE (source_name, source_type, source_reference)
SELECT seed.source_name, seed.source_type, seed.source_reference
FROM (VALUES
  ('FNRI_DOST', 'Government', 'FNRI-DOST Philippine Food Composition Tables'),
  ('Estimated_Common', 'Estimated', 'Common serving estimates for Filipino dishes')
) AS seed(source_name, source_type, source_reference)
WHERE NOT EXISTS (
  SELECT 1 FROM DATA_SOURCE existing
  WHERE existing.source_name = seed.source_name
);
