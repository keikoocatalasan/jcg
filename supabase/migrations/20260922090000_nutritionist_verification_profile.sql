-- 20260922090000: Nutritionist professional verification profile
--
-- Extends the existing nutritionist_application table (which already stores one
-- application/profile per user) with the professional credential fields required
-- by the JCG Nutritionist role: regulated profession, PRC license expiry,
-- typed rejection/suspension reasons, and revalidation state.
--
-- Status values are migrated from 'approved' to 'verified'. Existing approvals
-- are grandfathered as verified but flagged revalidation_required when the PRC
-- expiration date is unknown; no expiration date is invented.

-- ===== 1. Professional fields =====
ALTER TABLE public.nutritionist_application
  ADD COLUMN IF NOT EXISTS profession TEXT NOT NULL
    DEFAULT 'Nutritionist-Dietitian',
  ADD COLUMN IF NOT EXISTS prc_license_expiration_date DATE,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS suspension_reason TEXT,
  ADD COLUMN IF NOT EXISTS revalidation_required BOOLEAN NOT NULL DEFAULT FALSE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.nutritionist_application'::regclass
      AND conname = 'nutritionist_application_profession_valid'
  ) THEN
    ALTER TABLE public.nutritionist_application
      ADD CONSTRAINT nutritionist_application_profession_valid
      CHECK (profession = 'Nutritionist-Dietitian');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.nutritionist_application'::regclass
      AND conname = 'nutritionist_application_expiration_valid'
  ) THEN
    ALTER TABLE public.nutritionist_application
      ADD CONSTRAINT nutritionist_application_expiration_valid
      CHECK (
        prc_license_expiration_date IS NULL
        OR prc_license_expiration_date > DATE '1900-01-01'
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.nutritionist_application'::regclass
      AND conname = 'nutritionist_application_rejection_reason_valid'
  ) THEN
    ALTER TABLE public.nutritionist_application
      ADD CONSTRAINT nutritionist_application_rejection_reason_valid
      CHECK (
        rejection_reason IS NULL OR length(rejection_reason) <= 1000
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.nutritionist_application'::regclass
      AND conname = 'nutritionist_application_suspension_reason_valid'
  ) THEN
    ALTER TABLE public.nutritionist_application
      ADD CONSTRAINT nutritionist_application_suspension_reason_valid
      CHECK (
        suspension_reason IS NULL OR length(suspension_reason) <= 1000
      );
  END IF;
END;
$$;

-- ===== 2. Status migration approved -> verified =====
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.nutritionist_application'::regclass
      AND conname = 'nutritionist_application_status_check'
  ) THEN
    ALTER TABLE public.nutritionist_application
      DROP CONSTRAINT nutritionist_application_status_check;
  END IF;
END;
$$;

UPDATE public.nutritionist_application
SET status = 'verified'
WHERE status = 'approved';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.nutritionist_application'::regclass
      AND conname = 'nutritionist_application_status_valid'
  ) THEN
    ALTER TABLE public.nutritionist_application
      ADD CONSTRAINT nutritionist_application_status_valid
      CHECK (status IN ('pending', 'verified', 'rejected', 'suspended'));
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid =
            'public.nutritionist_application_review_log'::regclass
      AND conname = 'nutritionist_application_review_log_new_status_check'
  ) THEN
    ALTER TABLE public.nutritionist_application_review_log
      DROP CONSTRAINT nutritionist_application_review_log_new_status_check;
  END IF;
END;
$$;

UPDATE public.nutritionist_application_review_log
SET new_status = 'verified'
WHERE new_status = 'approved';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid =
            'public.nutritionist_application_review_log'::regclass
      AND conname = 'nutritionist_application_review_log_new_status_valid'
  ) THEN
    ALTER TABLE public.nutritionist_application_review_log
      ADD CONSTRAINT nutritionist_application_review_log_new_status_valid
      CHECK (new_status IN ('verified', 'rejected', 'suspended'));
  END IF;
END;
$$;

-- Grandfather existing verified accounts that have no expiration date recorded.
UPDATE public.nutritionist_application
SET revalidation_required = TRUE
WHERE status = 'verified'
  AND prc_license_expiration_date IS NULL;

-- ===== 3. Duplicate active license guard =====
CREATE UNIQUE INDEX IF NOT EXISTS uq_nutritionist_active_license
  ON public.nutritionist_application (lower(btrim(license_number)))
  WHERE status IN ('pending', 'verified');

-- ===== 4. Verified-nutritionist gate =====
-- Returns the app_user.user_id when the caller is a verified nutritionist whose
-- credential has not expired. Grandfathered rows with a NULL expiration remain
-- valid until an admin re-reviews them.
CREATE OR REPLACE FUNCTION public.current_nutritionist_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT applicant.user_id
  FROM public.nutritionist_application AS application
  JOIN public.app_user AS applicant ON applicant.user_id = application.user_id
  WHERE applicant.auth_user_id = (SELECT auth.uid())
    AND application.status = 'verified'
    AND (
      application.prc_license_expiration_date IS NULL
      OR application.prc_license_expiration_date
        >= (NOW() AT TIME ZONE 'Asia/Manila')::DATE
    )
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_verified_nutritionist()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.current_nutritionist_user_id() IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.current_nutritionist_user_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_verified_nutritionist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_nutritionist_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_verified_nutritionist() TO authenticated;

-- ===== 5. Application submission (now carries professional fields) =====
CREATE OR REPLACE FUNCTION public.submit_nutritionist_application(
  p_credential_name TEXT,
  p_license_number TEXT,
  p_credential_document_path TEXT,
  p_prc_license_expiration_date DATE DEFAULT NULL,
  p_profession TEXT DEFAULT 'Nutritionist-Dietitian'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_auth_user_id UUID := auth.uid();
  v_user_id UUID;
  v_previous_status TEXT;
  v_application public.nutritionist_application%ROWTYPE;
BEGIN
  IF v_auth_user_id IS NULL THEN
    RAISE EXCEPTION 'Sign in before submitting credentials';
  END IF;
  IF length(btrim(COALESCE(p_credential_name, ''))) NOT BETWEEN 2 AND 120
     OR length(btrim(COALESCE(p_license_number, ''))) NOT BETWEEN 3 AND 80 THEN
    RAISE EXCEPTION 'Enter the name and license number shown on the credential';
  END IF;
  IF btrim(COALESCE(p_profession, '')) <> 'Nutritionist-Dietitian' THEN
    RAISE EXCEPTION 'Only Nutritionist-Dietitian credentials are accepted';
  END IF;
  IF p_prc_license_expiration_date IS NULL THEN
    RAISE EXCEPTION 'Enter the PRC license expiration date';
  END IF;
  IF p_prc_license_expiration_date <= DATE '1900-01-01' THEN
    RAISE EXCEPTION 'Enter a valid PRC license expiration date';
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

  IF EXISTS (
    SELECT 1
    FROM public.nutritionist_application AS other
    WHERE lower(btrim(other.license_number)) =
          lower(btrim(p_license_number))
      AND other.user_id <> v_user_id
      AND other.status IN ('pending', 'verified')
  ) THEN
    RAISE EXCEPTION 'This PRC license number is already registered';
  END IF;

  SELECT application.*
    INTO v_application
  FROM public.nutritionist_application AS application
  WHERE application.user_id = v_user_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_application.status = 'suspended' THEN
      RAISE EXCEPTION 'This account cannot submit another application';
    END IF;
    v_previous_status := v_application.status;
    UPDATE public.nutritionist_application
      SET credential_name = btrim(p_credential_name),
          license_number = btrim(p_license_number),
          credential_document_path = p_credential_document_path,
          profession = btrim(p_profession),
          prc_license_expiration_date = p_prc_license_expiration_date,
          status = 'pending',
          submitted_at = NOW(),
          reviewed_by = NULL,
          reviewed_at = NULL,
          review_note = NULL,
          rejection_reason = NULL,
          suspension_reason = NULL,
          revalidation_required = (v_previous_status = 'verified'),
          updated_at = NOW()
      WHERE application_id = v_application.application_id
      RETURNING * INTO v_application;
  ELSE
    INSERT INTO public.nutritionist_application (
      user_id, credential_name, license_number, credential_document_path,
      profession, prc_license_expiration_date
    ) VALUES (
      v_user_id, btrim(p_credential_name), btrim(p_license_number),
      p_credential_document_path, btrim(p_profession),
      p_prc_license_expiration_date
    )
    RETURNING * INTO v_application;
  END IF;

  RETURN to_jsonb(v_application);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_nutritionist_application(
  TEXT, TEXT, TEXT, DATE, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_nutritionist_application(
  TEXT, TEXT, TEXT, DATE, TEXT
) TO authenticated;

-- Retire the previous 3-argument signature so older clients receive the
-- explicit expiration-date validation instead of creating an ambiguous
-- overload with the 5-argument function above.
DROP FUNCTION IF EXISTS public.submit_nutritionist_application(
  TEXT, TEXT, TEXT
);

-- ===== 6. Admin verification decision =====
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
     OR p_decision NOT IN ('verified', 'rejected', 'suspended') THEN
    RAISE EXCEPTION 'Decision must be verified, rejected, or suspended';
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

  IF p_decision = 'verified' THEN
    IF v_application.prc_license_expiration_date IS NULL THEN
      RAISE EXCEPTION 'The PRC license expiration date is missing';
    END IF;
    IF v_application.prc_license_expiration_date
       < (NOW() AT TIME ZONE 'Asia/Manila')::DATE THEN
      RAISE EXCEPTION 'The PRC credential is expired and cannot be verified';
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM storage.objects AS credential_file
      WHERE credential_file.bucket_id = 'nutritionist-credentials-private'
        AND credential_file.name = v_application.credential_document_path
    ) THEN
      RAISE EXCEPTION 'The credential image is unavailable for review';
    END IF;
  END IF;

  UPDATE public.nutritionist_application
    SET status = p_decision,
        reviewed_by = v_admin_user_id,
        reviewed_at = NOW(),
        review_note = NULLIF(btrim(COALESCE(p_review_note, '')), ''),
        rejection_reason = CASE
          WHEN p_decision = 'rejected'
          THEN NULLIF(btrim(COALESCE(p_review_note, '')), '')
          ELSE NULL
        END,
        suspension_reason = CASE
          WHEN p_decision = 'suspended'
          THEN NULLIF(btrim(COALESCE(p_review_note, '')), '')
          ELSE NULL
        END,
        revalidation_required = FALSE,
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

REVOKE ALL ON FUNCTION public.admin_review_nutritionist_application(
  UUID, TEXT, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_review_nutritionist_application(
  UUID, TEXT, TEXT
) TO authenticated;

-- ===== 7. Credential storage policy uses the new status value =====
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
      JOIN public.app_user AS applicant
        ON applicant.user_id = application.user_id
      WHERE applicant.auth_user_id = (SELECT auth.uid())
        AND application.credential_document_path = storage.objects.name
        AND application.status = 'verified'
    )
  );

-- ===== 8. Retire the legacy advisory review RPC =====
-- The advisory review flow is replaced by the verification workflow. Existing
-- rows stay readable; new submissions go through the review RPCs added in the
-- following migration.
REVOKE ALL ON FUNCTION public.submit_food_nutritionist_review(
  UUID, UUID, TEXT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
