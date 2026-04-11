import { pool } from '../db/pool.js';

const BUSINESS_LISTING_STATUSES = {
  draft: 'draft',
  underReview: 'under_review',
  live: 'live',
  rejected: 'rejected'
};

function emptyBasicDetails() {
  return {
    businessName: '',
    logo: null,
    selectedType: null,
    tagline: '',
    description: ''
  };
}

function emptyContactDetails() {
  return {
    businessEmail: '',
    phone: '',
    whatsapp: '',
    openingTime: null,
    closingTime: null,
    instagramUrl: '',
    facebookUrl: '',
    websiteUrl: '',
    address: '',
    zipCode: '',
    city: '',
    onlineOnly: false
  };
}

function normalizeBasicDetails(input = {}) {
  const empty = emptyBasicDetails();
  return {
    ...empty,
    ...input,
    businessName: input.businessName ?? empty.businessName,
    logo: input.logo ?? empty.logo,
    selectedType: input.selectedType ?? empty.selectedType,
    tagline: input.tagline ?? empty.tagline,
    description: input.description ?? empty.description
  };
}

function normalizeContactDetails(input = {}) {
  const empty = emptyContactDetails();
  return {
    ...empty,
    ...input,
    businessEmail: input.businessEmail ?? empty.businessEmail,
    phone: input.phone ?? empty.phone,
    whatsapp: input.whatsapp ?? empty.whatsapp,
    openingTime: input.openingTime ?? empty.openingTime,
    closingTime: input.closingTime ?? empty.closingTime,
    instagramUrl: input.instagramUrl ?? empty.instagramUrl,
    facebookUrl: input.facebookUrl ?? empty.facebookUrl,
    websiteUrl: input.websiteUrl ?? empty.websiteUrl,
    address: input.address ?? empty.address,
    zipCode: input.zipCode ?? empty.zipCode,
    city: input.city ?? empty.city,
    onlineOnly: input.onlineOnly ?? empty.onlineOnly
  };
}

function buildListingWriteValues({
  status,
  basicDetails,
  contactDetails,
  submittedAt = null,
  publishedAt = null,
  reviewedBy = null,
  reviewedAt = null,
  rejectionReason = null
}) {
  const selectedType = basicDetails.selectedType;

  return [
    status,
    JSON.stringify(basicDetails),
    JSON.stringify(contactDetails),
    basicDetails.businessName || null,
    selectedType?.groupId || null,
    selectedType?.groupLabel || null,
    selectedType?.itemId || null,
    selectedType?.itemLabel || null,
    contactDetails.businessEmail || null,
    contactDetails.phone || null,
    contactDetails.city || null,
    Boolean(contactDetails.onlineOnly),
    submittedAt,
    publishedAt,
    reviewedBy,
    reviewedAt,
    rejectionReason
  ];
}

function normalizeStoredCategoryField(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length ? trimmed : null;
}

function readPublicCategory(row) {
  const groupId = normalizeStoredCategoryField(row.category_group_id);
  const groupLabel = normalizeStoredCategoryField(row.category_group_label);
  const itemId = normalizeStoredCategoryField(row.category_item_id);
  const itemLabel = normalizeStoredCategoryField(row.category_item_label);

  if (!groupId && !groupLabel && !itemId && !itemLabel) {
    return null;
  }

  return {
    groupId,
    groupLabel,
    itemId,
    itemLabel
  };
}

function mapListingRow(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    status: row.status,
    basicDetails: normalizeBasicDetails(row.basic_details),
    contactDetails: normalizeContactDetails(row.contact_details),
    submittedAt: row.submitted_at ? new Date(row.submitted_at).toISOString() : null,
    publishedAt: row.published_at ? new Date(row.published_at).toISOString() : null,
    reviewedBy: row.reviewed_by ?? null,
    reviewedAt: row.reviewed_at ? new Date(row.reviewed_at).toISOString() : null,
    rejectionReason: row.rejection_reason ?? null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    lastUpdatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
    publicCategory: readPublicCategory(row),
    ...(row.submitter_id
      ? {
          submitter: {
            id: row.submitter_id,
            fullName: row.submitter_full_name,
            email: row.submitter_email
          }
        }
      : {})
  };
}

function mapBusinessReviewRow(row) {
  return {
    id: row.id,
    rating: Number(row.rating),
    userName: row.user_name?.trim() || 'Community Member',
    comment: row.comments?.trim() || '',
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null
  };
}

async function upsertBusinessListing({
  userId,
  status,
  basicDetails,
  contactDetails,
  submittedAt = null,
  publishedAt = null,
  reviewedBy = null,
  reviewedAt = null,
  rejectionReason = null
}) {
  const values = [
    userId,
    ...buildListingWriteValues({
      status,
      basicDetails,
      contactDetails,
      submittedAt,
      publishedAt,
      reviewedBy,
      reviewedAt,
      rejectionReason
    })
  ];

  const result = await pool.query(
    `INSERT INTO business_listings (
       user_id,
       status,
       basic_details,
       contact_details,
       business_name,
       category_group_id,
       category_group_label,
       category_item_id,
       category_item_label,
       business_email,
       phone,
       city,
       is_online_only,
       submitted_at,
       published_at,
       reviewed_by,
       reviewed_at,
       rejection_reason
     ) VALUES (
       $1,
       $2,
       $3::jsonb,
       $4::jsonb,
       $5,
       $6,
       $7,
       $8,
       $9,
       $10,
       $11,
       $12,
       $13,
       $14,
       $15,
       $16,
       $17,
       $18
     )
     ON CONFLICT (user_id) DO UPDATE SET
       status = EXCLUDED.status,
       basic_details = EXCLUDED.basic_details,
       contact_details = EXCLUDED.contact_details,
       business_name = EXCLUDED.business_name,
       category_group_id = EXCLUDED.category_group_id,
       category_group_label = EXCLUDED.category_group_label,
       category_item_id = EXCLUDED.category_item_id,
       category_item_label = EXCLUDED.category_item_label,
       business_email = EXCLUDED.business_email,
       phone = EXCLUDED.phone,
       city = EXCLUDED.city,
       is_online_only = EXCLUDED.is_online_only,
       submitted_at = EXCLUDED.submitted_at,
       published_at = EXCLUDED.published_at,
       reviewed_by = EXCLUDED.reviewed_by,
       reviewed_at = EXCLUDED.reviewed_at,
       rejection_reason = EXCLUDED.rejection_reason
     RETURNING
       id,
       user_id,
       status,
       basic_details,
       contact_details,
       category_group_id,
       category_group_label,
       category_item_id,
       category_item_label,
       submitted_at,
       published_at,
       reviewed_by,
       reviewed_at,
       rejection_reason,
       created_at,
       updated_at,
       xmax = 0 AS inserted`,
    values
  );

  return {
    created: Boolean(result.rows[0].inserted),
    listing: mapListingRow(result.rows[0])
  };
}

export async function saveBusinessListingDraft({ userId, draft }) {
  const basicDetails = normalizeBasicDetails(draft.basicDetails);
  const contactDetails = normalizeContactDetails(draft.contactDetails);

  return upsertBusinessListing({
    userId,
    status: BUSINESS_LISTING_STATUSES.draft,
    basicDetails,
    contactDetails
  });
}

export async function submitBusinessListingForReview({ userId, draft }) {
  const basicDetails = normalizeBasicDetails(draft.basicDetails);
  const contactDetails = normalizeContactDetails(draft.contactDetails);

  return upsertBusinessListing({
    userId,
    status: BUSINESS_LISTING_STATUSES.underReview,
    basicDetails,
    contactDetails,
    submittedAt: new Date()
  });
}

export async function fetchLatestBusinessListingStatus({ userId }) {
  const result = await pool.query(
    `SELECT
       id,
       user_id,
       status,
       basic_details,
       contact_details,
       category_group_id,
       category_group_label,
       category_item_id,
       category_item_label,
       submitted_at,
       published_at,
       reviewed_by,
       reviewed_at,
       rejection_reason,
       created_at,
       updated_at
     FROM business_listings
     WHERE user_id = $1
     ORDER BY updated_at DESC
     LIMIT 1`,
    [userId]
  );

  if (!result.rowCount) {
    return null;
  }

  return mapListingRow(result.rows[0]);
}

const moderationListingSelect = `
  SELECT
    bl.id,
    bl.user_id,
    bl.status,
    bl.basic_details,
    bl.contact_details,
    bl.category_group_id,
    bl.category_group_label,
    bl.category_item_id,
    bl.category_item_label,
    bl.submitted_at,
    bl.published_at,
    bl.reviewed_by,
    bl.reviewed_at,
    bl.rejection_reason,
    bl.created_at,
    bl.updated_at,
    u.id AS submitter_id,
    u.full_name AS submitter_full_name,
    u.email AS submitter_email
  FROM business_listings bl
  JOIN users u ON u.id = bl.user_id
`;

export async function listBusinessListingsForModeration() {
  const result = await pool.query(
    `${moderationListingSelect}
     WHERE bl.status = $1
     ORDER BY bl.submitted_at ASC NULLS LAST, bl.updated_at ASC`,
    [BUSINESS_LISTING_STATUSES.underReview]
  );

  return result.rows.map(mapListingRow);
}

export async function fetchBusinessListingForModeration({ listingId }) {
  const result = await pool.query(
    `${moderationListingSelect}
     WHERE bl.id = $1
     LIMIT 1`,
    [listingId]
  );

  if (!result.rowCount) {
    return null;
  }

  return mapListingRow(result.rows[0]);
}

export async function fetchLiveBusinessListingSummary({ listingId }) {
  const result = await pool.query(
    `SELECT id, business_name, status
     FROM business_listings
     WHERE id = $1
     LIMIT 1`,
    [listingId]
  );

  if (!result.rowCount) {
    return null;
  }

  return {
    id: result.rows[0].id,
    businessName: result.rows[0].business_name?.trim() || 'Business listing',
    status: result.rows[0].status
  };
}

export async function listBusinessListingReviews({ listingId }) {
  const [reviewsResult, summaryResult] = await Promise.all([
    pool.query(
      `SELECT
         r.id,
         r.rating,
         r.comments,
         r.created_at,
         u.full_name AS user_name
       FROM business_listing_reviews r
       JOIN users u ON u.id = r.user_id
       WHERE r.business_listing_id = $1
       ORDER BY r.created_at DESC`,
      [listingId]
    ),
    pool.query(
      `SELECT
         COUNT(*)::int AS total_reviews,
         ROUND(COALESCE(AVG(rating), 0)::numeric, 1)::double precision AS average_rating
       FROM business_listing_reviews
       WHERE business_listing_id = $1`,
      [listingId]
    )
  ]);

  const summaryRow = summaryResult.rows[0] ?? {};

  return {
    items: reviewsResult.rows.map(mapBusinessReviewRow),
    summary: {
      totalReviews: Number(summaryRow.total_reviews ?? 0),
      averageRating: Number(summaryRow.average_rating ?? 0)
    }
  };
}

export async function createBusinessListingReview({
  listingId,
  userId,
  rating,
  comments
}) {
  const result = await pool.query(
    `INSERT INTO business_listing_reviews (
       business_listing_id,
       user_id,
       rating,
       comments
     ) VALUES ($1, $2, $3, $4)
     RETURNING id, business_listing_id, rating, comments, created_at`,
    [listingId, userId, rating, comments]
  );

  return {
    id: result.rows[0].id,
    businessListingId: result.rows[0].business_listing_id,
    rating: Number(result.rows[0].rating),
    comments: result.rows[0].comments,
    createdAt: result.rows[0].created_at
      ? new Date(result.rows[0].created_at).toISOString()
      : null
  };
}

async function updateReviewedBusinessListing({
  listingId,
  status,
  reviewerUserId,
  rejectionReason = null
}) {
  const reviewedAt = new Date();
  const publishedAt =
    status === BUSINESS_LISTING_STATUSES.live ? reviewedAt : null;

  const result = await pool.query(
    `UPDATE business_listings
     SET status = $2,
         published_at = $3,
         reviewed_by = $4,
         reviewed_at = $5,
         rejection_reason = $6
     WHERE id = $1
       AND status = $7
     RETURNING
       id,
       user_id,
       status,
       basic_details,
       contact_details,
       category_group_id,
       category_group_label,
       category_item_id,
       category_item_label,
       submitted_at,
       published_at,
       reviewed_by,
       reviewed_at,
       rejection_reason,
       created_at,
       updated_at`,
    [
      listingId,
      status,
      publishedAt,
      reviewerUserId,
      reviewedAt,
      rejectionReason,
      BUSINESS_LISTING_STATUSES.underReview
    ]
  );

  if (!result.rowCount) {
    return null;
  }

  return mapListingRow(result.rows[0]);
}

export async function approveBusinessListing({ listingId, reviewerUserId }) {
  return updateReviewedBusinessListing({
    listingId,
    reviewerUserId,
    status: BUSINESS_LISTING_STATUSES.live
  });
}

export async function rejectBusinessListing({
  listingId,
  reviewerUserId,
  rejectionReason
}) {
  return updateReviewedBusinessListing({
    listingId,
    reviewerUserId,
    rejectionReason,
    status: BUSINESS_LISTING_STATUSES.rejected
  });
}

export { BUSINESS_LISTING_STATUSES };
