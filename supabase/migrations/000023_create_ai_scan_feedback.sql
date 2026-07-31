-- Persist deterministic scanner feedback submitted through FastAPI.
CREATE TABLE IF NOT EXISTS public.ai_scan_feedback (
  feedback_id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.app_user(user_id) ON DELETE CASCADE,
  client_scan_id UUID NOT NULL,
  -- Scanner candidates can be catalog UUIDs or deterministic demo identifiers.
  selected_food_id TEXT,
  was_helpful BOOLEAN NOT NULL,
  feedback_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_scan_feedback_user_created
  ON public.ai_scan_feedback(user_id, created_at DESC);

ALTER TABLE public.ai_scan_feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY ai_scan_feedback_select_own ON public.ai_scan_feedback
  FOR SELECT USING (user_id = public.get_app_user_id());
