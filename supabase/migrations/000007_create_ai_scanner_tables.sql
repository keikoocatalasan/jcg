-- 000007: AI scanner tables

CREATE TABLE IF NOT EXISTS AI_SCAN (
  scan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  scan_status_id SMALLINT NOT NULL REFERENCES AI_SCAN_STATUS(scan_status_id),
  client_scan_id UUID NOT NULL,
  image_path TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  raw_response_json JSONB,
  CONSTRAINT uq_client_scan_per_user UNIQUE (user_id, client_scan_id)
);

CREATE INDEX IF NOT EXISTS idx_ai_scan_user ON AI_SCAN(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_scan_client ON AI_SCAN(user_id, client_scan_id);

CREATE TABLE IF NOT EXISTS AI_SCAN_PREDICTION (
  prediction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scan_id UUID NOT NULL REFERENCES AI_SCAN(scan_id) ON DELETE CASCADE,
  food_id UUID REFERENCES FOOD_ITEM(food_id),
  predicted_food_name TEXT NOT NULL,
  confidence NUMERIC(6,4) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
  rank_number SMALLINT NOT NULL CHECK (rank_number > 0),
  calories NUMERIC(8,2),
  protein_g NUMERIC(8,2),
  carbs_g NUMERIC(8,2),
  fat_g NUMERIC(8,2),
  estimated_cost_php NUMERIC(8,2)
);

CREATE INDEX IF NOT EXISTS idx_ai_scan_prediction_scan ON AI_SCAN_PREDICTION(scan_id);

CREATE TABLE IF NOT EXISTS AI_SCAN_CONFIRMATION (
  confirmation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scan_id UUID NOT NULL UNIQUE REFERENCES AI_SCAN(scan_id) ON DELETE CASCADE,
  selected_prediction_id UUID REFERENCES AI_SCAN_PREDICTION(prediction_id),
  meal_log_id UUID REFERENCES MEAL_LOG(meal_log_id),
  confirmed_food_id UUID REFERENCES FOOD_ITEM(food_id),
  quantity NUMERIC(6,2) NOT NULL DEFAULT 1 CHECK (quantity > 0),
  meal_type_id SMALLINT REFERENCES MEAL_TYPE(meal_type_id),
  correction_reason TEXT,
  confirmed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_scan_confirmation_scan ON AI_SCAN_CONFIRMATION(scan_id);
