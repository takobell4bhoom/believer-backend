ALTER TABLE mosques
  ADD COLUMN IF NOT EXISTS moderation_status VARCHAR(32),
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

UPDATE mosques
SET moderation_status = CASE
  WHEN is_verified = TRUE THEN 'live'
  ELSE 'pending'
END
WHERE moderation_status IS NULL;

ALTER TABLE mosques
  ALTER COLUMN moderation_status SET DEFAULT 'pending';

ALTER TABLE mosques
  DROP CONSTRAINT IF EXISTS mosques_moderation_status_check;

ALTER TABLE mosques
  ADD CONSTRAINT mosques_moderation_status_check
  CHECK (moderation_status IN ('pending', 'live', 'rejected'));

ALTER TABLE mosques
  ALTER COLUMN moderation_status SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mosques_moderation_status
  ON mosques(moderation_status);
