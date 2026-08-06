-- 000036: Atomic admin food writes with immutable nutrition/price history.

CREATE OR REPLACE FUNCTION public.admin_upsert_food(
  p_food_id UUID,
  p_category_name TEXT,
  p_subcategory TEXT,
  p_description TEXT,
  p_food_name TEXT,
  p_normalized_name TEXT,
  p_is_local_food BOOLEAN,
  p_is_official BOOLEAN,
  p_is_active BOOLEAN,
  p_serving_id UUID,
  p_serving_label TEXT,
  p_serving_grams NUMERIC,
  p_calories NUMERIC,
  p_protein_g NUMERIC,
  p_carbs_g NUMERIC,
  p_fat_g NUMERIC,
  p_price_php NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_user_id UUID;
  v_category_id SMALLINT;
  v_source_id SMALLINT;
  v_old_food JSONB;
  v_current_price NUMERIC;
  v_current_price_serving_id UUID;
  v_current_calories NUMERIC;
  v_current_protein NUMERIC;
  v_current_carbs NUMERIC;
  v_current_fat NUMERIC;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can manage official foods';
  END IF;

  SELECT user_id INTO v_admin_user_id
  FROM public.app_user
  WHERE auth_user_id = auth.uid()::UUID;

  SELECT category_id INTO v_category_id
  FROM public.food_category
  WHERE category_name = p_category_name
    AND is_active = TRUE;

  IF v_category_id IS NULL THEN
    RAISE EXCEPTION 'Food category is not configured: %', p_category_name;
  END IF;

  SELECT source_id INTO v_source_id
  FROM public.data_source
  WHERE source_name = CASE
    WHEN p_is_official THEN 'FNRI_DOST'
    ELSE 'Estimated_Common'
  END;

  IF v_source_id IS NULL THEN
    RAISE EXCEPTION 'Food data source is not configured';
  END IF;

  SELECT jsonb_build_object(
    'food_name', f.food_name,
    'subcategory', f.subcategory,
    'description', f.description,
    'is_local_food', f.is_local_food,
    'is_official', f.is_official,
    'is_active', f.is_active,
    'estimated_price_php', (
      SELECT fp.estimated_price_php
      FROM public.food_price fp
      WHERE fp.food_id = f.food_id AND fp.is_active = TRUE
      ORDER BY fp.effective_from DESC
      LIMIT 1
    )
  ) INTO v_old_food
  FROM public.food_item f
  WHERE f.food_id = p_food_id;

  INSERT INTO public.food_item (
    food_id, category_id, owner_user_id, food_name, normalized_name,
    is_local_food, is_official, is_active, subcategory, description
  ) VALUES (
    p_food_id, v_category_id, v_admin_user_id, p_food_name, p_normalized_name,
    p_is_local_food, p_is_official, p_is_active, p_subcategory, p_description
  )
  ON CONFLICT (food_id) DO UPDATE SET
    category_id = EXCLUDED.category_id,
    food_name = EXCLUDED.food_name,
    normalized_name = EXCLUDED.normalized_name,
    is_local_food = EXCLUDED.is_local_food,
    is_official = EXCLUDED.is_official,
    is_active = EXCLUDED.is_active,
    subcategory = EXCLUDED.subcategory,
    description = EXCLUDED.description;

  IF EXISTS (
    SELECT 1 FROM public.food_serving
    WHERE serving_id = p_serving_id AND food_id <> p_food_id
  ) THEN
    RAISE EXCEPTION 'Serving belongs to another food item';
  END IF;

  UPDATE public.food_serving
  SET is_default = FALSE
  WHERE food_id = p_food_id AND serving_id <> p_serving_id;

  INSERT INTO public.food_serving (
    serving_id, food_id, serving_label, serving_grams, is_default, is_active
  ) VALUES (
    p_serving_id, p_food_id, p_serving_label, p_serving_grams, TRUE, TRUE
  )
  ON CONFLICT (serving_id) DO UPDATE SET
    serving_label = EXCLUDED.serving_label,
    serving_grams = EXCLUDED.serving_grams,
    is_default = TRUE,
    is_active = TRUE;

  SELECT calories, protein_g, carbs_g, fat_g
  INTO v_current_calories, v_current_protein, v_current_carbs, v_current_fat
  FROM public.food_nutrition_profile
  WHERE food_id = p_food_id
    AND serving_id = p_serving_id
    AND is_active = TRUE
  ORDER BY effective_from DESC
  LIMIT 1;

  IF v_current_calories IS DISTINCT FROM p_calories
     OR v_current_protein IS DISTINCT FROM p_protein_g
     OR v_current_carbs IS DISTINCT FROM p_carbs_g
     OR v_current_fat IS DISTINCT FROM p_fat_g THEN
    UPDATE public.food_nutrition_profile
    SET is_active = FALSE, effective_to = v_now
    WHERE food_id = p_food_id AND is_active = TRUE;

    INSERT INTO public.food_nutrition_profile (
      food_id, serving_id, source_id, calories, protein_g, carbs_g, fat_g,
      is_active, effective_from
    ) VALUES (
      p_food_id, p_serving_id, v_source_id, p_calories, p_protein_g,
      p_carbs_g, p_fat_g, TRUE, v_now
    );
  END IF;

  SELECT estimated_price_php, serving_id
  INTO v_current_price, v_current_price_serving_id
  FROM public.food_price
  WHERE food_id = p_food_id AND is_active = TRUE
  ORDER BY effective_from DESC
  LIMIT 1;

  IF v_current_price IS DISTINCT FROM p_price_php
     OR v_current_price_serving_id IS DISTINCT FROM p_serving_id THEN
    UPDATE public.food_price
    SET is_active = FALSE, effective_to = v_now
    WHERE food_id = p_food_id AND is_active = TRUE;

    INSERT INTO public.food_price (
      food_id, serving_id, source_id, estimated_price_php,
      is_active, effective_from
    ) VALUES (
      p_food_id, p_serving_id, v_source_id, p_price_php, TRUE, v_now
    );
  END IF;

  INSERT INTO public.food_change_log (
    food_id, changed_by_user_id, change_type, old_value_json, new_value_json,
    changed_at
  ) VALUES (
    p_food_id,
    v_admin_user_id,
    CASE WHEN v_old_food IS NULL THEN 'create' ELSE 'update' END,
    v_old_food,
    jsonb_build_object(
      'food_name', p_food_name,
      'subcategory', p_subcategory,
      'description', p_description,
      'is_local_food', p_is_local_food,
      'is_official', p_is_official,
      'is_active', p_is_active,
      'serving_label', p_serving_label,
      'serving_grams', p_serving_grams,
      'calories', p_calories,
      'protein_g', p_protein_g,
      'carbs_g', p_carbs_g,
      'fat_g', p_fat_g,
      'estimated_price_php', p_price_php
    ),
    v_now
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_food(
  uuid, text, text, text, text, text, boolean, boolean, boolean,
  uuid, text, numeric, numeric, numeric, numeric, numeric, numeric
) TO authenticated;
