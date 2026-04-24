CREATE TABLE IF NOT EXISTS notification_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  installation_id VARCHAR(120) NOT NULL,
  platform VARCHAR(20) NOT NULL CHECK (platform IN ('android', 'ios')),
  push_token TEXT NOT NULL,
  locale VARCHAR(24),
  app_version VARCHAR(40),
  remote_push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, installation_id)
);

CREATE INDEX IF NOT EXISTS idx_notification_devices_user_id
  ON notification_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_devices_active
  ON notification_devices(is_active, remote_push_enabled);
CREATE INDEX IF NOT EXISTS idx_notification_devices_push_token
  ON notification_devices(push_token);

DROP TRIGGER IF EXISTS notification_devices_set_updated_at ON notification_devices;
CREATE TRIGGER notification_devices_set_updated_at
BEFORE UPDATE ON notification_devices
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE IF NOT EXISTS notification_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type VARCHAR(80) NOT NULL,
  entity_type VARCHAR(80) NOT NULL,
  entity_id UUID,
  mosque_id UUID REFERENCES mosques(id) ON DELETE CASCADE,
  title VARCHAR(180) NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notification_events_event_type
  ON notification_events(event_type);
CREATE INDEX IF NOT EXISTS idx_notification_events_entity
  ON notification_events(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_notification_events_mosque_id
  ON notification_events(mosque_id);
