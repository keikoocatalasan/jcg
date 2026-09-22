-- Nutritionist applications are separate from APP_USER.role_id so approval
-- never replaces a user's normal application role.
CREATE TABLE public.nutritionist_application (
  application_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.app_user(user_id) ON DELETE CASCADE,
  credential_name TEXT NOT NULL,
  license_number TEXT NOT NULL,
  credential_document_path TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'suspended')),
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_by UUID REFERENCES public.app_user(user_id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  review_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT nutritionist_application_review_state_valid CHECK (
    (status = 'pending' AND reviewed_at IS NULL)
    OR (status <> 'pending' AND reviewed_at IS NOT NULL)
  ),
  CONSTRAINT nutritionist_application_name_valid CHECK (
    length(btrim(credential_name)) BETWEEN 2 AND 120
  ),
  CONSTRAINT nutritionist_application_license_valid CHECK (
    length(btrim(license_number)) BETWEEN 3 AND 80
  ),
  CONSTRAINT nutritionist_application_note_valid CHECK (
    review_note IS NULL OR length(review_note) <= 1000
  )
);

CREATE INDEX nutritionist_application_status_submitted_idx
  ON public.nutritionist_application(status, submitted_at DESC);

CREATE TABLE public.nutritionist_application_review_log (
  review_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL
    REFERENCES public.nutritionist_application(application_id) ON DELETE CASCADE,
  reviewed_by UUID REFERENCES public.app_user(user_id) ON DELETE SET NULL,
  previous_status TEXT,
  new_status TEXT NOT NULL
    CHECK (new_status IN ('approved', 'rejected', 'suspended')),
  review_note TEXT,
  reviewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.nutritionist_application ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutritionist_application_review_log ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.nutritionist_application
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.nutritionist_application_review_log
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.nutritionist_application,
  public.nutritionist_application_review_log TO authenticated;

CREATE POLICY nutritionist_application_select_owner_or_admin
  ON public.nutritionist_application FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.app_user AS applicant
      WHERE applicant.user_id = nutritionist_application.user_id
        AND applicant.auth_user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY nutritionist_application_review_log_admin_select
  ON public.nutritionist_application_review_log FOR SELECT TO authenticated
  USING (public.is_admin());

-- Applicants can only submit or resubmit their own credentials. Approval and
-- review fields are changed only by the admin RPC below.
CREATE OR REPLACE FUNCTION public.submit_nutritionist_application(
  p_credential_name TEXT,
  p_license_number TEXT,
  p_credential_document_path TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_auth_user_id UUID := auth.uid();
  v_user_id UUID;
  v_application public.nutritionist_application%ROWTYPE;
BEGIN
  IF v_auth_user_id IS NULL THEN
    RAISE EXCEPTION 'Sign in before submitting credentials';
  END IF;
  IF length(btrim(COALESCE(p_credential_name, ''))) NOT BETWEEN 2 AND 120
     OR length(btrim(COALESCE(p_license_number, ''))) NOT BETWEEN 3 AND 80 THEN
    RAISE EXCEPTION 'Enter the name and license number shown on the credential';
  END IF;
  IF p_credential_document_path IS NULL
     OR split_part(p_credential_document_path, '/', 1) <> v_auth_user_id::TEXT
     OR position('..' IN p_credential_document_path) > 0 THEN
    RAISE EXCEPTION 'Credential document path is invalid';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM storage.objects AS credential_file
    WHERE credential_file.bucket_id = 'nutritionist-credentials-private'
      AND credential_file.name = p_credential_document_path
  ) THEN
    RAISE EXCEPTION 'Upload the credential image before submitting';
  END IF;

  SELECT applicant.user_id
    INTO v_user_id
  FROM public.app_user AS applicant
  WHERE applicant.auth_user_id = v_auth_user_id;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Your account profile is not ready for applications';
  END IF;

  SELECT application.*
    INTO v_application
  FROM public.nutritionist_application AS application
  WHERE application.user_id = v_user_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_application.status IN ('approved', 'suspended') THEN
      RAISE EXCEPTION 'This account cannot submit another application';
    END IF;
    UPDATE public.nutritionist_application
      SET credential_name = btrim(p_credential_name),
          license_number = btrim(p_license_number),
          credential_document_path = p_credential_document_path,
          status = 'pending',
          submitted_at = NOW(),
          reviewed_by = NULL,
          reviewed_at = NULL,
          review_note = NULL,
          updated_at = NOW()
      WHERE application_id = v_application.application_id
      RETURNING * INTO v_application;
  ELSE
    INSERT INTO public.nutritionist_application (
      user_id, credential_name, license_number, credential_document_path
    ) VALUES (
      v_user_id, btrim(p_credential_name), btrim(p_license_number),
      p_credential_document_path
    )
    RETURNING * INTO v_application;
  END IF;

  RETURN to_jsonb(v_application);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_nutritionist_application(
  p_application_id UUID,
  p_decision TEXT,
  p_review_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_auth_user_id UUID := auth.uid();
  v_admin_user_id UUID;
  v_previous_status TEXT;
  v_application public.nutritionist_application%ROWTYPE;
BEGIN
  IF v_auth_user_id IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Administrator access is required';
  END IF;
  IF p_decision IS NULL
     OR p_decision NOT IN ('approved', 'rejected', 'suspended') THEN
    RAISE EXCEPTION 'Decision must be approved, rejected, or suspended';
  END IF;
  IF p_review_note IS NOT NULL AND length(p_review_note) > 1000 THEN
    RAISE EXCEPTION 'Review note must be 1000 characters or fewer';
  END IF;

  SELECT administrator.user_id
    INTO v_admin_user_id
  FROM public.app_user AS administrator
  WHERE administrator.auth_user_id = v_auth_user_id;

  SELECT application.*
    INTO v_application
  FROM public.nutritionist_application AS application
  WHERE application.application_id = p_application_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Application was not found';
  END IF;
  v_previous_status := v_application.status;
  IF p_decision = 'approved' AND NOT EXISTS (
    SELECT 1
    FROM storage.objects AS credential_file
    WHERE credential_file.bucket_id = 'nutritionist-credentials-private'
      AND credential_file.name = v_application.credential_document_path
  ) THEN
    RAISE EXCEPTION 'The credential image is unavailable for review';
  END IF;

  UPDATE public.nutritionist_application
    SET status = p_decision,
        reviewed_by = v_admin_user_id,
        reviewed_at = NOW(),
        review_note = NULLIF(btrim(COALESCE(p_review_note, '')), ''),
        updated_at = NOW()
    WHERE application_id = p_application_id
    RETURNING * INTO v_application;

  INSERT INTO public.nutritionist_application_review_log (
    application_id, reviewed_by, previous_status, new_status, review_note
  ) VALUES (
    p_application_id, v_admin_user_id, v_previous_status, p_decision,
    NULLIF(btrim(COALESCE(p_review_note, '')), '')
  );

  RETURN to_jsonb(v_application);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_nutritionist_application(TEXT, TEXT, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_nutritionist_application(TEXT, TEXT, TEXT)
  TO authenticated;
REVOKE ALL ON FUNCTION public.admin_review_nutritionist_application(UUID, TEXT, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_review_nutritionist_application(UUID, TEXT, TEXT)
  TO authenticated;

-- Keep credential images in a private bucket. Every object path starts with
-- the submitting Auth user's UUID, allowing scoped owner/admin access.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'nutritionist-credentials-private',
  'nutritionist-credentials-private',
  FALSE,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::TEXT[]
)
ON CONFLICT (id) DO UPDATE
SET public = FALSE,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS nutritionist_credentials_upload_own
  ON storage.objects;
CREATE POLICY nutritionist_credentials_upload_own
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'nutritionist-credentials-private'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
  );

DROP POLICY IF EXISTS nutritionist_credentials_read_owner_or_admin
  ON storage.objects;
CREATE POLICY nutritionist_credentials_read_owner_or_admin
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'nutritionist-credentials-private'
    AND (
      (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
      OR public.is_admin()
    )
  );

DROP POLICY IF EXISTS nutritionist_credentials_delete_unapproved_own
  ON storage.objects;
CREATE POLICY nutritionist_credentials_delete_unapproved_own
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'nutritionist-credentials-private'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
    AND NOT EXISTS (
      SELECT 1
      FROM public.nutritionist_application AS application
      JOIN public.app_user AS applicant ON applicant.user_id = application.user_id
      WHERE applicant.auth_user_id = (SELECT auth.uid())
        AND application.credential_document_path = storage.objects.name
        AND application.status = 'approved'
    )
  );

-- The published catalog remains unchanged. Approved nutritionists submit a
-- separate opinion against an exact food serving/nutrition version.
CREATE TABLE public.food_nutritionist_review (
  review_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nutrition_profile_id UUID NOT NULL
    REFERENCES public.food_nutrition_profile(nutrition_profile_id) ON DELETE CASCADE,
  food_id UUID NOT NULL REFERENCES public.food_item(food_id) ON DELETE CASCADE,
  serving_id UUID NOT NULL REFERENCES public.food_serving(serving_id) ON DELETE CASCADE,
  reviewer_user_id UUID NOT NULL
    REFERENCES public.app_user(user_id) ON DELETE CASCADE,
  serving_assessment TEXT NOT NULL
    CHECK (serving_assessment IN ('balanced_for_serving', 'watch_portion', 'needs_context')),
  macro_assessment TEXT NOT NULL
    CHECK (macro_assessment IN ('consistent', 'needs_recheck', 'insufficient_source')),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT food_nutritionist_review_comment_valid CHECK (
    comment IS NULL OR length(comment) <= 1200
  ),
  CONSTRAINT food_nutritionist_review_reviewer_version_unique
    UNIQUE (nutrition_profile_id, reviewer_user_id)
);

CREATE INDEX food_nutritionist_review_food_serving_idx
  ON public.food_nutritionist_review(food_id, serving_id, updated_at DESC);

ALTER TABLE public.food_nutritionist_review ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.food_nutritionist_review FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  review_id, nutrition_profile_id, food_id, serving_id,
  serving_assessment, macro_assessment,
  comment, created_at, updated_at
) ON TABLE public.food_nutritionist_review TO authenticated;

CREATE POLICY food_nutritionist_review_read_signed_in
  ON public.food_nutritionist_review FOR SELECT TO authenticated
  USING (TRUE);

CREATE OR REPLACE FUNCTION public.submit_food_nutritionist_review(
  p_food_id UUID,
  p_serving_id UUID,
  p_serving_assessment TEXT,
  p_macro_assessment TEXT,
  p_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_auth_user_id UUID := auth.uid();
  v_reviewer_user_id UUID;
  v_nutrition_profile_id UUID;
  v_review public.food_nutritionist_review%ROWTYPE;
BEGIN
  IF v_auth_user_id IS NULL THEN
    RAISE EXCEPTION 'Sign in before submitting a nutrition review';
  END IF;

  SELECT applicant.user_id
    INTO v_reviewer_user_id
  FROM public.app_user AS applicant
  JOIN public.nutritionist_application AS application
    ON application.user_id = applicant.user_id
  WHERE applicant.auth_user_id = v_auth_user_id
    AND application.status = 'approved';
  IF v_reviewer_user_id IS NULL THEN
    RAISE EXCEPTION 'Only admin-approved nutritionists can submit food reviews';
  END IF;

  IF p_serving_assessment IS NULL OR p_serving_assessment NOT IN (
    'balanced_for_serving', 'watch_portion', 'needs_context'
  ) THEN
    RAISE EXCEPTION 'Serving assessment is invalid';
  END IF;
  IF p_macro_assessment IS NULL OR p_macro_assessment NOT IN (
    'consistent', 'needs_recheck', 'insufficient_source'
  ) THEN
    RAISE EXCEPTION 'Macro assessment is invalid';
  END IF;
  IF p_comment IS NOT NULL AND length(p_comment) > 1200 THEN
    RAISE EXCEPTION 'Comment must be 1200 characters or fewer';
  END IF;

  SELECT nutrition.nutrition_profile_id
    INTO v_nutrition_profile_id
  FROM public.food_nutrition_profile AS nutrition
  JOIN public.food_item AS food ON food.food_id = nutrition.food_id
  JOIN public.food_serving AS serving ON serving.serving_id = nutrition.serving_id
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
    serving_assessment, macro_assessment, comment
  ) VALUES (
    v_nutrition_profile_id, p_food_id, p_serving_id, v_reviewer_user_id,
    p_serving_assessment, p_macro_assessment,
    NULLIF(btrim(COALESCE(p_comment, '')), '')
  )
  ON CONFLICT (nutrition_profile_id, reviewer_user_id)
  DO UPDATE SET
    serving_assessment = EXCLUDED.serving_assessment,
    macro_assessment = EXCLUDED.macro_assessment,
    comment = EXCLUDED.comment,
    updated_at = NOW()
  RETURNING * INTO v_review;

  RETURN to_jsonb(v_review);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_food_nutritionist_review(UUID, UUID, TEXT, TEXT, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_food_nutritionist_review(UUID, UUID, TEXT, TEXT, TEXT)
  TO authenticated;
