import { formatError, prepareIntegrationDatabase } from './lib/integration-db.js';

try {
  await prepareIntegrationDatabase();
} catch (error) {
  console.error(`Integration database bootstrap failed: ${formatError(error)}`);
  process.exitCode = 1;
}
