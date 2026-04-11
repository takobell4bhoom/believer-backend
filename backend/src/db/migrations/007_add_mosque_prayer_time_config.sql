CREATE TABLE IF NOT EXISTS mosque_prayer_time_configs (
  mosque_id UUID PRIMARY KEY REFERENCES mosques(id) ON DELETE CASCADE,
  calculation_method SMALLINT NOT NULL CHECK (calculation_method >= 0 AND calculation_method <= 99),
  school VARCHAR(16) NOT NULL DEFAULT 'standard',
  adjustments JSONB NOT NULL DEFAULT
    '{"fajr":0,"sunrise":0,"dhuhr":0,"asr":0,"maghrib":0,"isha":0}'::jsonb,
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'mosque_prayer_time_configs_school_check'
  ) THEN
    ALTER TABLE mosque_prayer_time_configs
      ADD CONSTRAINT mosque_prayer_time_configs_school_check
      CHECK (school IN ('standard', 'hanafi'));
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS mosque_prayer_time_daily_cache (
  mosque_id UUID NOT NULL REFERENCES mosques(id) ON DELETE CASCADE,
  prayer_date DATE NOT NULL,
  payload JSONB NOT NULL,
  cached_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (mosque_id, prayer_date)
);

CREATE INDEX IF NOT EXISTS idx_mosque_prayer_time_daily_cache_mosque_id
  ON mosque_prayer_time_daily_cache(mosque_id);

DROP TRIGGER IF EXISTS mosque_prayer_time_configs_set_updated_at
  ON mosque_prayer_time_configs;
CREATE TRIGGER mosque_prayer_time_configs_set_updated_at
BEFORE UPDATE ON mosque_prayer_time_configs
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
