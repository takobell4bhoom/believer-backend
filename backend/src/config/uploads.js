import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { env } from './env.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const backendRoot = path.resolve(__dirname, '../..');

export const uploadsRootDir = path.join(backendRoot, 'uploads');
export const mosqueUploadsDir = path.join(uploadsRootDir, 'mosques');
export const uploadsUrlPrefix = '/uploads/';
export const mosqueUploadsUrlPrefix = '/uploads/mosques';
export const maxMosqueImageUploadBytes = 5 * 1024 * 1024;

export async function ensureUploadsDirectories() {
  await fs.mkdir(mosqueUploadsDir, { recursive: true });
}

export function buildPublicUploadUrl(request, relativePath) {
  if (env.PUBLIC_API_ORIGIN) {
    return new URL(relativePath, `${env.PUBLIC_API_ORIGIN.replace(/\/+$/, '')}/`).toString();
  }

  const host = request.headers.host || `localhost:${env.PORT}`;
  const origin = `${request.protocol}://${host}`;
  return new URL(relativePath, `${origin}/`).toString();
}
