-- 20260922100000: Food nutrition verification, review workflow, reports, audit
--
-- Adds verification metadata and source provenance to the canonical nutrition
-- record (food_nutrition_profile), turns the legacy advisory review table into
-- the verification workflow record, adds the food-report queue and the
-- nutritionist action audit trail, and exposes verification metadata through
-- the food_catalog view.
--
-- Canonical values remain stored per serving. Reviews edit per-100 g values;
-- the RPC converts back to the serving basis using the linked serving grams so
-- the deterministic gram-scaling engine is unchanged.

-- ===== 1. Verification metadata on the canonical nutrition record =====
ALTER TABLE public.food_nutrition_profile
  ADD COLUMN IF NOT EXISTS verification_status TEXT NOT NULL
    DEFAULT 'unreviewed',
  ADD COLUMN IF NOT EXISTS nutrition_source_type TEXT,
  ADD COLUMN IF NOT EXISTS nutrition_source_name TEXT,
  ADD COLUMN IF NOT EXISTS nutrition_source_reference TEXT,
  ADD COLUMN IF NOT EXISTS source_checked_at DATE,
  ADD COLUMN IF NOT EXISTS source_notes TEXT,
  ADD COLUMN IF NOT EXISTS verified_by_user_id UUID
    REFERENCES public.app_user(user_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.food_nutrition_profile'::regclass
      AND conname = 'food_nutrition_verification_status_valid'
  ) THEN
    ALTER TABLE public.food_nutrition_profile
      ADD CONSTRAINT food_nutrition_verification_status_valid
      CHECK (verification_status IN (
        'unreviewed', 'in_review', 'verified', 'needs_revision',
        'rejected', 'archived'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.food_nutrition_profile'::regclass
      AND conname = 'food_nutrition_source_type_valid'
  ) THEN
    ALTER TABLE public.food_nutrition_profile
      ADD CONSTRAINT food_nutrition_source_type_valid
      CHECK (
        nutrition_source_type IS NULL
        OR nutrition_source_type IN (
          'philfct', 'manufacturer_label', 'recognized_source',
          'recipe_estimate', 'legacy_internal', 'unknown'
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.food_nutrition_profile'::regclass
      AND conname = 'food_nutrition_source_text_valid'
  ) THEN
    ALTER TABLE public.food_nutrition_profile
      ADD CONSTRAINT food_nutrition_source_text_valid
      CHECK (
        (nutrition_source_name IS NULL
          OR length(nutrition_source_name) <= 200)
        AND (nutrition_source_reference IS NULL
          OR length(nutrition_source_reference) <= 500)
        AND (source_notes IS NULL OR length(source_notes) <= 1000)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.food_nutrition_profile'::regclass
      AND conname = 'food_nutrition_verified_fields_valid'
  ) THEN
    ALTER TABLE public.food_nutrition_profile
      ADD CONSTRAINT food_nutrition_verified_fields_valid
      CHECK (
        verification_status <> 'verified'
        OR (verified_by_user_id IS NOT NULL AND verified_at IS NOT NULL)
      );
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_food_nutrition_verification
  ON public.food_nutrition_profile(verification_status)
  WHERE is_active = TRUE;

-- ===== 2. Review record becomes the verification workflow record =====
ALTER TABLE public.food_nutritionist_review
  ADD COLUMN IF NOT EXISTS decision TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'completed',
  ADD COLUMN IF NOT EXISTS review_note TEXT,
  ADD COLUMN IF NOT EXISTS source_type TEXT,
  ADD COLUMN IF NOT EXISTS source_name TEXT,
  ADD COLUMN IF NOT EXISTS source_reference TEXT,
  ADD COLUMN IF NOT EXISTS source_checked_at DATE,
  ADD COLUMN IF NOT EXISTS previous_values JSONB,
  ADD COLUMN IF NOT EXISTS proposed_values JSONB,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

ALTER TABLE public.food_nutritionist_review
  ALTER COLUMN serving_assessment DROP NOT NULL;
ALTER TABLE public.food_nutritionist_review
  ALTER COLUMN macro_assessment DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.food_nutritionist_review'::regclass
      AND conname = 'food_nutritionist_review_decision_valid'
  ) THEN
    ALTER TABLE public.food_nutritionist_review
      ADD CONSTRAINT food_nutritionist_review_decision_valid
      CHECK (
        decision IS NULL
        OR decision IN ('verified', 'needs_revision', 'rejected')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.food_nutritionist_review'::regclass
      AND conname = 'food_nutritionist_review_status_valid'
  ) THEN
    ALTER TABLE public.food_nutritionist_review
      ADD CONSTRAINT food_nutritionist_review_status_valid
      CHECK (status IN ('draft', 'completed', 'cancelled'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.food_nutritionist_review'::regclass
      AND conname = 'food_nutritionist_review_note_valid'
  ) THEN
    ALTER TABLE public.food_nutritionist_review
      ADD CONSTRAINT food_nutritionist_review_note_valid
      CHECK (review_note IS NULL OR length(review_note) <= 1200);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.food_nutritionist_review'::regclass
      AND conname = 'food_nutritionist_review_source_valid'
  ) THEN
    ALTER TABLE public.food_nutritionist_review
      ADD CONSTRAINT food_nutritionist_review_source_valid
      CHECK (
        (source_type IS NULL OR source_type IN (
          'philfct', 'manufacturer_label', 'recognized_source',
          'recipe_estimate', 'legacy_internal', 'unknown'
        ))
        AND (source_name IS NULL OR length(source_name) <= 200)
        AND (source_reference IS NULL
          OR length(source_reference) <= 500)
      );
  END IF;
END;
$$;

-- Read access to the new verification columns for signed-in clients (the
-- legacy grant is a column list, so new columns must be granted explicitly).
GRANT SELECT (
  review_id, nutrition_profile_id, food_id, serving_id,
  serving_assessment, macro_assessment, comment, created_at, updated_at,
  decision, status, review_note, source_type, source_name, source_reference,
  source_checked_at, previous_values, proposed_values, completed_at
) ON public.food_nutritionist_review TO authenticated;

-- ===== 3. Food-data reports =====
CREATE TABLE IF NOT EXISTS public.food_report (
  report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  food_id UUID NOT NULL
    REFERENCES public.food_item(food_id) ON DELETE CASCADE,
  nutrition_profile_id UUID
    REFERENCES public.food_nutrition_profile(nutrition_profile_id)
    ON DELETE SET NULL,
  reporter_user_id UUID NOT NULL
    REFERENCES public.app_user(user_id) ON DELETE CASCADE,
  issue_type TEXT NOT NULL CHECK (issue_type IN (
    'wrong_food', 'incorrect_nutrition', 'wrong_serving',
    'duplicate_food', 'missing_food', 'other'
  )),
  description TEXT,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_review', 'resolved', 'dismissed')),
  reviewed_by_user_id UUID
    REFERENCES public.app_user(user_id) ON DELETE SET NULL,
  resolution_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  CONSTRAINT food_report_description_valid
    CHECK (description IS NULL OR length(description) <= 1000),
  CONSTRAINT food_report_resolution_note_valid
    CHECK (resolution_note IS NULL OR length(resolution_note) <= 1000),
  CONSTRAINT food_report_resolution_state_valid
    CHECK ((status IN ('resolved', 'dismissed')) = (resolved_at IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_food_report_status
  ON public.food_report(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_food_report_food
  ON public.food_report(food_id);

DROP TRIGGER IF EXISTS trg_food_report_updated_at ON public.food_report;
CREATE TRIGGER trg_food_report_updated_at
  BEFORE UPDATE ON public.food_report
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE public.food_report ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.food_report FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.food_report TO authenticated;

DROP POLICY IF EXISTS food_report_select_own_reviewer_or_admin
  ON public.food_report;
CREATE POLICY food_report_select_own_reviewer_or_admin
  ON public.food_report FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR public.is_verified_nutritionist()
    OR reporter_user_id = public.get_app_user_id()
  );

-- ===== 4. Nutritionist action audit trail =====
CREATE TABLE IF NOT EXISTS public.nutritionist_action_log (
  action_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID NOT NULL
    REFERENCES public.app_user(user_id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (length(action) BETWEEN 2 AND 80),
  entity_type TEXT NOT NULL CHECK (length(entity_type) BETWEEN 2 AND 80),
  entity_id UUID,
  previous_values JSONB,
  new_values JSONB,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT nutritionist_action_log_reason_valid
    CHECK (reason IS NULL OR length(reason) <= 1000)
);

CREATE INDEX IF NOT EXISTS idx_nutritionist_action_log_actor
  ON public.nutritionist_action_log(actor_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_nutritionist_action_log_entity
  ON public.nutritionist_action_log(entity_type, entity_id);

ALTER TABLE public.nutritionist_action_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.nutritionist_action_log
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.nutritionist_action_log TO authenticated;

DROP POLICY IF EXISTS nutritionist_action_log_select_actor_or_admin
  ON public.nutritionist_action_log;
CREATE POLICY nutritionist_action_log_select_actor_or_admin
  ON public.nutritionist_action_log FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR actor_user_id = public.get_app_user_id()
  );

-- ===== 5. Begin a review draft =====
CREATE OR REPLACE FUNCTION public.nutritionist_begin_review(
  p_food_id UUID,
  p_serving_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reviewer_user_id UUID := public.current_nutritionist_user_id();
  v_nutrition_profile_id UUID;
  v_review public.food_nutritionist_review%ROWTYPE;
BEGIN
  IF v_reviewer_user_id IS NULL THEN
    RAISE EXCEPTION 'Verified nutritionist access is required';
  END IF;

  SELECT nutrition.nutrition_profile_id
    INTO v_nutrition_profile_id
  FROM public.food_nutrition_profile AS nutrition
  JOIN public.food_item AS food
    ON food.food_id = nutrition.food_id
  JOIN public.food_serving AS serving
    ON serving.serving_id = nutrition.serving_id
  WHERE nutrition.food_id = p_food_id
    AND nutrition.serving_id = p_serving_id
    AND nutrition.is_active = TRUE
    AND nutrition.effective_to IS NULL
    AND food.is_active = TRUE
    AND food.is_official = TRUE
    AND serving.is_active = TRUE
  ORDER BY nutrition.effective_from DESC
  LIMIT 1;

  IF v_nutrition_profile_id IS NULL THEN
    RAISE EXCEPTION 'The active official food serving was not found';
  END IF;

  INSERT INTO public.food_nutritionist_review (
    nutrition_profile_id, food_id, serving_id, reviewer_user_id,
    status
  ) VALUES (
    v_nutrition_profile_id, p_food_id, p_serving_id, v_reviewer_user_id,
    'draft'
  )
  ON CONFLICT (nutrition_profile_id, reviewer_user_id)
  DO UPDATE SET status = 'draft', updated_at = NOW()
  RETURNING * INTO v_review;

  UPDATE public.food_nutrition_profile
    SET verification_status = CASE
      WHEN verification_status IN ('unreviewed', 'needs_revision', 'rejected')
      THEN 'in_review'
      ELSE verification_status
    END
    WHERE nutrition_profile_id = v_nutrition_profile_id;

  RETURN jsonb_build_object(
    'review_id', v_review.review_id,
    'nutrition_profile_id', v_nutrition_profile_id,
    'food_id', p_food_id,
    'serving_id', p_serving_id,
    'status', v_review.status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.nutritionist_begin_review(UUID, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nutritionist_begin_review(UUID, UUID)
  TO authenticated;

-- ===== 6. Submit a verification decision =====
-- Proposed values are supplied per 100 g and converted to the serving basis
-- before they are stored, so per-100 g and per-serving units are never mixed.
CREATE OR REPLACE FUNCTION public.nutritionist_submit_review(
  p_review_id UUID,
  p_decision TEXT,
  p_review_note TEXT DEFAULT NULL,
  p_source_type TEXT DEFAULT NULL,
  p_source_name TEXT DEFAULT NULL,
  p_source_reference TEXT DEFAULT NULL,
  p_source_checked_at DATE DEFAULT NULL,
  p_calories_per_100g NUMERIC DEFAULT NULL,
  p_protein_per_100g NUMERIC DEFAULT NULL,
  p_carbs_per_100g NUMERIC DEFAULT NULL,
  p_fat_per_100g NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reviewer_user_id UUID := public.current_nutritionist_user_id();
  v_review public.food_nutritionist_review%ROWTYPE;
  v_serving_grams NUMERIC(8,2);
  v_source_id SMALLINT;
  v_previous_values JSONB;
  v_proposed_values JSONB;
  v_new_calories NUMERIC(8,2);
  v_new_protein NUMERIC(8,2);
  v_new_carbs NUMERIC(8,2);
  v_new_fat NUMERIC(8,2);
  v_changed BOOLEAN;
  v_new_profile_id UUID;
  v_warnings JSONB := '[]'::JSONB;
  v_energy NUMERIC;
  v_macro_sum NUMERIC;
  v_note TEXT := NULLIF(btrim(COALESCE(p_review_note, '')), '');
BEGIN
  IF v_reviewer_user_id IS NULL THEN
    RAISE EXCEPTION 'Verified nutritionist access is required';
  END IF;

  IF p_decision IS NULL
     OR p_decision NOT IN ('verified', 'needs_revision', 'rejected') THEN
    RAISE EXCEPTION 'Decision must be verified, needs_revision, or rejected';
  END IF;
  IF p_review_note IS NOT NULL AND length(p_review_note) > 1200 THEN
    RAISE EXCEPTION 'Review note must be 1200 characters or fewer';
  END IF;
  IF p_decision IN ('needs_revision', 'rejected') AND v_note IS NULL THEN
    RAISE EXCEPTION 'A review note is required for this decision';
  END IF;

  IF p_source_type IS NOT NULL AND p_source_type NOT IN (
    'philfct', 'manufacturer_label', 'recognized_source',
    'recipe_estimate', 'legacy_internal', 'unknown'
  ) THEN
    RAISE EXCEPTION 'Source type is invalid';
  END IF;
  IF p_decision = 'verified' THEN
    IF p_source_type IS NULL OR p_source_checked_at IS NULL THEN
      RAISE EXCEPTION 'Record the source type and the date it was checked';
    END IF;
    IF NULLIF(btrim(COALESCE(p_source_name, '')), '') IS NULL
       AND NULLIF(btrim(COALESCE(p_source_reference, '')), '') IS NULL THEN
      RAISE EXCEPTION 'Record a source name or reference';
    END IF;
    IF p_calories_per_100g IS NULL OR p_protein_per_100g IS NULL
       OR p_carbs_per_100g IS NULL OR p_fat_per_100g IS NULL THEN
      RAISE EXCEPTION 'Per-100 g nutrition values are required for verification';
    END IF;
  END IF;

  IF p_calories_per_100g IS NOT NULL THEN
    IF p_calories_per_100g = 'NaN'::NUMERIC
       OR p_calories_per_100g < 0 OR p_calories_per_100g > 1000 THEN
      RAISE EXCEPTION 'Calories per 100 g must be between 0 and 1000';
    END IF;
  END IF;
  IF p_protein_per_100g IS NOT NULL THEN
    IF p_protein_per_100g = 'NaN'::NUMERIC
       OR p_protein_per_100g < 0 OR p_protein_per_100g > 100 THEN
      RAISE EXCEPTION 'Protein per 100 g must be between 0 and 100';
    END IF;
  END IF;
  IF p_carbs_per_100g IS NOT NULL THEN
    IF p_carbs_per_100g = 'NaN'::NUMERIC
       OR p_carbs_per_100g < 0 OR p_carbs_per_100g > 100 THEN
      RAISE EXCEPTION 'Carbohydrates per 100 g must be between 0 and 100';
    END IF;
  END IF;
  IF p_fat_per_100g IS NOT NULL THEN
    IF p_fat_per_100g = 'NaN'::NUMERIC
       OR p_fat_per_100g < 0 OR p_fat_per_100g > 100 THEN
      RAISE EXCEPTION 'Fat per 100 g must be between 0 and 100';
    END IF;
  END IF;

  SELECT review.*
    INTO v_review
  FROM public.food_nutritionist_review AS review
  WHERE review.review_id = p_review_id
    AND review.reviewer_user_id = v_reviewer_user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Review draft was not found';
  END IF;
  IF v_review.status <> 'draft' THEN
    RAISE EXCEPTION 'This review draft is no longer open';
  END IF;

  SELECT serving.serving_grams
    INTO v_serving_grams
  FROM public.food_serving AS serving
  WHERE serving.serving_id = v_review.serving_id;
  IF v_serving_grams IS NULL THEN
    RAISE EXCEPTION 'The reviewed serving was not found';
  END IF;

  SELECT nutrition.source_id
    INTO v_source_id
  FROM public.food_nutrition_profile AS nutrition
  WHERE nutrition.nutrition_profile_id = v_review.nutrition_profile_id;

  SELECT jsonb_build_object(
      'nutrition_profile_id', nutrition.nutrition_profile_id,
      'serving_id', nutrition.serving_id,
      'serving_grams', serving.serving_grams,
      'calories', nutrition.calories,
      'protein_g', nutrition.protein_g,
      'carbs_g', nutrition.carbs_g,
      'fat_g', nutrition.fat_g
    )
    INTO v_previous_values
  FROM public.food_nutrition_profile AS nutrition
  JOIN public.food_serving AS serving
    ON serving.serving_id = nutrition.serving_id
  WHERE nutrition.nutrition_profile_id = v_review.nutrition_profile_id;

  v_new_calories := ROUND(p_calories_per_100g * v_serving_grams / 100, 2);
  v_new_protein  := ROUND(p_protein_per_100g * v_serving_grams / 100, 2);
  v_new_carbs    := ROUND(p_carbs_per_100g * v_serving_grams / 100, 2);
  v_new_fat      := ROUND(p_fat_per_100g * v_serving_grams / 100, 2);

  SELECT (nutrition.calories, nutrition.protein_g, nutrition.carbs_g,
          nutrition.fat_g)
         IS DISTINCT FROM
         (v_new_calories, v_new_protein, v_new_carbs, v_new_fat)
    INTO v_changed
  FROM public.food_nutrition_profile AS nutrition
  WHERE nutrition.nutrition_profile_id = v_review.nutrition_profile_id;

  IF p_calories_per_100g IS NOT NULL THEN
    v_proposed_values := jsonb_build_object(
      'calories_per_100g', p_calories_per_100g,
      'protein_per_100g', p_protein_per_100g,
      'carbs_per_100g', p_carbs_per_100g,
      'fat_per_100g', p_fat_per_100g,
      'serving_grams', v_serving_grams
    );
    v_macro_sum := p_protein_per_100g + p_carbs_per_100g + p_fat_per_100g;
    IF v_macro_sum > 110 THEN
      v_warnings := v_warnings || jsonb_build_array(
        'Protein, carbohydrate, and fat exceed 100 g per 100 g'
      );
    END IF;
    IF p_calories_per_100g > 0 THEN
      v_energy := (p_protein_per_100g * 4)
        + (p_carbs_per_100g * 4) + (p_fat_per_100g * 9);
      IF abs(v_energy - p_calories_per_100g) / p_calories_per_100g > 0.35 THEN
        v_warnings := v_warnings || jsonb_build_array(
          'Stored calories differ from the 4/4/9 estimate; review the source'
        );
      END IF;
    END IF;
  END IF;

  IF p_decision = 'verified' AND v_changed THEN
    UPDATE public.food_nutrition_profile
      SET is_active = FALSE, effective_to = NOW()
      WHERE nutrition_profile_id = v_review.nutrition_profile_id;

    INSERT INTO public.food_nutrition_profile (
      food_id, serving_id, source_id,
      calories, protein_g, carbs_g, fat_g,
      is_active, effective_from,
      verification_status, nutrition_source_type, nutrition_source_name,
      nutrition_source_reference, source_checked_at, source_notes,
      verified_by_user_id, verified_at
    ) VALUES (
      v_review.food_id, v_review.serving_id, v_source_id,
      v_new_calories, v_new_protein, v_new_carbs, v_new_fat,
      TRUE, NOW(),
      'verified', p_source_type,
      NULLIF(btrim(COALESCE(p_source_name, '')), ''),
      NULLIF(btrim(COALESCE(p_source_reference, '')), ''),
      p_source_checked_at, NULL,
      v_reviewer_user_id, NOW()
    )
    RETURNING nutrition_profile_id INTO v_new_profile_id;
  ELSE
    UPDATE public.food_nutrition_profile
      SET verification_status = p_decision,
          nutrition_source_type = COALESCE(
            p_source_type, nutrition_source_type
          ),
          nutrition_source_name = COALESCE(
            NULLIF(btrim(COALESCE(p_source_name, '')), ''),
            nutrition_source_name
          ),
          nutrition_source_reference = COALESCE(
            NULLIF(btrim(COALESCE(p_source_reference, '')), ''),
            nutrition_source_reference
          ),
          source_checked_at = COALESCE(
            p_source_checked_at, source_checked_at
          ),
          verified_by_user_id = CASE
            WHEN p_decision = 'verified'
            THEN v_reviewer_user_id ELSE verified_by_user_id
          END,
          verified_at = CASE
            WHEN p_decision = 'verified' THEN NOW() ELSE verified_at
          END,
          archived_at = NULL
      WHERE nutrition_profile_id = v_review.nutrition_profile_id;
    v_new_profile_id := v_review.nutrition_profile_id;
  END IF;

  UPDATE public.food_nutritionist_review
    SET decision = p_decision,
        status = 'completed',
        review_note = v_note,
        source_type = p_source_type,
        source_name = NULLIF(btrim(COALESCE(p_source_name, '')), ''),
        source_reference = NULLIF(
          btrim(COALESCE(p_source_reference, '')), ''
        ),
        source_checked_at = p_source_checked_at,
        previous_values = v_previous_values,
        proposed_values = v_proposed_values,
        completed_at = NOW(),
        updated_at = NOW()
    WHERE review_id = v_review.review_id;

  INSERT INTO public.nutritionist_action_log (
    actor_user_id, action, entity_type, entity_id,
    previous_values, new_values, reason
  ) VALUES (
    v_reviewer_user_id,
    CASE p_decision
      WHEN 'verified' THEN 'review_verified'
      WHEN 'needs_revision' THEN 'review_needs_revision'
      ELSE 'review_rejected'
    END,
    'food_nutrition_profile',
    v_new_profile_id,
    v_previous_values,
    v_proposed_values,
    v_note
  );

  RETURN jsonb_build_object(
    'review_id', v_review.review_id,
    'decision', p_decision,
    'verification_status', p_decision,
    'nutrition_profile_id', v_new_profile_id,
    'warnings', v_warnings
  );
END;
$$;

REVOKE ALL ON FUNCTION public.nutritionist_submit_review(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DATE, NUMERIC, NUMERIC, NUMERIC, NUMERIC
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nutritionist_submit_review(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DATE, NUMERIC, NUMERIC, NUMERIC, NUMERIC
) TO authenticated;

-- ===== 7. Archive an invalid/duplicate food (never hard-delete) =====
CREATE OR REPLACE FUNCTION public.nutritionist_archive_food(
  p_food_id UUID,
  p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reviewer_user_id UUID := public.current_nutritionist_user_id();
  v_reason TEXT := NULLIF(btrim(COALESCE(p_reason, '')), '');
  v_food public.food_item%ROWTYPE;
BEGIN
  IF v_reviewer_user_id IS NULL THEN
    RAISE EXCEPTION 'Verified nutritionist access is required';
  END IF;
  IF v_reason IS NULL OR length(v_reason) > 1000 THEN
    RAISE EXCEPTION 'A reason of 1000 characters or fewer is required';
  END IF;

  SELECT food.*
    INTO v_food
  FROM public.food_item AS food
  WHERE food.food_id = p_food_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Food was not found';
  END IF;

  UPDATE public.food_item
    SET is_active = FALSE
    WHERE food_id = p_food_id;

  UPDATE public.food_nutrition_profile
    SET verification_status = 'archived',
        archived_at = NOW()
    WHERE food_id = p_food_id
      AND verification_status <> 'archived';

  INSERT INTO public.nutritionist_action_log (
    actor_user_id, action, entity_type, entity_id,
    previous_values, new_values, reason
  ) VALUES (
    v_reviewer_user_id, 'food_archived', 'food_item', p_food_id,
    jsonb_build_object('is_active', v_food.is_active),
    jsonb_build_object('is_active', FALSE),
    v_reason
  );

  RETURN jsonb_build_object('food_id', p_food_id, 'is_active', FALSE);
END;
$$;

REVOKE ALL ON FUNCTION public.nutritionist_archive_food(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nutritionist_archive_food(UUID, TEXT)
  TO authenticated;

-- ===== 8. Food-data reports =====
CREATE OR REPLACE FUNCTION public.submit_food_report(
  p_food_id UUID,
  p_issue_type TEXT,
  p_description TEXT DEFAULT NULL,
  p_serving_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reporter_user_id UUID := public.get_app_user_id();
  v_nutrition_profile_id UUID;
  v_report public.food_report%ROWTYPE;
  v_recent_count INTEGER;
BEGIN
  IF auth.uid() IS NULL OR v_reporter_user_id IS NULL THEN
    RAISE EXCEPTION 'Sign in before reporting food data';
  END IF;
  IF p_issue_type IS NULL OR p_issue_type NOT IN (
    'wrong_food', 'incorrect_nutrition', 'wrong_serving',
    'duplicate_food', 'missing_food', 'other'
  ) THEN
    RAISE EXCEPTION 'Choose a valid food-data issue';
  END IF;
  IF p_description IS NOT NULL AND length(p_description) > 1000 THEN
    RAISE EXCEPTION 'Description must be 1000 characters or fewer';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.food_item WHERE food_id = p_food_id
  ) THEN
    RAISE EXCEPTION 'Food was not found';
  END IF;

  SELECT COUNT(*)
    INTO v_recent_count
  FROM public.food_report
  WHERE reporter_user_id = v_reporter_user_id
    AND created_at >= NOW() - INTERVAL '24 hours';
  IF v_recent_count >= 10 THEN
    RAISE EXCEPTION 'Too many reports submitted today; try again later';
  END IF;

  IF p_serving_id IS NOT NULL THEN
    SELECT nutrition.nutrition_profile_id
      INTO v_nutrition_profile_id
    FROM public.food_nutrition_profile AS nutrition
    WHERE nutrition.food_id = p_food_id
      AND nutrition.serving_id = p_serving_id
      AND nutrition.is_active = TRUE
      AND nutrition.effective_to IS NULL
    ORDER BY nutrition.effective_from DESC
    LIMIT 1;
  END IF;

  INSERT INTO public.food_report (
    food_id, nutrition_profile_id, reporter_user_id,
    issue_type, description
  ) VALUES (
    p_food_id, v_nutrition_profile_id, v_reporter_user_id,
    p_issue_type, NULLIF(btrim(COALESCE(p_description, '')), '')
  )
  RETURNING * INTO v_report;

  RETURN to_jsonb(v_report);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_food_report(UUID, TEXT, TEXT, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_food_report(UUID, TEXT, TEXT, UUID)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.nutritionist_resolve_food_report(
  p_report_id UUID,
  p_status TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reviewer_user_id UUID := public.current_nutritionist_user_id();
  v_note TEXT := NULLIF(btrim(COALESCE(p_note, '')), '');
  v_report public.food_report%ROWTYPE;
BEGIN
  IF v_reviewer_user_id IS NULL THEN
    RAISE EXCEPTION 'Verified nutritionist access is required';
  END IF;
  IF p_status IS NULL
     OR p_status NOT IN ('in_review', 'resolved', 'dismissed') THEN
    RAISE EXCEPTION 'Status must be in_review, resolved, or dismissed';
  END IF;
  IF p_status = 'dismissed' AND v_note IS NULL THEN
    RAISE EXCEPTION 'A reason is required to dismiss a report';
  END IF;
  IF p_note IS NOT NULL AND length(p_note) > 1000 THEN
    RAISE EXCEPTION 'Note must be 1000 characters or fewer';
  END IF;

  SELECT report.*
    INTO v_report
  FROM public.food_report AS report
  WHERE report.report_id = p_report_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report was not found';
  END IF;

  UPDATE public.food_report
    SET status = p_status,
        reviewed_by_user_id = v_reviewer_user_id,
        resolution_note = COALESCE(v_note, resolution_note),
        resolved_at = CASE
          WHEN p_status IN ('resolved', 'dismissed') THEN NOW()
          ELSE NULL
        END
    WHERE report_id = p_report_id
    RETURNING * INTO v_report;

  INSERT INTO public.nutritionist_action_log (
    actor_user_id, action, entity_type, entity_id,
    previous_values, new_values, reason
  ) VALUES (
    v_reviewer_user_id, 'report_' || p_status, 'food_report', p_report_id,
    jsonb_build_object('status', 'open'),
    jsonb_build_object('status', p_status),
    v_note
  );

  RETURN to_jsonb(v_report);
END;
$$;

REVOKE ALL ON FUNCTION public.nutritionist_resolve_food_report(
  UUID, TEXT, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nutritionist_resolve_food_report(
  UUID, TEXT, TEXT
) TO authenticated;

-- ===== 9. Dashboard aggregate counts =====
CREATE OR REPLACE FUNCTION public.nutritionist_dashboard_kpis()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reviewer_user_id UUID := public.current_nutritionist_user_id();
  v_unreviewed INTEGER;
  v_in_review INTEGER;
  v_verified INTEGER;
  v_needs_revision INTEGER;
  v_rejected INTEGER;
  v_open_reports INTEGER;
  v_my_reviews INTEGER;
  v_expiration DATE;
  v_revalidation BOOLEAN;
BEGIN
  IF v_reviewer_user_id IS NULL THEN
    RAISE EXCEPTION 'Verified nutritionist access is required';
  END IF;

  SELECT
    COUNT(*) FILTER (WHERE nutrition.verification_status = 'unreviewed'),
    COUNT(*) FILTER (WHERE nutrition.verification_status = 'in_review'),
    COUNT(*) FILTER (WHERE nutrition.verification_status = 'verified'),
    COUNT(*) FILTER (WHERE nutrition.verification_status = 'needs_revision'),
    COUNT(*) FILTER (WHERE nutrition.verification_status = 'rejected')
    INTO v_unreviewed, v_in_review, v_verified,
         v_needs_revision, v_rejected
  FROM public.food_nutrition_profile AS nutrition
  JOIN public.food_item AS food ON food.food_id = nutrition.food_id
  WHERE nutrition.is_active = TRUE
    AND nutrition.effective_to IS NULL
    AND food.is_active = TRUE
    AND food.is_official = TRUE;

  SELECT COUNT(*)
    INTO v_open_reports
  FROM public.food_report
  WHERE status IN ('open', 'in_review');

  SELECT COUNT(*)
    INTO v_my_reviews
  FROM public.food_nutritionist_review
  WHERE reviewer_user_id = v_reviewer_user_id
    AND status = 'completed'
    AND completed_at >= NOW() - INTERVAL '7 days';

  SELECT application.prc_license_expiration_date,
         application.revalidation_required
    INTO v_expiration, v_revalidation
  FROM public.nutritionist_application AS application
  WHERE application.user_id = v_reviewer_user_id;

  RETURN jsonb_build_object(
    'unreviewed', v_unreviewed,
    'in_review', v_in_review,
    'verified', v_verified,
    'needs_revision', v_needs_revision,
    'rejected', v_rejected,
    'open_reports', v_open_reports,
    'my_reviews_7d', v_my_reviews,
    'credential_expires_on', v_expiration,
    'credential_expired', v_expiration IS NOT NULL
      AND v_expiration < (NOW() AT TIME ZONE 'Asia/Manila')::DATE,
    'revalidation_required', COALESCE(v_revalidation, FALSE)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.nutritionist_dashboard_kpis()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nutritionist_dashboard_kpis()
  TO authenticated;

-- ===== 10. Expose verification metadata on the public catalog view =====
DROP VIEW IF EXISTS public.food_catalog;
CREATE VIEW public.food_catalog
WITH (security_invoker = true)
AS
SELECT f.food_id, c.category_name, f.owner_user_id, f.food_name,
  f.normalized_name, f.is_local_food, f.is_official, f.is_active,
  s.serving_id, s.serving_label, s.serving_grams,
  n.calories, n.protein_g, n.carbs_g, n.fat_g,
  COALESCE(p.estimated_price_php, 0) AS estimated_price_php,
  f.created_at, f.updated_at, f.subcategory, f.description,
  n.verification_status, n.verified_at,
  n.nutrition_source_type, n.nutrition_source_name, n.source_checked_at,
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
