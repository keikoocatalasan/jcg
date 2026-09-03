-- 000010: Sync support tables - device, sync queue

CREATE TABLE IF NOT EXISTS DEVICE (
  device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  device_name TEXT NOT NULL,
  platform TEXT NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_user ON DEVICE(user_id);

CREATE TABLE IF NOT EXISTS SYNC_QUEUE (
  sync_queue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  device_id UUID REFERENCES DEVICE(device_id),
  operation_id UUID NOT NULL,
  entity_type_id SMALLINT NOT NULL REFERENCES SYNC_ENTITY_TYPE(sync_entity_type_id),
  entity_id UUID NOT NULL,
  operation_type_id SMALLINT NOT NULL REFERENCES SYNC_OPERATION_TYPE(sync_operation_type_id),
  payload_json JSONB NOT NULL,
  changed_fields_json JSONB,
  client_created_at TIMESTAMPTZ NOT NULL,
  client_updated_at TIMESTAMPTZ,
  client_sequence BIGINT NOT NULL,
  attempt_count SMALLINT NOT NULL DEFAULT 0,
  last_error TEXT,
  depends_on_entity_type TEXT,
  depends_on_entity_id TEXT,
  sync_status_id SMALLINT NOT NULL REFERENCES SYNC_STATUS(sync_status_id) DEFAULT 1,
  server_synced_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_user ON SYNC_QUEUE(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON SYNC_QUEUE(sync_status_id);
CREATE INDEX IF NOT EXISTS idx_sync_queue_operation ON SYNC_QUEUE(operation_id);
CREATE INDEX IF NOT EXISTS idx_sync_queue_entity ON SYNC_QUEUE(entity_id);
