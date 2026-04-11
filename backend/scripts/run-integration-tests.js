import {
  backendDir,
  formatError,
  prepareIntegrationDatabase,
  resolveIntegrationDatabaseUrl,
  runCommand
} from './lib/integration-db.js';

async function main() {
  const runOnly = process.argv.includes('--run-only');
  const integrationDatabaseUrl = resolveIntegrationDatabaseUrl();

  try {
    if (!runOnly) {
      await prepareIntegrationDatabase();
    }
  } catch (error) {
    console.error(`Integration test bootstrap failed: ${formatError(error)}`);
    process.exitCode = 1;
    return;
  }

  const exitCode = await runCommand(
    'node',
    ['--test', 'test/integration.api.test.js'],
    {
      env: {
        ...process.env,
        NODE_ENV: 'test',
        DATABASE_URL: integrationDatabaseUrl
      }
    }
  );

  process.exitCode = exitCode;
}

await main();
