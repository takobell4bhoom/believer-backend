import { pool } from '../db/pool.js';
import { boundingBox, haversineKm } from '../utils/geo-distance.js';

function mapNearbyRow(row, distanceKm) {
  const classes = extractProgramItems(row.classes);
  const events = extractProgramItems(row.events);

  return {
    id: row.id,
    name: row.name,
    addressLine: row.address_line,
    city: row.city,
    state: row.state,
    country: row.country,
    postalCode: row.postal_code,
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    imageUrl: row.image_url,
    imageUrls: Array.isArray(row.image_urls)
        ? row.image_urls
        : row.image_url
            ? [row.image_url]
            : [],
    sect: row.sect,
    contactName: row.contact_name,
    contactPhone: row.contact_phone,
    contactEmail: row.contact_email,
    websiteUrl: row.website_url,
    duhrTime: row.duhr_time,
    asrTime: row.asr_time,
    facilities: row.facilities,
    isVerified: row.is_verified,
    averageRating: row.average_rating == null ? 0 : Number(row.average_rating),
    totalReviews: row.total_reviews == null ? 0 : Number(row.total_reviews),
    classes,
    events,
    classTags: extractContentTitles(classes),
    eventTags: extractContentTitles(events),
    distanceKm: Number(distanceKm.toFixed(3)),
    isBookmarked: Boolean(row.is_bookmarked),
    canEdit: Boolean(row.can_edit)
  };
}

function extractContentTitles(items) {
  return items
    .map((item) => item.title)
    .filter((value) => typeof value === 'string')
    .map((value) => value.trim())
    .filter(Boolean)
    .slice(0, 12);
}

function extractProgramItems(items) {
  if (!Array.isArray(items)) {
    return [];
  }

  return items
    .map((item) => ({
      id: typeof item?.id === 'string' ? item.id.trim() : '',
      title: typeof item?.title === 'string' ? item.title.trim() : '',
      schedule: typeof item?.schedule === 'string' ? item.schedule.trim() : '',
      posterLabel:
        typeof item?.posterLabel === 'string' ? item.posterLabel.trim() : '',
      location: typeof item?.location === 'string' ? item.location.trim() : '',
      description:
        typeof item?.description === 'string'
          ? item.description.trim()
          : ''
    }))
    .filter((item) => item.title.length > 0)
    .slice(0, 12);
}

// PostGIS migration note:
// This service intentionally isolates nearby search internals.
// We can later replace the SQL + Haversine with PostGIS ST_DWithin/ST_Distance,
// while keeping route signatures and response shapes unchanged.
export async function findNearbyMosques({
  latitude,
  longitude,
  radiusKm,
  limit,
  userId,
  extraWhere = [],
  extraParams = []
}) {
  const box = boundingBox(latitude, longitude, radiusKm);
  const params = [box.minLat, box.maxLat, box.minLng, box.maxLng, userId, ...extraParams];
  const bookmarkIdx = 5;

  const whereClauses = [
    'm.latitude BETWEEN $1 AND $2',
    'm.longitude BETWEEN $3 AND $4',
    ...extraWhere
  ];

  const sql = `
    SELECT
      m.id,
      m.name,
      m.address_line,
      m.city,
      m.state,
      m.country,
      m.postal_code,
      m.latitude,
      m.longitude,
      m.image_url,
      m.image_urls,
      m.sect,
      m.contact_name,
      m.contact_phone,
      m.contact_email,
      m.website_url,
      m.duhr_time,
      m.asr_time,
      m.facilities,
      m.is_verified,
      review_summary.average_rating,
      review_summary.total_reviews,
      c.classes,
      c.events,
      CASE WHEN b.id IS NULL THEN FALSE ELSE TRUE END AS is_bookmarked,
      CASE
        WHEN $${bookmarkIdx}::uuid IS NOT NULL AND m.created_by_user_id = $${bookmarkIdx}::uuid
          THEN TRUE
        ELSE FALSE
      END AS can_edit
    FROM mosques m
    LEFT JOIN bookmarks b
      ON b.mosque_id = m.id
     AND b.user_id = $${bookmarkIdx}::uuid
    LEFT JOIN mosque_page_content c
      ON c.mosque_id = m.id
    LEFT JOIN LATERAL (
      SELECT
        ROUND(AVG(r.rating)::numeric, 1) AS average_rating,
        COUNT(*)::int AS total_reviews
      FROM mosque_reviews r
      WHERE r.mosque_id = m.id
    ) review_summary ON TRUE
    WHERE ${whereClauses.join(' AND ')}
  `;

  const result = await pool.query(sql, params);

  return result.rows
    .map((row) => {
      const distanceKm = haversineKm(latitude, longitude, Number(row.latitude), Number(row.longitude));
      return mapNearbyRow(row, distanceKm);
    })
    .filter((row) => row.distanceKm <= radiusKm)
    .sort((a, b) => a.distanceKm - b.distanceKm)
    .slice(0, limit);
}
