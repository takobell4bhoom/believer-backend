import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { env } from '../../src/config/env.js';
import { runMigrations } from '../../src/db/migrate.js';

const { Pool } = pg;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const backendDir = path.resolve(__dirname, '../..');
const composeFile = path.join(backendDir, 'docker-compose.yml');
const DEFAULT_INTEGRATION_DATABASE_NAME = 'believer_test';

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function formatError(error) {
  if (!error) {
    return 'unknown error';
  }

  if (Array.isArray(error.errors) && error.errors.length > 0) {
    return error.errors
      .map((entry) => entry?.message || entry?.code || String(entry))
      .join('; ');
  }

  return error.message || error.code || String(error);
}

function quoteIdentifier(value) {
  return `"${String(value).replaceAll('"', '""')}"`;
}

function maskConnectionString(connectionString) {
  try {
    const url = new URL(connectionString);
    if (url.password) {
      url.password = '***';
    }

    return url.toString();
  } catch {
    return connectionString;
  }
}

function getDatabaseName(connectionString) {
  const url = new URL(connectionString);
  const databaseName = url.pathname.replace(/^\//, '');

  if (!databaseName) {
    throw new Error(`DATABASE_URL must include a database name: ${maskConnectionString(connectionString)}`);
  }

  return databaseName;
}

function replaceDatabaseName(connectionString, databaseName) {
  const url = new URL(connectionString);
  url.pathname = `/${databaseName}`;
  return url.toString();
}

export function resolveIntegrationDatabaseUrl() {
  if (process.env.DATABASE_TEST_URL) {
    return process.env.DATABASE_TEST_URL;
  }

  return replaceDatabaseName(env.DATABASE_URL, DEFAULT_INTEGRATION_DATABASE_NAME);
}

export function resolveAdminDatabaseUrl(connectionString = env.DATABASE_URL) {
  return replaceDatabaseName(connectionString, 'postgres');
}

export function assertIntegrationDatabaseIsIsolated() {
  const developmentDatabaseUrl = env.DATABASE_URL;
  const integrationDatabaseUrl = resolveIntegrationDatabaseUrl();
  const developmentDatabaseName = getDatabaseName(developmentDatabaseUrl);
  const integrationDatabaseName = getDatabaseName(integrationDatabaseUrl);

  if (integrationDatabaseName === developmentDatabaseName) {
    throw new Error(
      'Integration database isolation is not configured safely: ' +
        `DATABASE_TEST_URL resolves to the same database (${integrationDatabaseName}) as DATABASE_URL. ` +
        'Point DATABASE_TEST_URL at a dedicated test database before running integration tests.'
    );
  }

  return {
    developmentDatabaseUrl,
    developmentDatabaseName,
    integrationDatabaseUrl,
    integrationDatabaseName
  };
}

async function canConnect(connectionString, connectionTimeoutMillis = 1500) {
  const pool = new Pool({
    connectionString,
    max: 1,
    idleTimeoutMillis: 1000,
    connectionTimeoutMillis
  });

  try {
    await pool.query('SELECT 1');
    return { ok: true };
  } catch (error) {
    return { ok: false, error };
  } finally {
    await pool.end().catch(() => {});
  }
}

export function runCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd ?? backendDir,
      env: options.env ?? process.env,
      stdio: options.stdio ?? 'inherit'
    });

    child.on('error', reject);
    child.on('exit', (code, signal) => {
      if (signal) {
        reject(new Error(`${command} ${args.join(' ')} exited from signal ${signal}`));
        return;
      }

      resolve(code ?? 0);
    });
  });
}

async function startComposePostgres() {
  try {
    const exitCode = await runCommand('docker', ['compose', '-f', composeFile, 'up', '-d', 'postgres']);
    if (exitCode === 0) {
      return;
    }

    throw new Error(
      `docker compose could not start the repo-local postgres service (exit code ${exitCode}). ` +
        'Make sure Docker Desktop (or another Docker daemon) is installed and running, then retry.'
    );
  } catch (error) {
    if (error?.code === 'ENOENT') {
      throw new Error(
        'Docker is required for the local integration-test path, but the `docker` command was not found. ' +
          'Install Docker Desktop (or another Docker daemon), start it, and retry.'
      );
    }

    throw error;
  }
}

async function ensureDatabaseExists(connectionString) {
  const databaseName = getDatabaseName(connectionString);
  const adminPool = new Pool({
    connectionString: resolveAdminDatabaseUrl(connectionString),
    max: 1,
    idleTimeoutMillis: 1000,
    connectionTimeoutMillis: 5000
  });

  try {
    const existing = await adminPool.query('SELECT 1 FROM pg_database WHERE datname = $1', [databaseName]);
    if (existing.rowCount > 0) {
      return false;
    }

    await adminPool.query(`CREATE DATABASE ${quoteIdentifier(databaseName)}`);
    return true;
  } finally {
    await adminPool.end().catch(() => {});
  }
}

export async function ensurePostgresReady({
  startupTimeoutMs = 60000,
  pollIntervalMs = 1000
} = {}) {
  const adminDatabaseUrl = resolveAdminDatabaseUrl();
  const initialAttempt = await canConnect(adminDatabaseUrl);
  if (initialAttempt.ok) {
    return;
  }

  if (!fs.existsSync(composeFile)) {
    throw new Error(
      `PostgreSQL is not reachable at ${maskConnectionString(adminDatabaseUrl)}, and ${composeFile} was not found. ` +
        `Original error: ${formatError(initialAttempt.error)}`
    );
  }

  console.log('PostgreSQL is not reachable yet; starting or reusing the repo-local Docker Compose service...');
  await startComposePostgres();

  const startedAt = Date.now();
  while (Date.now() - startedAt < startupTimeoutMs) {
    const attempt = await canConnect(adminDatabaseUrl, 2000);
    if (attempt.ok) {
      return;
    }

    await sleep(pollIntervalMs);
  }

  const finalAttempt = await canConnect(adminDatabaseUrl, 2000);
  throw new Error(
    `PostgreSQL did not become ready within ${startupTimeoutMs / 1000}s at ${maskConnectionString(adminDatabaseUrl)}. ` +
      `Last error: ${formatError(finalAttempt.error || initialAttempt.error)}`
  );
}

export async function prepareIntegrationDatabase({ logger = console } = {}) {
  const {
    developmentDatabaseName,
    integrationDatabaseUrl,
    integrationDatabaseName
  } = assertIntegrationDatabaseIsIsolated();

  await ensurePostgresReady();

  const createdDatabase = await ensureDatabaseExists(integrationDatabaseUrl);
  logger.log(
    `Integration tests will use dedicated database "${integrationDatabaseName}" ` +
      `(separate from dev database "${developmentDatabaseName}").`
  );
  if (createdDatabase) {
    logger.log(`Created dedicated integration database "${integrationDatabaseName}".`);
  }

  logger.log('Running backend migrations for the dedicated integration database...');
  await runMigrations({
    logger,
    connectionString: integrationDatabaseUrl
  });

  return {
    databaseUrl: integrationDatabaseUrl,
    databaseName: integrationDatabaseName,
    createdDatabase
  };
}

export { backendDir };
