-- 000034: Admin visibility controls for posts and comments.
-- These RPCs keep moderation changes atomic and auditable.

INSERT INTO public.moderation_action_type (action_code, action_name)
VALUES ('unhide_comment', 'Unhide Comment')
ON CONFLICT (action_code) DO NOTHING;

CREATE OR REPLACE FUNCTION public.admin_set_post_visibility(
  p_post_id UUID,
  p_is_hidden BOOLEAN,
  p_report_id UUID DEFAULT NULL,
  p_details TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_user_id UUID;
  v_report_post_id UUID;
  v_action_type_id SMALLINT;
  v_action_code TEXT := CASE
    WHEN p_is_hidden THEN 'hide_post'
    ELSE 'unhide_post'
  END;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can change post visibility';
  END IF;

  SELECT user_id INTO v_admin_user_id
  FROM public.app_user
  WHERE auth_user_id = auth.uid()::UUID;

  IF NOT EXISTS (
    SELECT 1 FROM public.community_post
    WHERE post_id = p_post_id
  ) THEN
    RAISE EXCEPTION 'Post not found';
  END IF;

  IF p_report_id IS NOT NULL THEN
    SELECT post_id INTO v_report_post_id
    FROM public.community_report
    WHERE report_id = p_report_id;

    IF v_report_post_id IS NULL OR v_report_post_id <> p_post_id THEN
      RAISE EXCEPTION 'Report does not belong to post';
    END IF;
  END IF;

  SELECT action_type_id INTO v_action_type_id
  FROM public.moderation_action_type
  WHERE action_code = v_action_code;

  IF v_action_type_id IS NULL THEN
    RAISE EXCEPTION 'Moderation action is not configured: %', v_action_code;
  END IF;

  UPDATE public.community_post
  SET is_hidden = p_is_hidden
  WHERE post_id = p_post_id;

  IF p_is_hidden AND p_report_id IS NOT NULL THEN
    UPDATE public.community_report
    SET status_id = (
          SELECT status_id
          FROM public.report_status
          WHERE status_code = 'action_taken'
        ),
        reviewed_at = NOW()
    WHERE report_id = p_report_id;
  END IF;

  INSERT INTO public.moderation_action (
    admin_user_id, action_type_id, post_id, report_id, reason
  ) VALUES (
    v_admin_user_id,
    v_action_type_id,
    p_post_id,
    p_report_id,
    COALESCE(p_details, CASE
      WHEN p_is_hidden THEN 'Post hidden after moderation review'
      ELSE 'Post restored after moderation review'
    END)
  );

  INSERT INTO public.moderation_audit_log (
    admin_user_id, action_code, report_id, post_id, details
  ) VALUES (
    v_admin_user_id,
    v_action_code,
    p_report_id,
    p_post_id,
    COALESCE(p_details, 'Post visibility changed')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_comment_visibility(
  p_comment_id UUID,
  p_is_hidden BOOLEAN,
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
  v_action_type_id SMALLINT;
  v_action_code TEXT := CASE
    WHEN p_is_hidden THEN 'hide_comment'
    ELSE 'unhide_comment'
  END;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only administrators can change comment visibility';
  END IF;

  SELECT user_id INTO v_admin_user_id
  FROM public.app_user
  WHERE auth_user_id = auth.uid()::UUID;

  SELECT post_id INTO v_post_id
  FROM public.community_comment
  WHERE comment_id = p_comment_id;

  IF v_post_id IS NULL THEN
    RAISE EXCEPTION 'Comment not found';
  END IF;

  SELECT action_type_id INTO v_action_type_id
  FROM public.moderation_action_type
  WHERE action_code = v_action_code;

  IF v_action_type_id IS NULL THEN
    RAISE EXCEPTION 'Moderation action is not configured: %', v_action_code;
  END IF;

  UPDATE public.community_comment
  SET is_hidden = p_is_hidden
  WHERE comment_id = p_comment_id;

  INSERT INTO public.moderation_action (
    admin_user_id, action_type_id, post_id, comment_id, reason
  ) VALUES (
    v_admin_user_id,
    v_action_type_id,
    v_post_id,
    p_comment_id,
    COALESCE(p_details, 'Comment visibility changed')
  );

  INSERT INTO public.moderation_audit_log (
    admin_user_id, action_code, post_id, details
  ) VALUES (
    v_admin_user_id,
    v_action_code,
    v_post_id,
    COALESCE(p_details, 'Comment visibility changed')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_post_visibility(uuid, boolean, uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_comment_visibility(uuid, boolean, text)
  TO authenticated;
