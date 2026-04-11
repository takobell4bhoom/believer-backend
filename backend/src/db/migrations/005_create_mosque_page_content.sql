CREATE TABLE IF NOT EXISTS mosque_page_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mosque_id UUID NOT NULL REFERENCES mosques(id) ON DELETE CASCADE,
  events JSONB NOT NULL DEFAULT '[]'::jsonb,
  classes JSONB NOT NULL DEFAULT '[]'::jsonb,
  connect_links JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (mosque_id)
);

CREATE INDEX IF NOT EXISTS idx_mosque_page_content_mosque_id
  ON mosque_page_content(mosque_id);

DROP TRIGGER IF EXISTS mosque_page_content_set_updated_at ON mosque_page_content;
CREATE TRIGGER mosque_page_content_set_updated_at
BEFORE UPDATE ON mosque_page_content
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
