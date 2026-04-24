import { z } from 'zod';
import { pool } from '../db/pool.js';
import { ERROR_CODES } from '../utils/error-codes.js';
import { HttpError, successResponse } from '../utils/http.js';

const SUPPORTED_NOTIFICATION_SETTINGS = new Map([
  [
    'broadcast messages',
    {
      title: 'Broadcast Messages',
      description: 'Important community announcements from this mosque in your in-app updates feed.'
    }
  ],
  [
    'events & class updates',
    {
      title: 'Events & Class Updates',
      description: 'New events, classes, and halaqas from this mosque in your in-app updates feed.'
    }
  ]
]);

function normalizeSettingTitle(title) {
  return title.trim().toLowerCase().replace(/\s+/g, ' ');
}

const settingSchema = z
  .object({
    title: z.string().trim().min(1).max(120),
    description: z.string().trim().max(280).default(''),
    isEnabled: z.boolean()
  })
  .superRefine((value, ctx) => {
    if (!SUPPORTED_NOTIFICATION_SETTINGS.has(normalizeSettingTitle(value.title))) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Unsupported notification setting title',
        path: ['title']
      });
    }
  })
  .transform((value) => {
    const supportedSetting = SUPPORTED_NOTIFICATION_SETTINGS.get(
      normalizeSettingTitle(value.title)
    );

    return {
      title: supportedSetting.title,
      description: value.description || supportedSetting.description,
      isEnabled: value.isEnabled
    };
  });

const updateSettingsSchema = z.object({
  mosqueId: z.string().uuid(),
  settings: z.array(settingSchema).max(20)
}).superRefine((value, ctx) => {
  const seenTitles = new Set();

  for (const [index, setting] of value.settings.entries()) {
    const normalizedTitle = normalizeSettingTitle(setting.title);
    if (seenTitles.has(normalizedTitle)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Duplicate notification setting title',
        path: ['settings', index, 'title']
      });
      continue;
    }
    seenTitles.add(normalizedTitle);
  }
});

const readSettingsQuerySchema = z.object({
  mosqueId: z.string().uuid()
});

const notificationDevicePlatformSchema = z.enum(['android', 'ios']);

const upsertNotificationDeviceSchema = z.object({
  installationId: z.string().trim().min(8).max(120),
  pushToken: z.string().trim().min(16).max(4096),
  platform: notificationDevicePlatformSchema,
  locale: z.string().trim().max(24).optional(),
  appVersion: z.string().trim().max(40).optional()
});

const deleteNotificationDeviceParamsSchema = z.object({
  installationId: z.string().trim().min(8).max(120)
});

async function ensureMosqueExists(mosqueId) {
  const mosqueResult = await pool.query('SELECT id FROM mosques WHERE id = $1', [mosqueId]);
  if (!mosqueResult.rowCount) {
    throw new HttpError(404, ERROR_CODES.mosqueNotFound, 'Mosque not found');
  }
}

export async function notificationRoutes(app) {
  app.get('/api/v1/notifications/mosques', { preHandler: [app.authenticate] }, async (request) => {
    const result = await pool.query(
      `SELECT
         m.id,
         m.name,
         s.title,
         s.updated_at
       FROM mosque_notification_settings s
       JOIN mosques m
         ON m.id = s.mosque_id
       WHERE s.user_id = $1
         AND s.is_enabled = TRUE
       ORDER BY s.updated_at DESC, m.name ASC`,
      [request.user.sub]
    );

    const seenMosqueIds = new Set();
    const items = [];

    for (const row of result.rows) {
      if (!SUPPORTED_NOTIFICATION_SETTINGS.has(normalizeSettingTitle(row.title))) {
        continue;
      }
      if (seenMosqueIds.has(row.id)) {
        continue;
      }

      seenMosqueIds.add(row.id);
      items.push({
        id: row.id,
        name: row.name
      });
    }

    return successResponse({
      items
    });
  });

  app.get('/api/v1/notifications/settings', { preHandler: [app.authenticate] }, async (request) => {
    const parsed = readSettingsQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid notification settings query', parsed.error.issues);
    }

    const { mosqueId } = parsed.data;
    await ensureMosqueExists(mosqueId);

    const result = await pool.query(
      `SELECT title, description, is_enabled
       FROM mosque_notification_settings
       WHERE user_id = $1
         AND mosque_id = $2
       ORDER BY created_at ASC, title ASC`,
      [request.user.sub, mosqueId]
    );

    return successResponse({
      mosqueId,
      settings: result.rows
        .filter((row) => SUPPORTED_NOTIFICATION_SETTINGS.has(normalizeSettingTitle(row.title)))
        .map((row) => ({
          title: row.title,
          description: row.description,
          isEnabled: Boolean(row.is_enabled)
        }))
    });
  });

  app.put('/api/v1/notifications/settings', { preHandler: [app.authenticate] }, async (request, reply) => {
    const parsed = updateSettingsSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid notification settings payload', parsed.error.issues);
    }

    const { mosqueId, settings } = parsed.data;
    await ensureMosqueExists(mosqueId);

    const client = await pool.connect();

    try {
      await client.query('BEGIN');
      await client.query(
        'DELETE FROM mosque_notification_settings WHERE user_id = $1 AND mosque_id = $2',
        [request.user.sub, mosqueId]
      );

      for (const setting of settings) {
        await client.query(
          `INSERT INTO mosque_notification_settings (
             user_id,
             mosque_id,
             title,
             description,
             is_enabled
           ) VALUES ($1, $2, $3, $4, $5)`,
          [
            request.user.sub,
            mosqueId,
            setting.title,
            setting.description,
            setting.isEnabled
          ]
        );
      }

      await client.query('COMMIT');
      return reply.send(
        successResponse({
          success: true,
          settings
        })
      );
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  });

  app.put('/api/v1/notifications/devices', { preHandler: [app.authenticate] }, async (request, reply) => {
    const parsed = upsertNotificationDeviceSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid notification device payload', parsed.error.issues);
    }

    const payload = parsed.data;
    const result = await pool.query(
      `INSERT INTO notification_devices (
         user_id,
         installation_id,
         platform,
         push_token,
         locale,
         app_version,
         remote_push_enabled,
         is_active,
         last_seen_at
       ) VALUES ($1, $2, $3, $4, $5, $6, TRUE, TRUE, now())
       ON CONFLICT (user_id, installation_id) DO UPDATE SET
         platform = EXCLUDED.platform,
         push_token = EXCLUDED.push_token,
         locale = EXCLUDED.locale,
         app_version = EXCLUDED.app_version,
         remote_push_enabled = TRUE,
         is_active = TRUE,
         last_seen_at = now()
       RETURNING id, installation_id, platform, push_token, locale, app_version, remote_push_enabled, is_active, last_seen_at`,
      [
        request.user.sub,
        payload.installationId,
        payload.platform,
        payload.pushToken,
        payload.locale ?? null,
        payload.appVersion ?? null
      ]
    );

    return reply.send(
      successResponse({
        device: {
          id: result.rows[0].id,
          installationId: result.rows[0].installation_id,
          platform: result.rows[0].platform,
          pushToken: result.rows[0].push_token,
          locale: result.rows[0].locale,
          appVersion: result.rows[0].app_version,
          remotePushEnabled: Boolean(result.rows[0].remote_push_enabled),
          isActive: Boolean(result.rows[0].is_active),
          lastSeenAt: result.rows[0].last_seen_at
        }
      })
    );
  });

  app.delete('/api/v1/notifications/devices/:installationId', { preHandler: [app.authenticate] }, async (request, reply) => {
    const parsed = deleteNotificationDeviceParamsSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid notification device params', parsed.error.issues);
    }

    await pool.query(
      `UPDATE notification_devices
       SET is_active = FALSE,
           remote_push_enabled = FALSE,
           last_seen_at = now()
       WHERE user_id = $1
         AND installation_id = $2`,
      [request.user.sub, parsed.data.installationId]
    );

    return reply.send(
      successResponse({
        success: true
      })
    );
  });
}
