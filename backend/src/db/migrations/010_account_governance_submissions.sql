CREATE TABLE IF NOT EXISTS support_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  full_name VARCHAR(120) NOT NULL,
  email CITEXT NOT NULL,
  subject VARCHAR(120) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mosque_suggestions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  submitter_name VARCHAR(120) NOT NULL,
  submitter_email CITEXT NOT NULL,
  mosque_name VARCHAR(180) NOT NULL,
  city VARCHAR(120) NOT NULL,
  country VARCHAR(120) NOT NULL,
  address_line TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_support_requests_user_id
  ON support_requests(user_id);

CREATE INDEX IF NOT EXISTS idx_support_requests_created_at
  ON support_requests(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mosque_suggestions_user_id
  ON mosque_suggestions(user_id);

CREATE INDEX IF NOT EXISTS idx_mosque_suggestions_created_at
  ON mosque_suggestions(created_at DESC);
