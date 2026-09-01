-- AI-assisted nutrition review, canonical preference codes, and food meal tags.

ALTER TABLE public.allergy
  ADD COLUMN IF NOT EXISTS allergy_code TEXT;

UPDATE public.allergy
SET allergy_code = CASE lower(allergy_name)
  WHEN 'peanut' THEN 'peanut'
  WHEN 'tree nut' THEN 'tree_nut'
  WHEN 'milk' THEN 'milk'
  WHEN 'egg' THEN 'egg'
  WHEN 'fish' THEN 'fish'
  WHEN 'shellfish' THEN 'shellfish'
  WHEN 'soy' THEN 'soy'
  WHEN 'wheat' THEN 'wheat'
  WHEN 'gluten' THEN 'gluten'
  WHEN 'sesame' THEN 'sesame'
  WHEN 'sulfite' THEN 'sulfite'
  WHEN 'corn' THEN 'corn'
  ELSE regexp_replace(lower(allergy_name), '[^a-z0-9]+', '_', 'g')
END
WHERE allergy_code IS NULL;

ALTER TABLE public.allergy
  ALTER COLUMN allergy_code SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_allergy_code
  ON public.allergy(allergy_code);

ALTER TABLE public.dietary_restriction
  ADD COLUMN IF NOT EXISTS restriction_code TEXT;

UPDATE public.dietary_restriction
SET restriction_code = CASE lower(restriction_name)
  WHEN 'vegetarian' THEN 'vegetarian'
  WHEN 'vegan' THEN 'vegan'
  WHEN 'lactose intolerant' THEN 'lactose_intolerant'
  WHEN 'gluten-free' THEN 'gluten_free'
  WHEN 'low carb' THEN 'low_carb'
  WHEN 'low sodium' THEN 'low_sodium'
  WHEN 'diabetic-friendly' THEN 'diabetic'
  WHEN 'halal' THEN 'halal'
  WHEN 'no pork' THEN 'no_pork'
  WHEN 'no beef' THEN 'no_beef'
  ELSE regexp_replace(lower(restriction_name), '[^a-z0-9]+', '_', 'g')
END
WHERE restriction_code IS NULL;

ALTER TABLE public.dietary_restriction
  ALTER COLUMN restriction_code SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_dietary_restriction_code
  ON public.dietary_restriction(restriction_code);

-- These policy tables are read-only reference data. The live project advisor
-- currently reports them as public without RLS, so close that exposure here.
ALTER TABLE public.goal_calorie_policy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_macro_policy ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.goal_calorie_policy, public.goal_macro_policy
  FROM anon, authenticated;
GRANT SELECT ON TABLE public.goal_calorie_policy, public.goal_macro_policy
  TO authenticated;
DROP POLICY IF EXISTS goal_calorie_policy_select
  ON public.goal_calorie_policy;
DROP POLICY IF EXISTS goal_macro_policy_select
  ON public.goal_macro_policy;
CREATE POLICY goal_calorie_policy_select
ON public.goal_calorie_policy FOR SELECT
TO authenticated
USING (is_active = TRUE);
CREATE POLICY goal_macro_policy_select
ON public.goal_macro_policy FOR SELECT
TO authenticated
USING (is_active = TRUE);

CREATE TABLE IF NOT EXISTS public.food_meal_type (
  food_id UUID NOT NULL REFERENCES public.food_item(food_id) ON DELETE CASCADE,
  meal_type_id SMALLINT NOT NULL REFERENCES public.meal_type(meal_type_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (food_id, meal_type_id)
);

CREATE INDEX IF NOT EXISTS idx_food_meal_type_meal
  ON public.food_meal_type(meal_type_id, food_id);

INSERT INTO public.food_meal_type (food_id, meal_type_id)
SELECT f.food_id, mt.meal_type_id
FROM public.food_item f
JOIN public.food_category c ON c.category_id = f.category_id
JOIN public.meal_type mt ON (
  (mt.meal_type_code = 'breakfast' AND c.category_name IN (
    'Rice and Grains', 'Dairy and Eggs', 'Bread and Pastry',
    'Soups and Porridge', 'Fruits', 'Beverages'
  ))
  OR (mt.meal_type_code IN ('lunch', 'dinner') AND c.category_name IN (
    'Rice and Grains', 'Meat and Poultry', 'Seafood', 'Vegetables',
    'Soups and Porridge', 'Legumes and Tofu', 'Condiments and Spreads'
  ))
  OR (mt.meal_type_code = 'snack' AND c.category_name IN (
    'Fruits', 'Dairy and Eggs', 'Bread and Pastry', 'Beverages',
    'Snacks and Desserts', 'Condiments and Spreads'
  ))
  OR (mt.meal_type_code = 'breakfast' AND lower(f.food_name) ~
    '(tocino|longganisa|tapa|corned beef|hotdog)')
)
ON CONFLICT DO NOTHING;

ALTER TABLE public.food_meal_type ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.food_meal_type
  FROM anon, authenticated;

DROP POLICY IF EXISTS food_meal_type_select_visible
  ON public.food_meal_type;
CREATE POLICY food_meal_type_select_visible
ON public.food_meal_type FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.food_item f
    WHERE f.food_id = food_meal_type.food_id
      AND (f.is_active = TRUE OR public.is_admin())
      AND (
        f.is_official = TRUE
        OR f.owner_user_id = public.get_app_user_id()
        OR public.is_admin()
      )
  )
);

DROP POLICY IF EXISTS food_meal_type_admin_insert
  ON public.food_meal_type;
CREATE POLICY food_meal_type_admin_insert
ON public.food_meal_type FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS food_meal_type_admin_delete
  ON public.food_meal_type;
CREATE POLICY food_meal_type_admin_delete
ON public.food_meal_type FOR DELETE
TO authenticated
USING (public.is_admin());

GRANT SELECT ON public.food_meal_type TO authenticated;

INSERT INTO public.data_source (source_name, source_type, source_reference)
SELECT 'AI_Web_Research', 'AI-assisted',
  'Administrator-reviewed nutrition estimate with retained web evidence'
WHERE NOT EXISTS (
  SELECT 1 FROM public.data_source WHERE source_name = 'AI_Web_Research'
);

CREATE TABLE IF NOT EXISTS public.food_nutrition_evidence (
  evidence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  estimate_id UUID NOT NULL,
  nutrition_profile_id UUID NOT NULL
    REFERENCES public.food_nutrition_profile(nutrition_profile_id)
    ON DELETE CASCADE,
  source_title TEXT NOT NULL,
  source_url TEXT NOT NULL CHECK (source_url ~* '^https?://'),
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  provider TEXT NOT NULL,
  model_name TEXT,
  retrieved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  approved_by_user_id UUID NOT NULL REFERENCES public.app_user(user_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (estimate_id, source_url)
);

CREATE INDEX IF NOT EXISTS idx_food_nutrition_evidence_profile
  ON public.food_nutrition_evidence(nutrition_profile_id);

ALTER TABLE public.food_nutrition_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.food_nutrition_evidence
  FROM anon, authenticated;

DROP POLICY IF EXISTS food_nutrition_evidence_admin_select
  ON public.food_nutrition_evidence;
CREATE POLICY food_nutrition_evidence_admin_select
ON public.food_nutrition_evidence FOR SELECT
TO authenticated
USING (public.is_admin());

GRANT SELECT ON public.food_nutrition_evidence TO authenticated;

ALTER TABLE public.recommendation_session
  ADD COLUMN IF NOT EXISTS meal_type_id SMALLINT
    REFERENCES public.meal_type(meal_type_id),
  ADD COLUMN IF NOT EXISTS fitness_goal_id SMALLINT
    REFERENCES public.fitness_goal(fitness_goal_id),
  ADD COLUMN IF NOT EXISTS minimum_price_php NUMERIC(8,2)
    CHECK (minimum_price_php IS NULL OR minimum_price_php >= 0),
  ADD COLUMN IF NOT EXISTS maximum_price_php NUMERIC(8,2)
    CHECK (maximum_price_php IS NULL OR maximum_price_php >= 0);
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.recommendation_session'::regclass
      AND conname = 'recommendation_price_range_valid'
  ) THEN
    ALTER TABLE public.recommendation_session
      ADD CONSTRAINT recommendation_price_range_valid
      CHECK (
        minimum_price_php IS NULL
        OR maximum_price_php IS NULL
        OR minimum_price_php <= maximum_price_php
      );
  END IF;
END;
$$;

DROP POLICY IF EXISTS rec_item_update_own
  ON public.recommendation_item;
CREATE POLICY rec_item_update_own
ON public.recommendation_item FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.recommendation_session rs
    WHERE rs.session_id = recommendation_item.session_id
      AND rs.user_id = public.get_app_user_id()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.recommendation_session rs
    WHERE rs.session_id = recommendation_item.session_id
      AND rs.user_id = public.get_app_user_id()
  )
);

CREATE OR REPLACE VIEW public.food_catalog
WITH (security_invoker = true)
AS
SELECT f.food_id, c.category_name, f.owner_user_id, f.food_name,
  f.normalized_name, f.is_local_food, f.is_official, f.is_active,
  s.serving_id, s.serving_label, s.serving_grams,
  n.calories, n.protein_g, n.carbs_g, n.fat_g,
  COALESCE(p.estimated_price_php, 0) AS estimated_price_php,
  f.created_at, f.updated_at, f.subcategory, f.description,
  ARRAY(
    SELECT mt.meal_type_code
    FROM public.food_meal_type fmt
    JOIN public.meal_type mt ON mt.meal_type_id = fmt.meal_type_id
    WHERE fmt.food_id = f.food_id
    ORDER BY mt.meal_type_id
  ) AS meal_type_codes
FROM public.food_item f
JOIN public.food_category c ON c.category_id = f.category_id
JOIN public.food_serving s
  ON s.food_id = f.food_id AND s.is_default AND s.is_active
JOIN public.food_nutrition_profile n
  ON n.food_id = f.food_id AND n.serving_id = s.serving_id AND n.is_active
LEFT JOIN public.food_price p
  ON p.food_id = f.food_id AND p.serving_id = s.serving_id AND p.is_active
WHERE f.is_active;

GRANT SELECT ON public.food_catalog TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_upsert_food_with_evidence(
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
  p_price_php NUMERIC,
  p_meal_type_codes TEXT[],
  p_estimate_id UUID DEFAULT NULL,
  p_estimate_provider TEXT DEFAULT NULL,
  p_evidence JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_user_id UUID;
  v_category_id SMALLINT;
  v_nutrition_source_id SMALLINT;
  v_price_source_id SMALLINT;
  v_nutrition_profile_id UUID;
  v_current_calories NUMERIC;
  v_current_protein NUMERIC;
  v_current_carbs NUMERIC;
  v_current_fat NUMERIC;
  v_current_price NUMERIC;
  v_current_price_serving_id UUID;
  v_old_food JSONB;
  v_evidence JSONB;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can manage official foods';
  END IF;

  IF p_serving_grams <= 0 OR p_calories < 0 OR p_protein_g < 0
     OR p_carbs_g < 0 OR p_fat_g < 0 OR p_price_php < 0 THEN
    RAISE EXCEPTION 'Food nutrition, serving, and price values are invalid';
  END IF;

  SELECT user_id INTO v_admin_user_id
  FROM public.app_user
  WHERE auth_user_id = auth.uid()::UUID;

  SELECT category_id INTO v_category_id
  FROM public.food_category
  WHERE category_name = p_category_name AND is_active = TRUE;
  IF v_category_id IS NULL THEN
    RAISE EXCEPTION 'Food category is not configured: %', p_category_name;
  END IF;

  SELECT source_id INTO v_nutrition_source_id
  FROM public.data_source
  WHERE source_name = CASE
    WHEN p_estimate_provider = 'openai' THEN 'AI_Web_Research'
    WHEN p_estimate_provider IS NOT NULL THEN 'Estimated_Common'
    WHEN p_is_official THEN 'FNRI_DOST'
    ELSE 'Estimated_Common'
  END
  ORDER BY source_id
  LIMIT 1;

  SELECT source_id INTO v_price_source_id
  FROM public.data_source
  WHERE source_name = 'Estimated_Common'
  ORDER BY source_id
  LIMIT 1;

  IF v_nutrition_source_id IS NULL OR v_price_source_id IS NULL THEN
    RAISE EXCEPTION 'Required food data sources are not configured';
  END IF;

  SELECT jsonb_build_object(
    'food_name', f.food_name,
    'subcategory', f.subcategory,
    'description', f.description,
    'is_local_food', f.is_local_food,
    'is_official', f.is_official,
    'is_active', f.is_active
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

  SELECT nutrition_profile_id, calories, protein_g, carbs_g, fat_g
  INTO v_nutrition_profile_id, v_current_calories, v_current_protein,
       v_current_carbs, v_current_fat
  FROM public.food_nutrition_profile
  WHERE food_id = p_food_id AND serving_id = p_serving_id AND is_active = TRUE
  ORDER BY effective_from DESC
  LIMIT 1;

  IF v_nutrition_profile_id IS NULL
     OR v_current_calories IS DISTINCT FROM p_calories
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
      p_food_id, p_serving_id, v_nutrition_source_id, p_calories,
      p_protein_g, p_carbs_g, p_fat_g, TRUE, v_now
    ) RETURNING nutrition_profile_id INTO v_nutrition_profile_id;
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
      p_food_id, p_serving_id, v_price_source_id, p_price_php, TRUE, v_now
    );
  END IF;

  DELETE FROM public.food_meal_type WHERE food_id = p_food_id;
  INSERT INTO public.food_meal_type (food_id, meal_type_id)
  SELECT p_food_id, mt.meal_type_id
  FROM public.meal_type mt
  WHERE mt.meal_type_code = ANY(COALESCE(p_meal_type_codes, ARRAY[]::TEXT[]))
  ON CONFLICT DO NOTHING;

  IF p_estimate_id IS NOT NULL THEN
    FOR v_evidence IN SELECT * FROM jsonb_array_elements(COALESCE(p_evidence, '[]'))
    LOOP
      IF COALESCE(v_evidence->>'url', '') ~* '^https?://' THEN
        INSERT INTO public.food_nutrition_evidence (
          estimate_id, nutrition_profile_id, source_title, source_url,
          is_primary, provider, model_name, approved_by_user_id
        ) VALUES (
          p_estimate_id,
          v_nutrition_profile_id,
          COALESCE(v_evidence->>'title', v_evidence->>'url'),
          v_evidence->>'url',
          CASE
            WHEN lower(COALESCE(v_evidence->>'is_primary', 'false')) = 'true'
              THEN TRUE
            ELSE FALSE
          END,
          COALESCE(v_evidence->>'provider', 'openai'),
          v_evidence->>'model',
          v_admin_user_id
        )
        ON CONFLICT (estimate_id, source_url) DO UPDATE SET
          source_title = EXCLUDED.source_title,
          is_primary = EXCLUDED.is_primary,
          model_name = EXCLUDED.model_name;
      END IF;
    END LOOP;
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
      'estimated_price_php', p_price_php,
      'meal_type_codes', p_meal_type_codes,
      'estimate_id', p_estimate_id,
      'estimate_provider', p_estimate_provider
    ),
    v_now
  );

  RETURN jsonb_build_object(
    'food_id', p_food_id,
    'serving_id', p_serving_id,
    'nutrition_profile_id', v_nutrition_profile_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_food_with_evidence(
  uuid, text, text, text, text, text, boolean, boolean, boolean,
  uuid, text, numeric, numeric, numeric, numeric, numeric, numeric,
  text[], uuid, text, jsonb
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_upsert_food_with_evidence(
  uuid, text, text, text, text, text, boolean, boolean, boolean,
  uuid, text, numeric, numeric, numeric, numeric, numeric, numeric,
  text[], uuid, text, jsonb
) TO authenticated;
