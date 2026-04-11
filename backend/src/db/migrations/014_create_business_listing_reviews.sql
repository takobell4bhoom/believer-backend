CREATE TABLE IF NOT EXISTS business_listing_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_listing_id UUID NOT NULL REFERENCES business_listings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comments TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_listing_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_business_listing_reviews_listing_created_at
  ON business_listing_reviews(business_listing_id, created_at DESC);

