DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_role_check'
      AND conrelid = 'users'::regclass
  ) THEN
    ALTER TABLE users DROP CONSTRAINT users_role_check;
  END IF;

  ALTER TABLE users
    ADD CONSTRAINT users_role_check
    CHECK (role IN ('community', 'admin', 'super_admin'));
END $$;

ALTER TABLE business_listings
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE business_listings
  DROP CONSTRAINT IF EXISTS business_listings_status_check;

ALTER TABLE business_listings
  ADD CONSTRAINT business_listings_status_check
  CHECK (status IN ('draft', 'under_review', 'live', 'rejected'));
