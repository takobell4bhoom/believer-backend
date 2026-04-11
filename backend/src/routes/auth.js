import { z } from 'zod';
import { pool } from '../db/pool.js';
import { env } from '../config/env.js';
import { EmailConfigurationError, EmailDeliveryError } from '../services/email/index.js';
import { ERROR_CODES } from '../utils/error-codes.js';
import { HttpError, successResponse } from '../utils/http.js';
import {
  generatePasswordResetToken,
  generateRefreshToken,
  hashPassword,
  hashToken,
  verifyPassword
} from '../utils/auth.js';

const passwordSchema = z.string().min(8).max(128);

const signupSchema = z.object({
  fullName: z.string().trim().min(2).max(120),
  email: z.string().trim().toLowerCase().email(),
  password: passwordSchema,
  accountType: z.enum(['community', 'admin']).default('community')
});

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: passwordSchema
});

const refreshSchema = z.object({
  refreshToken: z.string().min(16)
});

const updateProfileSchema = z.object({
  fullName: z.string().trim().min(2).max(120)
});

const forgotPasswordSchema = z.object({
  email: z.string().trim().toLowerCase().email()
});

const resetPasswordSchema = z.object({
  token: z.string().trim().min(32).max(512),
  newPassword: passwordSchema
});

const changePasswordSchema = z
  .object({
    currentPassword: passwordSchema,
    newPassword: passwordSchema
  })
  .superRefine((value, context) => {
    if (value.currentPassword === value.newPassword) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['newPassword'],
        message: 'New password must be different from your current password'
      });
    }
  });

function serializeUser(user) {
  return {
    id: user.id,
    fullName: user.full_name,
    email: user.email,
    role: user.role
  };
}

function refreshExpiryDate() {
  const now = new Date();
  now.setDate(now.getDate() + env.REFRESH_TOKEN_TTL_DAYS);
  return now;
}

function passwordResetExpiryDate() {
  const now = new Date();
  now.setMinutes(now.getMinutes() + env.PASSWORD_RESET_TOKEN_TTL_MINUTES);
  return now;
}


async function issueAccessToken(app, user) {
  return app.jwt.sign(
    {
      sub: user.id,
      email: user.email,
      fullName: user.full_name,
      role: user.role
    },
    {
      expiresIn: env.JWT_EXPIRES_IN
    }
  );
}

async function createAndPersistRefreshToken(client, userId) {
  const token = generateRefreshToken();
  const tokenHash = hashToken(token);
  const expiresAt = refreshExpiryDate();

  await client.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
     VALUES ($1, $2, $3)`,
    [userId, tokenHash, expiresAt]
  );

  return token;
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
    tokenHash,
    expiresAt
  };
}

async function issueAuthSession(client, app, user) {
  const refreshToken = await createAndPersistRefreshToken(client, user.id);
  const accessToken = await issueAccessToken(app, user);

  return {
    user: serializeUser(user),
    tokens: {
      accessToken,
      refreshToken
    }
  };
}

function genericForgotPasswordResponse() {
  return successResponse({
    success: true,
    message: 'If an account exists for that email, a password reset link has been sent.'
  });
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

export async function authRoutes(app) {
  app.post(
    '/api/v1/auth/signup',
    {
      config: { rateLimit: { max: 20, timeWindow: '1 minute' } }
    },
    async (request, reply) => {
      const parsed = signupSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new HttpError(400, ERROR_CODES.validation, 'Invalid signup payload', parsed.error.issues);
      }

      const { fullName, email, password, accountType } = parsed.data;
      const requestedRole = accountType === 'admin' ? 'admin' : 'community';

      const passwordHash = await hashPassword(password);
      const client = await pool.connect();

      try {
        await client.query('BEGIN');

        const existing = await client.query('SELECT id FROM users WHERE email = $1', [email]);
        if (existing.rowCount) {
          throw new HttpError(409, ERROR_CODES.emailAlreadyExists, 'Email is already registered');
        }

        const userResult = await client.query(
          `INSERT INTO users (full_name, email, password_hash, role)
           VALUES ($1, $2, $3, $4)
           RETURNING id, full_name, email, role`,
          [fullName, email, passwordHash, requestedRole]
        );
        const user = userResult.rows[0];
        const session = await issueAuthSession(client, app, user);

        await client.query('COMMIT');

        if (typeof app.emailService?.sendWelcomeEmail === 'function') {
          try {
            await app.emailService.sendWelcomeEmail({
              to: user.email,
              fullName: user.full_name,
              role: user.role
            });
          } catch (error) {
            logSafeEmailFailure(app, {
              userId: user.id,
              flow: 'welcome_email',
              error
            });
          }
        }

        return reply.code(201).send(successResponse(session));
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    }
  );

  app.post(
    '/api/v1/auth/login',
    {
      config: { rateLimit: { max: 30, timeWindow: '1 minute' } }
    },
    async (request) => {
      const parsed = loginSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new HttpError(400, ERROR_CODES.validation, 'Invalid login payload', parsed.error.issues);
      }

      const { email, password } = parsed.data;
      const client = await pool.connect();
      let transactionStarted = false;

      try {
        const userResult = await client.query(
          `SELECT id, full_name, email, password_hash, is_active, role
           FROM users
           WHERE email = $1`,
          [email]
        );
        if (!userResult.rowCount) {
          throw new HttpError(401, ERROR_CODES.invalidCredentials, 'Invalid email or password');
        }

        const user = userResult.rows[0];
        if (!user.is_active) {
          throw new HttpError(403, ERROR_CODES.accountDisabled, 'Your account is disabled');
        }

        const validPassword = await verifyPassword(password, user.password_hash);
        if (!validPassword) {
          throw new HttpError(401, ERROR_CODES.invalidCredentials, 'Invalid email or password');
        }

        await client.query('BEGIN');
        transactionStarted = true;
        const session = await issueAuthSession(client, app, user);
        await client.query('COMMIT');
        transactionStarted = false;

        return successResponse(session);
      } catch (error) {
        if (transactionStarted) {
          await client.query('ROLLBACK');
        }
        throw error;
      } finally {
        client.release();
      }
    }
  );

  app.post(
    '/api/v1/auth/forgot-password',
    {
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } }
    },
    async (request, reply) => {
      const parsed = forgotPasswordSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new HttpError(
          400,
          ERROR_CODES.validation,
          'Invalid forgot password payload',
          parsed.error.issues
        );
      }

      try {
        app.emailService.ensurePasswordResetAvailable();
      } catch (error) {
        throw toPasswordResetEmailHttpError(error);
      }

      const result = await pool.query(
        `SELECT id, full_name, email
         FROM users
         WHERE email = $1
           AND is_active = TRUE`,
        [parsed.data.email]
      );

      if (!result.rowCount) {
        return reply.send(genericForgotPasswordResponse());
      }

      const user = result.rows[0];
      const client = await pool.connect();
      let resetToken = null;

      try {
        await client.query('BEGIN');
        resetToken = await createPasswordResetToken(client, user.id);
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }

      try {
        await app.emailService.sendPasswordResetEmail({
          to: user.email,
          fullName: user.full_name,
          resetToken: resetToken.token
        });
      } catch (error) {
        await pool.query('DELETE FROM password_reset_tokens WHERE token_hash = $1', [
          resetToken.tokenHash
        ]);
        throw toPasswordResetEmailHttpError(error);
      }

      return reply.send(genericForgotPasswordResponse());
    }
  );

  app.post(
    '/api/v1/auth/reset-password',
    {
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } }
    },
    async (request, reply) => {
      const parsed = resetPasswordSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new HttpError(
          400,
          ERROR_CODES.validation,
          'Invalid reset password payload',
          parsed.error.issues
        );
      }

      const client = await pool.connect();

      try {
        await client.query('BEGIN');

        const tokenResult = await client.query(
          `SELECT prt.id,
                  prt.user_id,
                  prt.expires_at,
                  prt.consumed_at,
                  u.email,
                  u.full_name,
                  u.role,
                  u.is_active
           FROM password_reset_tokens prt
           JOIN users u ON u.id = prt.user_id
           WHERE prt.token_hash = $1
           FOR UPDATE`,
          [hashToken(parsed.data.token)]
        );

        if (!tokenResult.rowCount) {
          throw new HttpError(
            400,
            ERROR_CODES.invalidPasswordResetToken,
            'Password reset token is invalid or expired'
          );
        }

        const tokenRow = tokenResult.rows[0];
        if (tokenRow.consumed_at || new Date(tokenRow.expires_at).getTime() <= Date.now()) {
          throw new HttpError(
            400,
            ERROR_CODES.invalidPasswordResetToken,
            'Password reset token is invalid or expired'
          );
        }

        if (!tokenRow.is_active) {
          throw new HttpError(403, ERROR_CODES.accountDisabled, 'Your account is disabled');
        }

        const nextPasswordHash = await hashPassword(parsed.data.newPassword);
        await client.query(
          `UPDATE users
           SET password_hash = $2
           WHERE id = $1`,
          [tokenRow.user_id, nextPasswordHash]
        );
        await client.query(
          `UPDATE password_reset_tokens
           SET consumed_at = now()
           WHERE id = $1`,
          [tokenRow.id]
        );
        await consumeOutstandingPasswordResetTokens(client, tokenRow.user_id);
        await revokeUserRefreshTokens(client, tokenRow.user_id);

        await client.query('COMMIT');
        return reply.send(
          successResponse({
            success: true
          })
        );
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    }
  );

  app.post(
    '/api/v1/auth/refresh',
    async (request) => {
      const parsed = refreshSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new HttpError(400, ERROR_CODES.validation, 'Invalid refresh payload', parsed.error.issues);
      }

      const { refreshToken } = parsed.data;
      const tokenHash = hashToken(refreshToken);
      const client = await pool.connect();

      try {
        await client.query('BEGIN');
        const tokenResult = await client.query(
          `SELECT rt.id, rt.user_id, u.email, u.full_name, u.is_active, u.role
           FROM refresh_tokens rt
           JOIN users u ON u.id = rt.user_id
           WHERE rt.token_hash = $1
             AND rt.revoked_at IS NULL
             AND rt.expires_at > now()`,
          [tokenHash]
        );

        if (!tokenResult.rowCount) {
          throw new HttpError(401, ERROR_CODES.invalidRefreshToken, 'Refresh token is invalid or expired');
        }

        const tokenRow = tokenResult.rows[0];
        if (!tokenRow.is_active) {
          throw new HttpError(403, ERROR_CODES.accountDisabled, 'Your account is disabled');
        }

        await client.query('UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1', [tokenRow.id]);
        const nextRefreshToken = await createAndPersistRefreshToken(client, tokenRow.user_id);
        const accessToken = await issueAccessToken(app, {
          id: tokenRow.user_id,
          email: tokenRow.email,
          full_name: tokenRow.full_name,
          role: tokenRow.role
        });

        await client.query('COMMIT');
        return successResponse({
          accessToken,
          refreshToken: nextRefreshToken
        });
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    }
  );

  app.get('/api/v1/auth/me', { preHandler: [app.authenticate] }, async (request) => {
    const userId = request.user.sub;
    const result = await pool.query(
      `SELECT id, full_name, email, role
       FROM users
       WHERE id = $1 AND is_active = TRUE`,
      [userId]
    );

    if (!result.rowCount) {
      throw new HttpError(404, ERROR_CODES.userNotFound, 'User not found');
    }

    return successResponse(serializeUser(result.rows[0]));
  });

  app.put('/api/v1/auth/me', { preHandler: [app.authenticate] }, async (request) => {
    const parsed = updateProfileSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new HttpError(
        400,
        ERROR_CODES.validation,
        'Invalid profile payload',
        parsed.error.issues
      );
    }

    const result = await pool.query(
      `UPDATE users
       SET full_name = $2
       WHERE id = $1
         AND is_active = TRUE
       RETURNING id, full_name, email, role`,
      [request.user.sub, parsed.data.fullName]
    );

    if (!result.rowCount) {
      throw new HttpError(404, ERROR_CODES.userNotFound, 'User not found');
    }

    return successResponse(serializeUser(result.rows[0]));
  });

  app.post(
    '/api/v1/auth/change-password',
    {
      preHandler: [app.authenticate],
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } }
    },
    async (request) => {
      const parsed = changePasswordSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new HttpError(
          400,
          ERROR_CODES.validation,
          'Invalid change password payload',
          parsed.error.issues
        );
      }

      const client = await pool.connect();

      try {
        await client.query('BEGIN');

        const userResult = await client.query(
          `SELECT id, full_name, email, role, password_hash, is_active
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

        const matchesCurrentPassword = await verifyPassword(
          parsed.data.currentPassword,
          user.password_hash
        );
        if (!matchesCurrentPassword) {
          throw new HttpError(
            400,
            ERROR_CODES.invalidCurrentPassword,
            'Current password is incorrect'
          );
        }

        const nextPasswordHash = await hashPassword(parsed.data.newPassword);
        await client.query(
          `UPDATE users
           SET password_hash = $2
           WHERE id = $1`,
          [user.id, nextPasswordHash]
        );
        await revokeUserRefreshTokens(client, user.id);
        await consumeOutstandingPasswordResetTokens(client, user.id);

        const refreshToken = await createAndPersistRefreshToken(client, user.id);
        const accessToken = await issueAccessToken(app, user);

        await client.query('COMMIT');
        return successResponse({
          user: serializeUser(user),
          tokens: {
            accessToken,
            refreshToken
          }
        });
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    }
  );

  app.post('/api/v1/auth/logout', { preHandler: [app.authenticate] }, async (request, reply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'refreshToken is required', parsed.error.issues);
    }

    const tokenHash = hashToken(parsed.data.refreshToken);
    await pool.query(
      `UPDATE refresh_tokens
       SET revoked_at = now()
       WHERE token_hash = $1 AND user_id = $2 AND revoked_at IS NULL`,
      [tokenHash, request.user.sub]
    );

    return reply.send(
      successResponse({
        success: true
      })
    );
  });
}
