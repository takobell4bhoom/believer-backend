CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email CITEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  full_name VARCHAR(120) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mosques (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(180) NOT NULL,
  address_line TEXT,
  city VARCHAR(120) NOT NULL,
  state VARCHAR(120),
  country VARCHAR(120) NOT NULL DEFAULT 'India',
  postal_code VARCHAR(20),
  latitude DOUBLE PRECISION NOT NULL CHECK (latitude >= -90 AND latitude <= 90),
  longitude DOUBLE PRECISION NOT NULL CHECK (longitude >= -180 AND longitude <= 180),
  google_place_id VARCHAR(255) UNIQUE,
  facilities JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'uq_mosques_identity'
  ) THEN
    ALTER TABLE mosques
      ADD CONSTRAINT uq_mosques_identity UNIQUE (name, city, address_line);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mosque_id UUID NOT NULL REFERENCES mosques(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, mosque_id)
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mosque_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mosque_id UUID NOT NULL REFERENCES mosques(id) ON DELETE CASCADE,
  rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comments TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, mosque_id)
);

CREATE TABLE IF NOT EXISTS mosque_notification_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mosque_id UUID NOT NULL REFERENCES mosques(id) ON DELETE CASCADE,
  title VARCHAR(120) NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, mosque_id, title)
);

CREATE INDEX IF NOT EXISTS idx_mosques_city ON mosques(city);
CREATE INDEX IF NOT EXISTS idx_mosques_name ON mosques(name);
CREATE INDEX IF NOT EXISTS idx_mosques_lat_lng ON mosques(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id ON bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_mosque_id ON bookmarks(mosque_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_mosque_reviews_user_id ON mosque_reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_mosque_reviews_mosque_id ON mosque_reviews(mosque_id);
CREATE INDEX IF NOT EXISTS idx_mosque_notification_settings_user_id
  ON mosque_notification_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_mosque_notification_settings_mosque_id
  ON mosque_notification_settings(mosque_id);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS users_set_updated_at ON users;
CREATE TRIGGER users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS mosques_set_updated_at ON mosques;
CREATE TRIGGER mosques_set_updated_at
BEFORE UPDATE ON mosques
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS mosque_reviews_set_updated_at ON mosque_reviews;
CREATE TRIGGER mosque_reviews_set_updated_at
BEFORE UPDATE ON mosque_reviews
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS mosque_notification_settings_set_updated_at ON mosque_notification_settings;
CREATE TRIGGER mosque_notification_settings_set_updated_at
BEFORE UPDATE ON mosque_notification_settings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Future PostGIS migration guidance:
-- 1) Add location geography(Point,4326) NULL column.
-- 2) Backfill from (longitude, latitude).
-- 3) Swap nearby query internals to ST_DWithin/ST_Distance in service layer.
-- API contracts remain unchanged.
