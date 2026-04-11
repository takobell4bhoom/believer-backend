import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import { env } from '../config/env.js';

export async function securityPlugin(app) {
  await app.register(helmet, {
    contentSecurityPolicy: false
  });

  await app.register(cors, {
    origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(',').map((it) => it.trim()),
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id'],
    exposedHeaders: ['X-Request-Id'],
    // We use bearer tokens (not cookie auth), so credentials are unnecessary.
    // Keeping this false avoids browser CORS edge-cases on Flutter Web.
    credentials: false,
    maxAge: 86400
  });

  await app.register(rateLimit, {
    global: false,
    max: 200,
    timeWindow: '1 minute'
  });
}
