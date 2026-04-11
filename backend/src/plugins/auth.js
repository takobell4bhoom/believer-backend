import fastifyJwt from '@fastify/jwt';
import { pool } from '../db/pool.js';
import { env } from '../config/env.js';
import { ERROR_CODES } from '../utils/error-codes.js';
import { HttpError } from '../utils/http.js';

export async function authPlugin(app) {
  await app.register(fastifyJwt, {
    secret: env.JWT_SECRET
  });

  app.decorate('authenticate', async function authenticate(request) {
    try {
      await request.jwtVerify();
    } catch {
      throw new HttpError(401, ERROR_CODES.unauthorized, 'Invalid or missing access token');
    }

    const userId = request.user?.sub;
    if (!userId) {
      throw new HttpError(401, ERROR_CODES.unauthorized, 'Invalid or missing access token');
    }

    const result = await pool.query(
      `SELECT id, full_name, email, role, is_active
       FROM users
       WHERE id = $1`,
      [userId]
    );

    if (!result.rowCount) {
      throw new HttpError(401, ERROR_CODES.unauthorized, 'Invalid or missing access token');
    }

    const account = result.rows[0];
    if (!account.is_active) {
      throw new HttpError(403, ERROR_CODES.accountDisabled, 'Your account is disabled');
    }

    request.authAccount = account;
  });

  app.decorate('optionalAuth', async function optionalAuth(request) {
    try {
      await request.jwtVerify();
      const userId = request.user?.sub;
      if (!userId) {
        request.user = null;
        request.authAccount = null;
        return;
      }

      const result = await pool.query(
        `SELECT id, full_name, email, role, is_active
         FROM users
         WHERE id = $1`,
        [userId]
      );

      if (!result.rowCount || !result.rows[0].is_active) {
        request.user = null;
        request.authAccount = null;
        return;
      }

      request.authAccount = result.rows[0];
    } catch {
      request.user = null;
      request.authAccount = null;
    }
  });
}
