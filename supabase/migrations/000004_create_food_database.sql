-- 000004: Food database - items, servings, nutrition, price, change log

CREATE TABLE IF NOT EXISTS FOOD_ITEM (
  food_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id SMALLINT NOT NULL REFERENCES FOOD_CATEGORY(category_id),
  owner_user_id UUID REFERENCES APP_USER(user_id),
  food_name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,
  is_local_food BOOLEAN NOT NULL DEFAULT FALSE,
  is_official BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_food_normalized_name ON FOOD_ITEM(normalized_name);
CREATE INDEX idx_food_category ON FOOD_ITEM(category_id);
CREATE INDEX idx_food_owner ON FOOD_ITEM(owner_user_id);
CREATE INDEX idx_food_active ON FOOD_ITEM(is_active);
CREATE INDEX idx_food_official ON FOOD_ITEM(is_official);

CREATE TABLE IF NOT EXISTS FOOD_SERVING (
  serving_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  food_id UUID NOT NULL REFERENCES FOOD_ITEM(food_id) ON DELETE CASCADE,
  serving_label TEXT NOT NULL,
  serving_grams NUMERIC(8,2) NOT NULL CHECK (serving_grams > 0),
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_food_serving_food ON FOOD_SERVING(food_id);
CREATE INDEX idx_food_serving_default ON FOOD_SERVING(is_default) WHERE is_default = TRUE AND is_active = TRUE;

CREATE TABLE IF NOT EXISTS FOOD_NUTRITION_PROFILE (
  nutrition_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  food_id UUID NOT NULL REFERENCES FOOD_ITEM(food_id) ON DELETE CASCADE,
  serving_id UUID NOT NULL REFERENCES FOOD_SERVING(serving_id) ON DELETE CASCADE,
  source_id SMALLINT NOT NULL REFERENCES DATA_SOURCE(source_id),
  calories NUMERIC(8,2) NOT NULL CHECK (calories >= 0),
  protein_g NUMERIC(8,2) NOT NULL CHECK (protein_g >= 0),
  carbs_g NUMERIC(8,2) NOT NULL CHECK (carbs_g >= 0),
  fat_g NUMERIC(8,2) NOT NULL CHECK (fat_g >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  effective_to TIMESTAMPTZ
);

CREATE INDEX idx_food_nutrition_food ON FOOD_NUTRITION_PROFILE(food_id);
CREATE INDEX idx_food_nutrition_serving ON FOOD_NUTRITION_PROFILE(serving_id);
CREATE INDEX idx_food_nutrition_active ON FOOD_NUTRITION_PROFILE(is_active) WHERE is_active = TRUE;

CREATE TABLE IF NOT EXISTS FOOD_PRICE (
  price_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  food_id UUID NOT NULL REFERENCES FOOD_ITEM(food_id) ON DELETE CASCADE,
  serving_id UUID NOT NULL REFERENCES FOOD_SERVING(serving_id) ON DELETE CASCADE,
  source_id SMALLINT NOT NULL REFERENCES DATA_SOURCE(source_id),
  estimated_price_php NUMERIC(8,2) NOT NULL CHECK (estimated_price_php >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  effective_to TIMESTAMPTZ
);

CREATE INDEX idx_food_price_food ON FOOD_PRICE(food_id);
CREATE INDEX idx_food_price_serving ON FOOD_PRICE(serving_id);
CREATE INDEX idx_food_price_active ON FOOD_PRICE(is_active) WHERE is_active = TRUE;

CREATE TABLE IF NOT EXISTS FOOD_CHANGE_LOG (
  change_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  food_id UUID NOT NULL REFERENCES FOOD_ITEM(food_id) ON DELETE CASCADE,
  changed_by_user_id UUID NOT NULL REFERENCES APP_USER(user_id),
  change_type TEXT NOT NULL,
  old_value_json JSONB,
  new_value_json JSONB,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_food_change_log_food ON FOOD_CHANGE_LOG(food_id);

CREATE TRIGGER trg_food_item_updated_at
  BEFORE UPDATE ON FOOD_ITEM
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
