CREATE TABLE IF NOT EXISTS mosque_broadcast_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mosque_id UUID NOT NULL REFERENCES mosques(id) ON DELETE CASCADE,
  title VARCHAR(180) NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (mosque_id, title, published_at)
);

CREATE INDEX IF NOT EXISTS idx_mosque_broadcast_messages_mosque_id
  ON mosque_broadcast_messages(mosque_id);

CREATE INDEX IF NOT EXISTS idx_mosque_broadcast_messages_published_at
  ON mosque_broadcast_messages(published_at DESC);
