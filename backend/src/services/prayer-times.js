import { pool } from '../db/pool.js';
import { env } from '../config/env.js';
import { ERROR_CODES } from '../utils/error-codes.js';
import { HttpError } from '../utils/http.js';

const PRAYER_ORDER = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

export const DEFAULT_PRAYER_ADJUSTMENTS = Object.freeze({
  fajr: 0,
  sunrise: 0,
  dhuhr: 0,
  asr: 0,
  maghrib: 0,
  isha: 0
});

export const CALCULATION_METHOD_LABELS = Object.freeze({
  0: 'Shia Ithna-Ashari, Leva Institute, Qum',
  1: 'University of Islamic Sciences, Karachi',
  2: 'Islamic Society of North America',
  3: 'Muslim World League',
  4: 'Umm Al-Qura University, Makkah',
  5: 'Egyptian General Authority of Survey',
  7: 'Institute of Geophysics, University of Tehran',
  8: 'Gulf Region',
  9: 'Kuwait',
  10: 'Qatar',
  11: 'Majlis Ugama Islam Singapura, Singapore',
  12: 'Diyanet Isleri Baskanligi, Turkey',
  13: 'Spiritual Administration of Muslims of Russia',
  14: 'Moonsighting Committee Worldwide',
  15: 'Dubai (UAE)',
  16: 'Jabatan Kemajuan Islam Malaysia',
  17: 'Tunisia',
  18: 'Algeria',
  19: 'Kementerian Agama Republik Indonesia',
  20: 'Morocco',
  21: 'Comunidade Islamica de Lisboa',
  22: 'Ministry of Awqaf, Jordan'
});

function pad(value) {
  return String(value).padStart(2, '0');
}

export function formatIsoDate(date) {
  const year = date.getFullYear();
  const month = pad(date.getMonth() + 1);
  const day = pad(date.getDate());
  return `${year}-${month}-${day}`;
}

function formatAlAdhanDate(date) {
  const year = date.getFullYear();
  const month = pad(date.getMonth() + 1);
  const day = pad(date.getDate());
  return `${day}-${month}-${year}`;
}

function parseIsoDate(dateString) {
  const [year, month, day] = dateString.split('-').map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (
    !Number.isFinite(parsed.getTime()) ||
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    return null;
  }

  return parsed;
}

function toTimeParts(date, timeZone) {
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });

  const parts = formatter.formatToParts(date);
  const hour = Number(parts.find((part) => part.type === 'hour')?.value ?? '0');
  const minute = Number(parts.find((part) => part.type === 'minute')?.value ?? '0');
  return { hour, minute };
}

function currentIsoDateInTimeZone(timeZone, now) {
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });

  const parts = formatter.formatToParts(now);
  const year = parts.find((part) => part.type === 'year')?.value ?? '0000';
  const month = parts.find((part) => part.type === 'month')?.value ?? '00';
  const day = parts.find((part) => part.type === 'day')?.value ?? '00';
  return `${year}-${month}-${day}`;
}

function schoolLabel(value) {
  return value === 'hanafi' ? 'Hanafi' : 'Standard';
}

export function normalizePrayerAdjustments(value) {
  const source = value && typeof value === 'object' ? value : {};

  return Object.fromEntries(
    PRAYER_ORDER.map((prayer) => {
      const numeric = Number(source[prayer] ?? 0);
      const bounded = Number.isFinite(numeric)
        ? Math.max(-59, Math.min(59, Math.trunc(numeric)))
        : 0;
      return [prayer, bounded];
    })
  );
}

function normalizeStoredConfiguration(row) {
  if (row.calculation_method == null) {
    return null;
  }

  const calculationMethodId = Number(row.calculation_method);
  const school = row.school === 'hanafi' ? 'hanafi' : 'standard';

  return {
    enabled: Boolean(row.prayer_config_enabled),
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    calculationMethod: {
      id: calculationMethodId,
      name:
        CALCULATION_METHOD_LABELS[calculationMethodId] ??
        `Calculation Method ${calculationMethodId}`
    },
    school: {
      value: school,
      label: schoolLabel(school)
    },
    adjustments: normalizePrayerAdjustments(row.prayer_adjustments)
  };
}

function extractClockValue(rawValue) {
  if (typeof rawValue !== 'string') {
    return '';
  }

  const match = rawValue.match(/(\d{1,2}):(\d{2})/);
  if (!match) {
    return '';
  }

  return `${pad(match[1])}:${match[2]}`;
}

function toTwelveHour(clockValue) {
  if (!clockValue) {
    return '';
  }

  const [hourRaw, minuteRaw] = clockValue.split(':').map(Number);
  if (!Number.isFinite(hourRaw) || !Number.isFinite(minuteRaw)) {
    return '';
  }

  const suffix = hourRaw >= 12 ? 'PM' : 'AM';
  const normalizedHour = hourRaw % 12 === 0 ? 12 : hourRaw % 12;
  return `${pad(normalizedHour)}:${pad(minuteRaw)} ${suffix}`;
}

function parseClockValue(clockValue) {
  const [hourRaw, minuteRaw] = clockValue.split(':').map(Number);
  if (!Number.isFinite(hourRaw) || !Number.isFinite(minuteRaw)) {
    return null;
  }

  return hourRaw * 60 + minuteRaw;
}

function computeNextPrayer(timings, { date, timeZone, now }) {
  if (!timings || currentIsoDateInTimeZone(timeZone, now) !== date) {
    return {
      nextPrayer: '',
      nextPrayerTime: ''
    };
  }

  const currentParts = toTimeParts(now, timeZone);
  const currentMinutes = currentParts.hour * 60 + currentParts.minute;
  const nextPrayerEntry = PRAYER_ORDER.filter((prayer) => prayer !== 'sunrise')
    .map((prayer) => ({
      prayer,
      minutes: parseClockValue(timings[prayer]?.clockValue ?? '')
    }))
    .find((entry) => entry.minutes != null && entry.minutes > currentMinutes);

  if (!nextPrayerEntry) {
    return {
      nextPrayer: '',
      nextPrayerTime: ''
    };
  }

  return {
    nextPrayer: toPrayerLabel(nextPrayerEntry.prayer),
    nextPrayerTime: timings[nextPrayerEntry.prayer].display
  };
}

function toPrayerLabel(prayer) {
  switch (prayer) {
    case 'fajr':
      return 'Fajr';
    case 'sunrise':
      return 'Sunrise';
    case 'dhuhr':
      return 'Dhuhr';
    case 'asr':
      return 'Asr';
    case 'maghrib':
      return 'Maghrib';
    case 'isha':
      return 'Isha';
    default:
      return prayer;
  }
}

function buildTimingsReadModel(timings) {
  if (!timings) {
    return null;
  }

  return Object.fromEntries(
    PRAYER_ORDER.map((prayer) => [prayer, timings[prayer]?.display ?? ''])
  );
}

function buildUnavailablePayload({
  mosqueId,
  date,
  configuration,
  status,
  unavailableReason
}) {
  return {
    mosqueId,
    date,
    status,
    isConfigured: configuration != null,
    isAvailable: false,
    source: 'none',
    unavailableReason,
    timezone: null,
    configuration,
    timings: null,
    nextPrayer: '',
    nextPrayerTime: '',
    cachedAt: null
  };
}

function buildPrayerTimesPayload({
  mosqueId,
  date,
  configuration,
  timezone,
  timings,
  source,
  cachedAt,
  now
}) {
  const nextPrayer = computeNextPrayer(timings, {
    date,
    timeZone: timezone,
    now
  });

  return {
    mosqueId,
    date,
    status: 'ready',
    isConfigured: true,
    isAvailable: true,
    source,
    unavailableReason: null,
    timezone,
    configuration,
    timings: buildTimingsReadModel(timings),
    nextPrayer: nextPrayer.nextPrayer,
    nextPrayerTime: nextPrayer.nextPrayerTime,
    cachedAt
  };
}

function toTuneParameter(adjustments) {
  return PRAYER_ORDER.map((prayer) => adjustments[prayer] ?? 0).join(',');
}

function shouldSyncSummaryTimings({ date, timeZone, now }) {
  return currentIsoDateInTimeZone(timeZone, now) === date;
}

async function syncMosqueSummaryTimings(client, mosqueId, timings) {
  await client.query(
    `UPDATE mosques
     SET duhr_time = $2,
         asr_time = $3
     WHERE id = $1`,
    [mosqueId, timings.dhuhr.display, timings.asr.display]
  );
}

export function createAlAdhanClient({
  fetchImpl = globalThis.fetch,
  baseUrl = env.ALADHAN_BASE_URL,
  timeoutMs = env.ALADHAN_TIMEOUT_MS
} = {}) {
  if (typeof fetchImpl !== 'function') {
    throw new Error('A fetch implementation is required for the AlAdhan client');
  }

  return {
    async getDailyTimings({ date, latitude, longitude, calculationMethodId, school, adjustments }) {
      const parsedDate = parseIsoDate(date);
      if (!parsedDate) {
        throw new Error(`Invalid prayer-time date: ${date}`);
      }

      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), timeoutMs);

      try {
        const url = new URL(`${baseUrl.replace(/\/$/, '')}/timings/${formatAlAdhanDate(parsedDate)}`);
        url.searchParams.set('latitude', String(latitude));
        url.searchParams.set('longitude', String(longitude));
        url.searchParams.set('method', String(calculationMethodId));
        url.searchParams.set('school', school === 'hanafi' ? '1' : '0');
        url.searchParams.set('tune', toTuneParameter(adjustments));

        const response = await fetchImpl(url, {
          method: 'GET',
          signal: controller.signal,
          headers: {
            accept: 'application/json'
          }
        });

        if (!response.ok) {
          throw new Error(`AlAdhan request failed with status ${response.status}`);
        }

        const payload = await response.json();
        const timings = payload?.data?.timings;
        if (!timings || typeof timings !== 'object') {
          throw new Error('AlAdhan payload did not include timings');
        }

        const normalizedTimings = Object.fromEntries(
          PRAYER_ORDER.map((prayer) => {
            const upstreamKey = prayer === 'dhuhr' ? 'Dhuhr' : toPrayerLabel(prayer);
            const clockValue = extractClockValue(timings[upstreamKey]);
            return [
              prayer,
              {
                clockValue,
                display: toTwelveHour(clockValue)
              }
            ];
          })
        );

        const timezone = payload?.data?.meta?.timezone || 'UTC';
        const methodName =
          payload?.data?.meta?.method?.name ||
          CALCULATION_METHOD_LABELS[calculationMethodId] ||
          `Calculation Method ${calculationMethodId}`;

        return {
          timezone,
          calculationMethodName: methodName,
          timings: normalizedTimings
        };
      } finally {
        clearTimeout(timeout);
      }
    }
  };
}

export async function upsertMosquePrayerTimeConfig({
  client,
  mosqueId,
  prayerTimeConfig
}) {
  if (prayerTimeConfig == null) {
    return;
  }

  const adjustments = normalizePrayerAdjustments(prayerTimeConfig.adjustments);
  const school = prayerTimeConfig.school === 'hanafi' ? 'hanafi' : 'standard';

  await client.query(
    `INSERT INTO mosque_prayer_time_configs (
       mosque_id,
       calculation_method,
       school,
       adjustments,
       is_enabled
     ) VALUES ($1, $2, $3, $4::jsonb, $5)
     ON CONFLICT (mosque_id) DO UPDATE SET
       calculation_method = EXCLUDED.calculation_method,
       school = EXCLUDED.school,
       adjustments = EXCLUDED.adjustments,
       is_enabled = EXCLUDED.is_enabled`,
    [
      mosqueId,
      prayerTimeConfig.calculationMethod,
      school,
      JSON.stringify(adjustments),
      prayerTimeConfig.enabled !== false
    ]
  );
}

export async function clearMosquePrayerTimeCache(client, mosqueId) {
  await client.query('DELETE FROM mosque_prayer_time_daily_cache WHERE mosque_id = $1', [mosqueId]);
}

export function createPrayerTimeService({
  db = pool,
  alAdhanClient = createAlAdhanClient(),
  now = () => new Date()
} = {}) {
  return {
    async readDailyTimings({ mosqueId, date }) {
      const result = await db.query(
        `SELECT
           m.id,
           m.latitude,
           m.longitude,
           c.calculation_method,
           c.school,
           c.adjustments AS prayer_adjustments,
           c.is_enabled AS prayer_config_enabled,
           cache.payload AS cached_payload,
           cache.cached_at
         FROM mosques m
         LEFT JOIN mosque_prayer_time_configs c
           ON c.mosque_id = m.id
         LEFT JOIN mosque_prayer_time_daily_cache cache
           ON cache.mosque_id = m.id
          AND cache.prayer_date = $2::date
         WHERE m.id = $1`,
        [mosqueId, date]
      );

      if (!result.rowCount) {
        throw new HttpError(404, ERROR_CODES.mosqueNotFound, 'Mosque not found');
      }

      const row = result.rows[0];
      const configuration = normalizeStoredConfiguration(row);

      if (configuration == null) {
        return buildUnavailablePayload({
          mosqueId,
          date,
          configuration: null,
          status: 'not_configured',
          unavailableReason: 'Prayer timings are not configured for this mosque yet.'
        });
      }

      if (!configuration.enabled) {
        return buildUnavailablePayload({
          mosqueId,
          date,
          configuration,
          status: 'disabled',
          unavailableReason: 'Prayer timings are currently disabled for this mosque.'
        });
      }

      if (row.cached_payload) {
        const cachedPayload =
          typeof row.cached_payload === 'string'
            ? JSON.parse(row.cached_payload)
            : row.cached_payload;

        return {
          ...cachedPayload,
          configuration,
          source: 'cache',
          cachedAt: row.cached_at?.toISOString?.() ?? cachedPayload.cachedAt ?? null
        };
      }

      try {
        const fetched = await alAdhanClient.getDailyTimings({
          date,
          latitude: configuration.latitude,
          longitude: configuration.longitude,
          calculationMethodId: configuration.calculationMethod.id,
          school: configuration.school.value,
          adjustments: configuration.adjustments
        });

        const currentTime = now();
        const payload = buildPrayerTimesPayload({
          mosqueId,
          date,
          configuration: {
            ...configuration,
            calculationMethod: {
              id: configuration.calculationMethod.id,
              name: fetched.calculationMethodName
            }
          },
          timezone: fetched.timezone,
          timings: fetched.timings,
          source: 'aladhan',
          cachedAt: currentTime.toISOString(),
          now: currentTime
        });

        await db.query(
          `INSERT INTO mosque_prayer_time_daily_cache (
             mosque_id,
             prayer_date,
             payload,
             cached_at
           ) VALUES ($1, $2::date, $3::jsonb, $4)
           ON CONFLICT (mosque_id, prayer_date) DO UPDATE SET
             payload = EXCLUDED.payload,
             cached_at = EXCLUDED.cached_at`,
          [mosqueId, date, JSON.stringify(payload), payload.cachedAt]
        );

        if (shouldSyncSummaryTimings({ date, timeZone: fetched.timezone, now: currentTime })) {
          await syncMosqueSummaryTimings(db, mosqueId, fetched.timings);
        }

        return payload;
      } catch {
        return buildUnavailablePayload({
          mosqueId,
          date,
          configuration,
          status: 'temporarily_unavailable',
          unavailableReason: 'Live prayer timings are temporarily unavailable. Please try again shortly.'
        });
      }
    }
  };
}
