import { z } from 'zod';
import { pool } from '../db/pool.js';
import { ERROR_CODES } from '../utils/error-codes.js';
import { HttpError, successResponse } from '../utils/http.js';

const deactivateAccountSchema = z.object({
  confirmation: z.literal('DEACTIVATE')
});

const supportRequestSchema = z.object({
  subject: z.string().trim().min(4).max(120),
  message: z.string().trim().min(10).max(4000)
});

const mosqueSuggestionSchema = z.object({
  mosqueName: z.string().trim().min(2).max(180),
  city: z.string().trim().min(2).max(120),
  country: z.string().trim().min(2).max(120),
  addressLine: z.string().trim().max(240).optional(),
  notes: z.string().trim().max(2000).optional()
});

async function revokeUserRefreshTokens(client, userId) {
  await client.query(
    `UPDATE refresh_tokens
     SET revoked_at = now()
     WHERE user_id = $1
       AND revoked_at IS NULL`,
    [userId]
  );
}

async function consumeOutstandingPasswordResetTokens(client, userId) {
  await client.query(
    `UPDATE password_reset_tokens
     SET consumed_at = now()
     WHERE user_id = $1
       AND consumed_at IS NULL`,
    [userId]
  );
}

export async function accountGovernanceRoutes(app) {
  app.post(
    '/api/v1/auth/deactivate',
    {
      preHandler: [app.authenticate],
      config: { rateLimit: { max: 5, timeWindow: '1 minute' } }
    },
    async (request) => {
      const parsed = deactivateAccountSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new HttpError(
          400,
          ERROR_CODES.validation,
          'Invalid deactivate account payload',
          parsed.error.issues
        );
      }

      const client = await pool.connect();

      try {
        await client.query('BEGIN');

        const userResult = await client.query(
          `SELECT id, is_active
           FROM users
           WHERE id = $1
           FOR UPDATE`,
          [request.user.sub]
        );

        if (!userResult.rowCount) {
          throw new HttpError(404, ERROR_CODES.userNotFound, 'User not found');
        }

        const user = userResult.rows[0];
        if (!user.is_active) {
          throw new HttpError(403, ERROR_CODES.accountDisabled, 'Your account is disabled');
        }

        await client.query(
          `UPDATE users
           SET is_active = FALSE
           WHERE id = $1`,
          [user.id]
        );
        await revokeUserRefreshTokens(client, user.id);
        await consumeOutstandingPasswordResetTokens(client, user.id);

        await client.query('COMMIT');
        return successResponse({
          success: true,
          message: 'Your account has been deactivated.'
        });
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    }
  );

  app.post(
    '/api/v1/account/support-requests',
    {
      preHandler: [app.authenticate],
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } }
    },
    async (request, reply) => {
      const parsed = supportRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new HttpError(
          400,
          ERROR_CODES.validation,
          'Invalid support request payload',
          parsed.error.issues
        );
      }

      const account = request.authAccount;
      await pool.query(
        `INSERT INTO support_requests (user_id, full_name, email, subject, message)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          request.user.sub,
          account.full_name,
          account.email,
          parsed.data.subject,
          parsed.data.message
        ]
      );

      return reply.code(201).send(
        successResponse({
          success: true,
          message: 'Your message has been received.'
        })
      );
    }
  );

  app.post(
    '/api/v1/account/mosque-suggestions',
    {
      preHandler: [app.authenticate],
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } }
    },
    async (request, reply) => {
      const parsed = mosqueSuggestionSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new HttpError(
          400,
          ERROR_CODES.validation,
          'Invalid mosque suggestion payload',
          parsed.error.issues
        );
      }

      const account = request.authAccount;
      await pool.query(
        `INSERT INTO mosque_suggestions (
           user_id,
           submitter_name,
           submitter_email,
           mosque_name,
           city,
           country,
           address_line,
           notes
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          request.user.sub,
          account.full_name,
          account.email,
          parsed.data.mosqueName,
          parsed.data.city,
          parsed.data.country,
          parsed.data.addressLine?.trim() || null,
          parsed.data.notes?.trim() || null
        ]
      );

      return reply.code(201).send(
        successResponse({
          success: true,
          message: 'Thanks for sharing this mosque suggestion.'
        })
      );
    }
  );
}
