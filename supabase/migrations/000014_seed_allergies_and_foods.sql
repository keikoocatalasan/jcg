-- 000014: Seed allergies, dietary restrictions, and Filipino food database

-- ALLERGY
INSERT INTO ALLERGY (allergy_name, is_active) VALUES
  ('Peanut', TRUE),
  ('Tree Nut', TRUE),
  ('Milk', TRUE),
  ('Egg', TRUE),
  ('Fish', TRUE),
  ('Shellfish', TRUE),
  ('Soy', TRUE),
  ('Wheat', TRUE),
  ('Gluten', TRUE),
  ('Sesame', TRUE),
  ('Sulfite', TRUE),
  ('Corn', TRUE);

-- DIETARY_RESTRICTION
INSERT INTO DIETARY_RESTRICTION (restriction_name, is_active) VALUES
  ('Vegetarian', TRUE),
  ('Vegan', TRUE),
  ('Lactose Intolerant', TRUE),
  ('Gluten-Free', TRUE),
  ('Low Carb', TRUE),
  ('Low Sodium', TRUE),
  ('Diabetic-Friendly', TRUE),
  ('Halal', TRUE),
  ('No Pork', TRUE),
  ('No Beef', TRUE);

-- ===== FOOD SEED DATA =====
-- Each food item gets one active default serving, one active nutrition profile, and one active price.
-- Using DATA_SOURCE source_id 1 (FNRI_DOST) for official, 2 (Estimated_Common) for estimated values.

-- Helper function
CREATE OR REPLACE FUNCTION get_category_id(cat_name TEXT) RETURNS SMALLINT LANGUAGE SQL AS $$
  SELECT category_id FROM FOOD_CATEGORY WHERE category_name = cat_name;
$$;

-- Helper variables (using PL/pgSQL block to set them once)
DO $$
DECLARE
  v_rice_cat SMALLINT; v_meat_cat SMALLINT; v_seafood_cat SMALLINT;
  v_veg_cat SMALLINT; v_fruit_cat SMALLINT; v_dairy_cat SMALLINT;
  v_bread_cat SMALLINT; v_soup_cat SMALLINT; v_snack_cat SMALLINT;
  v_legume_cat SMALLINT; v_condiment_cat SMALLINT;
  v_fnri_source SMALLINT := 1; v_est_source SMALLINT := 2;
  v_food_id UUID;
BEGIN
  SELECT category_id INTO v_rice_cat FROM FOOD_CATEGORY WHERE category_name = 'Rice and Grains';
  SELECT category_id INTO v_meat_cat FROM FOOD_CATEGORY WHERE category_name = 'Meat and Poultry';
  SELECT category_id INTO v_seafood_cat FROM FOOD_CATEGORY WHERE category_name = 'Seafood';
  SELECT category_id INTO v_veg_cat FROM FOOD_CATEGORY WHERE category_name = 'Vegetables';
  SELECT category_id INTO v_fruit_cat FROM FOOD_CATEGORY WHERE category_name = 'Fruits';
  SELECT category_id INTO v_dairy_cat FROM FOOD_CATEGORY WHERE category_name = 'Dairy and Eggs';
  SELECT category_id INTO v_bread_cat FROM FOOD_CATEGORY WHERE category_name = 'Bread and Pastry';
  SELECT category_id INTO v_soup_cat FROM FOOD_CATEGORY WHERE category_name = 'Soups and Porridge';
  SELECT category_id INTO v_snack_cat FROM FOOD_CATEGORY WHERE category_name = 'Snacks and Desserts';
  SELECT category_id INTO v_legume_cat FROM FOOD_CATEGORY WHERE category_name = 'Legumes and Tofu';
  SELECT category_id INTO v_condiment_cat FROM FOOD_CATEGORY WHERE category_name = 'Condiments and Spreads';

  -- 1. Rice (cooked)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_rice_cat, 'Rice (cooked)', 'rice cooked', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup cooked', 150, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 205, 4.3, 45, 0.4, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 15, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 2. Boiled Egg
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_dairy_cat, 'Boiled Egg', 'boiled egg', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 piece', 50, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 78, 6.3, 0.6, 5.3, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 12, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 3. Fried Egg
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_dairy_cat, 'Fried Egg', 'fried egg', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 piece', 55, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 110, 6.8, 0.8, 8.5, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 15, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 4. Chicken Breast (skinless, cooked)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Chicken Breast (skinless)', 'chicken breast skinless', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 piece (150g)', 150, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 247, 46.5, 0, 5.3, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 55, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 5. Chicken Adobo
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Chicken Adobo', 'chicken adobo', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 430, 35, 8, 28, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 65, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 6. Pork Adobo
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Pork Adobo', 'pork adobo', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 520, 28, 6, 42, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 60, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 7. Tinolang Manok
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_soup_cat, 'Tinolang Manok', 'tinolang manok', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 bowl', 300, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 280, 25, 12, 15, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 55, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 8. Sinigang na Baboy
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_soup_cat, 'Sinigang na Baboy', 'sinigang na baboy', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 bowl', 350, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 380, 22, 15, 26, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 65, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 9. Sinigang na Isda
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_soup_cat, 'Sinigang na Isda', 'sinigang na isda', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 bowl', 350, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 250, 28, 10, 10, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 55, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 10. Ginisang Monggo
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_legume_cat, 'Ginisang Monggo', 'ginisang monggo', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 260, 15, 35, 8, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 35, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 11. Tortang Talong
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_veg_cat, 'Tortang Talong', 'tortang talong', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 piece (150g)', 150, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 180, 8, 6, 14, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 25, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 12. Sardines (canned, in oil)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_seafood_cat, 'Sardines (canned)', 'sardines canned', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 can (155g)', 155, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 310, 28, 0, 22, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 25, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 13. Tuna (canned, in water)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_seafood_cat, 'Tuna (canned, water)', 'tuna canned water', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 can (180g)', 180, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 220, 44, 0, 3.6, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 35, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 14. Tofu (firm)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_legume_cat, 'Tofu (firm)', 'tofu firm', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '100g', 100, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 145, 17, 3, 8.7, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 15, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 15. Tokwa (fried tofu)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_legume_cat, 'Tokwa (fried tofu)', 'tokwa fried tofu', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 piece (50g)', 50, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 120, 10, 2, 8, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 10, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 16. Grilled Bangus (milkfish)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_seafood_cat, 'Grilled Bangus', 'grilled bangus', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 piece (200g)', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 350, 32, 0, 24, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 70, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 17. Fried Bangus
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_seafood_cat, 'Fried Bangus', 'fried bangus', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 piece (180g)', 180, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 380, 28, 4, 28, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 65, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 18. Oatmeal (cooked)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_rice_cat, 'Oatmeal (cooked)', 'oatmeal cooked', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup cooked', 240, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 166, 5.9, 28, 3.6, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 15, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 19. Banana (medium)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_fruit_cat, 'Banana (medium)', 'banana medium', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 medium (120g)', 120, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 105, 1.3, 27, 0.4, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 5, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 20. Kamote (sweet potato, medium)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_veg_cat, 'Kamote (sweet potato)', 'kamote sweet potato', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 medium (150g)', 150, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 130, 2, 30, 0.2, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 20, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 21. Peanut Butter (2 tbsp)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_condiment_cat, 'Peanut Butter', 'peanut butter', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '2 tbsp (32g)', 32, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 190, 8, 7, 16, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 12, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 22. Menudo
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Menudo', 'menudo', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 420, 22, 20, 28, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 60, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 23. Pinakbet
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_veg_cat, 'Pinakbet', 'pinakbet', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 180, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 160, 6, 15, 9, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 35, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 24. Laing
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_veg_cat, 'Laing', 'laing', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 180, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 200, 3, 8, 18, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 40, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 25. Pancit Canton
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_snack_cat, 'Pancit Canton', 'pancit canton', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 340, 10, 45, 14, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 45, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 26. Lumpiang Gulay
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_snack_cat, 'Lumpiang Gulay', 'lumpiang gulay', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '2 pieces', 150, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 200, 5, 22, 10, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 20, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 27. Beef Tapa
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Beef Tapa', 'beef tapa', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 serving (100g)', 100, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 250, 24, 8, 14, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 50, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 28. Longganisa
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Longganisa', 'longganisa', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '2 pieces (100g)', 100, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 310, 14, 8, 25, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 25, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 29. Tocino
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Tocino', 'tocino', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 serving (100g)', 100, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 340, 12, 18, 24, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 30, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 30. Giniling (ground pork stew)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Giniling (ground pork)', 'giniling ground pork', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 400, 24, 15, 26, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 55, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 31. Nilagang Baka
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_soup_cat, 'Nilagang Baka', 'nilagang baka', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 bowl', 350, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 350, 30, 18, 18, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 70, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 32. Chopsuey
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_veg_cat, 'Chopsuey', 'chopsuey', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 180, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 150, 6, 14, 8, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 40, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 33. Bicol Express
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Bicol Express', 'bicol express', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 380, 18, 6, 32, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 55, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 34. Grilled Tilapia
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_seafood_cat, 'Grilled Tilapia', 'grilled tilapia', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 piece (200g)', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 260, 42, 0, 9, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 50, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 35. Ensaladang Talong
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_veg_cat, 'Ensaladang Talong', 'ensaladang talong', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 serving', 150, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 120, 4, 8, 8, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 25, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 36. Malunggay Soup
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_soup_cat, 'Malunggay Soup', 'malunggay soup', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 bowl', 250, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 90, 5, 8, 4, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 25, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 37. Chicken Afritada
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Chicken Afritada', 'chicken afritada', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 350, 28, 15, 20, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 55, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 38. Pork Steak (Bistek)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Pork Steak (Bistek)', 'pork steak bistek', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 450, 26, 10, 34, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 55, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 39. Arroz Caldo
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_soup_cat, 'Arroz Caldo', 'arroz caldo', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 bowl', 300, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 310, 14, 40, 10, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 45, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 40. Lugaw
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_soup_cat, 'Lugaw', 'lugaw', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 bowl', 300, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 220, 6, 40, 4, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 35, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 41. Champorado
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_snack_cat, 'Champorado', 'champorado', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 bowl', 300, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 320, 8, 55, 8, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 30, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 42. Pandesal
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_bread_cat, 'Pandesal', 'pandesal', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 piece', 30, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 85, 2.5, 15, 1.5, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 3, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 43. Whole Wheat Bread
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_bread_cat, 'Whole Wheat Bread', 'whole wheat bread', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 slice', 30, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 70, 3, 12, 1, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 5, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 44. Fresh Milk (whole)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_dairy_cat, 'Fresh Milk (whole)', 'fresh milk whole', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup (250ml)', 250, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 150, 8, 12, 8, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 25, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 45. Yogurt (plain)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_dairy_cat, 'Yogurt (plain)', 'yogurt plain', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup (200g)', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 100, 10, 7, 3, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 35, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 46. Apple (medium)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_fruit_cat, 'Apple (medium)', 'apple medium', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 medium (180g)', 180, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 95, 0.5, 25, 0.3, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 25, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 47. Orange (medium)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_fruit_cat, 'Orange (medium)', 'orange medium', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 medium (150g)', 150, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 62, 1.2, 15, 0.2, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 20, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 48. Cucumber
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_veg_cat, 'Cucumber', 'cucumber', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup sliced', 100, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 16, 0.7, 3, 0.1, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 10, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 49. Cabbage
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_veg_cat, 'Cabbage', 'cabbage', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup shredded', 100, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 25, 1.3, 5, 0.1, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 12, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 50. Chicken Curry
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_meat_cat, 'Chicken Curry', 'chicken curry', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup', 200, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 400, 30, 12, 26, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 60, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 51. Fried Tilapia
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_seafood_cat, 'Fried Tilapia', 'fried tilapia', TRUE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 piece (180g)', 180, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_est_source, 320, 36, 4, 18, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 50, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

  -- 52. Milk (evaporated)
  v_food_id := gen_random_uuid();
  INSERT INTO FOOD_ITEM (food_id, category_id, food_name, normalized_name, is_local_food, is_official, is_active)
    VALUES (v_food_id, v_dairy_cat, 'Milk (evaporated)', 'milk evaporated', FALSE, TRUE, TRUE);
  INSERT INTO FOOD_SERVING (food_id, serving_label, serving_grams, is_default, is_active)
    VALUES (v_food_id, '1 cup (250ml)', 250, TRUE, TRUE);
  INSERT INTO FOOD_NUTRITION_PROFILE (food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g, is_active)
    SELECT food_id, serving_id, v_fnri_source, 170, 8.5, 12, 10, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;
  INSERT INTO FOOD_PRICE (food_id, serving_id, source_id, estimated_price_php, is_active)
    SELECT food_id, serving_id, v_est_source, 20, TRUE FROM FOOD_SERVING WHERE food_id = v_food_id AND is_default = TRUE;

END;
$$;
