ALTER TABLE mosque_page_content
  ADD COLUMN IF NOT EXISTS about_title TEXT,
  ADD COLUMN IF NOT EXISTS about_body TEXT;
