UPDATE business_listings
SET
  category_group_id = CASE
    WHEN NULLIF(TRIM(category_group_id), '') IS NULL
    THEN NULLIF(TRIM(basic_details->'selectedType'->>'groupId'), '')
    ELSE category_group_id
  END,
  category_group_label = CASE
    WHEN NULLIF(TRIM(category_group_label), '') IS NULL
    THEN NULLIF(TRIM(basic_details->'selectedType'->>'groupLabel'), '')
    ELSE category_group_label
  END,
  category_item_id = CASE
    WHEN NULLIF(TRIM(category_item_id), '') IS NULL
    THEN NULLIF(TRIM(basic_details->'selectedType'->>'itemId'), '')
    ELSE category_item_id
  END,
  category_item_label = CASE
    WHEN NULLIF(TRIM(category_item_label), '') IS NULL
    THEN NULLIF(TRIM(basic_details->'selectedType'->>'itemLabel'), '')
    ELSE category_item_label
  END
WHERE jsonb_typeof(basic_details->'selectedType') = 'object'
  AND (
    (
      NULLIF(TRIM(category_group_id), '') IS NULL
      AND NULLIF(TRIM(basic_details->'selectedType'->>'groupId'), '') IS NOT NULL
    )
    OR (
      NULLIF(TRIM(category_group_label), '') IS NULL
      AND NULLIF(TRIM(basic_details->'selectedType'->>'groupLabel'), '') IS NOT NULL
    )
    OR (
      NULLIF(TRIM(category_item_id), '') IS NULL
      AND NULLIF(TRIM(basic_details->'selectedType'->>'itemId'), '') IS NOT NULL
    )
    OR (
      NULLIF(TRIM(category_item_label), '') IS NULL
      AND NULLIF(TRIM(basic_details->'selectedType'->>'itemLabel'), '') IS NOT NULL
    )
  );
