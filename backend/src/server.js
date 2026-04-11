import { buildApp } from './app.js';
import { env } from './config/env.js';
import { pool } from './db/pool.js';
import { runMigrations } from './db/migrate.js';

export async function startServer({
  buildAppFn = buildApp,
  envConfig = env,
  poolInstance = pool,
  runMigrationsFn = runMigrations,
  signalSource = process,
  exitFn = (code) => process.exit(code)
} = {}) {
  const app = buildAppFn();

  const shutdown = async (signal) => {
    app.log.info({ signal }, 'Shutting down');
    try {
      await app.close();
      await poolInstance.end();
    } finally {
      exitFn(0);
    }
  };

  signalSource.on?.('SIGINT', () => shutdown('SIGINT'));
  signalSource.on?.('SIGTERM', () => shutdown('SIGTERM'));

  if (envConfig.NODE_ENV === 'development') {
    await runMigrationsFn({
      connectionString: envConfig.DATABASE_URL,
      logger: {
        log: (message) => app.log.info({ scope: 'migrations' }, message)
      }
    });
  }

  await app.listen({
    host: envConfig.HOST,
    port: envConfig.PORT
  });

  app.log.info(`API running on http://${envConfig.HOST}:${envConfig.PORT}`);
  return app;
}
