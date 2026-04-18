import { z } from 'zod';
import { pool } from '../db/pool.js';
import { EmailConfigurationError, EmailDeliveryError } from '../services/email/index.js';
import { ERROR_CODES } from '../utils/error-codes.js';
import { HttpError, paginatedResponse, successResponse } from '../utils/http.js';
import { generatePasswordResetToken, hashToken } from '../utils/auth.js';
import { env } from '../config/env.js';

const manageableRoles = ['community', 'admin', 'super_admin'];

const listUsersQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(50).default(20),
  search: z.string().trim().max(120).optional(),
  role: z.enum(manageableRoles).optional()
});

const userParamSchema = z.object({
  id: z.string().uuid()
});

function requireSuperAdmin(request) {
  if (request.authAccount?.role !== 'super_admin') {
    throw new HttpError(
      403,
      ERROR_CODES.forbidden,
      'Only super admins can access this admin operation'
    );
  }
}

function parsePagination({ page = 1, limit = 20 }) {
  const safePage = Number.isFinite(page) ? Math.max(1, Math.trunc(page)) : 1;
  const safeLimit = Number.isFinite(limit) ? Math.min(50, Math.max(1, Math.trunc(limit))) : 20;
  return {
    page: safePage,
    limit: safeLimit,
    offset: (safePage - 1) * safeLimit
  };
}

function serializeAdminUser(row) {
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    role: row.role,
    isActive: Boolean(row.is_active),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null
  };
}

function serializeAdminUserSummary(row) {
  return {
    ...serializeAdminUser(row),
    dependencySummary: {
      mosqueCount: Number(row.mosque_count ?? 0),
      businessListingCount: Number(row.business_listing_count ?? 0)
    }
  };
}

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

function passwordResetExpiryDate() {
  const now = new Date();
  now.setMinutes(now.getMinutes() + env.PASSWORD_RESET_TOKEN_TTL_MINUTES);
  return now;
}

async function createPasswordResetToken(client, userId) {
  const token = generatePasswordResetToken();
  const tokenHash = hashToken(token);
  const expiresAt = passwordResetExpiryDate();

  await consumeOutstandingPasswordResetTokens(client, userId);
  await client.query(
    `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
     VALUES ($1, $2, $3)`,
    [userId, tokenHash, expiresAt]
  );

  return {
    token,
    tokenHash
  };
}

function toPasswordResetEmailHttpError(error) {
  if (error instanceof EmailConfigurationError) {
    return new HttpError(
      503,
      ERROR_CODES.emailNotConfigured,
      'Password reset email is not configured for this environment'
    );
  }

  if (error instanceof EmailDeliveryError) {
    return new HttpError(
      502,
      ERROR_CODES.passwordResetEmailFailed,
      'Unable to send password reset email right now'
    );
  }

  return error;
}

function logSafeEmailFailure(app, { userId, flow, error }) {
  app.log.warn(
    {
      userId,
      flow,
      errorName: error?.name ?? 'Error',
      errorMessage: error?.message ?? null,
      emailProviderStatusCode: error?.statusCode ?? null,
      emailProviderResponseBody: error?.responseBody ?? null
    },
    'transactional email was not sent'
  );
}

async function fetchTargetUserForUpdate(client, userId) {
  const result = await client.query(
    `SELECT id, full_name, email, role, is_active, created_at, updated_at
     FROM users
     WHERE id = $1
     FOR UPDATE`,
    [userId]
  );

  if (!result.rowCount) {
    throw new HttpError(404, ERROR_CODES.userNotFound, 'User not found');
  }

  return result.rows[0];
}

async function fetchUserSummary(userId) {
  const result = await pool.query(
    `SELECT
       u.id,
       u.full_name,
       u.email,
       u.role,
       u.is_active,
       u.created_at,
       u.updated_at,
       (
         SELECT COUNT(*)::int
         FROM mosques m
         WHERE m.created_by_user_id = u.id
       ) AS mosque_count,
       (
         SELECT COUNT(*)::int
         FROM business_listings bl
         WHERE bl.user_id = u.id
       ) AS business_listing_count
     FROM users u
     WHERE u.id = $1`,
    [userId]
  );

  if (!result.rowCount) {
    throw new HttpError(404, ERROR_CODES.userNotFound, 'User not found');
  }

  return result.rows[0];
}

async function updateUserActiveState(client, userId, isActive) {
  const result = await client.query(
    `UPDATE users
     SET is_active = $2
     WHERE id = $1
     RETURNING id, full_name, email, role, is_active, created_at, updated_at`,
    [userId, isActive]
  );

  return result.rows[0];
}

function ensureManageableTarget({ actorUserId, targetUser }) {
  if (targetUser.id === actorUserId) {
    throw new HttpError(
      409,
      ERROR_CODES.validation,
      'You cannot run this admin action on your own account'
    );
  }

  if (targetUser.role === 'super_admin') {
    throw new HttpError(
      403,
      ERROR_CODES.forbidden,
      'Super admin accounts must be managed outside this panel'
    );
  }
}

export async function superAdminRoutes(app) {
  app.get(
    '/api/v1/admin/users',
    { preHandler: [app.authenticate] },
    async (request) => {
      requireSuperAdmin(request);

      const parsed = listUsersQuerySchema.safeParse(request.query);
      if (!parsed.success) {
        throw new HttpError(
          400,
          ERROR_CODES.validation,
          'Invalid admin user query',
          parsed.error.issues
        );
      }

      const { page, limit, offset } = parsePagination(parsed.data);
      const search = parsed.data.search?.trim();
      const filters = [];
      const params = [];

      if (search) {
        params.push(`%${search}%`);
        filters.push(`(u.full_name ILIKE $${params.length} OR u.email ILIKE $${params.length})`);
      }

      if (parsed.data.role) {
        params.push(parsed.data.role);
        filters.push(`u.role = $${params.length}`);
      }

      params.push(limit);
      params.push(offset);

      const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
      const result = await pool.query(
        `SELECT
           u.id,
           u.full_name,
           u.email,
           u.role,
           u.is_active,
           u.created_at,
           u.updated_at,
           COUNT(*) OVER() AS total_count
         FROM users u
         ${whereClause}
         ORDER BY u.created_at DESC, u.full_name ASC
         LIMIT $${params.length - 1}
         OFFSET $${params.length}`,
        params
      );

      const total = result.rowCount ? Number(result.rows[0].total_count) : 0;
      return paginatedResponse(
        {
          items: result.rows.map(serializeAdminUser)
        },
        {
          page,
          limit,
          total,
          totalPages: total == 0 ? 0 : Math.ceil(total / limit)
        }
      );
    }
  );

  app.get(
    '/api/v1/admin/users/:id',
    { preHandler: [app.authenticate] },
    async (request) => {
      requireSuperAdmin(request);

      const parsed = userParamSchema.safeParse(request.params);
      if (!parsed.success) {
        throw new HttpError(400, ERROR_CODES.validation, 'Invalid user id', parsed.error.issues);
      }

      const targetUser = await fetchUserSummary(parsed.data.id);
      return successResponse({
        user: serializeAdminUserSummary(targetUser)
      });
    }
  );

  app.post(
    '/api/v1/admin/users/:id/deactivate',
    { preHandler: [app.authenticate] },
    async (request) => {
      requireSuperAdmin(request);

      const parsed = userParamSchema.safeParse(request.params);
      if (!parsed.success) {
        throw new HttpError(400, ERROR_CODES.validation, 'Invalid user id', parsed.error.issues);
      }

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        const targetUser = await fetchTargetUserForUpdate(client, parsed.data.id);
        ensureManageableTarget({
          actorUserId: request.authAccount.id,
          targetUser
        });

        if (targetUser.is_active) {
          const updatedUser = await updateUserActiveState(client, targetUser.id, false);
          await revokeUserRefreshTokens(client, targetUser.id);
          await consumeOutstandingPasswordResetTokens(client, targetUser.id);
          Object.assign(targetUser, updatedUser);
        }

        await client.query('COMMIT');
        return successResponse({
          user: serializeAdminUser(targetUser)
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
    '/api/v1/admin/users/:id/reactivate',
    { preHandler: [app.authenticate] },
    async (request) => {
      requireSuperAdmin(request);

      const parsed = userParamSchema.safeParse(request.params);
      if (!parsed.success) {
        throw new HttpError(400, ERROR_CODES.validation, 'Invalid user id', parsed.error.issues);
      }

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        const targetUser = await fetchTargetUserForUpdate(client, parsed.data.id);
        ensureManageableTarget({
          actorUserId: request.authAccount.id,
          targetUser
        });

        if (!targetUser.is_active) {
          const updatedUser = await updateUserActiveState(client, targetUser.id, true);
          Object.assign(targetUser, updatedUser);
        }

        await client.query('COMMIT');
        return successResponse({
          user: serializeAdminUser(targetUser)
        });
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    }
  );

  const passwordResetHandler = async (request) => {
    requireSuperAdmin(request);

    const parsed = userParamSchema.safeParse(request.params);
    if (!parsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid user id', parsed.error.issues);
    }

    try {
      app.emailService.ensurePasswordResetAvailable();
    } catch (error) {
      throw toPasswordResetEmailHttpError(error);
    }

    const client = await pool.connect();
    let resetToken = null;
    let transactionStarted = false;

    try {
      await client.query('BEGIN');
      transactionStarted = true;

      const targetUser = await fetchTargetUserForUpdate(client, parsed.data.id);
      ensureManageableTarget({
        actorUserId: request.authAccount.id,
        targetUser
      });

      if (!targetUser.is_active) {
        throw new HttpError(
          409,
          ERROR_CODES.accountDisabled,
          'Reactivate the account before sending a password reset email'
        );
      }

      resetToken = await createPasswordResetToken(client, targetUser.id);
      await client.query('COMMIT');
      transactionStarted = false;

      try {
        await app.emailService.sendPasswordResetEmail({
          to: targetUser.email,
          fullName: targetUser.full_name,
          resetToken: resetToken.token
        });
      } catch (error) {
        logSafeEmailFailure(app, {
          userId: targetUser.id,
          flow: 'super_admin_password_reset',
          error
        });
        await pool.query('DELETE FROM password_reset_tokens WHERE token_hash = $1', [
          resetToken.tokenHash
        ]);
        throw toPasswordResetEmailHttpError(error);
      }

      return successResponse({
        success: true,
        message: 'Password reset email sent.'
      });
    } catch (error) {
      if (transactionStarted) {
        await client.query('ROLLBACK');
      }

      throw error;
    } finally {
      client.release();
    }
  };

  app.post(
    '/api/v1/admin/users/:id/send-password-reset',
    { preHandler: [app.authenticate] },
    passwordResetHandler
  );
  app.post(
    '/api/v1/admin/users/:id/password-reset',
    { preHandler: [app.authenticate] },
    passwordResetHandler
  );
}
