-- Add the egg variants that the focused egg/bread recognition pilot will use.
-- The inserts are idempotent so a reviewed deployment can be retried safely.

DO $$
DECLARE
  v_category SMALLINT;
  v_source SMALLINT;
  v_estimate_source SMALLINT;
  v_food_id UUID;
  v_serving_id UUID;
BEGIN
  SELECT category_id INTO v_category
  FROM food_category
  WHERE category_name = 'Dairy and Eggs';

  SELECT source_id INTO v_source
  FROM data_source
  WHERE source_name = 'FNRI_DOST'
  LIMIT 1;

  SELECT source_id INTO v_estimate_source
  FROM data_source
  WHERE source_name = 'Estimated_Common'
  LIMIT 1;

  IF v_category IS NULL THEN
    RAISE EXCEPTION 'Dairy and Eggs category is required';
  END IF;

  IF v_source IS NULL OR v_estimate_source IS NULL THEN
    RAISE EXCEPTION 'Nutrition and price data sources are required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM food_item WHERE normalized_name = 'scrambled egg'
  ) THEN
    v_food_id := gen_random_uuid();
    INSERT INTO food_item (
      food_id, category_id, food_name, normalized_name,
      is_local_food, is_official, is_active
    ) VALUES (
      v_food_id, v_category, 'Scrambled Egg', 'scrambled egg',
      FALSE, TRUE, TRUE
    );
    v_serving_id := gen_random_uuid();
    INSERT INTO food_serving (
      serving_id, food_id, serving_label, serving_grams, is_default, is_active
    ) VALUES (
      v_serving_id, v_food_id, '1 large egg', 50, TRUE, TRUE
    );
    INSERT INTO food_nutrition_profile (
      food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active
    ) VALUES (
      v_food_id, v_serving_id, v_source, 148, 10.1, 1.1, 11.0, TRUE
    );
    INSERT INTO food_price (
      food_id, serving_id, source_id, estimated_price_php, is_active
    ) VALUES (
      v_food_id, v_serving_id, v_estimate_source, 15, TRUE
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM food_item WHERE normalized_name = 'sunny side up egg'
  ) THEN
    v_food_id := gen_random_uuid();
    INSERT INTO food_item (
      food_id, category_id, food_name, normalized_name,
      is_local_food, is_official, is_active
    ) VALUES (
      v_food_id, v_category, 'Sunny-Side-Up Egg', 'sunny side up egg',
      FALSE, TRUE, TRUE
    );
    v_serving_id := gen_random_uuid();
    INSERT INTO food_serving (
      serving_id, food_id, serving_label, serving_grams, is_default, is_active
    ) VALUES (
      v_serving_id, v_food_id, '1 large egg', 55, TRUE, TRUE
    );
    INSERT INTO food_nutrition_profile (
      food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active
    ) VALUES (
      v_food_id, v_serving_id, v_source, 110, 6.8, 0.8, 8.5, TRUE
    );
    INSERT INTO food_price (
      food_id, serving_id, source_id, estimated_price_php, is_active
    ) VALUES (
      v_food_id, v_serving_id, v_estimate_source, 15, TRUE
    );
  END IF;
END;
$$;
