CREATE TABLE IF NOT EXISTS business_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(32) NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'under_review', 'live')),
  basic_details JSONB NOT NULL DEFAULT '{}'::jsonb,
  contact_details JSONB NOT NULL DEFAULT '{}'::jsonb,
  business_name VARCHAR(180),
  category_group_id VARCHAR(120),
  category_group_label VARCHAR(120),
  category_item_id VARCHAR(120),
  category_item_label VARCHAR(120),
  business_email CITEXT,
  phone VARCHAR(40),
  city VARCHAR(120),
  is_online_only BOOLEAN NOT NULL DEFAULT FALSE,
  submitted_at TIMESTAMPTZ,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_business_listings_status
  ON business_listings(status);

CREATE INDEX IF NOT EXISTS idx_business_listings_updated_at
  ON business_listings(updated_at DESC);

DROP TRIGGER IF EXISTS business_listings_set_updated_at ON business_listings;
CREATE TRIGGER business_listings_set_updated_at
BEFORE UPDATE ON business_listings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
