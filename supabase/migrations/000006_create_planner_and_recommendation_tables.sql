-- 000006: Meal planner and recommendation tables

CREATE TABLE IF NOT EXISTS MEAL_PLAN (
  meal_plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  food_id UUID REFERENCES FOOD_ITEM(food_id),
  meal_type_id SMALLINT NOT NULL REFERENCES MEAL_TYPE(meal_type_id),
  status_id SMALLINT NOT NULL REFERENCES MEAL_PLAN_STATUS(status_id),
  converted_meal_log_id UUID REFERENCES MEAL_LOG(meal_log_id),
  food_name_snapshot TEXT NOT NULL,
  serving_grams_snapshot NUMERIC(8,2) NOT NULL,
  quantity NUMERIC(6,2) NOT NULL CHECK (quantity > 0),
  calories_snapshot NUMERIC(8,2) NOT NULL CHECK (calories_snapshot >= 0),
  protein_g_snapshot NUMERIC(8,2) NOT NULL CHECK (protein_g_snapshot >= 0),
  carbs_g_snapshot NUMERIC(8,2) NOT NULL CHECK (carbs_g_snapshot >= 0),
  fat_g_snapshot NUMERIC(8,2) NOT NULL CHECK (fat_g_snapshot >= 0),
  cost_php_snapshot NUMERIC(8,2) NOT NULL CHECK (cost_php_snapshot >= 0),
  planned_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meal_plan_user_date ON MEAL_PLAN(user_id, planned_date);
CREATE INDEX idx_meal_plan_user ON MEAL_PLAN(user_id);

CREATE TABLE IF NOT EXISTS RECOMMENDATION_SESSION (
  session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  remaining_budget_php NUMERIC(8,2) NOT NULL,
  remaining_calories INTEGER NOT NULL,
  remaining_protein_g NUMERIC(6,1) NOT NULL,
  remaining_carbs_g NUMERIC(6,1) NOT NULL,
  remaining_fat_g NUMERIC(6,1) NOT NULL,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recommendation_session_user ON RECOMMENDATION_SESSION(user_id);

CREATE TABLE IF NOT EXISTS RECOMMENDATION_ITEM (
  recommendation_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES RECOMMENDATION_SESSION(session_id) ON DELETE CASCADE,
  food_id UUID NOT NULL REFERENCES FOOD_ITEM(food_id),
  linked_meal_log_id UUID REFERENCES MEAL_LOG(meal_log_id),
  linked_meal_plan_id UUID REFERENCES MEAL_PLAN(meal_plan_id),
  rank_number SMALLINT NOT NULL CHECK (rank_number > 0),
  final_score NUMERIC(6,4) NOT NULL,
  affordability_score NUMERIC(6,4) NOT NULL,
  protein_fit_score NUMERIC(6,4) NOT NULL,
  calorie_fit_score NUMERIC(6,4) NOT NULL,
  macro_balance_score NUMERIC(6,4) NOT NULL,
  goal_match_score NUMERIC(6,4) NOT NULL,
  meal_type_score NUMERIC(6,4) NOT NULL,
  over_budget_penalty NUMERIC(6,4) NOT NULL DEFAULT 0,
  reason_text TEXT NOT NULL,
  was_accepted BOOLEAN NOT NULL DEFAULT FALSE,
  accepted_at TIMESTAMPTZ
);

CREATE INDEX idx_recommendation_item_session ON RECOMMENDATION_ITEM(session_id);

CREATE TRIGGER trg_meal_plan_updated_at
  BEFORE UPDATE ON MEAL_PLAN
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
