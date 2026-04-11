import test from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';
import {
  createAlAdhanClient,
  createPrayerTimeService
} from '../src/services/prayer-times.js';

function createPrayerConfigRow(overrides = {}) {
  return {
    id: '11111111-1111-4111-8111-111111111111',
    latitude: 12.9716,
    longitude: 77.5946,
    calculation_method: 3,
    school: 'hanafi',
    prayer_adjustments: {
      fajr: 1,
      sunrise: 0,
      dhuhr: 2,
      asr: 0,
      maghrib: -1,
      isha: 0
    },
    prayer_config_enabled: true,
    cached_payload: null,
    cached_at: null,
    ...overrides
  };
}

test('AlAdhan client normalizes timings and forwards explicit config params', async () => {
  let requestedUrl;
  const client = createAlAdhanClient({
    baseUrl: 'https://api.aladhan.test/v1',
    timeoutMs: 2000,
    fetchImpl: async (url) => {
      requestedUrl = new URL(url);
      return {
        ok: true,
        async json() {
          return {
            data: {
              timings: {
                Fajr: '05:08 (+05)',
                Sunrise: '06:18 (+05)',
                Dhuhr: '12:31 (+05)',
                Asr: '16:02 (+05)',
                Maghrib: '18:41 (+05)',
                Isha: '19:55 (+05)'
              },
              meta: {
                timezone: 'Asia/Kolkata',
                method: {
                  id: 3,
                  name: 'Muslim World League'
                }
              }
            }
          };
        }
      };
    }
  });

  const result = await client.getDailyTimings({
    date: '2026-03-30',
    latitude: 12.9716,
    longitude: 77.5946,
    calculationMethodId: 3,
    school: 'hanafi',
    adjustments: {
      fajr: 1,
      sunrise: 0,
      dhuhr: 2,
      asr: 0,
      maghrib: -1,
      isha: 0
    }
  });

  assert.equal(requestedUrl.pathname, '/v1/timings/30-03-2026');
  assert.equal(requestedUrl.searchParams.get('latitude'), '12.9716');
  assert.equal(requestedUrl.searchParams.get('longitude'), '77.5946');
  assert.equal(requestedUrl.searchParams.get('method'), '3');
  assert.equal(requestedUrl.searchParams.get('school'), '1');
  assert.equal(requestedUrl.searchParams.get('tune'), '1,0,2,0,-1,0');
  assert.equal(result.timezone, 'Asia/Kolkata');
  assert.equal(result.calculationMethodName, 'Muslim World League');
  assert.equal(result.timings.fajr.display, '05:08 AM');
  assert.equal(result.timings.asr.display, '04:02 PM');
  assert.equal(result.timings.maghrib.display, '06:41 PM');
});

test('prayer time service returns cached payload without calling upstream', async () => {
  let upstreamCalls = 0;
  const cachedAt = '2026-03-30T04:00:00.000Z';
  const db = {
    async query(sql) {
      if (sql.includes('FROM mosques m')) {
        return {
          rowCount: 1,
          rows: [
            createPrayerConfigRow({
              cached_payload: {
                mosqueId: '11111111-1111-4111-8111-111111111111',
                date: '2026-03-30',
                status: 'ready',
                isConfigured: true,
                isAvailable: true,
                source: 'aladhan',
                unavailableReason: null,
                timezone: 'Asia/Kolkata',
                configuration: null,
                timings: {
                  fajr: '05:08 AM',
                  sunrise: '06:18 AM',
                  dhuhr: '12:31 PM',
                  asr: '04:02 PM',
                  maghrib: '06:41 PM',
                  isha: '07:55 PM'
                },
                nextPrayer: 'Asr',
                nextPrayerTime: '04:02 PM',
                cachedAt
              },
              cached_at: new Date(cachedAt)
            })
          ]
        };
      }

      throw new Error(`Unexpected SQL: ${sql}`);
    }
  };

  const service = createPrayerTimeService({
    db,
    alAdhanClient: {
      async getDailyTimings() {
        upstreamCalls += 1;
        throw new Error('should not be called');
      }
    }
  });

  const result = await service.readDailyTimings({
    mosqueId: '11111111-1111-4111-8111-111111111111',
    date: '2026-03-30'
  });

  assert.equal(upstreamCalls, 0);
  assert.equal(result.source, 'cache');
  assert.equal(result.configuration.calculationMethod.id, 3);
  assert.equal(result.configuration.school.value, 'hanafi');
  assert.equal(result.timings.dhuhr, '12:31 PM');
  assert.equal(result.cachedAt, cachedAt);
});

test('prayer time service caches a fresh upstream read and syncs daily summary fields', async () => {
  const queries = [];
  const db = {
    async query(sql, params) {
      queries.push({ sql, params });
      if (sql.includes('FROM mosques m')) {
        return {
          rowCount: 1,
          rows: [createPrayerConfigRow()]
        };
      }

      return { rowCount: 1, rows: [] };
    }
  };

  const service = createPrayerTimeService({
    db,
    now: () => new Date('2026-03-30T10:30:00.000Z'),
    alAdhanClient: {
      async getDailyTimings() {
        return {
          timezone: 'UTC',
          calculationMethodName: 'Muslim World League',
          timings: {
            fajr: { clockValue: '05:08', display: '05:08 AM' },
            sunrise: { clockValue: '06:18', display: '06:18 AM' },
            dhuhr: { clockValue: '12:31', display: '12:31 PM' },
            asr: { clockValue: '16:02', display: '04:02 PM' },
            maghrib: { clockValue: '18:41', display: '06:41 PM' },
            isha: { clockValue: '19:55', display: '07:55 PM' }
          }
        };
      }
    }
  });

  const result = await service.readDailyTimings({
    mosqueId: '11111111-1111-4111-8111-111111111111',
    date: '2026-03-30'
  });

  assert.equal(result.source, 'aladhan');
  assert.equal(result.timings.fajr, '05:08 AM');
  assert.equal(result.configuration.adjustments.dhuhr, 2);
  assert.ok(
    queries.some((entry) => entry.sql.includes('INSERT INTO mosque_prayer_time_daily_cache'))
  );
  assert.ok(
    queries.some(
      (entry) =>
        entry.sql.includes('UPDATE mosques') &&
        entry.params[1] === '12:31 PM' &&
        entry.params[2] === '04:02 PM'
    )
  );
});

test('GET /api/v1/mosques/:id/prayer-times wraps the delegated prayer-time payload', async () => {
  const app = buildApp({
    prayerTimeService: {
      async readDailyTimings({ mosqueId, date }) {
        assert.equal(mosqueId, '11111111-1111-4111-8111-111111111111');
        assert.equal(date, '2026-03-30');
        return {
          mosqueId,
          date,
          status: 'ready',
          isConfigured: true,
          isAvailable: true,
          source: 'cache',
          unavailableReason: null,
          timezone: 'Asia/Kolkata',
          configuration: {
            enabled: true,
            latitude: 12.9716,
            longitude: 77.5946,
            calculationMethod: {
              id: 3,
              name: 'Muslim World League'
            },
            school: {
              value: 'standard',
              label: 'Standard'
            },
            adjustments: {
              fajr: 0,
              sunrise: 0,
              dhuhr: 0,
              asr: 0,
              maghrib: 0,
              isha: 0
            }
          },
          timings: {
            fajr: '05:08 AM',
            sunrise: '06:18 AM',
            dhuhr: '12:31 PM',
            asr: '04:02 PM',
            maghrib: '06:41 PM',
            isha: '07:55 PM'
          },
          nextPrayer: 'Asr',
          nextPrayerTime: '04:02 PM',
          cachedAt: '2026-03-30T04:00:00.000Z'
        };
      }
    }
  });

  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/11111111-1111-4111-8111-111111111111/prayer-times?date=2026-03-30'
  });

  assert.equal(response.statusCode, 200);
  const body = response.json();
  assert.equal(body.error, null);
  assert.equal(body.data.status, 'ready');
  assert.equal(body.data.source, 'cache');
  assert.equal(body.data.timings.dhuhr, '12:31 PM');
  assert.equal(body.data.configuration.calculationMethod.id, 3);

  await app.close();
});
