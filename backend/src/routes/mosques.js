import fs from 'fs/promises';
import path from 'path';
import { randomUUID } from 'crypto';
import { z } from 'zod';
import {
  buildPublicUploadUrl,
  maxMosqueImageUploadBytes,
  mosqueUploadsDir,
  mosqueUploadsUrlPrefix
} from '../config/uploads.js';
import { pool } from '../db/pool.js';
import { ERROR_CODES } from '../utils/error-codes.js';
import { HttpError, paginatedResponse, parsePagination, successResponse } from '../utils/http.js';
import {
  mapMosquePageContent,
  normalizeAboutContent,
  normalizeConnectLinks,
  normalizeContentItems
} from '../services/mosque-content.js';
import { findNearbyMosques } from '../services/mosque-nearby.js';
import {
  clearMosquePrayerTimeCache,
  DEFAULT_PRAYER_ADJUSTMENTS,
  formatIsoDate,
  normalizePrayerAdjustments,
  upsertMosquePrayerTimeConfig
} from '../services/prayer-times.js';

const listQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  search: z.string().trim().max(180).optional(),
  city: z.string().trim().max(120).optional(),
  facilities: z.string().trim().optional(),
  sort: z.enum(['name', 'recent', 'distance']).default('recent'),
  latitude: z.coerce.number().min(-90).max(90).optional(),
  longitude: z.coerce.number().min(-180).max(180).optional(),
  radius: z.coerce.number().positive().max(50).default(10),
  // Backward compatibility aliases
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  radiusKm: z.coerce.number().positive().max(50).optional()
});

const nearbyQuerySchema = z.object({
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().positive().max(50).default(5),
  limit: z.coerce.number().int().positive().max(100).default(20),
  // Backward compatibility aliases
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  radiusKm: z.coerce.number().positive().max(50).optional()
});

const locationResolveQuerySchema = z.object({
  query: z.string().trim().min(2).max(200)
});

const locationSuggestQuerySchema = z.object({
  query: z.string().trim().min(2).max(200),
  limit: z.coerce.number().int().positive().max(8).default(5)
});

const locationReverseQuerySchema = z.object({
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180)
});

const reviewBodySchema = z.object({
  mosqueId: z.string().uuid().optional(),
  rating: z.coerce.number().int().min(1).max(5),
  comments: z.string().trim().max(250).default('')
});

const reviewParamSchema = z.object({
  id: z.string().uuid()
});

const moderationRejectionSchema = z.object({
  rejectionReason: z.string().trim().min(3).max(1000)
});

const broadcastParamSchema = z.object({
  id: z.string().uuid(),
  broadcastId: z.string().uuid()
});

const createMosqueBodySchema = z.object({
  name: z.string().trim().min(2).max(180),
  addressLine: z.string().trim().min(3).max(240),
  city: z.string().trim().min(2).max(120),
  state: z.string().trim().min(2).max(120),
  country: z.string().trim().min(2).max(120).default('India'),
  postalCode: z.string().trim().max(20).optional(),
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
  contactName: z.string().trim().max(160).optional(),
  contactPhone: z.string().trim().max(40).optional(),
  contactEmail: z
    .union([z.string().trim().toLowerCase().email().max(255), z.literal('')])
    .optional(),
  websiteUrl: z
    .union([z.string().trim().url().max(500), z.literal('')])
    .optional(),
  imageUrl: z
    .union([z.string().trim().url().max(500), z.literal('')])
    .optional(),
  imageUrls: z
    .array(z.union([z.string().trim().url().max(500), z.literal('')]))
    .max(10)
    .optional(),
  sect: z.enum(['Sunni', 'Shia', 'Mixed', 'Community']).default('Community'),
  duhrTime: z.string().trim().max(32).optional(),
  asrTime: z.string().trim().max(32).optional(),
  facilities: z.array(z.string().trim().min(1).max(40)).max(20).default([])
});

const prayerAdjustmentsSchema = z
  .object({
    fajr: z.coerce.number().int().min(-59).max(59).default(DEFAULT_PRAYER_ADJUSTMENTS.fajr),
    sunrise: z.coerce.number().int().min(-59).max(59).default(DEFAULT_PRAYER_ADJUSTMENTS.sunrise),
    dhuhr: z.coerce.number().int().min(-59).max(59).default(DEFAULT_PRAYER_ADJUSTMENTS.dhuhr),
    asr: z.coerce.number().int().min(-59).max(59).default(DEFAULT_PRAYER_ADJUSTMENTS.asr),
    maghrib: z.coerce.number().int().min(-59).max(59).default(DEFAULT_PRAYER_ADJUSTMENTS.maghrib),
    isha: z.coerce.number().int().min(-59).max(59).default(DEFAULT_PRAYER_ADJUSTMENTS.isha)
  })
  .default(DEFAULT_PRAYER_ADJUSTMENTS);

const prayerTimeConfigBodySchema = z.object({
  enabled: z.coerce.boolean().default(true),
  calculationMethod: z.coerce.number().int().min(0).max(99),
  school: z.enum(['standard', 'hanafi']).default('standard'),
  adjustments: prayerAdjustmentsSchema
});

const prayerTimesQuerySchema = z.object({
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .refine((value) => isValidIsoDate(value), {
      message: 'date must be a valid YYYY-MM-DD value'
    })
    .optional()
});

const mosqueContentItemSchema = z.object({
  id: z.string().trim().max(80).optional(),
  title: z.string().trim().min(1).max(180),
  schedule: z.string().trim().max(120).optional(),
  posterLabel: z.string().trim().max(60).optional(),
  location: z.string().trim().max(120).optional(),
  description: z.string().trim().max(400).optional()
});

const mosqueConnectItemSchema = z.object({
  id: z.string().trim().max(80).optional(),
  type: z.string().trim().min(1).max(40),
  label: z.string().trim().max(180).optional(),
  value: z.string().trim().min(1).max(500)
});

const mosqueAboutSchema = z.object({
  title: z.string().trim().max(120).optional(),
  body: z.string().trim().max(2000).optional()
});

const createBroadcastBodySchema = z.object({
  title: z.string().trim().min(1).max(180),
  message: z.string().trim().min(1).max(2000)
});

const allowedUploadExtensions = new Set(['.jpg', '.jpeg', '.png', '.webp']);

const mosqueContentBodySchema = z.object({
  events: z.array(mosqueContentItemSchema).max(12).default([]),
  classes: z.array(mosqueContentItemSchema).max(12).default([]),
  connect: z.array(mosqueConnectItemSchema).max(12).default([]),
  about: mosqueAboutSchema.optional()
});

const updateMosqueBodySchema = createMosqueBodySchema.extend({
  prayerTimeConfig: prayerTimeConfigBodySchema.optional(),
  content: mosqueContentBodySchema.default({
    events: [],
    classes: [],
    connect: []
  })
});

const createMosqueWithPrayerConfigBodySchema = createMosqueBodySchema.extend({
  prayerTimeConfig: prayerTimeConfigBodySchema.optional(),
  content: mosqueContentBodySchema.default({
    events: [],
    classes: [],
    connect: []
  })
});

function toFacilityArray(value) {
  if (!value) return [];
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, 20);
}

function resolveLocationQuery(query) {
  const latitude = query.latitude ?? query.lat;
  const longitude = query.longitude ?? query.lng;
  const radiusKm = query.radiusKm ?? query.radius;
  return { latitude, longitude, radiusKm };
}

function normalizeOptionalString(value) {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return normalized.length ? normalized : null;
}

function normalizeFacilityList(facilities) {
  return Array.from(
    new Set(
      (facilities ?? [])
        .map((item) => item.trim().toLowerCase().replace(/\s+/g, '_'))
        .filter(Boolean)
    )
  ).slice(0, 20);
}

function normalizeMosqueImageUrls(primaryImageUrl, imageUrls = []) {
  const normalized = [];
  const seen = new Set();

  const pushValue = (value) => {
    const normalizedValue = normalizeOptionalString(value);
    if (!normalizedValue || seen.has(normalizedValue)) {
      return;
    }

    seen.add(normalizedValue);
    normalized.push(normalizedValue);
  };

  pushValue(primaryImageUrl);
  for (const imageUrl of imageUrls) {
    pushValue(imageUrl);
  }

  return normalized.slice(0, 10);
}

function resolveMosqueImageUrls(row) {
  const imageUrls = Array.isArray(row?.image_urls)
    ? row.image_urls
        .filter((value) => typeof value === 'string')
        .map((value) => value.trim())
        .filter(Boolean)
    : [];

  return normalizeMosqueImageUrls(row?.image_url, imageUrls);
}

function isValidIsoDate(value) {
  const [year, month, day] = value.split('-').map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  return (
    Number.isFinite(parsed.getTime()) &&
    parsed.getUTCFullYear() === year &&
    parsed.getUTCMonth() === month - 1 &&
    parsed.getUTCDate() === day
  );
}

function normalizeUploadExtension(filename, mimetype) {
  const fileExtension = path.extname(filename || '').trim().toLowerCase();
  if (allowedUploadExtensions.has(fileExtension)) {
    return fileExtension;
  }

  switch ((mimetype || '').trim().toLowerCase()) {
    case 'image/jpeg':
    case 'image/jpg':
      return '.jpg';
    case 'image/png':
      return '.png';
    case 'image/webp':
      return '.webp';
    default:
      return null;
  }
}

function isMultipartTooLargeError(error) {
  return (
    error?.code === 'FST_REQ_FILE_TOO_LARGE' ||
    error?.code === 'FST_FILES_LIMIT' ||
    error?.statusCode === 413
  );
}

async function getOptionalUserId(app, request) {
  const authHeader = request.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;

  const token = authHeader.slice(7);
  try {
    const decoded = await app.jwt.verify(token);
    return decoded.sub;
  } catch {
    return null;
  }
}

function mapMosqueRow(row) {
  const imageUrls = resolveMosqueImageUrls(row);
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
    imageUrl: imageUrls[0] ?? row.image_url,
    imageUrls,
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
    classTags: extractContentTitles(row.classes),
    eventTags: extractContentTitles(row.events),
    distanceKm: row.distance_km == null ? null : Number(row.distance_km),
    isBookmarked: Boolean(row.is_bookmarked),
    canEdit: Boolean(row.can_edit ?? row.canEdit)
  };
}

function extractContentTitles(items) {
  if (!Array.isArray(items)) {
    return [];
  }

  return items
    .map((item) => item?.title)
    .filter((value) => typeof value === 'string')
    .map((value) => value.trim())
    .filter(Boolean)
    .slice(0, 12);
}

function mapReviewRow(row) {
  return {
    id: row.id,
    userName: row.user_name || 'Community Member',
    rating: Number(row.rating),
    comment: row.comments,
    createdAt: row.created_at
  };
}

function mapBroadcastRow(row) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    publishedAt: row.published_at
  };
}

function buildPublicMosqueVisibilityClause(alias = 'm') {
  return `COALESCE(
    ${alias}.moderation_status,
    CASE
      WHEN ${alias}.is_verified = TRUE THEN 'live'
      ELSE 'pending'
    END
  ) = 'live'`;
}

async function ensureMosqueExists(mosqueId, client = pool) {
  const mosqueResult = await client.query('SELECT id FROM mosques WHERE id = $1', [mosqueId]);
  if (!mosqueResult.rowCount) {
    throw new HttpError(404, ERROR_CODES.mosqueNotFound, 'Mosque not found');
  }
}

async function ensureMosqueOwnedByUser({ mosqueId, userId, client = pool }) {
  const result = await client.query(
    `SELECT id, name, created_by_user_id
     FROM mosques
     WHERE id = $1`,
    [mosqueId]
  );

  if (!result.rowCount) {
    throw new HttpError(404, ERROR_CODES.mosqueNotFound, 'Mosque not found');
  }

  if (result.rows[0].created_by_user_id !== userId) {
    throw new HttpError(
      403,
      ERROR_CODES.forbidden,
      'Only the mosque owner can manage this mosque'
    );
  }

  return result.rows[0];
}

async function ensureAdminUser(userId) {
  const result = await pool.query(
    `SELECT role, is_active
     FROM users
     WHERE id = $1`,
    [userId]
  );

  if (!result.rowCount) {
    throw new HttpError(404, ERROR_CODES.userNotFound, 'User not found');
  }

  const user = result.rows[0];
  if (!user.is_active) {
    throw new HttpError(403, ERROR_CODES.accountDisabled, 'Your account is disabled');
  }

  if (user.role !== 'admin' && user.role !== 'super_admin') {
    throw new HttpError(403, ERROR_CODES.forbidden, 'Admin access required');
  }
}

function requireSuperAdmin(request) {
  if (request.authAccount?.role !== 'super_admin') {
    throw new HttpError(
      403,
      ERROR_CODES.forbidden,
      'Only super admins can moderate mosques'
    );
  }
}

function mapMosqueModerationRow(row) {
  const moderationStatus =
    row.moderation_status ?? (row.is_verified ? 'live' : 'pending');

  return {
    id: row.id,
    status: moderationStatus,
    name: row.name,
    addressLine: row.address_line,
    city: row.city,
    state: row.state,
    country: row.country,
    sect: row.sect,
    contactName: row.contact_name,
    contactEmail: row.contact_email,
    contactPhone: row.contact_phone,
    submittedAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    reviewedAt: row.reviewed_at ? new Date(row.reviewed_at).toISOString() : null,
    rejectionReason: row.rejection_reason ?? null,
    submitter: {
      id: row.submitter_id ?? '',
      fullName: row.submitter_name ?? '',
      email: row.submitter_email ?? ''
    }
  };
}

async function listPendingMosquesForModeration(client = pool) {
  const result = await client.query(
    `SELECT
       m.id,
       m.name,
       m.address_line,
       m.city,
       m.state,
       m.country,
       m.sect,
       m.contact_name,
       m.contact_email,
       m.contact_phone,
       m.is_verified,
       m.moderation_status,
       m.created_at,
       m.reviewed_at,
       m.rejection_reason,
       u.id AS submitter_id,
       COALESCE(NULLIF(u.full_name, ''), 'Admin User') AS submitter_name,
       COALESCE(u.email, '') AS submitter_email
     FROM mosques m
     LEFT JOIN users u
       ON u.id = m.created_by_user_id
     WHERE COALESCE(
       m.moderation_status,
       CASE
         WHEN m.is_verified = TRUE THEN 'live'
         ELSE 'pending'
       END
     ) = 'pending'
     ORDER BY m.created_at ASC, m.name ASC`
  );

  return result.rows.map(mapMosqueModerationRow);
}

async function approvePendingMosque({ mosqueId, reviewerUserId, client = pool }) {
  const result = await client.query(
    `WITH updated AS (
       UPDATE mosques
       SET is_verified = TRUE,
           moderation_status = 'live',
           reviewed_by = $2,
           reviewed_at = now(),
           rejection_reason = NULL
       WHERE id = $1
         AND COALESCE(
           moderation_status,
           CASE
             WHEN is_verified = TRUE THEN 'live'
             ELSE 'pending'
           END
         ) = 'pending'
       RETURNING *
     )
     SELECT
       updated.id,
       updated.name,
       updated.address_line,
       updated.city,
       updated.state,
       updated.country,
       updated.sect,
       updated.contact_name,
       updated.contact_email,
       updated.contact_phone,
       updated.is_verified,
       updated.moderation_status,
       updated.created_at,
       updated.reviewed_at,
       updated.rejection_reason,
       u.id AS submitter_id,
       COALESCE(NULLIF(u.full_name, ''), 'Admin User') AS submitter_name,
       COALESCE(u.email, '') AS submitter_email
     FROM updated
     LEFT JOIN users u
       ON u.id = updated.created_by_user_id`,
    [mosqueId, reviewerUserId]
  );

  if (!result.rowCount) {
    return null;
  }

  return mapMosqueModerationRow(result.rows[0]);
}

async function rejectPendingMosque({
  mosqueId,
  reviewerUserId,
  rejectionReason,
  client = pool
}) {
  const result = await client.query(
    `WITH updated AS (
       UPDATE mosques
       SET is_verified = FALSE,
           moderation_status = 'rejected',
           reviewed_by = $2,
           reviewed_at = now(),
           rejection_reason = $3
       WHERE id = $1
         AND COALESCE(
           moderation_status,
           CASE
             WHEN is_verified = TRUE THEN 'live'
             ELSE 'pending'
           END
         ) = 'pending'
       RETURNING *
     )
     SELECT
       updated.id,
       updated.name,
       updated.address_line,
       updated.city,
       updated.state,
       updated.country,
       updated.sect,
       updated.contact_name,
       updated.contact_email,
       updated.contact_phone,
       updated.is_verified,
       updated.moderation_status,
       updated.created_at,
       updated.reviewed_at,
       updated.rejection_reason,
       u.id AS submitter_id,
       COALESCE(NULLIF(u.full_name, ''), 'Admin User') AS submitter_name,
       COALESCE(u.email, '') AS submitter_email
     FROM updated
     LEFT JOIN users u
       ON u.id = updated.created_by_user_id`,
    [mosqueId, reviewerUserId, rejectionReason]
  );

  if (!result.rowCount) {
    return null;
  }

  return mapMosqueModerationRow(result.rows[0]);
}

async function createReview(request, reply, mosqueIdFromPath) {
  const parsed = reviewBodySchema.safeParse(request.body);
  if (!parsed.success) {
    throw new HttpError(400, ERROR_CODES.validation, 'Invalid review payload', parsed.error.issues);
  }

  const bodyMosqueId = parsed.data.mosqueId;
  if (mosqueIdFromPath != null && bodyMosqueId != null && mosqueIdFromPath != bodyMosqueId) {
    throw new HttpError(400, ERROR_CODES.validation, 'mosqueId does not match route param');
  }

  const mosqueId = mosqueIdFromPath ?? bodyMosqueId;
  if (mosqueId == null) {
    throw new HttpError(400, ERROR_CODES.validation, 'mosqueId is required');
  }

  await ensureMosqueExists(mosqueId);

  try {
    const result = await pool.query(
      `INSERT INTO mosque_reviews (user_id, mosque_id, rating, comments)
       VALUES ($1, $2, $3, $4)
       RETURNING id, mosque_id, rating, comments, created_at`,
      [request.user.sub, mosqueId, parsed.data.rating, parsed.data.comments]
    );

    return reply.code(201).send(successResponse({
      id: result.rows[0].id,
      mosqueId: result.rows[0].mosque_id,
      rating: result.rows[0].rating,
      comments: result.rows[0].comments,
      createdAt: result.rows[0].created_at
    }));
  } catch (error) {
    if (error?.code === '23505') {
      throw new HttpError(
        409,
        ERROR_CODES.reviewAlreadyExists,
        'You have already reviewed this mosque'
      );
    }

    throw error;
  }
}

async function publishBroadcastMessage(request, reply) {
  await ensureAdminUser(request.user.sub);

  const paramsParsed = reviewParamSchema.safeParse(request.params);
  if (!paramsParsed.success) {
    throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque id', paramsParsed.error.issues);
  }

  const bodyParsed = createBroadcastBodySchema.safeParse(request.body);
  if (!bodyParsed.success) {
    throw new HttpError(
      400,
      ERROR_CODES.validation,
      'Invalid broadcast payload',
      bodyParsed.error.issues
    );
  }

  const mosque = await ensureMosqueOwnedByUser({
    mosqueId: paramsParsed.data.id,
    userId: request.user.sub
  });

  const result = await pool.query(
    `INSERT INTO mosque_broadcast_messages (
       mosque_id,
       title,
       description
     ) VALUES ($1, $2, $3)
     RETURNING id, title, description, published_at`,
    [paramsParsed.data.id, bodyParsed.data.title, bodyParsed.data.message]
  );

  const broadcast = mapBroadcastRow(result.rows[0]);
  const notificationEventResult = await pool.query(
    `INSERT INTO notification_events (
       event_type,
       entity_type,
       entity_id,
       mosque_id,
       title,
       body,
       payload
     ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
     RETURNING id`,
    [
      'mosque_broadcast_published',
      'mosque_broadcast_message',
      broadcast.id,
      paramsParsed.data.id,
      broadcast.title,
      broadcast.description,
      JSON.stringify({
        mosqueId: paramsParsed.data.id,
        mosqueName: mosque.name,
        broadcastId: broadcast.id
      })
    ]
  );

  const recipientDevicesResult = await pool.query(
    `SELECT DISTINCT ON (d.push_token)
       d.id,
       d.user_id,
       d.installation_id,
       d.platform,
       d.push_token
     FROM notification_devices d
     JOIN mosque_notification_settings s
       ON s.user_id = d.user_id
      AND s.mosque_id = $1
     WHERE d.is_active = TRUE
       AND d.remote_push_enabled = TRUE
       AND s.is_enabled = TRUE
       AND s.title = 'Broadcast Messages'
     ORDER BY d.push_token, d.last_seen_at DESC`,
    [paramsParsed.data.id]
  );

  try {
    const delivery = await request.server.pushNotificationService.sendMosqueBroadcastNotification({
      event: {
        id: notificationEventResult.rows[0].id,
        mosqueId: paramsParsed.data.id,
        mosqueName: mosque.name,
        broadcastId: broadcast.id,
        title: broadcast.title,
        body: broadcast.description
      },
      devices: recipientDevicesResult.rows.map((row) => ({
        id: row.id,
        userId: row.user_id,
        installationId: row.installation_id,
        platform: row.platform,
        pushToken: row.push_token
      }))
    });

    if (delivery.invalidDeviceIds.length > 0) {
      await pool.query(
        `UPDATE notification_devices
         SET is_active = FALSE,
             remote_push_enabled = FALSE,
             last_seen_at = now()
         WHERE id = ANY($1::uuid[])`,
        [delivery.invalidDeviceIds]
      );
    }

    request.log.info(
      {
        mosqueId: paramsParsed.data.id,
        broadcastId: broadcast.id,
        attemptedDevices: delivery.attemptedCount,
        sentDevices: delivery.sentCount,
        configured: delivery.configured
      },
      'processed mosque broadcast push delivery'
    );
  } catch (error) {
    request.log.warn(
      {
        err: error,
        mosqueId: paramsParsed.data.id,
        broadcastId: broadcast.id
      },
      'mosque broadcast push delivery failed after broadcast persistence'
    );
  }

  return reply.code(201).send(successResponse(broadcast));
}

async function deleteBroadcastMessage(request, reply) {
  await ensureAdminUser(request.user.sub);

  const paramsParsed = broadcastParamSchema.safeParse(request.params);
  if (!paramsParsed.success) {
    throw new HttpError(400, ERROR_CODES.validation, 'Invalid broadcast route params', paramsParsed.error.issues);
  }

  await ensureMosqueOwnedByUser({
    mosqueId: paramsParsed.data.id,
    userId: request.user.sub
  });

  const result = await pool.query(
    `DELETE FROM mosque_broadcast_messages
     WHERE mosque_id = $1
       AND id = $2
     RETURNING id`,
    [paramsParsed.data.id, paramsParsed.data.broadcastId]
  );

  if (!result.rowCount) {
    throw new HttpError(404, ERROR_CODES.broadcastNotFound, 'Broadcast message not found');
  }

  return reply.send(
    successResponse({
      success: true
    })
  );
}

async function createMosque(request, reply) {
  await ensureAdminUser(request.user.sub);

  const parsed = createMosqueWithPrayerConfigBodySchema.safeParse(request.body);
  if (!parsed.success) {
    throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque payload', parsed.error.issues);
  }

  const payload = parsed.data;
  const facilities = normalizeFacilityList(payload.facilities);
  const imageUrls = normalizeMosqueImageUrls(payload.imageUrl, payload.imageUrls);
  const primaryImageUrl = imageUrls[0] ?? null;
  const normalizedEvents = normalizeContentItems(payload.content.events, 'event');
  const normalizedClasses = normalizeContentItems(payload.content.classes, 'class');
  const normalizedConnect = normalizeConnectLinks(payload.content.connect);
  const normalizedAbout = normalizeAboutContent(payload.content.about);
  const values = [
    payload.name,
    payload.addressLine,
    payload.city,
    payload.state,
    payload.country,
    normalizeOptionalString(payload.postalCode),
    payload.latitude,
    payload.longitude,
    primaryImageUrl,
    JSON.stringify(imageUrls),
    payload.sect,
    normalizeOptionalString(payload.contactName),
    normalizeOptionalString(payload.contactPhone),
    normalizeOptionalString(payload.contactEmail),
    normalizeOptionalString(payload.websiteUrl),
    normalizeOptionalString(payload.duhrTime),
    normalizeOptionalString(payload.asrTime),
    JSON.stringify(facilities),
    request.user.sub
  ];

  const insertSql = `
    INSERT INTO mosques (
      name,
      address_line,
      city,
      state,
      country,
      postal_code,
      latitude,
      longitude,
      image_url,
      image_urls,
      sect,
      contact_name,
      contact_phone,
      contact_email,
      website_url,
      duhr_time,
      asr_time,
      facilities,
      is_verified,
      created_by_user_id
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9,
      $10::jsonb, $11, $12, $13, $14, $15, $16, $17,
      $18::jsonb, FALSE, $19
    )
    RETURNING
      id,
      name,
      address_line,
      city,
      state,
      country,
      postal_code,
      latitude,
      longitude,
      image_url,
      image_urls,
      sect,
      contact_name,
      contact_phone,
      contact_email,
      website_url,
      duhr_time,
      asr_time,
      facilities,
      is_verified,
      0::numeric AS average_rating,
      0::int AS total_reviews,
      '[]'::jsonb AS classes,
      '[]'::jsonb AS events,
      NULL::double precision AS distance_km,
      FALSE AS is_bookmarked
  `;

  try {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(insertSql, values);
      const mosque = result.rows[0];

      await client.query(
        `INSERT INTO mosque_page_content (
           mosque_id,
           events,
           classes,
           connect_links,
           about_title,
           about_body
         ) VALUES ($1, $2::jsonb, $3::jsonb, $4::jsonb, $5, $6)
         ON CONFLICT (mosque_id) DO UPDATE SET
           events = EXCLUDED.events,
           classes = EXCLUDED.classes,
           connect_links = EXCLUDED.connect_links,
           about_title = EXCLUDED.about_title,
           about_body = EXCLUDED.about_body`,
        [
          mosque.id,
          JSON.stringify(normalizedEvents),
          JSON.stringify(normalizedClasses),
          JSON.stringify(normalizedConnect),
          normalizedAbout?.title ?? null,
          normalizedAbout?.body ?? null
        ]
      );

      if (payload.prayerTimeConfig) {
        await upsertMosquePrayerTimeConfig({
          client,
          mosqueId: mosque.id,
          prayerTimeConfig: {
            ...payload.prayerTimeConfig,
            adjustments: normalizePrayerAdjustments(payload.prayerTimeConfig.adjustments)
          }
        });
        await clearMosquePrayerTimeCache(client, mosque.id);
      }

      await client.query('COMMIT');
      return reply.code(201).send(
        successResponse(
          mapMosqueRow({
            ...mosque,
            events: normalizedEvents,
            classes: normalizedClasses,
            can_edit: true
          })
        )
      );
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    if (error?.code === '23505') {
      throw new HttpError(409, ERROR_CODES.mosqueAlreadyExists, 'A mosque with this identity already exists');
    }

    throw error;
  }
}

async function updateMosque(request, reply) {
  await ensureAdminUser(request.user.sub);

  const paramsParsed = reviewParamSchema.safeParse(request.params);
  if (!paramsParsed.success) {
    throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque id', paramsParsed.error.issues);
  }

  const bodyParsed = updateMosqueBodySchema.safeParse(request.body);
  if (!bodyParsed.success) {
    throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque payload', bodyParsed.error.issues);
  }

  const mosqueId = paramsParsed.data.id;
  const payload = bodyParsed.data;
  const facilities = normalizeFacilityList(payload.facilities);
  const imageUrls = normalizeMosqueImageUrls(payload.imageUrl, payload.imageUrls);
  const primaryImageUrl = imageUrls[0] ?? null;
  const normalizedEvents = normalizeContentItems(payload.content.events, 'event');
  const normalizedClasses = normalizeContentItems(payload.content.classes, 'class');
  const normalizedConnect = normalizeConnectLinks(payload.content.connect);
  const normalizedAbout = normalizeAboutContent(payload.content.about);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await ensureMosqueOwnedByUser({
      mosqueId,
      userId: request.user.sub,
      client
    });

    const updateResult = await client.query(
      `UPDATE mosques
       SET
         name = $2,
         address_line = $3,
         city = $4,
         state = $5,
         country = $6,
         postal_code = $7,
         latitude = $8,
         longitude = $9,
         image_url = $10,
         image_urls = $11::jsonb,
         sect = $12,
         contact_name = $13,
         contact_phone = $14,
         contact_email = $15,
         website_url = $16,
         duhr_time = $17,
         asr_time = $18,
         facilities = $19::jsonb
       WHERE id = $1
       RETURNING
         id,
         name,
         address_line,
         city,
         state,
         country,
         postal_code,
         latitude,
         longitude,
         image_url,
         image_urls,
         sect,
         contact_name,
         contact_phone,
         contact_email,
         website_url,
         duhr_time,
         asr_time,
         facilities,
         is_verified,
         0::numeric AS average_rating,
         0::int AS total_reviews,
         '[]'::jsonb AS classes,
         '[]'::jsonb AS events,
         NULL::double precision AS distance_km,
         FALSE AS is_bookmarked`,
      [
        mosqueId,
        payload.name,
        payload.addressLine,
        payload.city,
        payload.state,
        payload.country,
        normalizeOptionalString(payload.postalCode),
        payload.latitude,
        payload.longitude,
        primaryImageUrl,
        JSON.stringify(imageUrls),
        payload.sect,
        normalizeOptionalString(payload.contactName),
        normalizeOptionalString(payload.contactPhone),
        normalizeOptionalString(payload.contactEmail),
        normalizeOptionalString(payload.websiteUrl),
        normalizeOptionalString(payload.duhrTime),
        normalizeOptionalString(payload.asrTime),
        JSON.stringify(facilities)
      ]
    );

    await client.query(
      `INSERT INTO mosque_page_content (
         mosque_id,
         events,
         classes,
         connect_links,
         about_title,
         about_body
       ) VALUES ($1, $2::jsonb, $3::jsonb, $4::jsonb, $5, $6)
       ON CONFLICT (mosque_id) DO UPDATE SET
         events = EXCLUDED.events,
         classes = EXCLUDED.classes,
         connect_links = EXCLUDED.connect_links,
         about_title = EXCLUDED.about_title,
         about_body = EXCLUDED.about_body`,
      [
        mosqueId,
        JSON.stringify(normalizedEvents),
        JSON.stringify(normalizedClasses),
        JSON.stringify(normalizedConnect),
        normalizedAbout?.title ?? null,
        normalizedAbout?.body ?? null
      ]
    );

    if (payload.prayerTimeConfig) {
      await upsertMosquePrayerTimeConfig({
        client,
        mosqueId,
        prayerTimeConfig: {
          ...payload.prayerTimeConfig,
          adjustments: normalizePrayerAdjustments(payload.prayerTimeConfig.adjustments)
        }
      });
      await clearMosquePrayerTimeCache(client, mosqueId);
    }

    const contentResult = await client.query(
      `SELECT
         m.contact_phone,
         m.contact_email,
         m.website_url,
         c.events,
         c.classes,
         c.connect_links,
         c.about_title,
         c.about_body
       FROM mosques m
       LEFT JOIN mosque_page_content c
         ON c.mosque_id = m.id
       WHERE m.id = $1`,
      [mosqueId]
    );

    await client.query('COMMIT');

    return reply.send(successResponse({
      mosque: mapMosqueRow({
        ...updateResult.rows[0],
        can_edit: true
      }),
      content: mapMosquePageContent(contentResult.rows[0])
    }));
  } catch (error) {
    await client.query('ROLLBACK');
    if (error?.code === '23505') {
      throw new HttpError(409, ERROR_CODES.mosqueAlreadyExists, 'A mosque with this identity already exists');
    }

    throw error;
  } finally {
    client.release();
  }
}

async function uploadMosqueImage(request, reply) {
  await ensureAdminUser(request.user.sub);

  try {
    const file = await request.file();
    if (!file) {
      throw new HttpError(400, ERROR_CODES.validation, 'Image file is required');
    }

    const extension = normalizeUploadExtension(file.filename, file.mimetype);
    if (extension == null) {
      throw new HttpError(
        400,
        ERROR_CODES.invalidUploadFile,
        'Upload a JPG, PNG, or WebP image'
      );
    }

    const buffer = await file.toBuffer();
    if (!buffer.length) {
      throw new HttpError(400, ERROR_CODES.validation, 'Image file is required');
    }

    if (file.file.truncated || buffer.length > maxMosqueImageUploadBytes) {
      throw new HttpError(
        413,
        ERROR_CODES.uploadTooLarge,
        'Image upload must be 5 MB or smaller'
      );
    }

    const storedFileName = `${Date.now()}-${randomUUID()}${extension}`;
    const storedFilePath = path.join(mosqueUploadsDir, storedFileName);
    await fs.writeFile(storedFilePath, buffer);

    const imagePath = `${mosqueUploadsUrlPrefix}/${storedFileName}`;
    return reply.code(201).send(
      successResponse({
        imageUrl: buildPublicUploadUrl(request, imagePath),
        imagePath,
        fileName: storedFileName
      })
    );
  } catch (error) {
    if (isMultipartTooLargeError(error)) {
      throw new HttpError(
        413,
        ERROR_CODES.uploadTooLarge,
        'Image upload must be 5 MB or smaller'
      );
    }
    throw error;
  }
}

export async function mosqueRoutes(app) {
  const publicMosqueVisibilityClause = buildPublicMosqueVisibilityClause();

  app.post('/api/v1/mosques', { preHandler: [app.authenticate] }, async (request, reply) => {
    return createMosque(request, reply);
  });

  app.post('/api/v1/mosques/upload-image', { preHandler: [app.authenticate] }, async (request, reply) => {
    return uploadMosqueImage(request, reply);
  });

  app.put('/api/v1/mosques/:id', { preHandler: [app.authenticate] }, async (request, reply) => {
    return updateMosque(request, reply);
  });

  app.post('/api/v1/mosques/:id/broadcasts', { preHandler: [app.authenticate] }, async (request, reply) => {
    return publishBroadcastMessage(request, reply);
  });

  app.delete('/api/v1/mosques/:id/broadcasts/:broadcastId', { preHandler: [app.authenticate] }, async (request, reply) => {
    return deleteBroadcastMessage(request, reply);
  });

  app.get('/api/v1/admin/mosques/pending', { preHandler: [app.authenticate] }, async (request) => {
    requireSuperAdmin(request);

    const items = await listPendingMosquesForModeration();
    return successResponse({ items });
  });

  app.post('/api/v1/admin/mosques/:id/approve', { preHandler: [app.authenticate] }, async (request) => {
    requireSuperAdmin(request);

    const paramsParsed = reviewParamSchema.safeParse(request.params);
    if (!paramsParsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque id', paramsParsed.error.issues);
    }

    const existingMosque = await pool.query(
      `SELECT
         id,
         COALESCE(
           moderation_status,
           CASE
             WHEN is_verified = TRUE THEN 'live'
             ELSE 'pending'
           END
         ) AS moderation_status
       FROM mosques
       WHERE id = $1`,
      [paramsParsed.data.id]
    );

    if (!existingMosque.rowCount) {
      throw new HttpError(404, ERROR_CODES.mosqueNotFound, 'Mosque not found');
    }

    if (existingMosque.rows[0].moderation_status !== 'pending') {
      throw new HttpError(409, ERROR_CODES.validation, 'Only pending mosques can be approved');
    }

    const mosque = await approvePendingMosque({
      mosqueId: paramsParsed.data.id,
      reviewerUserId: request.authAccount.id
    });

    if (mosque == null) {
      throw new HttpError(409, ERROR_CODES.validation, 'This mosque is no longer available for approval');
    }

    return successResponse({ mosque });
  });

  app.post('/api/v1/admin/mosques/:id/reject', { preHandler: [app.authenticate] }, async (request) => {
    requireSuperAdmin(request);

    const paramsParsed = reviewParamSchema.safeParse(request.params);
    if (!paramsParsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque id', paramsParsed.error.issues);
    }

    const bodyParsed = moderationRejectionSchema.safeParse(request.body);
    if (!bodyParsed.success) {
      throw new HttpError(
        400,
        ERROR_CODES.validation,
        'Invalid mosque rejection payload',
        bodyParsed.error.issues
      );
    }

    const existingMosque = await pool.query(
      `SELECT
         id,
         COALESCE(
           moderation_status,
           CASE
             WHEN is_verified = TRUE THEN 'live'
             ELSE 'pending'
           END
         ) AS moderation_status
       FROM mosques
       WHERE id = $1`,
      [paramsParsed.data.id]
    );

    if (!existingMosque.rowCount) {
      throw new HttpError(404, ERROR_CODES.mosqueNotFound, 'Mosque not found');
    }

    if (existingMosque.rows[0].moderation_status !== 'pending') {
      throw new HttpError(409, ERROR_CODES.validation, 'Only pending mosques can be rejected');
    }

    const mosque = await rejectPendingMosque({
      mosqueId: paramsParsed.data.id,
      reviewerUserId: request.authAccount.id,
      rejectionReason: bodyParsed.data.rejectionReason
    });

    if (mosque == null) {
      throw new HttpError(409, ERROR_CODES.validation, 'This mosque is no longer available for rejection');
    }

    return successResponse({ mosque });
  });

  app.get('/api/v1/mosques', async (request) => {
    const parsed = listQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid query params', parsed.error.issues);
    }

    const query = parsed.data;
    const { latitude, longitude, radiusKm } = resolveLocationQuery(query);

    if (query.sort === 'distance' && (latitude == null || longitude == null)) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'latitude and longitude are required for distance sort');
    }

    const userId = await getOptionalUserId(app, request);

    if (query.sort === 'distance' && latitude != null && longitude != null) {
      const facilities = toFacilityArray(query.facilities);
      const { page, limit, offset } = parsePagination(query, 100);

      const extraWhere = [publicMosqueVisibilityClause];
      const extraParams = [];

      if (query.search) {
        extraParams.push(`%${query.search}%`);
        extraWhere.push(`(m.name ILIKE $${5 + extraParams.length} OR m.address_line ILIKE $${5 + extraParams.length})`);
      }

      if (query.city) {
        extraParams.push(query.city);
        extraWhere.push(`m.city ILIKE $${5 + extraParams.length}`);
      }

      if (facilities.length) {
        extraParams.push(facilities);
        extraWhere.push(`m.facilities ?| $${5 + extraParams.length}::text[]`);
      }

      const allNearby = await findNearbyMosques({
        latitude,
        longitude,
        radiusKm,
        limit: 2000,
        userId,
        extraWhere,
        extraParams
      });

      return paginatedResponse(
        {
          items: allNearby.slice(offset, offset + limit)
        },
        {
          page,
          limit,
          total: allNearby.length,
          hasNext: offset + limit < allNearby.length
        }
      );
    }

    const { page, limit, offset } = parsePagination(query, 100);
    const facilities = toFacilityArray(query.facilities);

    const params = [];
    const where = [publicMosqueVisibilityClause];

    if (query.search) {
      params.push(`%${query.search}%`);
      const idx = params.length;
      where.push(`(m.name ILIKE $${idx} OR m.address_line ILIKE $${idx})`);
    }

    if (query.city) {
      params.push(query.city);
      where.push(`m.city ILIKE $${params.length}`);
    }

    if (facilities.length) {
      params.push(facilities);
      where.push(`m.facilities ?| $${params.length}::text[]`);
    }

    let orderBy = 'm.created_at DESC';
    if (query.sort === 'name') {
      orderBy = 'm.name ASC';
    }

    const whereClause = where.length ? `WHERE ${where.join(' AND ')}` : '';

    params.push(userId);
    const bookmarkIdx = params.length;

    params.push(limit, offset);
    const limitIdx = params.length - 1;
    const offsetIdx = params.length;

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
        NULL::double precision AS distance_km,
        CASE WHEN b.id IS NULL THEN FALSE ELSE TRUE END AS is_bookmarked,
        CASE
          WHEN $${bookmarkIdx}::uuid IS NOT NULL AND m.created_by_user_id = $${bookmarkIdx}::uuid
            THEN TRUE
          ELSE FALSE
        END AS can_edit,
        COUNT(*) OVER()::int AS total_count
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
      ${whereClause}
      ORDER BY ${orderBy}
      LIMIT $${limitIdx}
      OFFSET $${offsetIdx}
    `;

    const result = await pool.query(sql, params);
    const total = result.rows[0]?.total_count ?? 0;

    return paginatedResponse(
      {
        items: result.rows.map(mapMosqueRow)
      },
      {
        page,
        limit,
        total,
        hasNext: offset + limit < total
      }
    );
  });

  app.get('/api/v1/mosques/nearby', async (request) => {
    const parsed = nearbyQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid nearby params', parsed.error.issues);
    }

    const query = parsed.data;
    const resolved = resolveLocationQuery(query);
    if (resolved.latitude == null || resolved.longitude == null) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'latitude and longitude are required');
    }

    const userId = await getOptionalUserId(app, request);
    const nearby = await findNearbyMosques({
      latitude: resolved.latitude,
      longitude: resolved.longitude,
      radiusKm: resolved.radiusKm,
      limit: query.limit,
      userId,
      extraWhere: [publicMosqueVisibilityClause]
    });

    return successResponse({
        items: nearby
      });
  });

  app.get('/api/v1/mosques/location-resolve', async (request) => {
    const parsed = locationResolveQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid location lookup params', parsed.error.issues);
    }

    try {
      const resolved = await app.locationLookupService.resolve(parsed.data.query);
      return successResponse({
        label: resolved?.label ?? parsed.data.query,
        latitude: resolved?.latitude ?? null,
        longitude: resolved?.longitude ?? null,
        provider: resolved?.provider ?? null,
        resolved: resolved != null
      });
    } catch (error) {
      request.log.warn({ err: error }, 'location lookup failed');
      throw new HttpError(503, 'LOCATION_LOOKUP_UNAVAILABLE', 'Location lookup is unavailable right now');
    }
  });

  app.get('/api/v1/mosques/location-suggest', async (request) => {
    const parsed = locationSuggestQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid location suggestion params', parsed.error.issues);
    }

    try {
      const suggestions = await app.locationLookupService.suggest(
        parsed.data.query,
        { limit: parsed.data.limit }
      );
      return successResponse({
        items: suggestions.map((suggestion) => ({
          label: suggestion.label,
          primaryText: suggestion.primaryText ?? suggestion.label,
          secondaryText: suggestion.secondaryText ?? null,
          latitude: suggestion.latitude,
          longitude: suggestion.longitude,
          provider: suggestion.provider ?? null
        }))
      });
    } catch (error) {
      request.log.warn({ err: error }, 'location suggestion lookup failed');
      throw new HttpError(
        503,
        'LOCATION_LOOKUP_UNAVAILABLE',
        'Location suggestions are unavailable right now'
      );
    }
  });

  app.get('/api/v1/mosques/location-reverse', async (request) => {
    const parsed = locationReverseQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid location reverse-lookup params', parsed.error.issues);
    }

    try {
      const resolved = await app.locationLookupService.reverseResolve(
        parsed.data.latitude,
        parsed.data.longitude
      );
      return successResponse({
        label: resolved?.label ?? null,
        latitude: resolved?.latitude ?? parsed.data.latitude,
        longitude: resolved?.longitude ?? parsed.data.longitude,
        provider: resolved?.provider ?? null,
        resolved: resolved != null
      });
    } catch (error) {
      request.log.warn({ err: error }, 'location reverse lookup failed');
      throw new HttpError(503, 'LOCATION_LOOKUP_UNAVAILABLE', 'Location lookup is unavailable right now');
    }
  });

  app.get('/api/v1/mosques/mine', { preHandler: [app.authenticate] }, async (request) => {
    await ensureAdminUser(request.user.sub);

    const result = await pool.query(
      `SELECT
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
         NULL::double precision AS distance_km,
         FALSE AS is_bookmarked,
         TRUE AS can_edit
       FROM mosques m
       LEFT JOIN mosque_page_content c
         ON c.mosque_id = m.id
       LEFT JOIN LATERAL (
         SELECT
           ROUND(AVG(r.rating)::numeric, 1) AS average_rating,
           COUNT(*)::int AS total_reviews
         FROM mosque_reviews r
         WHERE r.mosque_id = m.id
       ) review_summary ON TRUE
       WHERE m.created_by_user_id = $1
       ORDER BY m.created_at DESC`,
      [request.user.sub]
    );

    return successResponse({
      items: result.rows.map(mapMosqueRow)
    });
  });

  app.get('/api/v1/mosques/:id', async (request) => {
    const idSchema = z.object({ id: z.string().uuid() });
    const parsed = idSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid mosque id', parsed.error.issues);
    }

    const userId = await getOptionalUserId(app, request);
    const result = await pool.query(
      `SELECT
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
         NULL::double precision AS distance_km,
         CASE WHEN b.id IS NULL THEN FALSE ELSE TRUE END AS is_bookmarked,
         CASE
           WHEN $2::uuid IS NOT NULL AND m.created_by_user_id = $2::uuid
             THEN TRUE
           ELSE FALSE
         END AS can_edit
       FROM mosques m
       LEFT JOIN bookmarks b
         ON b.mosque_id = m.id
        AND b.user_id = $2::uuid
       LEFT JOIN mosque_page_content c
         ON c.mosque_id = m.id
       LEFT JOIN LATERAL (
         SELECT
           ROUND(AVG(r.rating)::numeric, 1) AS average_rating,
           COUNT(*)::int AS total_reviews
         FROM mosque_reviews r
         WHERE r.mosque_id = m.id
       ) review_summary ON TRUE
       WHERE m.id = $1
         AND (
           ${publicMosqueVisibilityClause}
           OR ($2::uuid IS NOT NULL AND m.created_by_user_id = $2::uuid)
         )`,
      [parsed.data.id, userId]
    );

    if (!result.rowCount) {
      throw new HttpError(404, ERROR_CODES.mosqueNotFound, 'Mosque not found');
    }

    return successResponse(mapMosqueRow(result.rows[0]));
  });

  app.post('/api/v1/mosques/review', { preHandler: [app.authenticate] }, async (request, reply) => {
    return createReview(request, reply);
  });

  app.get('/api/v1/mosques/:id/broadcasts', async (request) => {
    const parsed = reviewParamSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque id', parsed.error.issues);
    }

    await ensureMosqueExists(parsed.data.id);

    const result = await pool.query(
      `SELECT id, title, description, published_at
       FROM mosque_broadcast_messages
       WHERE mosque_id = $1
         AND published_at >= now() - INTERVAL '60 days'
       ORDER BY published_at DESC
       LIMIT 20`,
      [parsed.data.id]
    );

    return successResponse({
      items: result.rows.map(mapBroadcastRow)
    });
  });

  app.get('/api/v1/mosques/:id/content', async (request) => {
    const parsed = reviewParamSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque id', parsed.error.issues);
    }

    const result = await pool.query(
      `SELECT
         m.contact_phone,
         m.contact_email,
         m.website_url,
         c.events,
         c.classes,
         c.connect_links,
         c.about_title,
         c.about_body
       FROM mosques m
       LEFT JOIN mosque_page_content c
         ON c.mosque_id = m.id
       WHERE m.id = $1`,
      [parsed.data.id]
    );

    if (!result.rowCount) {
      throw new HttpError(404, ERROR_CODES.mosqueNotFound, 'Mosque not found');
    }

    return successResponse(mapMosquePageContent(result.rows[0]));
  });

  app.get('/api/v1/mosques/:id/prayer-times', async (request) => {
    const paramsParsed = reviewParamSchema.safeParse(request.params);
    if (!paramsParsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque id', paramsParsed.error.issues);
    }

    const queryParsed = prayerTimesQuerySchema.safeParse(request.query);
    if (!queryParsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid prayer-times query', queryParsed.error.issues);
    }

    const date = queryParsed.data.date ?? formatIsoDate(new Date());
    const data = await app.prayerTimeService.readDailyTimings({
      mosqueId: paramsParsed.data.id,
      date
    });

    return successResponse(data);
  });

  app.get('/api/v1/mosques/:id/reviews', async (request) => {
    const parsed = reviewParamSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque id', parsed.error.issues);
    }

    await ensureMosqueExists(parsed.data.id);

    const [reviewsResult, summaryResult] = await Promise.all([
      pool.query(
        `SELECT
           r.id,
           r.rating,
           r.comments,
           r.created_at,
           COALESCE(NULLIF(u.full_name, ''), 'Community Member') AS user_name
         FROM mosque_reviews r
         JOIN users u
           ON u.id = r.user_id
         WHERE r.mosque_id = $1
         ORDER BY r.created_at DESC`,
        [parsed.data.id]
      ),
      pool.query(
        `SELECT
           COUNT(*)::int AS total_reviews,
           ROUND(COALESCE(AVG(rating), 0)::numeric, 1)::double precision AS average_rating
         FROM mosque_reviews
         WHERE mosque_id = $1`,
        [parsed.data.id]
      )
    ]);

    const summaryRow = summaryResult.rows[0] ?? {};

    return successResponse({
      items: reviewsResult.rows.map(mapReviewRow),
      summary: {
        totalReviews: summaryRow.total_reviews ?? 0,
        averageRating: Number(summaryRow.average_rating ?? 0)
      }
    });
  });

  app.post('/api/v1/mosques/:id/reviews', { preHandler: [app.authenticate] }, async (request, reply) => {
    const parsed = reviewParamSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid mosque id', parsed.error.issues);
    }

    return createReview(request, reply, parsed.data.id);
  });
}
