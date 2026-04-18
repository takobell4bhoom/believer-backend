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
              date: {
                hijri: {
                  day: '20',
                  month: { en: 'Shawwal' },
                  year: '1447',
                  designation: { abbreviated: 'AH' }
                },
                gregorian: {
                  day: '18',
                  month: { en: 'April' },
                  weekday: { en: 'Saturday' }
                }
              },
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
  assert.equal(result.dateLabel, '20 Shawwal 1447 AH | Sat 18 Apr');
  assert.equal(result.timings.fajr.display, '05:08 AM');
  assert.equal(result.timings.asr.display, '04:02 PM');
  assert.equal(result.timings.maghrib.display, '06:41 PM');
});

test('AlAdhan client omits method when not explicitly provided and returns upstream-selected method', async () => {
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
              date: {
                hijri: {
                  day: '20',
                  month: { en: 'Shawwal' },
                  year: '1447',
                  designation: { abbreviated: 'AH' }
                },
                gregorian: {
                  day: '18',
                  month: { en: 'April' },
                  weekday: { en: 'Saturday' }
                }
              },
              timings: {
                Fajr: '05:48 (-04)',
                Sunrise: '06:58 (-04)',
                Dhuhr: '13:24 (-04)',
                Asr: '17:02 (-04)',
                Maghrib: '19:50 (-04)',
                Isha: '21:00 (-04)'
              },
              meta: {
                timezone: 'America/New_York',
                method: {
                  id: 2,
                  name: 'Islamic Society of North America'
                }
              }
            }
          };
        }
      };
    }
  });

  const result = await client.getDailyTimings({
    date: '2026-04-18',
    latitude: 27.9944,
    longitude: -81.7603,
    school: 'standard',
    adjustments: {
      fajr: 0,
      sunrise: 0,
      dhuhr: 0,
      asr: 0,
      maghrib: 0,
      isha: 0
    }
  });

  assert.equal(requestedUrl.pathname, '/v1/timings/18-04-2026');
  assert.equal(requestedUrl.searchParams.get('latitude'), '27.9944');
  assert.equal(requestedUrl.searchParams.get('longitude'), '-81.7603');
  assert.equal(requestedUrl.searchParams.has('method'), false);
  assert.equal(requestedUrl.searchParams.get('school'), '0');
  assert.equal(result.timezone, 'America/New_York');
  assert.equal(result.calculationMethodId, 2);
  assert.equal(result.calculationMethodName, 'Islamic Society of North America');
  assert.equal(result.timings.asr.display, '05:02 PM');
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
                dateLabel: '10 Shawwal 1447 AH | Mon 30 Mar',
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
          dateLabel: '10 Shawwal 1447 AH | Mon 30 Mar',
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
  assert.equal(result.dateLabel, '10 Shawwal 1447 AH | Mon 30 Mar');
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
          dateLabel: '10 Shawwal 1447 AH | Mon 30 Mar',
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
  assert.equal(body.data.dateLabel, '10 Shawwal 1447 AH | Mon 30 Mar');
  assert.equal(body.data.timings.dhuhr, '12:31 PM');
  assert.equal(body.data.configuration.calculationMethod.id, 3);

  await app.close();
});

test('location prayer-time service delegates latitude longitude and school', async () => {
  const service = createPrayerTimeService({
    now: () => new Date('2026-04-18T08:50:00.000Z'),
    alAdhanClient: {
      async getDailyTimings(params) {
        assert.equal(params.date, '2026-04-18');
        assert.equal(params.latitude, 12.9716);
        assert.equal(params.longitude, 77.5946);
        assert.equal(params.calculationMethodId, undefined);
        assert.equal(params.school, 'hanafi');
        return {
          timezone: 'Asia/Kolkata',
          calculationMethodId: 3,
          calculationMethodName: 'Muslim World League',
          dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
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

  const result = await service.readLocationDailyTimings({
    date: '2026-04-18',
    latitude: 12.9716,
    longitude: 77.5946,
    school: 'hanafi'
  });

  assert.equal(result.dateLabel, '20 Shawwal 1447 AH | Sat 18 Apr');
  assert.equal(result.isAvailable, true);
  assert.equal(result.timings.asr, '04:02 PM');
  assert.equal(result.configuration.school.value, 'hanafi');
  assert.equal(result.configuration.calculationMethod.id, 3);
  assert.equal(result.configuration.calculationMethod.name, 'Muslim World League');
  assert.equal(result.nextPrayer, 'Asr');
  assert.equal(result.nextPrayerTime, '04:02 PM');
  assert.equal(Object.hasOwn(result, 'mosqueId'), false);
});

test('location prayer-time service uses AlAdhan-selected method metadata for Florida when method is omitted', async () => {
  const service = createPrayerTimeService({
    now: () => new Date('2026-04-18T08:50:00.000Z'),
    alAdhanClient: {
      async getDailyTimings(params) {
        assert.equal(params.latitude, 27.9944);
        assert.equal(params.longitude, -81.7603);
        assert.equal(params.calculationMethodId, undefined);
        assert.equal(params.school, 'standard');
        return {
          timezone: 'America/New_York',
          calculationMethodId: 2,
          calculationMethodName: 'Islamic Society of North America',
          dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
          timings: {
            fajr: { clockValue: '05:48', display: '05:48 AM' },
            sunrise: { clockValue: '06:58', display: '06:58 AM' },
            dhuhr: { clockValue: '13:24', display: '01:24 PM' },
            asr: { clockValue: '17:02', display: '05:02 PM' },
            maghrib: { clockValue: '19:50', display: '07:50 PM' },
            isha: { clockValue: '21:00', display: '09:00 PM' }
          }
        };
      }
    }
  });

  const result = await service.readLocationDailyTimings({
    date: '2026-04-18',
    latitude: 27.9944,
    longitude: -81.7603,
    school: 'standard'
  });

  assert.equal(result.configuration.calculationMethod.id, 2);
  assert.equal(result.configuration.calculationMethod.name, 'Islamic Society of North America');
  assert.equal(result.configuration.school.value, 'standard');
  assert.equal(result.timezone, 'America/New_York');
});

test('location prayer-time service keeps school independent from the method AlAdhan returns', async () => {
  const methods = [];
  const service = createPrayerTimeService({
    alAdhanClient: {
      async getDailyTimings(params) {
        methods.push({
          calculationMethodId: params.calculationMethodId,
          school: params.school
        });
        return {
          timezone: 'America/New_York',
          calculationMethodId: 2,
          calculationMethodName: 'Islamic Society of North America',
          dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
          timings: {
            fajr: { clockValue: '05:48', display: '05:48 AM' },
            sunrise: { clockValue: '06:58', display: '06:58 AM' },
            dhuhr: { clockValue: '13:24', display: '01:24 PM' },
            asr: { clockValue: '17:02', display: '05:02 PM' },
            maghrib: { clockValue: '19:50', display: '07:50 PM' },
            isha: { clockValue: '21:00', display: '09:00 PM' }
          }
        };
      }
    }
  });

  const standardResult = await service.readLocationDailyTimings({
    date: '2026-04-18',
    latitude: 27.9944,
    longitude: -81.7603,
    school: 'standard'
  });
  const hanafiResult = await service.readLocationDailyTimings({
    date: '2026-04-18',
    latitude: 27.9944,
    longitude: -81.7603,
    school: 'hanafi'
  });

  assert.deepEqual(methods, [
    {
      calculationMethodId: undefined,
      school: 'standard'
    },
    {
      calculationMethodId: undefined,
      school: 'hanafi'
    }
  ]);
  assert.equal(standardResult.configuration.calculationMethod.id, 2);
  assert.equal(hanafiResult.configuration.calculationMethod.id, 2);
  assert.equal(standardResult.configuration.school.value, 'standard');
  assert.equal(hanafiResult.configuration.school.value, 'hanafi');
});

test('location prayer-time service respects an explicit method override', async () => {
  const service = createPrayerTimeService({
    alAdhanClient: {
      async getDailyTimings(params) {
        assert.equal(params.latitude, 27.9944);
        assert.equal(params.longitude, -81.7603);
        assert.equal(params.calculationMethodId, 3);
        return {
          timezone: 'America/New_York',
          calculationMethodId: 3,
          calculationMethodName: 'Muslim World League',
          dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
          timings: {
            fajr: { clockValue: '05:44', display: '05:44 AM' },
            sunrise: { clockValue: '06:58', display: '06:58 AM' },
            dhuhr: { clockValue: '13:24', display: '01:24 PM' },
            asr: { clockValue: '17:02', display: '05:02 PM' },
            maghrib: { clockValue: '19:50', display: '07:50 PM' },
            isha: { clockValue: '20:54', display: '08:54 PM' }
          }
        };
      }
    }
  });

  const result = await service.readLocationDailyTimings({
    date: '2026-04-18',
    latitude: 27.9944,
    longitude: -81.7603,
    calculationMethodId: 3,
    school: 'standard'
  });

  assert.equal(result.configuration.calculationMethod.id, 3);
  assert.equal(result.configuration.calculationMethod.name, 'Muslim World League');
});

test('GET /api/v1/prayer-times/daily validates input and returns delegated payload', async () => {
  const delegatedMethodIds = [];
  const app = buildApp({
    prayerTimeService: {
      async readLocationDailyTimings({
        date,
        latitude,
        longitude,
        school,
        calculationMethodId
      }) {
        assert.equal(date, '2026-04-18');
        assert.equal(latitude, 12.9716);
        assert.equal(longitude, 77.5946);
        assert.equal(school, 'hanafi');
        delegatedMethodIds.push(calculationMethodId);
        return {
          date,
          dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
          status: 'ready',
          isConfigured: true,
          isAvailable: true,
          source: 'aladhan',
          unavailableReason: null,
          timezone: 'Asia/Kolkata',
          configuration: {
            enabled: true,
            latitude,
            longitude,
            calculationMethod: {
              id: calculationMethodId ?? 3,
              name:
                calculationMethodId === 4
                  ? 'Umm Al-Qura University, Makkah'
                  : 'Muslim World League'
            },
            school: {
              value: school,
              label: 'Hanafi'
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
          cachedAt: '2026-04-18T08:50:00.000Z'
        };
      }
    }
  });

  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/prayer-times/daily?date=2026-04-18&latitude=12.9716&longitude=77.5946&school=hanafi'
  });

  assert.equal(response.statusCode, 200);
  const body = response.json();
  assert.equal(body.data.timings.asr, '04:02 PM');
  assert.equal(body.data.nextPrayer, 'Asr');
  assert.equal(body.data.nextPrayerTime, '04:02 PM');
  assert.equal(body.data.configuration.school.value, 'hanafi');
  assert.equal(Object.hasOwn(body.data, 'mosqueId'), false);

  const explicitMethodResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/prayer-times/daily?date=2026-04-18&latitude=12.9716&longitude=77.5946&school=hanafi&method=4'
  });

  assert.equal(explicitMethodResponse.statusCode, 200);
  assert.deepEqual(delegatedMethodIds, [undefined, 4]);
  assert.equal(
    explicitMethodResponse.json().data.configuration.calculationMethod.id,
    4
  );

  const invalidDateResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/prayer-times/daily?date=2026-02-30&latitude=12.9716&longitude=77.5946&school=standard'
  });

  assert.equal(invalidDateResponse.statusCode, 400);

  const invalidCoordinatesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/prayer-times/daily?date=2026-04-18&latitude=hello&longitude=181&school=standard'
  });

  assert.equal(invalidCoordinatesResponse.statusCode, 400);

  const invalidSchoolResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/prayer-times/daily?date=2026-04-18&latitude=12.9716&longitude=77.5946&school=invalid'
  });

  assert.equal(invalidSchoolResponse.statusCode, 400);

  const missingRequiredResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/prayer-times/daily?latitude=12.9716&longitude=77.5946'
  });

  assert.equal(missingRequiredResponse.statusCode, 400);

  await app.close();
});

test('location prayer-time service returns an unavailable payload when AlAdhan fails', async () => {
  const service = createPrayerTimeService({
    alAdhanClient: {
      async getDailyTimings() {
        throw new Error('upstream unavailable');
      }
    }
  });

  const result = await service.readLocationDailyTimings({
    date: '2026-04-18',
    latitude: 12.9716,
    longitude: 77.5946,
    school: 'hanafi'
  });

  assert.equal(result.status, 'temporarily_unavailable');
  assert.equal(result.isAvailable, false);
  assert.equal(result.source, 'none');
  assert.equal(result.timings, null);
  assert.equal(result.nextPrayer, '');
  assert.equal(result.nextPrayerTime, '');
  assert.equal(result.configuration.school.value, 'hanafi');
  assert.equal(Object.hasOwn(result, 'mosqueId'), false);
});
