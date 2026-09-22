-- Add searchable meal add-ons and an estimated Caldereta serving.
-- USDA values below are scaled from FoodData Central SR Legacy records:
-- cheddar (FDC 170899) and raw tomato (FDC 170457).
-- Caldereta varies by recipe and remains explicitly estimated.

DO $$
DECLARE
  v_dairy_category SMALLINT;
  v_vegetable_category SMALLINT;
  v_meat_category SMALLINT;
  v_usda_source SMALLINT;
  v_estimate_source SMALLINT;
  v_food_id UUID;
  v_serving_id UUID;
BEGIN
  SELECT category_id INTO v_dairy_category
  FROM food_category
  WHERE category_name = 'Dairy and Eggs';

  SELECT category_id INTO v_vegetable_category
  FROM food_category
  WHERE category_name = 'Vegetables';

  SELECT category_id INTO v_meat_category
  FROM food_category
  WHERE category_name = 'Meat and Poultry';

  SELECT source_id INTO v_estimate_source
  FROM data_source
  WHERE source_name = 'Estimated_Common'
  LIMIT 1;

  IF v_dairy_category IS NULL OR v_vegetable_category IS NULL OR v_meat_category IS NULL THEN
    RAISE EXCEPTION 'Food categories required for meal add-ons are missing';
  END IF;

  IF v_estimate_source IS NULL THEN
    RAISE EXCEPTION 'Estimated_Common nutrition source is required';
  END IF;

  SELECT source_id INTO v_usda_source
  FROM data_source
  WHERE source_name = 'USDA_FDC'
  LIMIT 1;

  IF v_usda_source IS NULL THEN
    INSERT INTO data_source (source_name, source_type, source_reference)
    VALUES (
      'USDA_FDC',
      'Public Database',
      'USDA FoodData Central SR Legacy; cheddar FDC 170899, raw tomato FDC 170457'
    )
    RETURNING source_id INTO v_usda_source;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM food_item WHERE normalized_name = 'cheddar cheese'
  ) THEN
    v_food_id := gen_random_uuid();
    INSERT INTO food_item (
      food_id, category_id, food_name, normalized_name,
      is_local_food, is_official, is_active
    ) VALUES (
      v_food_id, v_dairy_category, 'Cheddar Cheese', 'cheddar cheese',
      FALSE, TRUE, TRUE
    );

    v_serving_id := gen_random_uuid();
    INSERT INTO food_serving (
      serving_id, food_id, serving_label, serving_grams, is_default, is_active
    ) VALUES (
      v_serving_id, v_food_id, '1 slice (28g)', 28, TRUE, TRUE
    );

    INSERT INTO food_nutrition_profile (
      food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active
    ) VALUES (
      v_food_id, v_serving_id, v_usda_source, 115, 6.8, 0.6, 9.5, TRUE
    );

    INSERT INTO food_price (
      food_id, serving_id, source_id, estimated_price_php, is_active
    ) VALUES (
      v_food_id, v_serving_id, v_estimate_source, 20, TRUE
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM food_item WHERE normalized_name = 'tomato kamatis raw'
  ) THEN
    v_food_id := gen_random_uuid();
    INSERT INTO food_item (
      food_id, category_id, food_name, normalized_name,
      is_local_food, is_official, is_active
    ) VALUES (
      v_food_id, v_vegetable_category, 'Tomato (Kamatis, raw)', 'tomato kamatis raw',
      FALSE, TRUE, TRUE
    );

    v_serving_id := gen_random_uuid();
    INSERT INTO food_serving (
      serving_id, food_id, serving_label, serving_grams, is_default, is_active
    ) VALUES (
      v_serving_id, v_food_id, '1 medium tomato (123g)', 123, TRUE, TRUE
    );

    INSERT INTO food_nutrition_profile (
      food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active
    ) VALUES (
      v_food_id, v_serving_id, v_usda_source, 22, 1.1, 4.8, 0.2, TRUE
    );

    INSERT INTO food_price (
      food_id, serving_id, source_id, estimated_price_php, is_active
    ) VALUES (
      v_food_id, v_serving_id, v_estimate_source, 10, TRUE
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM food_item WHERE normalized_name = 'beef caldereta kaldereta'
  ) THEN
    v_food_id := gen_random_uuid();
    INSERT INTO food_item (
      food_id, category_id, food_name, normalized_name,
      is_local_food, is_official, is_active
    ) VALUES (
      v_food_id, v_meat_category, 'Beef Caldereta (Kaldereta)', 'beef caldereta kaldereta',
      TRUE, TRUE, TRUE
    );

    v_serving_id := gen_random_uuid();
    INSERT INTO food_serving (
      serving_id, food_id, serving_label, serving_grams, is_default, is_active
    ) VALUES (
      v_serving_id, v_food_id, '1 cup (250g, estimated)', 250, TRUE, TRUE
    );

    INSERT INTO food_nutrition_profile (
      food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active
    ) VALUES (
      v_food_id, v_serving_id, v_estimate_source, 420, 26, 18, 28, TRUE
    );

    INSERT INTO food_price (
      food_id, serving_id, source_id, estimated_price_php, is_active
    ) VALUES (
      v_food_id, v_serving_id, v_estimate_source, 90, TRUE
    );
  END IF;
END;
$$;
