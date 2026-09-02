-- Community content safety, realtime publication, and update-policy hardening.

CREATE TABLE IF NOT EXISTS public.community_blocked_word (
  blocked_word_id BIGSERIAL PRIMARY KEY,
  blocked_word TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

REVOKE ALL ON TABLE public.community_blocked_word FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.community_blocked_word TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.community_blocked_word_blocked_word_id_seq
  TO authenticated;

ALTER TABLE public.community_blocked_word ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS community_blocked_word_admin_select
  ON public.community_blocked_word;
CREATE POLICY community_blocked_word_admin_select
ON public.community_blocked_word FOR SELECT
TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS community_blocked_word_admin_write
  ON public.community_blocked_word;
CREATE POLICY community_blocked_word_admin_write
ON public.community_blocked_word FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

INSERT INTO public.community_blocked_word (blocked_word)
VALUES
  ('putangina'),
  ('putang ina'),
  ('puta'),
  ('gago'),
  ('tanga'),
  ('bobo'),
  ('ulol'),
  ('fuck'),
  ('fck'),
  ('fucking'),
  ('shit'),
  ('bitch'),
  ('asshole'),
  ('kill yourself')
ON CONFLICT (blocked_word) DO NOTHING;

CREATE OR REPLACE FUNCTION public.community_reject_blocked_content()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_text TEXT;
  v_normalized TEXT;
BEGIN
  v_text := CASE TG_TABLE_NAME
    WHEN 'community_post' THEN NEW.body_text
    ELSE NEW.comment_text
  END;
  v_normalized := regexp_replace(lower(coalesce(v_text, '')), '[^[:alnum:]]+', ' ', 'g');

  IF char_length(coalesce(v_text, '')) > 500 THEN
    RAISE EXCEPTION 'COMMUNITY_CONTENT_TOO_LONG'
      USING ERRCODE = 'check_violation';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.community_blocked_word bw
    WHERE bw.is_active
      AND (' ' || v_normalized || ' ') LIKE
          ('% ' || regexp_replace(lower(bw.blocked_word), '[^[:alnum:]]+', ' ', 'g') || ' %')
  ) THEN
    RAISE EXCEPTION 'COMMUNITY_CONTENT_BLOCKED'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_community_post_content_safety
  ON public.community_post;
CREATE TRIGGER trg_community_post_content_safety
BEFORE INSERT OR UPDATE OF body_text ON public.community_post
FOR EACH ROW EXECUTE FUNCTION public.community_reject_blocked_content();

DROP TRIGGER IF EXISTS trg_community_comment_content_safety
  ON public.community_comment;
CREATE TRIGGER trg_community_comment_content_safety
BEFORE INSERT OR UPDATE OF comment_text ON public.community_comment
FOR EACH ROW EXECUTE FUNCTION public.community_reject_blocked_content();

DROP POLICY IF EXISTS community_post_update_own ON public.community_post;
CREATE POLICY community_post_update_own
ON public.community_post FOR UPDATE
TO authenticated
USING (user_id = public.get_app_user_id())
WITH CHECK (user_id = public.get_app_user_id());

DROP POLICY IF EXISTS community_comment_update_own ON public.community_comment;
CREATE POLICY community_comment_update_own
ON public.community_comment FOR UPDATE
TO authenticated
USING (user_id = public.get_app_user_id())
WITH CHECK (user_id = public.get_app_user_id());

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'community_post'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.community_post;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'community_comment'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.community_comment;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'community_like'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.community_like;
    END IF;
  END IF;
END;
$$;
