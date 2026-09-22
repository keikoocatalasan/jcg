-- Cancel an abandoned nutritionist review draft without deleting history.
CREATE OR REPLACE FUNCTION public.nutritionist_cancel_review(
  p_review_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reviewer_user_id UUID := public.current_nutritionist_user_id();
  v_review public.food_nutritionist_review%ROWTYPE;
  v_has_completed BOOLEAN;
BEGIN
  IF v_reviewer_user_id IS NULL THEN
    RAISE EXCEPTION 'Verified nutritionist access is required';
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
    RAISE EXCEPTION 'This review is no longer open';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.food_nutritionist_review AS completed
    WHERE completed.nutrition_profile_id = v_review.nutrition_profile_id
      AND completed.status = 'completed'
  ) INTO v_has_completed;

  UPDATE public.food_nutritionist_review
    SET status = 'cancelled',
        completed_at = NULL,
        updated_at = NOW()
    WHERE review_id = p_review_id;

  IF NOT v_has_completed THEN
    UPDATE public.food_nutrition_profile
      SET verification_status = 'unreviewed'
      WHERE nutrition_profile_id = v_review.nutrition_profile_id
        AND verification_status = 'in_review';
  END IF;

  RETURN jsonb_build_object(
    'review_id', p_review_id,
    'status', 'cancelled',
    'profile_restored', NOT v_has_completed
  );
END;
$$;

REVOKE ALL ON FUNCTION public.nutritionist_cancel_review(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nutritionist_cancel_review(UUID)
  TO authenticated;
