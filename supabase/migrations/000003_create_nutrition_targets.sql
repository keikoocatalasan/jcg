-- 000003: Nutrition targets, goal policies, daily snapshots

CREATE TABLE IF NOT EXISTS GOAL_CALORIE_POLICY (
  policy_id SMALLINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  fitness_goal_id SMALLINT NOT NULL REFERENCES FITNESS_GOAL(fitness_goal_id),
  calorie_adjustment SMALLINT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_goal_calorie_policy UNIQUE (fitness_goal_id)
);

CREATE TABLE IF NOT EXISTS GOAL_MACRO_POLICY (
  policy_id SMALLINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  fitness_goal_id SMALLINT NOT NULL REFERENCES FITNESS_GOAL(fitness_goal_id),
  protein_pct NUMERIC(5,2) NOT NULL CHECK (protein_pct >= 0 AND protein_pct <= 100),
  carbs_pct NUMERIC(5,2) NOT NULL CHECK (carbs_pct >= 0 AND carbs_pct <= 100),
  fat_pct NUMERIC(5,2) NOT NULL CHECK (fat_pct >= 0 AND fat_pct <= 100),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_goal_macro_policy UNIQUE (fitness_goal_id),
  CONSTRAINT macro_pct_total_100 CHECK (protein_pct + carbs_pct + fat_pct = 100)
);

CREATE TABLE IF NOT EXISTS NUTRITION_TARGET (
  target_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  formula_version_id SMALLINT NOT NULL REFERENCES NUTRITION_FORMULA_VERSION(formula_version_id),
  fitness_goal_id SMALLINT NOT NULL REFERENCES FITNESS_GOAL(fitness_goal_id),
  source_weight_log_id UUID,
  bmr NUMERIC(7,2) NOT NULL,
  tdee NUMERIC(7,2) NOT NULL,
  calorie_target INTEGER NOT NULL CHECK (calorie_target > 0),
  protein_target_g NUMERIC(6,1) NOT NULL CHECK (protein_target_g >= 0),
  carbs_target_g NUMERIC(6,1) NOT NULL CHECK (carbs_target_g >= 0),
  fat_target_g NUMERIC(6,1) NOT NULL CHECK (fat_target_g >= 0),
  water_target_ml INTEGER NOT NULL CHECK (water_target_ml >= 0),
  effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  effective_to TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT one_active_target_per_user CHECK (NOT (is_active = TRUE AND effective_to IS NULL))
);

CREATE UNIQUE INDEX idx_one_active_target ON NUTRITION_TARGET(user_id) WHERE is_active = TRUE;
CREATE INDEX idx_nutrition_target_user ON NUTRITION_TARGET(user_id);
CREATE INDEX idx_nutrition_target_active ON NUTRITION_TARGET(is_active);

CREATE TABLE IF NOT EXISTS DAILY_TARGET_SNAPSHOT (
  snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  nutrition_target_id UUID NOT NULL REFERENCES NUTRITION_TARGET(target_id),
  target_date DATE NOT NULL,
  calorie_target_snapshot INTEGER NOT NULL,
  protein_target_g_snapshot NUMERIC(6,1) NOT NULL,
  carbs_target_g_snapshot NUMERIC(6,1) NOT NULL,
  fat_target_g_snapshot NUMERIC(6,1) NOT NULL,
  water_target_ml_snapshot INTEGER NOT NULL,
  daily_budget_php_snapshot NUMERIC(8,2) NOT NULL,
  CONSTRAINT uq_user_daily_target UNIQUE (user_id, target_date)
);

CREATE INDEX idx_daily_target_user_date ON DAILY_TARGET_SNAPSHOT(user_id, target_date);
