import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { z } from 'zod';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const envPath = path.resolve(__dirname, '../../.env');
dotenv.config({ path: envPath });

const optionalString = z.preprocess((value) => {
  if (typeof value !== 'string') {
    return value;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}, z.string().optional());

const optionalUrl = z.preprocess((value) => {
  if (typeof value !== 'string') {
    return value;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}, z.string().url().optional());

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(4000),
  HOST: z.string().default('0.0.0.0'),
  TRUST_PROXY: z.coerce.boolean().default(false),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 chars'),
  JWT_EXPIRES_IN: z.string().default('15m'),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().max(365).default(30),
  CORS_ORIGIN: z.string().default('*'),
  PUBLIC_API_ORIGIN: optionalUrl,
  GOOGLE_MAPS_API_KEY: optionalString,
  RESEND_API_KEY: optionalString,
  EMAIL_FROM: optionalString,
  EMAIL_REPLY_TO: optionalString,
  APP_WEB_ORIGIN: optionalUrl,
  PASSWORD_RESET_URL_BASE: optionalString,
  PASSWORD_RESET_TOKEN_TTL_MINUTES: z.coerce.number().int().positive().max(1440).default(60),
  ALADHAN_BASE_URL: z.string().url().default('https://api.aladhan.com/v1'),
  ALADHAN_TIMEOUT_MS: z.coerce.number().int().positive().max(30000).default(5000)
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  const issue = parsed.error.issues[0];
  throw new Error(`Invalid environment config: ${issue.path.join('.')}: ${issue.message}`);
}

export const env = parsed.data;
