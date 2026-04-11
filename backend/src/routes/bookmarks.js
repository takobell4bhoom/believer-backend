import { z } from 'zod';
import { pool } from '../db/pool.js';
import { HttpError, paginatedResponse, parsePagination, successResponse } from '../utils/http.js';

const createSchema = z.object({
  mosqueId: z.string().uuid()
});

const listQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20)
});

export async function bookmarkRoutes(app) {
  app.post('/api/v1/bookmarks', { preHandler: [app.authenticate] }, async (request, reply) => {
    const parsed = createSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid bookmark payload', parsed.error.issues);
    }

    const userId = request.user.sub;
    const { mosqueId } = parsed.data;

    const mosqueResult = await pool.query('SELECT id FROM mosques WHERE id = $1', [mosqueId]);
    if (!mosqueResult.rowCount) {
      throw new HttpError(404, 'MOSQUE_NOT_FOUND', 'Mosque not found');
    }

    const result = await pool.query(
      `INSERT INTO bookmarks (user_id, mosque_id)
       VALUES ($1, $2)
       ON CONFLICT (user_id, mosque_id) DO NOTHING
       RETURNING id, user_id, mosque_id, created_at`,
      [userId, mosqueId]
    );

    if (!result.rowCount) {
      return reply.code(200).send(successResponse({
        mosqueId,
        status: 'already_bookmarked'
      }));
    }

    return reply.code(201).send(successResponse({
      id: result.rows[0].id,
      mosqueId: result.rows[0].mosque_id,
      createdAt: result.rows[0].created_at,
      status: 'created'
    }));
  });

  app.delete('/api/v1/bookmarks/:mosqueId', { preHandler: [app.authenticate] }, async (request, reply) => {
    const paramSchema = z.object({ mosqueId: z.string().uuid() });
    const parsed = paramSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid mosque id', parsed.error.issues);
    }

    await pool.query('DELETE FROM bookmarks WHERE user_id = $1 AND mosque_id = $2', [request.user.sub, parsed.data.mosqueId]);
    return reply.send(
      successResponse({
        success: true
      })
    );
  });

  app.get('/api/v1/bookmarks', { preHandler: [app.authenticate] }, async (request) => {
    const parsed = listQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid query params', parsed.error.issues);
    }

    const { page, limit, offset } = parsePagination(parsed.data, 100);

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
         m.facilities,
         m.is_verified,
         b.created_at AS bookmarked_at,
         COUNT(*) OVER()::int AS total_count
       FROM bookmarks b
       JOIN mosques m ON m.id = b.mosque_id
       WHERE b.user_id = $1
       ORDER BY b.created_at DESC
       LIMIT $2 OFFSET $3`,
      [request.user.sub, limit, offset]
    );

    const total = result.rows[0]?.total_count ?? 0;

    return paginatedResponse(
      {
        items: result.rows.map((row) => ({
          id: row.id,
          name: row.name,
          addressLine: row.address_line,
          city: row.city,
          state: row.state,
          country: row.country,
          postalCode: row.postal_code,
          latitude: Number(row.latitude),
          longitude: Number(row.longitude),
          facilities: row.facilities,
          isVerified: row.is_verified,
          bookmarkedAt: row.bookmarked_at
        }))
      },
      {
        page,
        limit,
        total,
        hasNext: offset + limit < total
      }
    );
  });
}
