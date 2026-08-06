-- 000032: Preserve admin food metadata and make report decisions atomic.

ALTER TABLE public.food_item
  ADD COLUMN IF NOT EXISTS description TEXT;

CREATE OR REPLACE VIEW public.food_catalog
WITH (security_invoker = true)
AS
SELECT f.food_id, c.category_name, f.owner_user_id, f.food_name,
  f.normalized_name, f.is_local_food, f.is_official, f.is_active,
  s.serving_id, s.serving_label, s.serving_grams,
  n.calories, n.protein_g, n.carbs_g, n.fat_g,
  COALESCE(p.estimated_price_php, 0) AS estimated_price_php,
  f.created_at, f.updated_at, f.subcategory, f.description
FROM public.food_item f
JOIN public.food_category c ON c.category_id = f.category_id
JOIN public.food_serving s ON s.food_id = f.food_id AND s.is_default AND s.is_active
JOIN public.food_nutrition_profile n
  ON n.food_id = f.food_id AND n.serving_id = s.serving_id AND n.is_active
LEFT JOIN public.food_price p
  ON p.food_id = f.food_id AND p.serving_id = s.serving_id AND p.is_active
WHERE f.is_active;

GRANT SELECT ON public.food_catalog TO authenticated;

-- SECURITY DEFINER functions must not inherit a caller-controlled search_path.
ALTER FUNCTION public.admin_set_food_price(uuid, numeric, smallint)
  SET search_path = public;
ALTER FUNCTION public.admin_hide_reported_post(uuid)
  SET search_path = public;
ALTER FUNCTION public.admin_set_user_role(uuid, smallint)
  SET search_path = public;
ALTER FUNCTION public.admin_log_moderation_action(text, uuid, uuid, text)
  SET search_path = public;

CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id UUID,
  p_status_code TEXT,
  p_details TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_user_id UUID;
  v_post_id UUID;
  v_status_id SMALLINT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only administrators can resolve reports';
  END IF;

  IF p_status_code NOT IN ('dismissed', 'reviewed') THEN
    RAISE EXCEPTION 'Unsupported report status: %', p_status_code;
  END IF;

  SELECT user_id INTO v_admin_user_id
  FROM app_user
  WHERE auth_user_id = auth.uid()::UUID;

  SELECT post_id INTO v_post_id
  FROM community_report
  WHERE report_id = p_report_id;

  IF v_post_id IS NULL THEN
    RAISE EXCEPTION 'Report not found';
  END IF;

  SELECT status_id INTO v_status_id
  FROM report_status
  WHERE status_code = p_status_code;

  IF v_status_id IS NULL THEN
    RAISE EXCEPTION 'Report status is not configured: %', p_status_code;
  END IF;

  UPDATE community_report
  SET status_id = v_status_id
  WHERE report_id = p_report_id;

  INSERT INTO moderation_audit_log (
    admin_user_id, action_code, report_id, post_id, details
  ) VALUES (
    v_admin_user_id, p_status_code, p_report_id, v_post_id,
    COALESCE(p_details, 'Report status updated')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_report(uuid, text, text)
  TO authenticated;
