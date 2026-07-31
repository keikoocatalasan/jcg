-- 000005: Tracking tables - meal logs, water logs, weight logs

CREATE TABLE IF NOT EXISTS MEAL_LOG (
  meal_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  food_id UUID REFERENCES FOOD_ITEM(food_id),
  meal_type_id SMALLINT NOT NULL REFERENCES MEAL_TYPE(meal_type_id),
  log_source_id SMALLINT NOT NULL REFERENCES LOG_SOURCE(log_source_id),
  food_name_snapshot TEXT NOT NULL,
  serving_grams_snapshot NUMERIC(8,2) NOT NULL,
  quantity NUMERIC(6,2) NOT NULL CHECK (quantity > 0),
  calories_snapshot NUMERIC(8,2) NOT NULL CHECK (calories_snapshot >= 0),
  protein_g_snapshot NUMERIC(8,2) NOT NULL CHECK (protein_g_snapshot >= 0),
  carbs_g_snapshot NUMERIC(8,2) NOT NULL CHECK (carbs_g_snapshot >= 0),
  fat_g_snapshot NUMERIC(8,2) NOT NULL CHECK (fat_g_snapshot >= 0),
  cost_php_snapshot NUMERIC(8,2) NOT NULL CHECK (cost_php_snapshot >= 0),
  logged_at TIMESTAMPTZ NOT NULL,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meal_log_user_date ON MEAL_LOG(user_id, logged_at);
CREATE INDEX idx_meal_log_user ON MEAL_LOG(user_id);
CREATE INDEX idx_meal_log_active ON MEAL_LOG(user_id) WHERE is_deleted = FALSE;

CREATE TABLE IF NOT EXISTS WATER_LOG (
  water_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  amount_ml INTEGER NOT NULL CHECK (amount_ml > 0 AND amount_ml <= 5000),
  logged_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_water_log_user_date ON WATER_LOG(user_id, logged_at);
CREATE INDEX idx_water_log_user ON WATER_LOG(user_id);

CREATE TABLE IF NOT EXISTS WEIGHT_LOG (
  weight_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  weight_kg NUMERIC(5,1) NOT NULL CHECK (weight_kg >= 20 AND weight_kg <= 300),
  logged_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_weight_log_user_date ON WEIGHT_LOG(user_id, logged_at DESC);
CREATE INDEX idx_weight_log_user ON WEIGHT_LOG(user_id);

CREATE TRIGGER trg_meal_log_updated_at
  BEFORE UPDATE ON MEAL_LOG
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_water_log_updated_at
  BEFORE UPDATE ON WATER_LOG
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_weight_log_updated_at
  BEFORE UPDATE ON WEIGHT_LOG
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
