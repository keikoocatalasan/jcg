-- Add component-aware scan metadata without breaking the existing candidate API.

ALTER TABLE public.ai_scan
  ADD COLUMN IF NOT EXISTS pipeline_version TEXT NOT NULL DEFAULT 'scanner-v2',
  ADD COLUMN IF NOT EXISTS composition_confidence NUMERIC(6,4),
  ADD COLUMN IF NOT EXISTS needs_portion_input BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE public.ai_scan_prediction
  ADD COLUMN IF NOT EXISTS serving_grams NUMERIC(8,2);

-- The original scanner policies only allowed administrators to insert
-- predictions. Restore the required owner-scoped app write path with checks.
DROP POLICY IF EXISTS ai_scan_insert_own ON public.ai_scan;
CREATE POLICY ai_scan_insert_own ON public.ai_scan
  FOR INSERT WITH CHECK (user_id = public.get_app_user_id());

DROP POLICY IF EXISTS ai_scan_update_own ON public.ai_scan;
CREATE POLICY ai_scan_update_own ON public.ai_scan
  FOR UPDATE
  USING (user_id = public.get_app_user_id())
  WITH CHECK (user_id = public.get_app_user_id());

DROP POLICY IF EXISTS ai_scan_prediction_insert_own
  ON public.ai_scan_prediction;
CREATE POLICY ai_scan_prediction_insert_own ON public.ai_scan_prediction
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.ai_scan
      WHERE ai_scan.scan_id = ai_scan_prediction.scan_id
        AND ai_scan.user_id = public.get_app_user_id()
    )
  );

DROP POLICY IF EXISTS ai_scan_prediction_update_own
  ON public.ai_scan_prediction;
CREATE POLICY ai_scan_prediction_update_own ON public.ai_scan_prediction
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.ai_scan
      WHERE ai_scan.scan_id = ai_scan_prediction.scan_id
        AND ai_scan.user_id = public.get_app_user_id()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.ai_scan
      WHERE ai_scan.scan_id = ai_scan_prediction.scan_id
        AND ai_scan.user_id = public.get_app_user_id()
    )
  );

DROP POLICY IF EXISTS ai_scan_prediction_delete_own
  ON public.ai_scan_prediction;
CREATE POLICY ai_scan_prediction_delete_own ON public.ai_scan_prediction
  FOR DELETE USING (
    EXISTS (
      SELECT 1
      FROM public.ai_scan
      WHERE ai_scan.scan_id = ai_scan_prediction.scan_id
        AND ai_scan.user_id = public.get_app_user_id()
    )
  );

CREATE TABLE IF NOT EXISTS public.ai_scan_component (
  component_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scan_id UUID NOT NULL REFERENCES public.ai_scan(scan_id) ON DELETE CASCADE,
  component_order SMALLINT NOT NULL CHECK (component_order > 0),
  role_code TEXT NOT NULL CHECK (
    role_code IN ('ulam', 'rice', 'vegetable', 'soup', 'side', 'drink', 'sauce', 'dessert', 'unknown')
  ),
  food_id UUID REFERENCES public.food_item(food_id),
  predicted_food_name TEXT NOT NULL,
  confidence NUMERIC(6,4) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
  alternative_names JSONB NOT NULL DEFAULT '[]'::JSONB,
  reference_grams NUMERIC(8,2) CHECK (reference_grams IS NULL OR reference_grams > 0),
  grams NUMERIC(8,2) CHECK (grams IS NULL OR grams > 0),
  portion_method TEXT NOT NULL DEFAULT 'not_provided' CHECK (
    portion_method IN ('not_provided', 'user_input', 'serving_preset', 'visual_estimate')
  ),
  portion_confidence NUMERIC(6,4) CHECK (
    portion_confidence IS NULL OR (portion_confidence >= 0 AND portion_confidence <= 1)
  ),
  calories NUMERIC(8,2) CHECK (calories IS NULL OR calories >= 0),
  protein_g NUMERIC(8,2) CHECK (protein_g IS NULL OR protein_g >= 0),
  carbs_g NUMERIC(8,2) CHECK (carbs_g IS NULL OR carbs_g >= 0),
  fat_g NUMERIC(8,2) CHECK (fat_g IS NULL OR fat_g >= 0),
  estimated_cost_php NUMERIC(8,2) CHECK (
    estimated_cost_php IS NULL OR estimated_cost_php >= 0
  ),
  is_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_ai_scan_component_order UNIQUE (scan_id, component_order)
);

CREATE INDEX IF NOT EXISTS idx_ai_scan_component_scan
  ON public.ai_scan_component(scan_id, component_order);

CREATE INDEX IF NOT EXISTS idx_ai_scan_component_food
  ON public.ai_scan_component(food_id)
  WHERE food_id IS NOT NULL;

ALTER TABLE public.ai_scan_component ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_scan_component_select_own
  ON public.ai_scan_component;
CREATE POLICY ai_scan_component_select_own ON public.ai_scan_component
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM public.ai_scan
      WHERE ai_scan.scan_id = ai_scan_component.scan_id
        AND ai_scan.user_id = public.get_app_user_id()
    )
  );

DROP POLICY IF EXISTS ai_scan_component_insert_own
  ON public.ai_scan_component;
CREATE POLICY ai_scan_component_insert_own ON public.ai_scan_component
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.ai_scan
      WHERE ai_scan.scan_id = ai_scan_component.scan_id
        AND ai_scan.user_id = public.get_app_user_id()
    )
  );

DROP POLICY IF EXISTS ai_scan_component_update_own
  ON public.ai_scan_component;
CREATE POLICY ai_scan_component_update_own ON public.ai_scan_component
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.ai_scan
      WHERE ai_scan.scan_id = ai_scan_component.scan_id
        AND ai_scan.user_id = public.get_app_user_id()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.ai_scan
      WHERE ai_scan.scan_id = ai_scan_component.scan_id
        AND ai_scan.user_id = public.get_app_user_id()
    )
  );

DROP POLICY IF EXISTS ai_scan_component_delete_own
  ON public.ai_scan_component;
CREATE POLICY ai_scan_component_delete_own ON public.ai_scan_component
  FOR DELETE USING (
    EXISTS (
      SELECT 1
      FROM public.ai_scan
      WHERE ai_scan.scan_id = ai_scan_component.scan_id
        AND ai_scan.user_id = public.get_app_user_id()
    )
  );

DROP POLICY IF EXISTS ai_scan_component_admin_all
  ON public.ai_scan_component;
DROP POLICY IF EXISTS ai_scan_component_admin_select
  ON public.ai_scan_component;
CREATE POLICY ai_scan_component_admin_select ON public.ai_scan_component
  FOR SELECT USING (public.is_admin());
DROP POLICY IF EXISTS ai_scan_component_admin_insert
  ON public.ai_scan_component;
CREATE POLICY ai_scan_component_admin_insert ON public.ai_scan_component
  FOR INSERT WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS ai_scan_component_admin_update
  ON public.ai_scan_component;
CREATE POLICY ai_scan_component_admin_update ON public.ai_scan_component
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS ai_scan_component_admin_delete
  ON public.ai_scan_component;
CREATE POLICY ai_scan_component_admin_delete ON public.ai_scan_component
  FOR DELETE USING (public.is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.ai_scan_component TO authenticated;

INSERT INTO public.sync_entity_type (entity_code, entity_name)
VALUES ('ai_scan_component', 'AI Scan Component')
ON CONFLICT (entity_code) DO NOTHING;

CREATE OR REPLACE FUNCTION public.touch_ai_scan_component_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ai_scan_component_updated_at
  ON public.ai_scan_component;
CREATE TRIGGER trg_ai_scan_component_updated_at
  BEFORE UPDATE ON public.ai_scan_component
  FOR EACH ROW EXECUTE FUNCTION public.touch_ai_scan_component_updated_at();
