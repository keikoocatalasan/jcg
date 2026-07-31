-- 000028: Audit trail tables and RPC for admin operations

-- ────────────────────────────────────────────────────────────
-- TABLE: admin_role_audit — tracks manual role changes
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ADMIN_ROLE_AUDIT (
  audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  changed_by UUID NOT NULL REFERENCES APP_USER(user_id),
  target_user UUID NOT NULL REFERENCES APP_USER(user_id),
  old_role_id SMALLINT REFERENCES ROLE(role_id),
  new_role_id SMALLINT NOT NULL REFERENCES ROLE(role_id),
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_admin_role_audit_target ON ADMIN_ROLE_AUDIT(target_user);
CREATE INDEX idx_admin_role_audit_changed_by ON ADMIN_ROLE_AUDIT(changed_by);

ALTER TABLE ADMIN_ROLE_AUDIT ENABLE ROW LEVEL SECURITY;
CREATE POLICY admin_role_audit_select ON ADMIN_ROLE_AUDIT
  FOR SELECT USING (is_admin());
CREATE POLICY admin_role_audit_insert ON ADMIN_ROLE_AUDIT
  FOR INSERT WITH CHECK (is_admin());

-- ────────────────────────────────────────────────────────────
-- RPC: admin_set_user_role — atomic role change + audit trail
-- Replace raw UPDATE app_user with this RPC going forward.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_set_user_role(
  p_target_user_id UUID,
  p_new_role_id SMALLINT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_user_id UUID;
  v_old_role_id SMALLINT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only administrators can change user roles';
  END IF;

  SELECT user_id INTO v_admin_user_id
  FROM APP_USER WHERE auth_user_id = auth.uid()::UUID;

  SELECT role_id INTO v_old_role_id
  FROM APP_USER WHERE user_id = p_target_user_id;

  IF v_old_role_id IS NULL THEN
    RAISE EXCEPTION 'Target user not found';
  END IF;

  UPDATE APP_USER SET role_id = p_new_role_id
  WHERE user_id = p_target_user_id;

  INSERT INTO ADMIN_ROLE_AUDIT (
    changed_by, target_user, old_role_id, new_role_id
  ) VALUES (
    v_admin_user_id, p_target_user_id, v_old_role_id, p_new_role_id
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- TABLE: moderation_audit_log — tracks all moderation actions
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS MODERATION_AUDIT_LOG (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL REFERENCES APP_USER(user_id),
  action_code TEXT NOT NULL,
  report_id UUID REFERENCES COMMUNITY_REPORT(report_id),
  post_id UUID REFERENCES COMMUNITY_POST(post_id),
  details TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_moderation_audit_admin ON MODERATION_AUDIT_LOG(admin_user_id);
CREATE INDEX idx_moderation_audit_report ON MODERATION_AUDIT_LOG(report_id);
CREATE INDEX idx_moderation_audit_created ON MODERATION_AUDIT_LOG(created_at);

ALTER TABLE MODERATION_AUDIT_LOG ENABLE ROW LEVEL SECURITY;
CREATE POLICY moderation_audit_select ON MODERATION_AUDIT_LOG
  FOR SELECT USING (is_admin());
CREATE POLICY moderation_audit_insert ON MODERATION_AUDIT_LOG
  FOR INSERT WITH CHECK (is_admin());

-- ────────────────────────────────────────────────────────────
-- RPC: admin_log_moderation_action — atomic moderation + audit
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_log_moderation_action(
  p_action_code TEXT,
  p_report_id UUID DEFAULT NULL,
  p_post_id UUID DEFAULT NULL,
  p_details TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_user_id UUID;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only administrators can log moderation actions';
  END IF;

  SELECT user_id INTO v_admin_user_id
  FROM APP_USER WHERE auth_user_id = auth.uid()::UUID;

  INSERT INTO MODERATION_AUDIT_LOG (
    admin_user_id, action_code, report_id, post_id, details
  ) VALUES (
    v_admin_user_id, p_action_code, p_report_id, p_post_id, p_details
  );
END;
$$;

-- Enhance admin_hide_reported_post to also write audit
CREATE OR REPLACE FUNCTION admin_hide_reported_post(
  p_report_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_post_id UUID;
  v_admin_user_id UUID;
  v_action_taken_id SMALLINT;
  v_hide_post_type_id SMALLINT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only administrators can hide reported posts';
  END IF;

  SELECT status_id INTO v_action_taken_id
  FROM REPORT_STATUS WHERE status_code = 'action_taken';

  SELECT action_type_id INTO v_hide_post_type_id
  FROM MODERATION_ACTION_TYPE WHERE action_code = 'hide_post';

  SELECT user_id INTO v_admin_user_id
  FROM APP_USER WHERE auth_user_id = auth.uid()::UUID;

  SELECT post_id INTO v_post_id
  FROM COMMUNITY_REPORT WHERE report_id = p_report_id;

  IF v_post_id IS NULL THEN
    RAISE EXCEPTION 'Report not found';
  END IF;

  UPDATE COMMUNITY_REPORT
  SET status_id = v_action_taken_id
  WHERE report_id = p_report_id;

  UPDATE COMMUNITY_POST
  SET is_hidden = TRUE
  WHERE post_id = v_post_id;

  INSERT INTO MODERATION_ACTION (
    admin_user_id, action_type_id, post_id,
    report_id, reason
  ) VALUES (
    v_admin_user_id, v_hide_post_type_id, v_post_id,
    p_report_id, 'Post hidden after moderation review'
  );

  INSERT INTO MODERATION_AUDIT_LOG (
    admin_user_id, action_code, report_id, post_id, details
  ) VALUES (
    v_admin_user_id, 'hide_post', p_report_id, v_post_id,
    'Post hidden after moderation review'
  );
END;
$$;
