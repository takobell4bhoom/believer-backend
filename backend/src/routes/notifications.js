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
}
