-- Expand Community content safety to cover common Filipino/English abuse and
-- the simple obfuscation patterns handled by the Flutter client.

INSERT INTO public.community_blocked_word (blocked_word)
VALUES
  ('putangina'), ('putang ina'), ('putang ina mo'), ('puta'), ('gago'),
  ('gaga'), ('tanga'), ('bobo'), ('ulol'), ('kupal'), ('tarantado'),
  ('siraulo'), ('bwisit'), ('buwisit'), ('lintik'), ('leche'), ('pakshet'),
  ('pakshit'), ('hinayupak'), ('hayop ka'), ('manyakis'), ('malandi'),
  ('bastos'), ('yawa'), ('pisti'), ('fuck'), ('fck'), ('fucking'), ('shit'),
  ('bullshit'), ('bitch'), ('asshole'), ('bastard'), ('damn'), ('crap'),
  ('dick'), ('pussy'), ('cunt'), ('slut'), ('whore'), ('jerk'), ('idiot'),
  ('moron'), ('stupid'), ('porn'), ('nude'), ('nudes'), ('sexual'), ('rape'),
  ('rapist'), ('kys'), ('kill yourself'), ('go die'), ('i will kill you'),
  ('kill you'), ('shoot you'), ('nigger'), ('nigga'), ('faggot'), ('fag'),
  ('dyke'), ('tranny'), ('retard'), ('chink'), ('spic'), ('wetback'), ('kike')
ON CONFLICT (blocked_word) DO NOTHING;

CREATE OR REPLACE FUNCTION public.community_normalize_content(p_text TEXT)
RETURNS TEXT
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT trim(
    regexp_replace(
      regexp_replace(
        translate(
          lower(coalesce(p_text, '')),
          '01345789@$!|áàâäãåéèêëíìîïóòôöõúùûüñçаеіоскрхуορι',
          'oieastbgasiiaaaaaaeeeeiiiiooooouuuuncaeiockpxyopi'
        ),
        '(.)\1+',
        '\1',
        'g'
      ),
      '[^[:alnum:]]+',
      ' ',
      'g'
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.community_reject_blocked_content()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_text TEXT;
  v_normalized TEXT;
  v_compact TEXT;
BEGIN
  v_text := CASE TG_TABLE_NAME
    WHEN 'community_post' THEN NEW.body_text
    ELSE NEW.comment_text
  END;
  v_normalized := public.community_normalize_content(v_text);
  v_compact := regexp_replace(v_normalized, '[^[:alnum:]]', '', 'g');

  IF char_length(coalesce(v_text, '')) > 500 THEN
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
        (' ' || v_normalized || ' ') LIKE
          ('% ' || term.normalized_word || ' %')
        OR (
          char_length(regexp_replace(term.normalized_word, '[^[:alnum:]]', '', 'g')) >= 3
          AND v_compact LIKE '%' || regexp_replace(term.normalized_word, '[^[:alnum:]]', '', 'g') || '%'
        )
      )
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
