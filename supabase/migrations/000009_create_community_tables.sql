-- 000009: Community and moderation tables

CREATE TABLE IF NOT EXISTS COMMUNITY_POST (
  post_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  body_text TEXT NOT NULL CHECK (char_length(body_text) > 0),
  is_hidden BOOLEAN NOT NULL DEFAULT FALSE,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_community_post_user ON COMMUNITY_POST(user_id);
CREATE INDEX idx_community_post_visible ON COMMUNITY_POST(created_at DESC) WHERE is_hidden = FALSE AND is_deleted = FALSE;

CREATE TABLE IF NOT EXISTS COMMUNITY_COMMENT (
  comment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES COMMUNITY_POST(post_id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  comment_text TEXT NOT NULL CHECK (char_length(comment_text) > 0),
  is_hidden BOOLEAN NOT NULL DEFAULT FALSE,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_community_comment_post ON COMMUNITY_COMMENT(post_id);
CREATE INDEX idx_community_comment_visible ON COMMUNITY_COMMENT(post_id, created_at) WHERE is_hidden = FALSE AND is_deleted = FALSE;

CREATE TABLE IF NOT EXISTS COMMUNITY_LIKE (
  like_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES COMMUNITY_POST(post_id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_post_user_like UNIQUE (post_id, user_id)
);

CREATE INDEX idx_community_like_post ON COMMUNITY_LIKE(post_id);

CREATE TABLE IF NOT EXISTS COMMUNITY_REPORT (
  report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES COMMUNITY_POST(post_id) ON DELETE CASCADE,
  reason_id SMALLINT NOT NULL REFERENCES REPORT_REASON(reason_id),
  status_id SMALLINT NOT NULL REFERENCES REPORT_STATUS(status_id) DEFAULT 1,
  details TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ
);

CREATE INDEX idx_community_report_status ON COMMUNITY_REPORT(status_id);

CREATE TABLE IF NOT EXISTS MODERATION_ACTION (
  moderation_action_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  action_type_id SMALLINT NOT NULL REFERENCES MODERATION_ACTION_TYPE(action_type_id),
  post_id UUID REFERENCES COMMUNITY_POST(post_id),
  comment_id UUID REFERENCES COMMUNITY_COMMENT(comment_id),
  report_id UUID REFERENCES COMMUNITY_REPORT(report_id),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_moderation_action_admin ON MODERATION_ACTION(admin_user_id);

CREATE TRIGGER trg_community_post_updated_at
  BEFORE UPDATE ON COMMUNITY_POST
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_community_comment_updated_at
  BEFORE UPDATE ON COMMUNITY_COMMENT
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
