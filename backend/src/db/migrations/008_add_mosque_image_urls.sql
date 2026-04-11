ALTER TABLE mosques
  ADD COLUMN IF NOT EXISTS image_urls JSONB NOT NULL DEFAULT '[]'::jsonb;

UPDATE mosques
SET image_urls = CASE
  WHEN image_url IS NULL OR btrim(image_url) = '' THEN '[]'::jsonb
  ELSE jsonb_build_array(image_url)
END
WHERE image_urls = '[]'::jsonb;
