import crypto from 'node:crypto';

import { env } from '../config/env.js';

const GOOGLE_OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const FCM_API_ORIGIN = 'https://fcm.googleapis.com/v1/projects';

function normalizePrivateKey(value) {
  if (typeof value !== 'string') {
    return undefined;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed.replace(/\\n/g, '\n') : undefined;
}

function readCredentialsFromEnv(config = env) {
  if (config.FIREBASE_SERVICE_ACCOUNT_JSON) {
    try {
      const parsed = JSON.parse(config.FIREBASE_SERVICE_ACCOUNT_JSON);
      const projectId = parsed.project_id?.trim();
      const clientEmail = parsed.client_email?.trim();
      const privateKey = normalizePrivateKey(parsed.private_key);

      if (projectId && clientEmail && privateKey) {
        return {
          projectId,
          clientEmail,
          privateKey
        };
      }
    } catch {
      return null;
    }
  }

  if (
    config.FCM_PROJECT_ID &&
    config.FCM_CLIENT_EMAIL &&
    config.FCM_PRIVATE_KEY
  ) {
    return {
      projectId: config.FCM_PROJECT_ID.trim(),
      clientEmail: config.FCM_CLIENT_EMAIL.trim(),
      privateKey: normalizePrivateKey(config.FCM_PRIVATE_KEY)
    };
  }

  return null;
}

function base64UrlEncode(value) {
  const source = typeof value === 'string' ? Buffer.from(value) : value;
  return source
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function buildSignedJwt({
  clientEmail,
  privateKey,
  issuedAtSeconds,
  expirationSeconds
}) {
  const header = base64UrlEncode(JSON.stringify({
    alg: 'RS256',
    typ: 'JWT'
  }));
  const payload = base64UrlEncode(JSON.stringify({
    iss: clientEmail,
    scope: FCM_SCOPE,
    aud: GOOGLE_OAUTH_TOKEN_URL,
    iat: issuedAtSeconds,
    exp: expirationSeconds
  }));
  const unsignedToken = `${header}.${payload}`;
  const signature = crypto.sign(
    'RSA-SHA256',
    Buffer.from(unsignedToken),
    privateKey
  );
  return `${unsignedToken}.${base64UrlEncode(signature)}`;
}

function parseSendFailure(responseBody) {
  const responseText = typeof responseBody === 'string' ? responseBody : '';
  if (!responseText.trim()) {
    return { isUnregistered: false, code: null, message: 'Unknown FCM error' };
  }

  try {
    const parsed = JSON.parse(responseText);
    const error = parsed?.error ?? {};
    const details = Array.isArray(error.details) ? error.details : [];
    const detailErrorCode = details.find((item) => typeof item?.errorCode === 'string')?.errorCode ?? null;
    const statusCode = typeof error.status === 'string' ? error.status : null;
    const message = typeof error.message === 'string' && error.message.trim().length > 0
      ? error.message.trim()
      : 'FCM request failed';
    const isUnregistered = detailErrorCode === 'UNREGISTERED' || statusCode === 'UNREGISTERED';
    return {
      isUnregistered,
      code: detailErrorCode ?? statusCode,
      message
    };
  } catch {
    return {
      isUnregistered: false,
      code: null,
      message: responseText.trim().slice(0, 500)
    };
  }
}

export function createPushNotificationService({
  config = env,
  fetchImpl = globalThis.fetch,
  now = () => new Date()
} = {}) {
  const credentials = readCredentialsFromEnv(config);
  let cachedAccessToken = null;
  let cachedAccessTokenExpiresAt = 0;

  async function getAccessToken() {
    if (!credentials) {
      return null;
    }

    const nowMs = now().getTime();
    if (cachedAccessToken && cachedAccessTokenExpiresAt - nowMs > 60_000) {
      return cachedAccessToken;
    }

    const issuedAtSeconds = Math.floor(nowMs / 1000);
    const expirationSeconds = issuedAtSeconds + 3600;
    const assertion = buildSignedJwt({
      clientEmail: credentials.clientEmail,
      privateKey: credentials.privateKey,
      issuedAtSeconds,
      expirationSeconds
    });

    const response = await fetchImpl(GOOGLE_OAUTH_TOKEN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion
      })
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`OAuth token request failed (${response.status}): ${body.slice(0, 500)}`);
    }

    const payload = await response.json();
    const accessToken = typeof payload?.access_token === 'string'
      ? payload.access_token
      : null;
    const expiresInSeconds = Number(payload?.expires_in);

    if (!accessToken) {
      throw new Error('OAuth token response did not include access_token');
    }

    cachedAccessToken = accessToken;
    cachedAccessTokenExpiresAt = nowMs + (Number.isFinite(expiresInSeconds) ? expiresInSeconds * 1000 : 3600_000);
    return cachedAccessToken;
  }

  async function sendMosqueBroadcastNotification({
    event,
    devices
  }) {
    if (!credentials || !fetchImpl || !Array.isArray(devices) || devices.length == 0) {
      return {
        configured: Boolean(credentials && fetchImpl),
        attemptedCount: 0,
        sentCount: 0,
        invalidDeviceIds: []
      };
    }

    const accessToken = await getAccessToken();
    if (!accessToken) {
      return {
        configured: false,
        attemptedCount: 0,
        sentCount: 0,
        invalidDeviceIds: []
      };
    }

    const uniqueDevices = [];
    const seenTokens = new Set();
    for (const device of devices) {
      const pushToken = device?.pushToken?.trim();
      if (!pushToken || seenTokens.has(pushToken)) {
        continue;
      }
      seenTokens.add(pushToken);
      uniqueDevices.push({
        ...device,
        pushToken
      });
    }

    const invalidDeviceIds = [];
    let sentCount = 0;

    await Promise.all(
      uniqueDevices.map(async (device) => {
        const response = await fetchImpl(
          `${FCM_API_ORIGIN}/${credentials.projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${accessToken}`
            },
            body: JSON.stringify({
              message: {
                token: device.pushToken,
                notification: {
                  title: event.title,
                  body: event.body
                },
                data: {
                  notificationType: 'mosque_broadcast',
                  eventId: event.id,
                  mosqueId: event.mosqueId,
                  mosqueName: event.mosqueName,
                  broadcastId: event.broadcastId
                },
                android: {
                  priority: 'high',
                  notification: {
                    channel_id: 'mosque_updates'
                  }
                },
                apns: {
                  headers: {
                    'apns-priority': '10'
                  },
                  payload: {
                    aps: {
                      sound: 'default'
                    }
                  }
                }
              }
            })
          }
        );

        if (response.ok) {
          sentCount += 1;
          return;
        }

        const failure = parseSendFailure(await response.text());
        if (failure.isUnregistered && device.id) {
          invalidDeviceIds.push(device.id);
        }
        throw Object.assign(
          new Error(`FCM send failed for installation ${device.installationId}: ${failure.message}`),
          {
            fcmCode: failure.code
          }
        );
      }).map((promise) =>
        promise.catch(() => {
          // Best-effort push; caller logs aggregate failures.
        })
      )
    );

    return {
      configured: true,
      attemptedCount: uniqueDevices.length,
      sentCount,
      invalidDeviceIds
    };
  }

  return {
    isConfigured() {
      return Boolean(credentials);
    },
    async sendMosqueBroadcastNotification(args) {
      return sendMosqueBroadcastNotification(args);
    }
  };
}
