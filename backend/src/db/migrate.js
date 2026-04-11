import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';
import { env } from '../config/env.js';

const { Pool } = pg;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const migrationsDir = path.join(__dirname, 'migrations');

async function ensureMigrationsTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id SERIAL PRIMARY KEY,
      filename TEXT NOT NULL UNIQUE,
      executed_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

export async function runMigrations({
  logger = console,
  connectionString = env.DATABASE_URL
} = {}) {
  const migrationPool = new Pool({
    connectionString,
    max: 1,
    idleTimeoutMillis: 1000,
    connectionTimeoutMillis: 10000
  });

  const client = await migrationPool.connect();
  try {
    await client.query('BEGIN');
    await ensureMigrationsTable(client);

    const files = (await fs.readdir(migrationsDir))
      .filter((file) => file.endsWith('.sql'))
      .sort();

    const executed = await client.query('SELECT filename FROM schema_migrations');
    const executedSet = new Set(executed.rows.map((row) => row.filename));

    for (const file of files) {
      if (executedSet.has(file)) continue;
      const sql = await fs.readFile(path.join(migrationsDir, file), 'utf8');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [file]);
      logger.log(`Applied migration: ${file}`);
    }

    await client.query('COMMIT');
    logger.log('Migration complete.');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await migrationPool.end();
  }
}

const isDirectRun = process.argv[1] && path.resolve(process.argv[1]) === __filename;

if (isDirectRun) {
  try {
    await runMigrations();
  } catch (error) {
    console.error('Migration failed:', error);
    process.exitCode = 1;
  }
}
