-- 000008: Chatbot tables

CREATE TABLE IF NOT EXISTS CHAT_SESSION (
  chat_session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_chat_session_user ON CHAT_SESSION(user_id);

CREATE TABLE IF NOT EXISTS CHAT_MESSAGE (
  chat_message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_session_id UUID NOT NULL REFERENCES CHAT_SESSION(chat_session_id) ON DELETE CASCADE,
  chat_role_id SMALLINT NOT NULL REFERENCES CHAT_ROLE(chat_role_id),
  safety_status_id SMALLINT NOT NULL REFERENCES CHAT_SAFETY_STATUS(safety_status_id),
  delivery_status_id SMALLINT NOT NULL REFERENCES CHAT_DELIVERY_STATUS(delivery_status_id),
  message_text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_chat_message_session ON CHAT_MESSAGE(chat_session_id);
CREATE INDEX IF NOT EXISTS idx_chat_message_created ON CHAT_MESSAGE(chat_session_id, created_at);

CREATE TABLE IF NOT EXISTS CHAT_MESSAGE_CONTEXT (
  context_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_message_id UUID NOT NULL REFERENCES CHAT_MESSAGE(chat_message_id) ON DELETE CASCADE,
  context_type TEXT NOT NULL,
  context_value_json JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_chat_context_message ON CHAT_MESSAGE_CONTEXT(chat_message_id);
