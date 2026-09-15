-- Fix community moderation without changing the existing trigger attachments.
-- JSON field lookup avoids referencing a column absent from the current NEW row.

CREATE OR REPLACE FUNCTION public.community_assert_content_allowed(p_text TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_normalized TEXT;
  v_compact TEXT;
BEGIN
  v_normalized := public.community_normalize_content(p_text);
  v_compact := regexp_replace(v_normalized, '[^[:alnum:]]', '', 'g');

  IF char_length(coalesce(p_text, '')) > 500 THEN
    RAISE EXCEPTION 'COMMUNITY_CONTENT_TOO_LONG'
      USING ERRCODE = 'check_violation';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.community_blocked_word bw
    CROSS JOIN LATERAL (
      SELECT public.community_normalize_content(bw.blocked_word) AS normalized_word
    ) term
    WHERE bw.is_active
      AND (
        (' ' || v_normalized || ' ') LIKE ('% ' || term.normalized_word || ' %')
        OR (
          char_length(regexp_replace(term.normalized_word, '[^[:alnum:]]', '', 'g')) >= 3
          AND v_compact LIKE '%' || regexp_replace(term.normalized_word, '[^[:alnum:]]', '', 'g') || '%'
        )
      )
  ) THEN
    RAISE EXCEPTION 'COMMUNITY_CONTENT_BLOCKED'
      USING ERRCODE = 'check_violation';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.community_reject_blocked_content()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_text TEXT;
BEGIN
  v_text := COALESCE(to_jsonb(NEW)->>'body_text', to_jsonb(NEW)->>'comment_text');
  PERFORM public.community_assert_content_allowed(v_text);
  RETURN NEW;
END;
$$;
