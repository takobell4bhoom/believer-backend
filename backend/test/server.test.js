import test from 'node:test';
import assert from 'node:assert/strict';
import { startServer } from '../src/server.js';

function createAppStub(events) {
  return {
    log: {
      info: (...args) => events.push(['log', ...args])
    },
    listen: async (options) => {
      events.push(['listen', options]);
    },
    close: async () => {
      events.push(['close']);
    }
  };
}

test('startServer runs migrations before listening in development', async () => {
  const events = [];
  const app = createAppStub(events);
  let migrationCall = null;

  await startServer({
    buildAppFn: () => app,
    envConfig: {
      NODE_ENV: 'development',
      HOST: '127.0.0.1',
      PORT: 4000,
      DATABASE_URL: 'postgresql://example/dev'
    },
    poolInstance: {
      end: async () => {
        events.push(['pool.end']);
      }
    },
    runMigrationsFn: async (options) => {
      migrationCall = options;
      events.push(['migrate']);
    },
    signalSource: {
      on: (signal) => {
        events.push(['signal', signal]);
      }
    },
    exitFn: () => {
      events.push(['exit']);
    }
  });

  assert.deepEqual(events.slice(0, 4), [
    ['signal', 'SIGINT'],
    ['signal', 'SIGTERM'],
    ['migrate'],
    ['listen', { host: '127.0.0.1', port: 4000 }]
  ]);
  assert.equal(migrationCall.connectionString, 'postgresql://example/dev');
  assert.equal(typeof migrationCall.logger.log, 'function');
});

test('startServer skips migrations outside development', async () => {
  const events = [];
  const app = createAppStub(events);
  let migrationAttempts = 0;

  await startServer({
    buildAppFn: () => app,
    envConfig: {
      NODE_ENV: 'production',
      HOST: '0.0.0.0',
      PORT: 8080,
      DATABASE_URL: 'postgresql://example/prod'
    },
    poolInstance: {
      end: async () => {
        events.push(['pool.end']);
      }
    },
    runMigrationsFn: async () => {
      migrationAttempts += 1;
    },
    signalSource: {
      on: () => {}
    },
    exitFn: () => {}
  });

  assert.equal(migrationAttempts, 0);
  assert.deepEqual(events[0], ['listen', { host: '0.0.0.0', port: 8080 }]);
});
