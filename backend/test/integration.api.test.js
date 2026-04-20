import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildApp } from '../src/app.js';
import { pool } from '../src/db/pool.js';
import { createEmailService, EmailConfigurationError } from '../src/services/email/index.js';
import { createPrayerTimeService } from '../src/services/prayer-times.js';
import { hashToken } from '../src/utils/auth.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const API_REQUEST_ID = 'itest-request-001';
function buildMultipartImagePayload({
  fieldName = 'file',
  fileName = 'mosque.png',
  contentType = 'image/png',
  bytes = Buffer.from([137, 80, 78, 71])
} = {}) {
  const boundary = `----believer-upload-${Date.now()}`;
  const header = Buffer.from(
    `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="${fieldName}"; filename="${fileName}"\r\n` +
      `Content-Type: ${contentType}\r\n\r\n`
  );
  const footer = Buffer.from(`\r\n--${boundary}--\r\n`);

  return {
    boundary,
    payload: Buffer.concat([header, bytes, footer])
  };
}

async function resetData() {
  await pool.query('DELETE FROM business_listing_reviews');
  await pool.query('DELETE FROM business_listings');
  await pool.query('DELETE FROM support_requests');
  await pool.query('DELETE FROM mosque_suggestions');
  await pool.query('DELETE FROM password_reset_tokens');
  await pool.query('DELETE FROM mosque_prayer_time_daily_cache');
  await pool.query('DELETE FROM mosque_prayer_time_configs');
  await pool.query('DELETE FROM mosque_page_content');
  await pool.query('DELETE FROM mosque_broadcast_messages');
  await pool.query('DELETE FROM mosque_notification_settings');
  await pool.query('DELETE FROM mosque_reviews');
  await pool.query('DELETE FROM bookmarks');
  await pool.query('DELETE FROM refresh_tokens');
  await pool.query('DELETE FROM mosques');
  await pool.query('DELETE FROM users');
}

async function seedBroadcastMessages(mosqueId) {
  await pool.query(
    `INSERT INTO mosque_broadcast_messages (
      mosque_id,
      title,
      description,
      published_at
    ) VALUES
      ($1, $2, $3, $4),
      ($1, $5, $6, $7)`,
    [
      mosqueId,
      'Jummah Parking Update',
      'Overflow parking volunteers will guide arrivals from 12:15 PM this Friday.',
      '2026-03-27T08:30:00.000Z',
      'Weekend Quran Circle Registration',
      'Registration is open for the new weekend Quran circle.',
      '2026-03-24T09:15:00.000Z'
    ]
  );
}

async function seedMosquePageContent(mosqueId) {
  await pool.query(
    `INSERT INTO mosque_page_content (
      mosque_id,
      events,
      classes,
      connect_links,
      about_title,
      about_body
    ) VALUES ($1, $2::jsonb, $3::jsonb, $4::jsonb, $5, $6)`,
    [
      mosqueId,
      JSON.stringify([
        {
          id: 'event-1',
          title: 'Weekend Family Night',
          schedule: 'This Sat',
          posterLabel: 'Family'
        },
        {
          id: 'event-2',
          title: 'Youth Service Day',
          schedule: 'New',
          posterLabel: 'Serve'
        }
      ]),
      JSON.stringify([
        {
          id: 'class-1',
          title: 'Quran Reflection Circle',
          schedule: 'Tue 7 PM',
          posterLabel: 'Quran'
        }
      ]),
      JSON.stringify([
        {
          id: 'connect-1',
          type: 'instagram',
          label: 'instagram.com/integrationmosque',
          value: 'instagram.com/integrationmosque'
        }
      ]),
      'About Integration Mosque',
      'A welcoming mosque for prayer, study, and community gatherings.'
    ]
  );
}

async function seedMosque({ createdByUserId = null } = {}) {
  const result = await pool.query(
    `INSERT INTO mosques (
      name, address_line, city, state, country, postal_code,
      latitude, longitude, facilities, is_verified, moderation_status, created_by_user_id
    ) VALUES (
      $1, $2, $3, $4, $5, $6,
      $7, $8, $9::jsonb, $10, $11, $12
    )
    RETURNING id`,
    [
      'Integration Test Mosque',
      'Test Street',
      'Bengaluru',
      'Karnataka',
      'India',
      '560001',
      12.9716,
      77.5946,
      JSON.stringify(['parking', 'wudu']),
      true,
      'live',
      createdByUserId
    ]
  );

  return result.rows[0].id;
}

async function seedPrayerTimeConfig(mosqueId, overrides = {}) {
  await pool.query(
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
      overrides.calculationMethod ?? 3,
      overrides.school ?? 'standard',
      JSON.stringify(
        overrides.adjustments ?? {
          fajr: 0,
          sunrise: 0,
          dhuhr: 1,
          asr: 0,
          maghrib: 0,
          isha: 0
        }
      ),
      overrides.enabled ?? true
    ]
  );
}

async function signupAndPromoteAdmin(app, email) {
  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Admin User',
      email,
      password: 'StrongPass@123',
      accountType: 'admin'
    }
  });

  assert.equal(signupResponse.statusCode, 201);
  assert.equal(signupResponse.json().data.user.role, 'admin');

  const loginResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(loginResponse.statusCode, 200);
  return loginResponse.json().data.tokens.accessToken;
}

async function signupAdminSession(app, email) {
  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Admin User',
      email,
      password: 'StrongPass@123',
      accountType: 'admin'
    }
  });

  assert.equal(signupResponse.statusCode, 201);

  const loginResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(loginResponse.statusCode, 200);

  return {
    userId: signupResponse.json().data.user.id,
    accessToken: loginResponse.json().data.tokens.accessToken,
  };
}

async function signupCommunitySession(app, email) {
  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Community User',
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);

  const loginResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(loginResponse.statusCode, 200);

  return {
    userId: signupResponse.json().data.user.id,
    accessToken: loginResponse.json().data.tokens.accessToken,
  };
}

async function signupSuperAdminSession(app, email) {
  const session = await signupCommunitySession(app, email);

  await pool.query(
    `UPDATE users
     SET role = 'super_admin'
     WHERE id = $1`,
    [session.userId]
  );

  const loginResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(loginResponse.statusCode, 200);
  assert.equal(loginResponse.json().data.user.role, 'super_admin');

  return {
    userId: session.userId,
    accessToken: loginResponse.json().data.tokens.accessToken,
  };
}

function buildBusinessListingPayload(overrides = {}) {
  return {
    basicDetails: {
      businessName: 'Noor Catering',
      logo: {
        fileName: 'noor.png',
        contentType: 'image/png',
        bytesBase64: 'bm9vci1sb2dv',
        tileBackgroundColor: 4293512350
      },
      selectedType: {
        groupId: 'food',
        groupLabel: 'Halal Food',
        itemId: 'catering',
        itemLabel: 'Catering Services'
      },
      tagline: 'Trusted halal catering for family and community events.',
      description: 'We handle wedding catering, office lunches, and weekend dawat events.',
      ...overrides.basicDetails
    },
    contactDetails: {
      businessEmail: 'hello@noorcatering.example',
      phone: '+91 9988776655',
      whatsapp: '+91 9988776655',
      openingTime: { hour: 9, minute: 0 },
      closingTime: { hour: 18, minute: 30 },
      instagramUrl: 'instagram.com/noorcatering',
      facebookUrl: 'facebook.com/noorcatering',
      websiteUrl: 'https://noorcatering.example',
      address: '12 Crescent Road',
      zipCode: '560001',
      city: 'Bengaluru',
      onlineOnly: false,
      ...overrides.contactDetails
    }
  };
}

async function submitBusinessListingForReview(app, session, overrides = {}) {
  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/business-listings/submit',
    headers: {
      authorization: `Bearer ${session.accessToken}`,
      'content-type': 'application/json'
    },
    payload: buildBusinessListingPayload(overrides)
  });

  assert.equal(response.statusCode, 202);
  return response.json().data.listing;
}

function buildMosquePayload(overrides = {}) {
  return {
    name: 'Admin Created Mosque',
    addressLine: '15 Unity Street',
    city: 'Bengaluru',
    state: 'Karnataka',
    country: 'India',
    postalCode: '560001',
    latitude: 12.9716,
    longitude: 77.5946,
    contactName: 'Fatima Noor',
    contactPhone: '+91-9999999999',
    contactEmail: 'fatima@example.com',
    websiteUrl: 'https://example.org',
    imageUrl: 'https://example.org/mosque.jpg',
    sect: 'Sunni',
    duhrTime: '01:15 PM',
    asrTime: '04:45 PM',
    facilities: ['parking', 'wudu', 'women_area'],
    content: {
      events: [
        {
          title: 'Community Family Night',
          schedule: 'Fri, Apr 12 • 7:30 PM',
          posterLabel: 'Family',
          location: 'Main Prayer Hall',
          description: 'Dinner, reminders, and an open community gathering.'
        }
      ],
      classes: [],
      connect: []
    },
    ...overrides
  };
}

async function createMosqueAsAdmin(app, accessToken, overrides = {}) {
  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/mosques',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: buildMosquePayload(overrides)
  });

  assert.equal(response.statusCode, 201);
  return response.json().data;
}

async function runMigration013BackfillBusinessListingCategoryFields() {
  const migrationPath = path.resolve(
    __dirname,
    '../src/db/migrations/013_backfill_business_listing_category_fields.sql'
  );
  const sql = await fs.readFile(migrationPath, 'utf8');
  await pool.query(sql);
}

async function runMigration015SuperAdminMosqueModeration() {
  const migrationPath = path.resolve(
    __dirname,
    '../src/db/migrations/015_super_admin_mosque_moderation.sql'
  );
  const sql = await fs.readFile(migrationPath, 'utf8');
  await pool.query(sql);
}

function createEmailStub() {
  const sentEmails = [];
  const sentWelcomeEmails = [];

  return {
    sentEmails,
    sentWelcomeEmails,
    service: {
      ensurePasswordResetAvailable() {},
      async sendPasswordResetEmail({ to, fullName, resetToken }) {
        sentEmails.push({ to, fullName, resetToken });
        return { id: `email-${sentEmails.length}` };
      },
      async sendWelcomeEmail({ to, fullName, role }) {
        sentWelcomeEmails.push({ to, fullName, role });
        return { id: `welcome-${sentWelcomeEmails.length}` };
      }
    }
  };
}

function assertAdminUserPayloadHasNoSecrets(user) {
  assert.equal('passwordHash' in user, false);
  assert.equal('password_hash' in user, false);
  assert.equal('refreshToken' in user, false);
  assert.equal('refresh_token' in user, false);
  assert.equal('refreshTokens' in user, false);
  assert.equal('resetTokenHash' in user, false);
  assert.equal('reset_token_hash' in user, false);
  assert.equal('tokenHash' in user, false);
  assert.equal('token_hash' in user, false);
}

test.before(async () => {
  await runMigration015SuperAdminMosqueModeration();
  await resetData();
});

test('auth flow + request id propagation', async () => {
  const app = buildApp();

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json',
      'x-request-id': API_REQUEST_ID
    },
    payload: {
      fullName: 'Integration User',
      email: `integration-${Date.now()}@example.com`,
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);
  assert.equal(signupResponse.headers['x-request-id'], API_REQUEST_ID);

  const signupBody = signupResponse.json();
  assert.equal(signupBody.error, null);
  assert.ok(signupBody.data.tokens.accessToken);
  assert.ok(signupBody.data.tokens.refreshToken);

  const meResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/auth/me',
    headers: {
      authorization: `Bearer ${signupBody.data.tokens.accessToken}`,
      'x-request-id': API_REQUEST_ID
    }
  });

  assert.equal(meResponse.statusCode, 200);
  assert.equal(meResponse.headers['x-request-id'], API_REQUEST_ID);
  assert.equal(meResponse.json().data.fullName, 'Integration User');

  const updateProfileResponse = await app.inject({
    method: 'PUT',
    url: '/api/v1/auth/me',
    headers: {
      authorization: `Bearer ${signupBody.data.tokens.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Integration User Updated'
    }
  });

  assert.equal(updateProfileResponse.statusCode, 200);
  assert.equal(updateProfileResponse.json().data.fullName, 'Integration User Updated');

  await app.close();
});

test('signup sends a non-blocking welcome email when transactional email is available', async () => {
  await resetData();

  const emailStub = createEmailStub();
  const app = buildApp({ emailService: emailStub.service });

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Welcome User',
      email: `welcome-${Date.now()}@example.com`,
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);
  assert.equal(emailStub.sentWelcomeEmails.length, 1);
  assert.equal(emailStub.sentWelcomeEmails[0].fullName, 'Welcome User');
  assert.equal(emailStub.sentWelcomeEmails[0].role, 'community');

  await app.close();
});

test('signup welcome email flows through the real email service contract', async () => {
  await resetData();

  const sentPayloads = [];
  const email = `welcome-contract-${Date.now()}@example.com`;
  const app = buildApp({
    emailService: createEmailService({
      provider: {
        isConfigured: true,
        async send(payload) {
          sentPayloads.push(payload);
          return { id: `welcome-${sentPayloads.length}` };
        }
      },
      fromAddress: 'Believers Lens <no-reply@example.com>',
      replyToAddress: 'support@example.com'
    })
  });

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Contract User',
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);
  assert.equal(sentPayloads.length, 1);
  assert.equal(sentPayloads[0].to, email);
  assert.equal(sentPayloads[0].replyTo, 'support@example.com');
  assert.equal(sentPayloads[0].subject, 'Welcome to BelieversLens');

  await app.close();
});

test('signup still succeeds when welcome email delivery fails', async () => {
  await resetData();

  const app = buildApp({
    emailService: {
      ensurePasswordResetAvailable() {},
      async sendPasswordResetEmail() {
        return { id: 'reset-1' };
      },
      async sendWelcomeEmail() {
        throw new Error('welcome send failed');
      }
    }
  });

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Welcome Resilient User',
      email: `welcome-resilient-${Date.now()}@example.com`,
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);
  assert.ok(signupResponse.json().data.tokens.accessToken);

  await app.close();
});

test('forgot password stays non-enumerating, sends reset email, and revokes old refresh tokens after reset', async () => {
  await resetData();

  const emailStub = createEmailStub();
  const app = buildApp({ emailService: emailStub.service });
  const email = `recovery-${Date.now()}@example.com`;

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Recovery User',
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);
  const originalRefreshToken = signupResponse.json().data.tokens.refreshToken;

  const missingUserResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/forgot-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email: `missing-${Date.now()}@example.com`
    }
  });

  assert.equal(missingUserResponse.statusCode, 200);
  assert.equal(missingUserResponse.json().data.success, true);
  assert.equal(emailStub.sentEmails.length, 0);

  const forgotPasswordResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/forgot-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email
    }
  });

  assert.equal(forgotPasswordResponse.statusCode, 200);
  assert.equal(forgotPasswordResponse.json().data.success, true);
  assert.equal(emailStub.sentEmails.length, 1);

  const tokenRows = await pool.query(
    `SELECT token_hash, consumed_at, expires_at
     FROM password_reset_tokens`
  );

  assert.equal(tokenRows.rowCount, 1);
  assert.equal(tokenRows.rows[0].token_hash, hashToken(emailStub.sentEmails[0].resetToken));
  assert.equal(tokenRows.rows[0].consumed_at, null);
  assert.ok(new Date(tokenRows.rows[0].expires_at).getTime() > Date.now());

  const passwordResetResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/reset-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      token: emailStub.sentEmails[0].resetToken,
      newPassword: 'StrongerPass@456'
    }
  });

  assert.equal(passwordResetResponse.statusCode, 200);
  assert.equal(passwordResetResponse.json().data.success, true);

  const consumedTokenRow = await pool.query(
    `SELECT consumed_at
     FROM password_reset_tokens
     WHERE token_hash = $1`,
    [hashToken(emailStub.sentEmails[0].resetToken)]
  );

  assert.equal(consumedTokenRow.rowCount, 1);
  assert.notEqual(consumedTokenRow.rows[0].consumed_at, null);

  const oldPasswordLogin = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(oldPasswordLogin.statusCode, 401);

  const oldRefreshResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/refresh',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      refreshToken: originalRefreshToken
    }
  });

  assert.equal(oldRefreshResponse.statusCode, 401);

  const newPasswordLogin = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email,
      password: 'StrongerPass@456'
    }
  });

  assert.equal(newPasswordLogin.statusCode, 200);

  await app.close();
});

test('reset password rejects reused, expired, invalid, and malformed tokens', async () => {
  await resetData();

  const emailStub = createEmailStub();
  const app = buildApp({ emailService: emailStub.service });
  const email = `reset-token-${Date.now()}@example.com`;

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Reset Token User',
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);

  const forgotPasswordResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/forgot-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email
    }
  });

  assert.equal(forgotPasswordResponse.statusCode, 200);
  const issuedToken = emailStub.sentEmails[0].resetToken;

  const firstUseResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/reset-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      token: issuedToken,
      newPassword: 'StrongPass@456'
    }
  });

  assert.equal(firstUseResponse.statusCode, 200);

  const reusedTokenResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/reset-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      token: issuedToken,
      newPassword: 'StrongPass@789'
    }
  });

  assert.equal(reusedTokenResponse.statusCode, 400);
  assert.equal(reusedTokenResponse.json().error.code, 'INVALID_PASSWORD_RESET_TOKEN');

  const secondForgotPassword = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/forgot-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email
    }
  });

  assert.equal(secondForgotPassword.statusCode, 200);
  const expiringToken = emailStub.sentEmails[1].resetToken;
  await pool.query(
    `UPDATE password_reset_tokens
     SET expires_at = now() - interval '1 minute'
     WHERE token_hash = $1`,
    [hashToken(expiringToken)]
  );

  const expiredTokenResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/reset-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      token: expiringToken,
      newPassword: 'StrongPass@999'
    }
  });

  assert.equal(expiredTokenResponse.statusCode, 400);
  assert.equal(expiredTokenResponse.json().error.code, 'INVALID_PASSWORD_RESET_TOKEN');

  const invalidTokenResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/reset-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      token: 'a'.repeat(43),
      newPassword: 'StrongPass@999'
    }
  });

  assert.equal(invalidTokenResponse.statusCode, 400);
  assert.equal(invalidTokenResponse.json().error.code, 'INVALID_PASSWORD_RESET_TOKEN');

  const malformedTokenResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/reset-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      token: 'short-token',
      newPassword: 'StrongPass@999'
    }
  });

  assert.equal(malformedTokenResponse.statusCode, 400);
  assert.equal(malformedTokenResponse.json().error.code, 'VALIDATION_ERROR');

  await app.close();
});

test('forgot password returns a hard failure when email delivery is not configured', async () => {
  await resetData();

  const app = buildApp({
    emailService: {
      ensurePasswordResetAvailable() {
        throw new EmailConfigurationError('Password reset email is not configured');
      },
      async sendPasswordResetEmail() {
        throw new Error('should not be called');
      }
    }
  });

  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/forgot-password',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email: `config-${Date.now()}@example.com`
    }
  });

  assert.equal(response.statusCode, 503);
  assert.equal(response.json().error.code, 'EMAIL_NOT_CONFIGURED');

  await app.close();
});

test('change password requires the current password, rotates session tokens, and allows the new password', async () => {
  await resetData();

  const app = buildApp();
  const email = `change-password-${Date.now()}@example.com`;

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Change Password User',
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);
  const { accessToken, refreshToken } = signupResponse.json().data.tokens;

  const wrongCurrentPasswordResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/change-password',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      currentPassword: 'WrongPass@123',
      newPassword: 'StrongerPass@456'
    }
  });

  assert.equal(wrongCurrentPasswordResponse.statusCode, 400);
  assert.equal(wrongCurrentPasswordResponse.json().error.code, 'INVALID_CURRENT_PASSWORD');

  const changePasswordResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/change-password',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      currentPassword: 'StrongPass@123',
      newPassword: 'StrongerPass@456'
    }
  });

  assert.equal(changePasswordResponse.statusCode, 200);
  assert.ok(changePasswordResponse.json().data.tokens.accessToken);
  assert.ok(changePasswordResponse.json().data.tokens.refreshToken);

  const reusedRefreshResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/refresh',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      refreshToken
    }
  });

  assert.equal(reusedRefreshResponse.statusCode, 401);

  const oldPasswordLogin = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email,
      password: 'StrongPass@123'
    }
  });

  assert.equal(oldPasswordLogin.statusCode, 401);

  const newPasswordLogin = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email,
      password: 'StrongerPass@456'
    }
  });

  assert.equal(newPasswordLogin.statusCode, 200);

  await app.close();
});

test('deactivate account disables future authenticated access and revokes refresh tokens', async () => {
  const app = buildApp({
    prayerTimeService: createPrayerTimeService()
  });
  await resetData();

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Deactivate Me',
      email: 'deactivate@example.com',
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);
  const signupBody = signupResponse.json();
  const accessToken = signupBody.data.tokens.accessToken;
  const refreshToken = signupBody.data.tokens.refreshToken;
  const userId = signupBody.data.user.id;

  const deactivateResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/deactivate',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      confirmation: 'DEACTIVATE'
    }
  });

  assert.equal(deactivateResponse.statusCode, 200);
  assert.equal(deactivateResponse.json().data.success, true);

  const userRow = await pool.query('SELECT is_active FROM users WHERE id = $1', [
    userId
  ]);
  assert.equal(userRow.rows[0].is_active, false);

  const revokedTokens = await pool.query(
    `SELECT count(*)::int AS revoked_count
     FROM refresh_tokens
     WHERE user_id = $1
       AND revoked_at IS NOT NULL`,
    [userId]
  );
  assert.equal(revokedTokens.rows[0].revoked_count, 1);

  const refreshResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/refresh',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      refreshToken
    }
  });

  assert.equal(refreshResponse.statusCode, 401);
  assert.equal(refreshResponse.json().error.code, 'INVALID_REFRESH_TOKEN');

  const notificationsResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/notifications/mosques',
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });

  assert.equal(notificationsResponse.statusCode, 403);
  assert.equal(notificationsResponse.json().error.code, 'ACCOUNT_DISABLED');
});

test('support requests and mosque suggestions persist authenticated account-governance submissions', async () => {
  const app = buildApp({
    prayerTimeService: createPrayerTimeService()
  });
  await resetData();

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Support User',
      email: 'support@example.com',
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);
  const accessToken = signupResponse.json().data.tokens.accessToken;
  const userId = signupResponse.json().data.user.id;

  const supportResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/account/support-requests',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      subject: 'Need help with my account',
      message: 'Please help me understand how to update my mosque details.'
    }
  });

  assert.equal(supportResponse.statusCode, 201);
  assert.equal(supportResponse.json().data.success, true);

  const supportRow = await pool.query(
    `SELECT user_id, full_name, email, subject, message
     FROM support_requests
     WHERE user_id = $1`,
    [userId]
  );
  assert.equal(supportRow.rowCount, 1);
  assert.equal(supportRow.rows[0].full_name, 'Support User');
  assert.equal(supportRow.rows[0].email, 'support@example.com');
  assert.equal(supportRow.rows[0].subject, 'Need help with my account');

  const suggestionResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/account/mosque-suggestions',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      mosqueName: 'Masjid Al Noor',
      city: 'Hyderabad',
      country: 'India',
      addressLine: '123 Market Road',
      notes: 'Women prayer space and parking available.'
    }
  });

  assert.equal(suggestionResponse.statusCode, 201);
  assert.equal(suggestionResponse.json().data.success, true);

  const suggestionRow = await pool.query(
    `SELECT user_id, submitter_name, submitter_email, mosque_name, city, country, address_line, notes
     FROM mosque_suggestions
     WHERE user_id = $1`,
    [userId]
  );
  assert.equal(suggestionRow.rowCount, 1);
  assert.equal(suggestionRow.rows[0].submitter_name, 'Support User');
  assert.equal(suggestionRow.rows[0].submitter_email, 'support@example.com');
  assert.equal(suggestionRow.rows[0].mosque_name, 'Masjid Al Noor');
  assert.equal(suggestionRow.rows[0].city, 'Hyderabad');
  assert.equal(suggestionRow.rows[0].country, 'India');
});

test('mosque admin signup works without an access code', async () => {
  await resetData();

  const app = buildApp();
  const timestamp = Date.now();

  const allowedResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Allowed Admin',
      email: `allowed-admin-${timestamp}@example.com`,
      password: 'StrongPass@123',
      accountType: 'admin'
    }
  });

  assert.equal(allowedResponse.statusCode, 201);
  assert.equal(allowedResponse.json().data.user.role, 'admin');

  await app.close();
});

test('mosque listing/nearby + bookmark flow', async () => {
  await resetData();

  const mosqueId = await seedMosque();
  await seedBroadcastMessages(mosqueId);
  await seedMosquePageContent(mosqueId);
  const app = buildApp();

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Bookmark User',
      email: `bookmark-${Date.now()}@example.com`,
      password: 'StrongPass@123'
    }
  });

  assert.equal(signupResponse.statusCode, 201);
  const { accessToken } = signupResponse.json().data.tokens;

  const reviewResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/mosques/review',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      mosqueId,
      rating: 5,
      comments: 'Warm welcome and clear prayer rows.'
    }
  });
  assert.equal(reviewResponse.statusCode, 201);

  const listResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques?city=Bengaluru&search=Integration&sort=distance&latitude=12.9716&longitude=77.5946&radius=5',
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });
  assert.equal(listResponse.statusCode, 200);
  assert.ok(Array.isArray(listResponse.json().data.items));
  assert.equal(listResponse.json().data.items.length, 1);
  assert.equal(listResponse.json().meta.pagination.total, 1);
  assert.equal(listResponse.json().data.items[0].averageRating, 5);
  assert.equal(listResponse.json().data.items[0].totalReviews, 1);
  assert.deepEqual(listResponse.json().data.items[0].classTags, ['Quran Reflection Circle']);
  assert.deepEqual(listResponse.json().data.items[0].eventTags, ['Weekend Family Night', 'Youth Service Day']);

  const nearbyResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/nearby?latitude=12.9716&longitude=77.5946&radius=5&limit=20',
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });
  assert.equal(nearbyResponse.statusCode, 200);
  assert.equal(nearbyResponse.json().data.items[0].id, mosqueId);
  assert.equal(nearbyResponse.json().data.items[0].averageRating, 5);
  assert.equal(nearbyResponse.json().data.items[0].totalReviews, 1);
  assert.deepEqual(nearbyResponse.json().data.items[0].classTags, ['Quran Reflection Circle']);
  assert.deepEqual(nearbyResponse.json().data.items[0].eventTags, ['Weekend Family Night', 'Youth Service Day']);

  const detailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}`,
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });
  assert.equal(detailResponse.statusCode, 200);
  assert.equal(detailResponse.json().data.averageRating, 5);
  assert.equal(detailResponse.json().data.totalReviews, 1);
  assert.deepEqual(detailResponse.json().data.classTags, ['Quran Reflection Circle']);
  assert.deepEqual(detailResponse.json().data.eventTags, ['Weekend Family Night', 'Youth Service Day']);

  const createBookmark = await app.inject({
    method: 'POST',
    url: '/api/v1/bookmarks',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      mosqueId
    }
  });
  assert.equal(createBookmark.statusCode, 201);
  assert.equal(createBookmark.json().data.status, 'created');

  const listBookmarks = await app.inject({
    method: 'GET',
    url: '/api/v1/bookmarks',
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });
  assert.equal(listBookmarks.statusCode, 200);
  assert.equal(listBookmarks.json().data.items.length, 1);

  const deleteBookmark = await app.inject({
    method: 'DELETE',
    url: `/api/v1/bookmarks/${mosqueId}`,
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });
  assert.equal(deleteBookmark.statusCode, 200);
  assert.equal(deleteBookmark.json().data.success, true);

  await app.close();
});

test('admin mosque create flow persists as pending and remains available to the owner', async () => {
  await resetData();

  const app = buildApp();
  const adminEmail = `admin-${Date.now()}@example.com`;
  const accessToken = await signupAndPromoteAdmin(app, adminEmail);

  const createdMosque = await createMosqueAsAdmin(app, accessToken);
  assert.equal(createdMosque.name, 'Admin Created Mosque');
  assert.equal(createdMosque.city, 'Bengaluru');
  assert.equal(createdMosque.sect, 'Sunni');
  assert.equal(createdMosque.duhrTime, '01:15 PM');
  assert.equal(createdMosque.asrTime, '04:45 PM');
  assert.deepEqual(createdMosque.facilities, ['parking', 'wudu', 'women_area']);
  assert.equal(createdMosque.isVerified, false);
  assert.equal(createdMosque.averageRating, 0);
  assert.equal(createdMosque.totalReviews, 0);
  assert.equal(createdMosque.canEdit, true);
  assert.deepEqual(createdMosque.classTags, []);
  assert.deepEqual(createdMosque.eventTags, ['Community Family Night']);

  const detailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${createdMosque.id}`,
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });

  assert.equal(detailResponse.statusCode, 200);
  assert.equal(detailResponse.json().data.name, 'Admin Created Mosque');
  assert.equal(detailResponse.json().data.contactName, 'Fatima Noor');
  assert.equal(detailResponse.json().data.totalReviews, 0);
  assert.equal(detailResponse.json().data.canEdit, true);
  assert.deepEqual(detailResponse.json().data.classTags, []);
  assert.deepEqual(detailResponse.json().data.eventTags, ['Community Family Night']);

  const contentResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${createdMosque.id}/content`
  });

  assert.equal(contentResponse.statusCode, 200);
  assert.equal(contentResponse.json().data.events[0].title, 'Community Family Night');
  assert.equal(contentResponse.json().data.events[0].location, 'Main Prayer Hall');
  assert.equal(
    contentResponse.json().data.events[0].description,
    'Dinner, reminders, and an open community gathering.'
  );

  const nearbyResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/nearby?latitude=12.9716&longitude=77.5946&radius=5&limit=20',
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });

  assert.equal(nearbyResponse.statusCode, 200);
  const nearbyItems = nearbyResponse.json().data.items;
  assert.equal(nearbyItems.length, 0);

  const mineResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/mine',
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });

  assert.equal(mineResponse.statusCode, 200);
  assert.equal(mineResponse.json().data.items.length, 1);
  assert.equal(mineResponse.json().data.items[0].id, createdMosque.id);
  assert.equal(mineResponse.json().data.items[0].canEdit, true);

  const publicListResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques?city=Bengaluru&search=Admin%20Created&sort=recent'
  });

  assert.equal(publicListResponse.statusCode, 200);
  assert.equal(publicListResponse.json().data.items.length, 0);

  const publicDetailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${createdMosque.id}`
  });

  assert.equal(publicDetailResponse.statusCode, 404);

  const duplicateResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/mosques',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      name: 'Admin Created Mosque',
      addressLine: '15 Unity Street',
      city: 'Bengaluru',
      state: 'Karnataka',
      country: 'India',
      latitude: 12.9716,
      longitude: 77.5946,
      facilities: []
    }
  });

  assert.equal(duplicateResponse.statusCode, 409);
  assert.equal(duplicateResponse.json().error.code, 'MOSQUE_ALREADY_EXISTS');

  await app.close();
});

test('pending mosque appears in the super-admin mosque moderation queue', async () => {
  await resetData();

  const app = buildApp();
  const adminSession = await signupAdminSession(
    app,
    `mosque-pending-admin-${Date.now()}@example.com`
  );
  const createdMosque = await createMosqueAsAdmin(app, adminSession.accessToken, {
    name: 'Pending Queue Mosque'
  });
  const superAdminSession = await signupSuperAdminSession(
    app,
    `mosque-pending-super-admin-${Date.now()}@example.com`
  );

  const pendingResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/admin/mosques/pending',
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(pendingResponse.statusCode, 200);
  assert.equal(pendingResponse.json().data.items.length, 1);
  assert.equal(pendingResponse.json().data.items[0].id, createdMosque.id);
  assert.equal(pendingResponse.json().data.items[0].status, 'pending');
  assert.equal(pendingResponse.json().data.items[0].submitter.id, adminSession.userId);

  await app.close();
});

test('super admin approval flips mosque verification to live', async () => {
  await resetData();

  const app = buildApp();
  const adminSession = await signupAdminSession(
    app,
    `mosque-approve-admin-${Date.now()}@example.com`
  );
  const createdMosque = await createMosqueAsAdmin(app, adminSession.accessToken, {
    name: 'Approval Flip Mosque'
  });
  const superAdminSession = await signupSuperAdminSession(
    app,
    `mosque-approve-super-admin-${Date.now()}@example.com`
  );

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/mosques/${createdMosque.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);
  assert.equal(approveResponse.json().data.mosque.id, createdMosque.id);
  assert.equal(approveResponse.json().data.mosque.status, 'live');

  const persistedMosque = await pool.query(
    `SELECT is_verified
     FROM mosques
     WHERE id = $1`,
    [createdMosque.id]
  );

  assert.equal(persistedMosque.rowCount, 1);
  assert.equal(persistedMosque.rows[0].is_verified, true);

  await app.close();
});

test('super admin can reject a mosque, store a reason, and remove it from the pending queue', async () => {
  await resetData();

  const app = buildApp();
  const adminSession = await signupAdminSession(
    app,
    `mosque-reject-admin-${Date.now()}@example.com`
  );
  const createdMosque = await createMosqueAsAdmin(app, adminSession.accessToken, {
    name: 'Rejected Queue Mosque'
  });
  const superAdminSession = await signupSuperAdminSession(
    app,
    `mosque-reject-super-admin-${Date.now()}@example.com`
  );
  const rejectionReason = 'Please add a clearer contact phone number before approval.';

  const rejectResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/mosques/${createdMosque.id}/reject`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      rejectionReason
    }
  });

  assert.equal(rejectResponse.statusCode, 200);
  assert.equal(rejectResponse.json().data.mosque.id, createdMosque.id);
  assert.equal(rejectResponse.json().data.mosque.status, 'rejected');
  assert.equal(rejectResponse.json().data.mosque.rejectionReason, rejectionReason);
  assert.ok(rejectResponse.json().data.mosque.reviewedAt);

  const persistedMosque = await pool.query(
    `SELECT is_verified, moderation_status, reviewed_by, reviewed_at, rejection_reason
     FROM mosques
     WHERE id = $1`,
    [createdMosque.id]
  );

  assert.equal(persistedMosque.rowCount, 1);
  assert.equal(persistedMosque.rows[0].is_verified, false);
  assert.equal(persistedMosque.rows[0].moderation_status, 'rejected');
  assert.equal(persistedMosque.rows[0].reviewed_by, superAdminSession.userId);
  assert.ok(persistedMosque.rows[0].reviewed_at);
  assert.equal(persistedMosque.rows[0].rejection_reason, rejectionReason);

  const pendingResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/admin/mosques/pending',
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(pendingResponse.statusCode, 200);
  assert.equal(pendingResponse.json().data.items.length, 0);

  await app.close();
});

test('approved mosque becomes visible in public mosque list, detail, and nearby APIs', async () => {
  await resetData();

  const app = buildApp();
  const adminSession = await signupAdminSession(
    app,
    `mosque-public-admin-${Date.now()}@example.com`
  );
  const createdMosque = await createMosqueAsAdmin(app, adminSession.accessToken, {
    name: 'Public Live Mosque'
  });
  const superAdminSession = await signupSuperAdminSession(
    app,
    `mosque-public-super-admin-${Date.now()}@example.com`
  );

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/mosques/${createdMosque.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);

  const listResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques?city=Bengaluru&search=Public%20Live&sort=recent'
  });

  assert.equal(listResponse.statusCode, 200);
  assert.equal(listResponse.json().data.items.length, 1);
  assert.equal(listResponse.json().data.items[0].id, createdMosque.id);
  assert.equal(listResponse.json().data.items[0].isVerified, true);

  const detailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${createdMosque.id}`
  });

  assert.equal(detailResponse.statusCode, 200);
  assert.equal(detailResponse.json().data.id, createdMosque.id);
  assert.equal(detailResponse.json().data.isVerified, true);

  const nearbyResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/nearby?latitude=12.9716&longitude=77.5946&radius=5&limit=20'
  });

  assert.equal(nearbyResponse.statusCode, 200);
  assert.equal(nearbyResponse.json().data.items.length, 1);
  assert.equal(nearbyResponse.json().data.items[0].id, createdMosque.id);
  assert.equal(nearbyResponse.json().data.items[0].isVerified, true);

  await app.close();
});

test('public mosque discovery honors live moderation status even if legacy verification flag is stale', async () => {
  await resetData();

  const app = buildApp();
  const adminSession = await signupAdminSession(
    app,
    `mosque-live-status-admin-${Date.now()}@example.com`
  );
  const createdMosque = await createMosqueAsAdmin(app, adminSession.accessToken, {
    name: 'Live Status Nearby Mosque'
  });
  const superAdminSession = await signupSuperAdminSession(
    app,
    `mosque-live-status-super-admin-${Date.now()}@example.com`
  );

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/mosques/${createdMosque.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);

  await pool.query(
    `UPDATE mosques
     SET is_verified = FALSE,
         moderation_status = 'live'
     WHERE id = $1`,
    [createdMosque.id]
  );

  const listResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques?city=Bengaluru&search=Live%20Status%20Nearby&sort=recent'
  });

  assert.equal(listResponse.statusCode, 200);
  assert.equal(listResponse.json().data.items.length, 1);
  assert.equal(listResponse.json().data.items[0].id, createdMosque.id);

  const nearbyResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/nearby?latitude=12.9716&longitude=77.5946&radius=5&limit=20'
  });

  assert.equal(nearbyResponse.statusCode, 200);
  assert.equal(nearbyResponse.json().data.items.length, 1);
  assert.equal(nearbyResponse.json().data.items[0].id, createdMosque.id);

  const detailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${createdMosque.id}`
  });

  assert.equal(detailResponse.statusCode, 200);
  assert.equal(detailResponse.json().data.id, createdMosque.id);

  await app.close();
});

test('non-super-admin users are forbidden from super-admin user management endpoints', async () => {
  await resetData();

  const app = buildApp();
  const communitySession = await signupCommunitySession(
    app,
    `customer-forbidden-user-${Date.now()}@example.com`
  );
  const adminSession = await signupAdminSession(
    app,
    `customer-forbidden-admin-${Date.now()}@example.com`
  );

  const listResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/admin/users',
    headers: {
      authorization: `Bearer ${adminSession.accessToken}`
    }
  });

  assert.equal(listResponse.statusCode, 403);
  assert.equal(listResponse.json().error.code, 'FORBIDDEN');

  const deactivateResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/users/${communitySession.userId}/deactivate`,
    headers: {
      authorization: `Bearer ${adminSession.accessToken}`
    }
  });

  assert.equal(deactivateResponse.statusCode, 403);
  assert.equal(deactivateResponse.json().error.code, 'FORBIDDEN');

  const detailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/admin/users/${communitySession.userId}`,
    headers: {
      authorization: `Bearer ${adminSession.accessToken}`
    }
  });

  assert.equal(detailResponse.statusCode, 403);
  assert.equal(detailResponse.json().error.code, 'FORBIDDEN');

  await app.close();
});

test('super admin can list users with search, role filtering, and safe fields only', async () => {
  await resetData();

  const app = buildApp();
  await signupCommunitySession(app, `customer-alpha-${Date.now()}@example.com`);
  await signupAdminSession(app, `manager-beta-${Date.now()}@example.com`);
  const superAdminSession = await signupSuperAdminSession(
    app,
    `customer-search-super-admin-${Date.now()}@example.com`
  );

  const searchResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/admin/users?search=manager&role=admin&page=1&limit=1',
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(searchResponse.statusCode, 200);
  assert.equal(searchResponse.json().data.items.length, 1);
  assert.equal(searchResponse.json().data.items[0].role, 'admin');
  assert.match(searchResponse.json().data.items[0].email, /manager-beta-/);
  assert.ok(searchResponse.json().data.items[0].updatedAt);
  assertAdminUserPayloadHasNoSecrets(searchResponse.json().data.items[0]);
  assert.equal(searchResponse.json().meta.pagination.page, 1);
  assert.equal(searchResponse.json().meta.pagination.limit, 1);
  assert.equal(searchResponse.json().meta.pagination.total, 1);
  assert.equal(searchResponse.json().meta.pagination.totalPages, 1);

  await app.close();
});

test('super admin can fetch one user summary with dependency counts and safe fields only', async () => {
  await resetData();

  const app = buildApp();
  const targetSession = await signupAdminSession(
    app,
    `customer-summary-admin-${Date.now()}@example.com`
  );
  const superAdminSession = await signupSuperAdminSession(
    app,
    `customer-summary-super-admin-${Date.now()}@example.com`
  );

  await createMosqueAsAdmin(app, targetSession.accessToken, {
    name: `Summary Owned Mosque ${Date.now()}`
  });
  await submitBusinessListingForReview(app, targetSession, {
    basicDetails: {
      businessName: `Summary Listing ${Date.now()}`
    },
    contactDetails: {
      businessEmail: `summary-listing-${Date.now()}@example.com`
    }
  });

  const detailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/admin/users/${targetSession.userId}`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(detailResponse.statusCode, 200);
  assert.equal(detailResponse.json().data.user.id, targetSession.userId);
  assert.equal(detailResponse.json().data.user.role, 'admin');
  assert.equal(detailResponse.json().data.user.dependencySummary.mosqueCount, 1);
  assert.equal(detailResponse.json().data.user.dependencySummary.businessListingCount, 1);
  assert.ok(detailResponse.json().data.user.updatedAt);
  assertAdminUserPayloadHasNoSecrets(detailResponse.json().data.user);

  await app.close();
});

test('super admin can deactivate a user, revoke refresh tokens, and later reactivate them', async () => {
  await resetData();

  const app = buildApp();
  const targetEmail = `customer-toggle-${Date.now()}@example.com`;
  const targetSession = await signupCommunitySession(app, targetEmail);
  const superAdminSession = await signupSuperAdminSession(
    app,
    `customer-toggle-super-admin-${Date.now()}@example.com`
  );
  const activeRefreshTokensBeforeDeactivation = await pool.query(
    `SELECT count(*)::int AS active_count
     FROM refresh_tokens
     WHERE user_id = $1
       AND revoked_at IS NULL`,
    [targetSession.userId]
  );

  const deactivateResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/users/${targetSession.userId}/deactivate`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(deactivateResponse.statusCode, 200);
  assert.equal(deactivateResponse.json().data.user.isActive, false);
  assert.ok(deactivateResponse.json().data.user.updatedAt);
  assertAdminUserPayloadHasNoSecrets(deactivateResponse.json().data.user);

  const revokedTokens = await pool.query(
    `SELECT count(*)::int AS revoked_count
     FROM refresh_tokens
     WHERE user_id = $1
       AND revoked_at IS NOT NULL`,
    [targetSession.userId]
  );

  assert.equal(
    revokedTokens.rows[0].revoked_count,
    activeRefreshTokensBeforeDeactivation.rows[0].active_count
  );

  const disabledLoginResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email: targetEmail,
      password: 'StrongPass@123'
    }
  });

  assert.equal(disabledLoginResponse.statusCode, 403);
  assert.equal(disabledLoginResponse.json().error.code, 'ACCOUNT_DISABLED');

  const reactivateResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/users/${targetSession.userId}/reactivate`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(reactivateResponse.statusCode, 200);
  assert.equal(reactivateResponse.json().data.user.isActive, true);
  assertAdminUserPayloadHasNoSecrets(reactivateResponse.json().data.user);

  const enabledLoginResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/login',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      email: targetEmail,
      password: 'StrongPass@123'
    }
  });

  assert.equal(enabledLoginResponse.statusCode, 200);

  await app.close();
});

test('super admin cannot deactivate their own account through the admin endpoint', async () => {
  await resetData();

  const app = buildApp();
  const superAdminSession = await signupSuperAdminSession(
    app,
    `customer-self-block-super-admin-${Date.now()}@example.com`
  );

  const selfDeactivateResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/users/${superAdminSession.userId}/deactivate`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(selfDeactivateResponse.statusCode, 409);
  assert.equal(selfDeactivateResponse.json().error.code, 'VALIDATION_ERROR');

  await app.close();
});

test('super admin can trigger a safe password reset flow for an active user', async () => {
  await resetData();

  const emailStub = createEmailStub();
  const app = buildApp({ emailService: emailStub.service });
  const targetEmail = `customer-reset-${Date.now()}@example.com`;
  const targetSession = await signupCommunitySession(app, targetEmail);
  const superAdminSession = await signupSuperAdminSession(
    app,
    `customer-reset-super-admin-${Date.now()}@example.com`
  );

  const passwordResetResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/users/${targetSession.userId}/send-password-reset`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(passwordResetResponse.statusCode, 200);
  assert.equal(passwordResetResponse.json().data.success, true);
  assert.equal(emailStub.sentEmails.length, 1);
  assert.equal(emailStub.sentEmails[0].to, targetEmail);

  const tokenRows = await pool.query(
    `SELECT token_hash, consumed_at
     FROM password_reset_tokens
     WHERE user_id = $1`,
    [targetSession.userId]
  );

  assert.equal(tokenRows.rowCount, 1);
  assert.equal(tokenRows.rows[0].token_hash, hashToken(emailStub.sentEmails[0].resetToken));
  assert.equal(tokenRows.rows[0].consumed_at, null);

  await app.close();
});

test('unapproved mosque stays hidden from public APIs but visible to its owner admin flow', async () => {
  await resetData();

  const app = buildApp();
  const adminSession = await signupAdminSession(
    app,
    `mosque-owner-admin-${Date.now()}@example.com`
  );
  const createdMosque = await createMosqueAsAdmin(app, adminSession.accessToken, {
    name: 'Owner Pending Mosque'
  });

  const listResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques?city=Bengaluru&search=Owner%20Pending&sort=recent'
  });

  assert.equal(listResponse.statusCode, 200);
  assert.equal(listResponse.json().data.items.length, 0);

  const nearbyResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/nearby?latitude=12.9716&longitude=77.5946&radius=5&limit=20'
  });

  assert.equal(nearbyResponse.statusCode, 200);
  assert.equal(nearbyResponse.json().data.items.length, 0);

  const publicDetailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${createdMosque.id}`
  });

  assert.equal(publicDetailResponse.statusCode, 404);

  const ownerMineResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/mine',
    headers: {
      authorization: `Bearer ${adminSession.accessToken}`
    }
  });

  assert.equal(ownerMineResponse.statusCode, 200);
  assert.equal(ownerMineResponse.json().data.items.length, 1);
  assert.equal(ownerMineResponse.json().data.items[0].id, createdMosque.id);
  assert.equal(ownerMineResponse.json().data.items[0].isVerified, false);

  const ownerDetailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${createdMosque.id}`,
    headers: {
      authorization: `Bearer ${adminSession.accessToken}`
    }
  });

  assert.equal(ownerDetailResponse.statusCode, 200);
  assert.equal(ownerDetailResponse.json().data.id, createdMosque.id);
  assert.equal(ownerDetailResponse.json().data.isVerified, false);
  assert.equal(ownerDetailResponse.json().data.canEdit, true);

  await app.close();
});

test('public mosque discovery keeps pending mosques hidden even if the legacy verification flag is stale', async () => {
  await resetData();

  const app = buildApp();
  const adminSession = await signupAdminSession(
    app,
    `mosque-pending-status-admin-${Date.now()}@example.com`
  );
  const createdMosque = await createMosqueAsAdmin(app, adminSession.accessToken, {
    name: 'Pending Status Hidden Mosque'
  });

  await pool.query(
    `UPDATE mosques
     SET is_verified = TRUE,
         moderation_status = 'pending'
     WHERE id = $1`,
    [createdMosque.id]
  );

  const listResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques?city=Bengaluru&search=Pending%20Status%20Hidden&sort=recent'
  });

  assert.equal(listResponse.statusCode, 200);
  assert.equal(listResponse.json().data.items.length, 0);

  const nearbyResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/nearby?latitude=12.9716&longitude=77.5946&radius=5&limit=20'
  });

  assert.equal(nearbyResponse.statusCode, 200);
  assert.equal(nearbyResponse.json().data.items.length, 0);

  const detailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${createdMosque.id}`
  });

  assert.equal(detailResponse.statusCode, 404);

  await app.close();
});

test('business listing draft save, update, and submit flow persists for the current user', async () => {
  await resetData();

  const app = buildApp();
  const session = await signupCommunitySession(
    app,
    `business-owner-${Date.now()}@example.com`
  );

  const initialDraft = {
    basicDetails: {
      businessName: 'Noor Catering',
      logo: {
        fileName: 'noor.png',
        contentType: 'image/png',
        bytesBase64: 'bm9vci1sb2dv',
        tileBackgroundColor: 4293512350
      },
      selectedType: {
        groupId: 'food',
        groupLabel: 'Halal Food',
        itemId: 'catering',
        itemLabel: 'Catering Services'
      },
      tagline: 'Trusted halal catering for family and community events.',
      description: 'We handle wedding catering, office lunches, and weekend dawat events.'
    },
    contactDetails: {
      businessEmail: 'hello@noorcatering.example',
      phone: '+91 9988776655',
      whatsapp: '+91 9988776655',
      instagramUrl: 'instagram.com/noorcatering',
      facebookUrl: 'facebook.com/noorcatering',
      websiteUrl: 'https://noorcatering.example',
      address: '12 Crescent Road',
      zipCode: '560001',
      city: 'Bengaluru',
      onlineOnly: false
    }
  };

  const createDraftResponse = await app.inject({
    method: 'PUT',
    url: '/api/v1/business-listings/draft',
    headers: {
      authorization: `Bearer ${session.accessToken}`,
      'content-type': 'application/json'
    },
    payload: initialDraft
  });

  assert.equal(createDraftResponse.statusCode, 201);
  assert.equal(createDraftResponse.json().data.listing.status, 'draft');
  assert.equal(
    createDraftResponse.json().data.listing.basicDetails.businessName,
    'Noor Catering'
  );
  assert.equal(
    createDraftResponse.json().data.listing.contactDetails.city,
    'Bengaluru'
  );
  assert.equal(createDraftResponse.json().data.listing.submittedAt, null);

  const updateDraftResponse = await app.inject({
    method: 'PUT',
    url: '/api/v1/business-listings/draft',
    headers: {
      authorization: `Bearer ${session.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      ...initialDraft,
      contactDetails: {
        ...initialDraft.contactDetails,
        openingTime: { hour: 9, minute: 0 },
        closingTime: { hour: 18, minute: 30 },
        city: 'Mysuru'
      }
    }
  });

  assert.equal(updateDraftResponse.statusCode, 200);
  assert.equal(updateDraftResponse.json().data.listing.status, 'draft');
  assert.equal(
    updateDraftResponse.json().data.listing.contactDetails.city,
    'Mysuru'
  );
  assert.deepEqual(
    updateDraftResponse.json().data.listing.contactDetails.openingTime,
    { hour: 9, minute: 0 }
  );

  const submitResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/business-listings/submit',
    headers: {
      authorization: `Bearer ${session.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      ...initialDraft,
      contactDetails: {
        ...initialDraft.contactDetails,
        openingTime: { hour: 9, minute: 0 },
        closingTime: { hour: 18, minute: 30 },
        city: 'Mysuru'
      }
    }
  });

  assert.equal(submitResponse.statusCode, 202);
  assert.equal(submitResponse.json().data.listing.status, 'under_review');
  assert.ok(submitResponse.json().data.listing.submittedAt);
  assert.equal(submitResponse.json().data.listing.contactDetails.city, 'Mysuru');

  const latestResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/business-listings/me',
    headers: {
      authorization: `Bearer ${session.accessToken}`
    }
  });

  assert.equal(latestResponse.statusCode, 200);
  assert.equal(latestResponse.json().data.listing.status, 'under_review');
  assert.equal(latestResponse.json().data.listing.basicDetails.businessName, 'Noor Catering');
  assert.equal(latestResponse.json().data.listing.contactDetails.city, 'Mysuru');

  const persistedListing = await pool.query(
    `SELECT
       status,
       business_name,
       city,
       submitted_at,
       published_at,
       category_group_label,
       category_item_label,
       basic_details,
       contact_details
     FROM business_listings
     WHERE user_id = $1`,
    [session.userId]
  );

  assert.equal(persistedListing.rowCount, 1);
  assert.equal(persistedListing.rows[0].status, 'under_review');
  assert.equal(persistedListing.rows[0].business_name, 'Noor Catering');
  assert.equal(persistedListing.rows[0].city, 'Mysuru');
  assert.ok(persistedListing.rows[0].submitted_at);
  assert.equal(persistedListing.rows[0].published_at, null);
  assert.equal(persistedListing.rows[0].category_group_label, 'Halal Food');
  assert.equal(persistedListing.rows[0].category_item_label, 'Catering Services');
  assert.equal(
    persistedListing.rows[0].basic_details.businessName,
    'Noor Catering'
  );
  assert.equal(
    persistedListing.rows[0].basic_details.selectedType.groupLabel,
    'Halal Food'
  );
  assert.equal(
    persistedListing.rows[0].basic_details.selectedType.itemLabel,
    'Catering Services'
  );
  assert.equal(
    persistedListing.rows[0].contact_details.city,
    'Mysuru'
  );

  await app.close();
});

test('business listing draft validation rejects malformed contact details', async () => {
  await resetData();

  const app = buildApp();
  const session = await signupCommunitySession(
    app,
    `business-invalid-${Date.now()}@example.com`
  );

  const response = await app.inject({
    method: 'PUT',
    url: '/api/v1/business-listings/draft',
    headers: {
      authorization: `Bearer ${session.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      basicDetails: {
        businessName: 'Draft With Errors'
      },
      contactDetails: {
        businessEmail: 'not-an-email',
        openingTime: { hour: 9, minute: 0 }
      }
    }
  });

  assert.equal(response.statusCode, 400);
  assert.equal(response.json().error.code, 'VALIDATION_ERROR');
  assert.ok(Array.isArray(response.json().error.details));
  assert.equal(response.json().error.details.length, 2);

  await app.close();
});

test('business listing submit validation requires a review-ready payload', async () => {
  await resetData();

  const app = buildApp();
  const session = await signupCommunitySession(
    app,
    `business-submit-invalid-${Date.now()}@example.com`
  );

  const response = await app.inject({
    method: 'POST',
    url: '/api/v1/business-listings/submit',
    headers: {
      authorization: `Bearer ${session.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      basicDetails: {
        businessName: 'Partial Listing'
      },
      contactDetails: {
        businessEmail: 'owner@example.com',
        phone: '+91 9988776655',
        onlineOnly: false
      }
    }
  });

  assert.equal(response.statusCode, 400);
  assert.equal(response.json().error.code, 'VALIDATION_ERROR');
  assert.ok(
    response.json().error.details.some(
      (issue) => issue.path.join('.') === 'basicDetails.logo'
    )
  );
  assert.ok(
    response.json().error.details.some(
      (issue) => issue.path.join('.') === 'contactDetails.openingTime'
    )
  );
  assert.ok(
    response.json().error.details.some(
      (issue) => issue.path.join('.') === 'contactDetails.address'
    )
  );

  await app.close();
});

test('super admin can list pending business listings and inspect one listing', async () => {
  await resetData();

  const app = buildApp();
  const submitterEmail = `business-reviewer-source-${Date.now()}@example.com`;
  const submitterSession = await signupCommunitySession(
    app,
    submitterEmail
  );
  const submittedListing = await submitBusinessListingForReview(app, submitterSession);
  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-super-admin-${Date.now()}@example.com`
  );

  const pendingResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/admin/business-listings/pending',
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(pendingResponse.statusCode, 200);
  assert.equal(pendingResponse.json().data.items.length, 1);
  assert.equal(pendingResponse.json().data.items[0].id, submittedListing.id);
  assert.equal(pendingResponse.json().data.items[0].status, 'under_review');
  assert.equal(
    pendingResponse.json().data.items[0].submitter.email,
    submitterEmail
  );

  const detailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/admin/business-listings/${submittedListing.id}`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(detailResponse.statusCode, 200);
  assert.equal(detailResponse.json().data.listing.id, submittedListing.id);
  assert.equal(
    detailResponse.json().data.listing.basicDetails.businessName,
    'Noor Catering'
  );

  await app.close();
});

test('non-super-admin users are forbidden from business listing moderation endpoints', async () => {
  await resetData();

  const app = buildApp();
  const submitterSession = await signupCommunitySession(
    app,
    `business-forbidden-user-${Date.now()}@example.com`
  );
  const listing = await submitBusinessListingForReview(app, submitterSession);
  const adminSession = await signupAdminSession(
    app,
    `business-forbidden-admin-${Date.now()}@example.com`
  );

  const pendingResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/admin/business-listings/pending',
    headers: {
      authorization: `Bearer ${adminSession.accessToken}`
    }
  });

  assert.equal(pendingResponse.statusCode, 403);
  assert.equal(pendingResponse.json().error.code, 'FORBIDDEN');

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/business-listings/${listing.id}/approve`,
    headers: {
      authorization: `Bearer ${adminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 403);
  assert.equal(approveResponse.json().error.code, 'FORBIDDEN');

  await app.close();
});

test('super admin can approve a business listing and publish it', async () => {
  await resetData();

  const app = buildApp();
  const submitterSession = await signupCommunitySession(
    app,
    `business-approve-user-${Date.now()}@example.com`
  );
  const listing = await submitBusinessListingForReview(app, submitterSession);
  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-approve-admin-${Date.now()}@example.com`
  );

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/business-listings/${listing.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);
  assert.equal(approveResponse.json().data.listing.status, 'live');
  assert.ok(approveResponse.json().data.listing.publishedAt);
  assert.equal(approveResponse.json().data.listing.reviewedBy, superAdminSession.userId);
  assert.ok(approveResponse.json().data.listing.reviewedAt);
  assert.equal(approveResponse.json().data.listing.rejectionReason, null);

  const persistedListing = await pool.query(
    `SELECT
       status,
       published_at,
       reviewed_by,
       reviewed_at,
       rejection_reason,
       category_group_label,
       category_item_label,
       basic_details
     FROM business_listings
     WHERE id = $1`,
    [listing.id]
  );

  assert.equal(persistedListing.rowCount, 1);
  assert.equal(persistedListing.rows[0].status, 'live');
  assert.ok(persistedListing.rows[0].published_at);
  assert.equal(persistedListing.rows[0].reviewed_by, superAdminSession.userId);
  assert.ok(persistedListing.rows[0].reviewed_at);
  assert.equal(persistedListing.rows[0].rejection_reason, null);
  assert.equal(persistedListing.rows[0].category_group_label, 'Halal Food');
  assert.equal(persistedListing.rows[0].category_item_label, 'Catering Services');
  assert.equal(
    persistedListing.rows[0].basic_details.selectedType.groupLabel,
    'Halal Food'
  );
  assert.equal(
    persistedListing.rows[0].basic_details.selectedType.itemLabel,
    'Catering Services'
  );

  const submitterMeResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/business-listings/me',
    headers: {
      authorization: `Bearer ${submitterSession.accessToken}`
    }
  });

  assert.equal(submitterMeResponse.statusCode, 200);
  assert.equal(submitterMeResponse.json().data.listing.status, 'live');
  assert.ok(submitterMeResponse.json().data.listing.publishedAt);
  assert.equal(submitterMeResponse.json().data.listing.rejectionReason, null);

  await app.close();
});

test('owner status payload stays aligned with public feed category fields when draft taxonomy diverges', async () => {
  await resetData();

  const app = buildApp();
  const submitterSession = await signupCommunitySession(
    app,
    `business-owner-status-category-${Date.now()}@example.com`
  );
  const listing = await submitBusinessListingForReview(
    app,
    submitterSession,
    {
      basicDetails: {
        businessName: 'Shifa Dental Care',
        selectedType: {
          groupId: 'health-wellness',
          groupLabel: 'Health & Wellness',
          itemId: 'dental-clinics',
          itemLabel: 'Dental Clinics'
        }
      }
    }
  );
  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-owner-status-category-admin-${Date.now()}@example.com`
  );

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/business-listings/${listing.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);

  await pool.query(
    `UPDATE business_listings
     SET category_group_id = $2,
         category_group_label = $3,
         category_item_id = $4,
         category_item_label = $5,
         basic_details = jsonb_set(
           jsonb_set(
             basic_details,
             '{selectedType,groupLabel}',
             to_jsonb($6::text),
             false
           ),
           '{selectedType,itemLabel}',
           to_jsonb($7::text),
           false
         )
     WHERE id = $1`,
    [
      listing.id,
      'health-wellness',
      'Health & Wellness',
      'dental-clinics',
      'Dental Clinics',
      'Halal Food & Restaurants',
      'Catering Services'
    ]
  );

  const ownerStatusResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/business-listings/me',
    headers: {
      authorization: `Bearer ${submitterSession.accessToken}`
    }
  });

  assert.equal(ownerStatusResponse.statusCode, 200);
  assert.equal(ownerStatusResponse.json().data.listing.status, 'live');
  assert.deepEqual(ownerStatusResponse.json().data.listing.publicCategory, {
    groupId: 'health-wellness',
    groupLabel: 'Health & Wellness',
    itemId: 'dental-clinics',
    itemLabel: 'Dental Clinics'
  });
  assert.equal(
    ownerStatusResponse.json().data.listing.basicDetails.selectedType.groupLabel,
    'Halal Food & Restaurants'
  );
  assert.equal(
    ownerStatusResponse.json().data.listing.basicDetails.selectedType.itemLabel,
    'Catering Services'
  );

  const healthFeedResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Health%20%26%20Wellness'
  });
  const foodFeedResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food%20%26%20Restaurants'
  });

  assert.equal(healthFeedResponse.statusCode, 200);
  assert.deepEqual(
    healthFeedResponse.json().data.services.map((service) => service.id),
    [listing.id]
  );
  assert.equal(foodFeedResponse.statusCode, 200);
  assert.deepEqual(foodFeedResponse.json().data.services, []);

  await app.close();
});

test('super admin can reject a business listing and store review metadata', async () => {
  await resetData();

  const app = buildApp();
  const submitterSession = await signupCommunitySession(
    app,
    `business-reject-user-${Date.now()}@example.com`
  );
  const listing = await submitBusinessListingForReview(app, submitterSession);
  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-reject-admin-${Date.now()}@example.com`
  );
  const rejectionReason = 'Please add clearer operating hours before resubmitting.';

  const rejectResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/business-listings/${listing.id}/reject`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      rejectionReason
    }
  });

  assert.equal(rejectResponse.statusCode, 200);
  assert.equal(rejectResponse.json().data.listing.status, 'rejected');
  assert.equal(rejectResponse.json().data.listing.publishedAt, null);
  assert.equal(rejectResponse.json().data.listing.reviewedBy, superAdminSession.userId);
  assert.ok(rejectResponse.json().data.listing.reviewedAt);
  assert.equal(rejectResponse.json().data.listing.rejectionReason, rejectionReason);

  const persistedListing = await pool.query(
    `SELECT status, published_at, reviewed_by, reviewed_at, rejection_reason
     FROM business_listings
     WHERE id = $1`,
    [listing.id]
  );

  assert.equal(persistedListing.rowCount, 1);
  assert.equal(persistedListing.rows[0].status, 'rejected');
  assert.equal(persistedListing.rows[0].published_at, null);
  assert.equal(persistedListing.rows[0].reviewed_by, superAdminSession.userId);
  assert.ok(persistedListing.rows[0].reviewed_at);
  assert.equal(persistedListing.rows[0].rejection_reason, rejectionReason);

  const submitterMeResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/business-listings/me',
    headers: {
      authorization: `Bearer ${submitterSession.accessToken}`
    }
  });

  assert.equal(submitterMeResponse.statusCode, 200);
  assert.equal(submitterMeResponse.json().data.listing.status, 'rejected');
  assert.equal(submitterMeResponse.json().data.listing.publishedAt, null);
  assert.equal(submitterMeResponse.json().data.listing.rejectionReason, rejectionReason);

  await app.close();
});

test('approved business listings appear in the public services feed for stored registration taxonomy labels and legacy aliases', async () => {
  await resetData();

  const app = buildApp();
  const submitterSession = await signupCommunitySession(
    app,
    `business-services-user-${Date.now()}@example.com`
  );
  const listing = await submitBusinessListingForReview(
    app,
    submitterSession,
    {
      basicDetails: {
        businessName: 'Fresh Tandoor',
        tagline: 'Live naan and catering for family gatherings.',
        description: 'Fresh Tandoor handles halal catering and daily meal orders.',
        selectedType: {
          groupId: 'food',
          groupLabel: 'Halal Food & Restaurants',
          itemId: 'catering',
          itemLabel: 'Catering Services'
        }
      },
      contactDetails: {
        city: 'Bengaluru',
        phone: '+91 9770011223',
        businessEmail: 'hello@freshtandoor.example',
        address: '88 Market Road',
        zipCode: '560001'
      }
    }
  );
  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-services-admin-${Date.now()}@example.com`
  );

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/business-listings/${listing.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);

  const taxonomyServicesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food%20%26%20Restaurants'
  });
  const legacyAliasServicesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food'
  });

  assert.equal(taxonomyServicesResponse.statusCode, 200);
  assert.equal(legacyAliasServicesResponse.statusCode, 200);

  const services = taxonomyServicesResponse.json().data.services;
  assert.ok(Array.isArray(services));
  assert.equal(services[0].id, listing.id);
  assert.equal(services.length, 1);
  assert.equal(services[0].logo.fileName, 'noor.png');
  assert.equal(services[0].logo.bytesBase64, 'bm9vci1sb2dv');
  assert.ok(
    services.some(
      (service) =>
        service.id === listing.id &&
        service.name === 'Fresh Tandoor' &&
        service.category === 'Halal Food & Restaurants' &&
        service.tags.includes('Halal Food & Restaurants') &&
        service.tags.includes('Catering Services')
    )
  );
  assert.deepEqual(
    legacyAliasServicesResponse.json().data.services.map((service) => service.id),
    [listing.id]
  );

  await app.close();
});

test('public services feed defaults to newest published live listings first without hiding older live listings', async () => {
  await resetData();

  const app = buildApp();
  const olderOwner = await signupCommunitySession(
    app,
    `business-services-new-default-older-${Date.now()}@example.com`
  );
  const newerOwner = await signupCommunitySession(
    app,
    `business-services-new-default-newer-${Date.now()}@example.com`
  );

  const olderListing = await submitBusinessListingForReview(app, olderOwner, {
    basicDetails: {
      businessName: 'Older Listing'
    }
  });
  const newerListing = await submitBusinessListingForReview(app, newerOwner, {
    basicDetails: {
      businessName: 'Newer Listing'
    }
  });

  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-services-new-default-admin-${Date.now()}@example.com`
  );

  for (const listingId of [olderListing.id, newerListing.id]) {
    const approveResponse = await app.inject({
      method: 'POST',
      url: `/api/v1/admin/business-listings/${listingId}/approve`,
      headers: {
        authorization: `Bearer ${superAdminSession.accessToken}`
      }
    });

    assert.equal(approveResponse.statusCode, 200);
  }

  await pool.query(
    `UPDATE business_listings
     SET published_at = $2
     WHERE id = $1`,
    [olderListing.id, '2026-04-01T10:00:00.000Z']
  );
  await pool.query(
    `UPDATE business_listings
     SET published_at = $2
     WHERE id = $1`,
    [newerListing.id, '2026-04-09T10:00:00.000Z']
  );

  const defaultResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food'
  });

  assert.equal(defaultResponse.statusCode, 200);
  assert.deepEqual(
    defaultResponse.json().data.services.map((service) => service.id),
    [newerListing.id, olderListing.id]
  );

  const explicitNewResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food&sort=new'
  });

  assert.equal(explicitNewResponse.statusCode, 200);
  assert.deepEqual(
    explicitNewResponse.json().data.services.map((service) => service.id),
    [newerListing.id, olderListing.id]
  );

  await app.close();
});

test('business listing reviews create, load, and roll up into the public services feed', async () => {
  await resetData();

  const app = buildApp();
  const ownerSession = await signupCommunitySession(
    app,
    `business-review-owner-${Date.now()}@example.com`
  );
  const reviewerSession = await signupCommunitySession(
    app,
    `business-review-user-${Date.now()}@example.com`
  );
  const listing = await submitBusinessListingForReview(app, ownerSession, {
    basicDetails: {
      businessName: 'Reviewable Listing'
    }
  });
  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-review-admin-${Date.now()}@example.com`
  );

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/business-listings/${listing.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);

  const reviewResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/business-listings/${listing.id}/reviews`,
    headers: {
      authorization: `Bearer ${reviewerSession.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      rating: 5,
      comments: 'Welcoming team and clear service options.'
    }
  });

  assert.equal(reviewResponse.statusCode, 201);
  assert.equal(reviewResponse.json().data.businessListingId, listing.id);
  assert.equal(reviewResponse.json().data.rating, 5);

  const reviewsResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/business-listings/${listing.id}/reviews`
  });

  assert.equal(reviewsResponse.statusCode, 200);
  assert.equal(reviewsResponse.json().data.items.length, 1);
  assert.equal(reviewsResponse.json().data.items[0].comment, 'Welcoming team and clear service options.');
  assert.equal(reviewsResponse.json().data.summary.totalReviews, 1);
  assert.equal(reviewsResponse.json().data.summary.averageRating, 5);

  const servicesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food'
  });

  assert.equal(servicesResponse.statusCode, 200);
  assert.equal(servicesResponse.json().data.services[0].id, listing.id);
  assert.equal(servicesResponse.json().data.services[0].reviewCount, 1);
  assert.equal(servicesResponse.json().data.services[0].rating, 5);

  const duplicateReviewResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/business-listings/${listing.id}/reviews`,
    headers: {
      authorization: `Bearer ${reviewerSession.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      rating: 4,
      comments: 'Second review should fail.'
    }
  });

  assert.equal(duplicateReviewResponse.statusCode, 409);
  assert.equal(duplicateReviewResponse.json().error.code, 'REVIEW_ALREADY_EXISTS');

  await app.close();
});

test('supported live listings map into the correct public services category across multiple real registration categories', async () => {
  await resetData();

  const app = buildApp();
  const halalSubmitterSession = await signupCommunitySession(
    app,
    `business-services-halal-${Date.now()}@example.com`
  );
  const booksSubmitterSession = await signupCommunitySession(
    app,
    `business-services-books-${Date.now()}@example.com`
  );

  const halalListing = await submitBusinessListingForReview(
    app,
    halalSubmitterSession,
    {
      basicDetails: {
        businessName: 'Weekend Dastarkhwan',
        selectedType: {
          groupId: 'food',
          groupLabel: 'Halal Food & Restaurants',
          itemId: 'restaurants-cafes',
          itemLabel: 'Restaurants & Cafes'
        }
      }
    }
  );
  const booksListing = await submitBusinessListingForReview(
    app,
    booksSubmitterSession,
    {
      basicDetails: {
        businessName: 'Wardah Stationery',
        selectedType: {
          groupId: 'islamic-ecommerce-retail',
          groupLabel: 'Islamic E-commerce & Retail',
          itemId: 'books-stationery',
          itemLabel: 'Books & Stationery'
        }
      }
    }
  );
  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-services-multi-admin-${Date.now()}@example.com`
  );

  for (const listingId of [halalListing.id, booksListing.id]) {
    const approveResponse = await app.inject({
      method: 'POST',
      url: `/api/v1/admin/business-listings/${listingId}/approve`,
      headers: {
        authorization: `Bearer ${superAdminSession.accessToken}`
      }
    });

    assert.equal(approveResponse.statusCode, 200);
  }

  const halalFeedResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food'
  });
  const booksFeedResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Islamic%20E-commerce%20%26%20Retail'
  });

  assert.equal(halalFeedResponse.statusCode, 200);
  assert.equal(booksFeedResponse.statusCode, 200);

  const halalServices = halalFeedResponse.json().data.services;
  const bookServices = booksFeedResponse.json().data.services;

  assert.ok(halalServices.some((service) => service.id === halalListing.id));
  assert.equal(halalServices.some((service) => service.id === booksListing.id), false);

  assert.ok(bookServices.some((service) => service.id === booksListing.id));
  assert.equal(bookServices.some((service) => service.id === halalListing.id), false);
  assert.ok(
    bookServices.some(
      (service) =>
        service.id === booksListing.id &&
        service.category === 'Islamic E-commerce & Retail' &&
        service.tags.includes('Islamic E-commerce & Retail') &&
        service.tags.includes('Books & Stationery')
    )
  );

  await app.close();
});

test('public services feed only shows live business listings and keeps top-rated filtering scoped to rated results', async () => {
  await resetData();

  const app = buildApp();
  const submitterSession = await signupCommunitySession(
    app,
    `business-services-visibility-${Date.now()}@example.com`
  );

  const draftResponse = await app.inject({
    method: 'PUT',
    url: '/api/v1/business-listings/draft',
    headers: {
      authorization: `Bearer ${submitterSession.accessToken}`,
      'content-type': 'application/json'
    },
    payload: buildBusinessListingPayload({
      basicDetails: {
        businessName: 'Alias Kitchen',
        selectedType: {
          groupId: 'food',
          groupLabel: 'Halal Food & Restaurants',
          itemId: 'catering',
          itemLabel: 'Catering Services'
        }
      }
    })
  });

  assert.equal(draftResponse.statusCode, 201);
  const draftListingId = draftResponse.json().data.listing.id;

  const draftServicesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food'
  });

  assert.equal(draftServicesResponse.statusCode, 200);
  assert.deepEqual(draftServicesResponse.json().data.services, []);

  const underReviewListing = await submitBusinessListingForReview(
    app,
    submitterSession,
    {
      basicDetails: {
        businessName: 'Alias Kitchen',
        selectedType: {
          groupId: 'food',
          groupLabel: 'Halal Food & Restaurants',
          itemId: 'catering',
          itemLabel: 'Catering Services'
        }
      }
    }
  );

  const underReviewServicesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food'
  });

  assert.equal(underReviewServicesResponse.statusCode, 200);
  assert.deepEqual(underReviewServicesResponse.json().data.services, []);

  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-services-visibility-admin-${Date.now()}@example.com`
  );
  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/business-listings/${underReviewListing.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);

  const filteredServicesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food&filters=Top%20Rated'
  });

  assert.equal(filteredServicesResponse.statusCode, 200);
  assert.deepEqual(filteredServicesResponse.json().data.services, []);

  const liveServicesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food'
  });

  assert.equal(liveServicesResponse.statusCode, 200);
  assert.deepEqual(
    liveServicesResponse.json().data.services.map((service) => service.id),
    [underReviewListing.id]
  );

  await app.close();
});

test('approved live business listings in other registration categories stay discoverable through the public services feed', async () => {
  await resetData();

  const app = buildApp();
  const submitterSession = await signupCommunitySession(
    app,
    `business-services-health-${Date.now()}@example.com`
  );
  const listing = await submitBusinessListingForReview(
    app,
    submitterSession,
    {
      basicDetails: {
        businessName: 'Shifa Dental Care',
        selectedType: {
          groupId: 'health-wellness',
          groupLabel: 'Health & Wellness',
          itemId: 'dental-clinics',
          itemLabel: 'Dental Clinics'
        }
      }
    }
  );
  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-services-health-admin-${Date.now()}@example.com`
  );

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/business-listings/${listing.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);

  const healthFeedResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Health%20%26%20Wellness'
  });
  const itemFeedResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Dental%20Clinics'
  });

  assert.equal(healthFeedResponse.statusCode, 200);
  assert.equal(itemFeedResponse.statusCode, 200);
  assert.deepEqual(
    healthFeedResponse.json().data.services.map((service) => service.id),
    [listing.id]
  );
  assert.deepEqual(
    itemFeedResponse.json().data.services.map((service) => service.id),
    [listing.id]
  );
  assert.equal(
    healthFeedResponse.json().data.services[0].category,
    'Health & Wellness'
  );

  await app.close();
});

test('public services feed falls back to selectedType labels when legacy denormalized category columns are empty', async () => {
  await resetData();

  const app = buildApp();
  const submitterSession = await signupCommunitySession(
    app,
    `business-services-fallback-${Date.now()}@example.com`
  );
  const listing = await submitBusinessListingForReview(
    app,
    submitterSession,
    {
      basicDetails: {
        businessName: 'Noor Smile Clinic',
        selectedType: {
          groupId: 'health-wellness',
          groupLabel: 'Health & Wellness',
          itemId: 'dental-clinics',
          itemLabel: 'Dental Clinics'
        }
      }
    }
  );
  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-services-fallback-admin-${Date.now()}@example.com`
  );

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/business-listings/${listing.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);

  await pool.query(
    `UPDATE business_listings
     SET category_group_label = NULL,
         category_item_label = NULL
     WHERE id = $1`,
    [listing.id]
  );

  const servicesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Health%20%26%20Wellness'
  });

  assert.equal(servicesResponse.statusCode, 200);
  assert.deepEqual(
    servicesResponse.json().data.services.map((service) => service.id),
    [listing.id]
  );

  await app.close();
});

test('public services feed labels live results from the stored approved category fields', async () => {
  await resetData();

  const app = buildApp();
  const submitterSession = await signupCommunitySession(
    app,
    `business-services-approved-category-${Date.now()}@example.com`
  );
  const listing = await submitBusinessListingForReview(
    app,
    submitterSession,
    {
      basicDetails: {
        businessName: 'Shifa Dental Care',
        selectedType: {
          groupId: 'health-wellness',
          groupLabel: 'Health & Wellness',
          itemId: 'dental-clinics',
          itemLabel: 'Dental Clinics'
        }
      }
    }
  );
  const superAdminSession = await signupSuperAdminSession(
    app,
    `business-services-approved-category-admin-${Date.now()}@example.com`
  );

  const approveResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/admin/business-listings/${listing.id}/approve`,
    headers: {
      authorization: `Bearer ${superAdminSession.accessToken}`
    }
  });

  assert.equal(approveResponse.statusCode, 200);

  await pool.query(
    `UPDATE business_listings
     SET basic_details = jsonb_set(
       jsonb_set(
         basic_details,
         '{selectedType,groupLabel}',
         to_jsonb($2::text),
         false
       ),
       '{selectedType,itemLabel}',
       to_jsonb($3::text),
       false
     )
     WHERE id = $1`,
    [listing.id, 'Halal Food & Restaurants', 'Catering Services']
  );

  const servicesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Health%20%26%20Wellness'
  });

  assert.equal(servicesResponse.statusCode, 200);
  assert.deepEqual(
    servicesResponse.json().data.services.map((service) => service.id),
    [listing.id]
  );
  assert.equal(
    servicesResponse.json().data.services[0].category,
    'Health & Wellness'
  );
  assert.ok(
    servicesResponse.json().data.services[0].tags.includes('Health & Wellness')
  );
  assert.ok(
    servicesResponse.json().data.services[0].tags.includes('Dental Clinics')
  );
  assert.equal(
    servicesResponse.json().data.services[0].tags.includes('Halal Food & Restaurants'),
    false
  );

  await app.close();
});

test('migration 013 only backfills missing approved category fields and preserves non-empty values', async () => {
  await resetData();

  const app = buildApp();
  const submitterSession = await signupCommunitySession(
    app,
    `business-category-migration-${Date.now()}@example.com`
  );
  const listing = await submitBusinessListingForReview(app, submitterSession);

  await pool.query(
    `UPDATE business_listings
     SET category_group_id = NULL,
         category_group_label = $2,
         category_item_id = NULL,
         category_item_label = $3,
         basic_details = jsonb_set(
           jsonb_set(
             jsonb_set(
               jsonb_set(
                 basic_details,
                 '{selectedType,groupId}',
                 to_jsonb($4::text),
                 false
               ),
               '{selectedType,groupLabel}',
               to_jsonb($5::text),
               false
             ),
             '{selectedType,itemId}',
             to_jsonb($6::text),
             false
           ),
           '{selectedType,itemLabel}',
           to_jsonb($7::text),
           false
         )
     WHERE id = $1`,
    [
      listing.id,
      'Approved Health Category',
      'Approved Dental Category',
      'draft-food',
      'Draft Food Category',
      'draft-catering',
      'Draft Catering Category'
    ]
  );

  await runMigration013BackfillBusinessListingCategoryFields();

  const persistedListing = await pool.query(
    `SELECT
       category_group_id,
       category_group_label,
       category_item_id,
       category_item_label
     FROM business_listings
     WHERE id = $1`,
    [listing.id]
  );

  assert.equal(persistedListing.rowCount, 1);
  assert.equal(persistedListing.rows[0].category_group_id, 'draft-food');
  assert.equal(
    persistedListing.rows[0].category_group_label,
    'Approved Health Category'
  );
  assert.equal(persistedListing.rows[0].category_item_id, 'draft-catering');
  assert.equal(
    persistedListing.rows[0].category_item_label,
    'Approved Dental Category'
  );

  await app.close();
});

test('admin mosque image upload stores a local file and returns a usable image URL', async () => {
  await resetData();

  const app = buildApp();
  const adminEmail = `upload-admin-${Date.now()}@example.com`;
  const accessToken = await signupAndPromoteAdmin(app, adminEmail);
  const { boundary, payload } = buildMultipartImagePayload();

  const uploadResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/mosques/upload-image',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': `multipart/form-data; boundary=${boundary}`
    },
    payload
  });

  assert.equal(uploadResponse.statusCode, 201);
  const uploaded = uploadResponse.json().data;
  assert.match(uploaded.imageUrl, /^http:\/\/.+\/uploads\/mosques\/.+\.(png|jpg|jpeg|webp)$/);
  assert.match(uploaded.imagePath, /^\/uploads\/mosques\/.+\.(png|jpg|jpeg|webp)$/);

  const storedFilePath = path.join(__dirname, '..', uploaded.imagePath.replace(/^\//, ''));
  await fs.access(storedFilePath);
  await fs.rm(storedFilePath, { force: true });

  await app.close();
});

test('admin mosque image upload rejects non-image files', async () => {
  await resetData();

  const app = buildApp();
  const adminEmail = `upload-invalid-${Date.now()}@example.com`;
  const accessToken = await signupAndPromoteAdmin(app, adminEmail);
  const { boundary, payload } = buildMultipartImagePayload({
    fileName: 'notes.pdf',
    contentType: 'application/pdf',
    bytes: Buffer.from('%PDF-1.4')
  });

  const uploadResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/mosques/upload-image',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': `multipart/form-data; boundary=${boundary}`
    },
    payload
  });

  assert.equal(uploadResponse.statusCode, 400);
  assert.equal(uploadResponse.json().error.code, 'INVALID_UPLOAD_FILE');

  await app.close();
});

test('admin mosque update flow persists detail and page content changes', async () => {
  await resetData();

  const app = buildApp();
  const ownerSession = await signupAdminSession(
    app,
    `editor-${Date.now()}@example.com`
  );
  const mosqueId = await seedMosque({ createdByUserId: ownerSession.userId });
  await seedMosquePageContent(mosqueId);

  const updateResponse = await app.inject({
    method: 'PUT',
    url: `/api/v1/mosques/${mosqueId}`,
    headers: {
      authorization: `Bearer ${ownerSession.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      name: 'Updated Integration Mosque',
      addressLine: '88 Mercy Road',
      city: 'Bengaluru',
      state: 'Karnataka',
      country: 'India',
      postalCode: '560002',
      latitude: 12.9716,
      longitude: 77.5946,
      contactName: 'Amina Yusuf',
      contactPhone: '+91-9988776655',
      contactEmail: 'connect@example.org',
      websiteUrl: 'https://updated.example.org',
      imageUrl: 'https://updated.example.org/mosque.jpg',
      imageUrls: [
        'https://updated.example.org/mosque.jpg',
        'https://updated.example.org/mosque-2.jpg'
      ],
      sect: 'Community',
      duhrTime: '01:20 PM',
      asrTime: '04:50 PM',
      facilities: ['parking', 'wheelchair', 'wudu'],
      content: {
        about: {
          title: 'About Updated Integration Mosque',
          body: 'Freshly updated community-facing content for the mosque page.'
        },
        events: [
          {
            title: 'Updated Family Night',
            schedule: 'Fri 7 PM',
            posterLabel: 'Family',
            location: 'Prayer Hall',
            description: 'Updated event details for the mosque page.'
          }
        ],
        classes: [
          {
            title: 'Updated Tafsir Circle',
            schedule: 'Wed 8 PM',
            posterLabel: 'Tafsir'
          }
        ],
        connect: [
          {
            type: 'instagram',
            label: 'instagram.com/updatedmosque',
            value: 'instagram.com/updatedmosque'
          },
          {
            type: 'website',
            value: 'https://updated.example.org'
          }
        ]
      }
    }
  });

  assert.equal(updateResponse.statusCode, 200);
  assert.equal(updateResponse.json().data.mosque.name, 'Updated Integration Mosque');
  assert.equal(updateResponse.json().data.mosque.duhrTime, '01:20 PM');
  assert.deepEqual(updateResponse.json().data.mosque.imageUrls, [
    'https://updated.example.org/mosque.jpg',
    'https://updated.example.org/mosque-2.jpg'
  ]);
  assert.deepEqual(updateResponse.json().data.mosque.facilities, ['parking', 'wheelchair', 'wudu']);
  assert.equal(updateResponse.json().data.content.events[0].title, 'Updated Family Night');
  assert.equal(updateResponse.json().data.content.events[0].location, 'Prayer Hall');
  assert.equal(updateResponse.json().data.content.classes[0].title, 'Updated Tafsir Circle');
  assert.equal(updateResponse.json().data.content.connect.length, 4);
  assert.equal(updateResponse.json().data.content.about.title, 'About Updated Integration Mosque');

  const detailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}`,
    headers: {
      authorization: `Bearer ${ownerSession.accessToken}`
    }
  });

  assert.equal(detailResponse.statusCode, 200);
  assert.equal(detailResponse.json().data.name, 'Updated Integration Mosque');
  assert.equal(detailResponse.json().data.contactPhone, '+91-9988776655');
  assert.equal(detailResponse.json().data.canEdit, true);
  assert.deepEqual(detailResponse.json().data.imageUrls, [
    'https://updated.example.org/mosque.jpg',
    'https://updated.example.org/mosque-2.jpg'
  ]);

  const contentResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}/content`
  });

  assert.equal(contentResponse.statusCode, 200);
  assert.equal(contentResponse.json().data.events[0].title, 'Updated Family Night');
  assert.equal(
    contentResponse.json().data.events[0].description,
    'Updated event details for the mosque page.'
  );
  assert.equal(contentResponse.json().data.classes[0].title, 'Updated Tafsir Circle');
  assert.equal(contentResponse.json().data.connect.length, 4);
  assert.equal(
    contentResponse.json().data.about.body,
    'Freshly updated community-facing content for the mosque page.'
  );

  await app.close();
});

test('admin mosque broadcast publish and remove flow persists through the existing read route', async () => {
  await resetData();

  const app = buildApp();
  const ownerSession = await signupAdminSession(
    app,
    `broadcast-admin-${Date.now()}@example.com`
  );
  const mosqueId = await seedMosque({ createdByUserId: ownerSession.userId });

  const publishResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/mosques/${mosqueId}/broadcasts`,
    headers: {
      authorization: `Bearer ${ownerSession.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      title: 'Jummah Parking Update',
      message: 'Overflow parking volunteers will guide arrivals from 12:15 PM this Friday.'
    }
  });

  assert.equal(publishResponse.statusCode, 201);
  assert.equal(publishResponse.json().data.title, 'Jummah Parking Update');
  assert.equal(
    publishResponse.json().data.description,
    'Overflow parking volunteers will guide arrivals from 12:15 PM this Friday.'
  );
  assert.ok(publishResponse.json().data.id);
  assert.ok(publishResponse.json().data.publishedAt);

  const broadcastId = publishResponse.json().data.id;

  const readResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}/broadcasts`
  });

  assert.equal(readResponse.statusCode, 200);
  assert.equal(readResponse.json().data.items.length, 1);
  assert.equal(readResponse.json().data.items[0].id, broadcastId);
  assert.equal(readResponse.json().data.items[0].title, 'Jummah Parking Update');

  const deleteResponse = await app.inject({
    method: 'DELETE',
    url: `/api/v1/mosques/${mosqueId}/broadcasts/${broadcastId}`,
    headers: {
      authorization: `Bearer ${ownerSession.accessToken}`
    }
  });

  assert.equal(deleteResponse.statusCode, 200);
  assert.equal(deleteResponse.json().data.success, true);

  const readAfterDeleteResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}/broadcasts`
  });

  assert.equal(readAfterDeleteResponse.statusCode, 200);
  assert.equal(readAfterDeleteResponse.json().data.items.length, 0);

  await app.close();
});

test('non-owner admins get 403 for mosque update and broadcast writes', async () => {
  await resetData();

  const app = buildApp();
  const ownerSession = await signupAdminSession(
    app,
    `owner-${Date.now()}@example.com`
  );
  const otherAdminToken = await signupAndPromoteAdmin(
    app,
    `other-${Date.now()}@example.com`
  );
  const mosqueId = await seedMosque({ createdByUserId: ownerSession.userId });
  await seedMosquePageContent(mosqueId);

  const deniedUpdateResponse = await app.inject({
    method: 'PUT',
    url: `/api/v1/mosques/${mosqueId}`,
    headers: {
      authorization: `Bearer ${otherAdminToken}`,
      'content-type': 'application/json'
    },
    payload: {
      name: 'Hijacked Mosque',
      addressLine: '15 Unity Street',
      city: 'Bengaluru',
      state: 'Karnataka',
      country: 'India',
      latitude: 12.9716,
      longitude: 77.5946,
      facilities: ['parking'],
      content: {
        about: {
          title: 'Hijacked',
          body: 'This should be blocked.'
        },
        events: [
          {
            title: 'Unauthorized Event',
            schedule: 'Fri 7 PM',
            posterLabel: 'Event'
          }
        ],
        classes: [],
        connect: []
      }
    }
  });

  assert.equal(deniedUpdateResponse.statusCode, 403);
  assert.equal(deniedUpdateResponse.json().error.code, 'FORBIDDEN');

  const deniedBroadcastPublishResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/mosques/${mosqueId}/broadcasts`,
    headers: {
      authorization: `Bearer ${otherAdminToken}`,
      'content-type': 'application/json'
    },
    payload: {
      title: 'Unauthorized Broadcast',
      message: 'This should be blocked.'
    }
  });

  assert.equal(deniedBroadcastPublishResponse.statusCode, 403);
  assert.equal(deniedBroadcastPublishResponse.json().error.code, 'FORBIDDEN');

  const ownerBroadcastResponse = await app.inject({
    method: 'POST',
    url: `/api/v1/mosques/${mosqueId}/broadcasts`,
    headers: {
      authorization: `Bearer ${ownerSession.accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      title: 'Owner Broadcast',
      message: 'Owner-published message.'
    }
  });

  assert.equal(ownerBroadcastResponse.statusCode, 201);
  const broadcastId = ownerBroadcastResponse.json().data.id;

  const deniedBroadcastDeleteResponse = await app.inject({
    method: 'DELETE',
    url: `/api/v1/mosques/${mosqueId}/broadcasts/${broadcastId}`,
    headers: {
      authorization: `Bearer ${otherAdminToken}`
    }
  });

  assert.equal(deniedBroadcastDeleteResponse.statusCode, 403);
  assert.equal(deniedBroadcastDeleteResponse.json().error.code, 'FORBIDDEN');

  const ownerMineResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/mine',
    headers: {
      authorization: `Bearer ${ownerSession.accessToken}`
    }
  });

  assert.equal(ownerMineResponse.statusCode, 200);
  assert.equal(ownerMineResponse.json().data.items.length, 1);
  assert.equal(ownerMineResponse.json().data.items[0].id, mosqueId);

  const otherMineResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/mine',
    headers: {
      authorization: `Bearer ${otherAdminToken}`
    }
  });

  assert.equal(otherMineResponse.statusCode, 200);
  assert.equal(otherMineResponse.json().data.items.length, 0);

  await app.close();
});

test('mosque prayer times route returns backend-owned live timings and caches them', async () => {
  await resetData();

  const mosqueId = await seedMosque();
  await seedPrayerTimeConfig(mosqueId, {
    calculationMethod: 3,
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

  let upstreamCalls = 0;
  const app = buildApp({
    prayerTimeService: createPrayerTimeService({
      db: pool,
      now: () => new Date('2026-03-30T10:30:00.000Z'),
      alAdhanClient: {
        async getDailyTimings() {
          upstreamCalls += 1;
          return {
            timezone: 'UTC',
            calculationMethodName: 'Muslim World League',
            timings: {
              fajr: { clockValue: '05:08', display: '05:08 AM' },
              sunrise: { clockValue: '06:18', display: '06:18 AM' },
              dhuhr: { clockValue: '12:31', display: '12:31 PM' },
              asr: { clockValue: '16:02', display: '04:02 PM' },
              maghrib: { clockValue: '06:41', display: '06:41 PM' },
              isha: { clockValue: '07:55', display: '07:55 PM' }
            }
          };
        }
      }
    })
  });

  const firstResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}/prayer-times?date=2026-03-30`
  });

  assert.equal(firstResponse.statusCode, 200);
  assert.equal(firstResponse.json().data.status, 'ready');
  assert.equal(firstResponse.json().data.source, 'aladhan');
  assert.equal(firstResponse.json().data.timings.dhuhr, '12:31 PM');
  assert.equal(firstResponse.json().data.configuration.calculationMethod.id, 3);
  assert.equal(firstResponse.json().data.configuration.school.value, 'hanafi');
  assert.equal(firstResponse.json().data.configuration.adjustments.dhuhr, 2);
  assert.equal(upstreamCalls, 1);

  const cachedResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}/prayer-times?date=2026-03-30`
  });

  assert.equal(cachedResponse.statusCode, 200);
  assert.equal(cachedResponse.json().data.source, 'cache');
  assert.equal(cachedResponse.json().data.timings.asr, '04:02 PM');
  assert.equal(upstreamCalls, 1);

  const detailResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}`
  });

  assert.equal(detailResponse.statusCode, 200);
  assert.equal(detailResponse.json().data.duhrTime, '12:31 PM');
  assert.equal(detailResponse.json().data.asrTime, '04:02 PM');

  await app.close();
});

test('review submission and mosque notification settings flow', async () => {
  await resetData();

  const mosqueId = await seedMosque();
  await seedBroadcastMessages(mosqueId);
  await seedMosquePageContent(mosqueId);
  const app = buildApp();

  const signupResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/auth/signup',
    headers: {
      'content-type': 'application/json'
    },
    payload: {
      fullName: 'Settings User',
      email: `settings-${Date.now()}@example.com`,
      password: 'StrongPass@123'
    }
  });

  const { accessToken } = signupResponse.json().data.tokens;

  const reviewResponse = await app.inject({
    method: 'POST',
    url: '/api/v1/mosques/review',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      mosqueId,
      rating: 5,
      comments: 'Warm welcome and clear prayer announcements.'
    }
  });

  assert.equal(reviewResponse.statusCode, 201);
  assert.equal(reviewResponse.json().data.mosqueId, mosqueId);
  assert.equal(reviewResponse.json().data.rating, 5);

  const reviewsResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}/reviews`
  });

  assert.equal(reviewsResponse.statusCode, 200);
  assert.equal(reviewsResponse.json().data.items.length, 1);
  assert.equal(reviewsResponse.json().data.items[0].userName, 'Settings User');
  assert.equal(reviewsResponse.json().data.summary.totalReviews, 1);
  assert.equal(reviewsResponse.json().data.summary.averageRating, 5);

  const broadcastResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}/broadcasts`
  });

  assert.equal(broadcastResponse.statusCode, 200);
  assert.equal(broadcastResponse.json().data.items.length, 2);
  assert.equal(broadcastResponse.json().data.items[0].title, 'Jummah Parking Update');

  const contentResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/mosques/${mosqueId}/content`
  });

  assert.equal(contentResponse.statusCode, 200);
  assert.equal(contentResponse.json().data.events.length, 2);
  assert.equal(contentResponse.json().data.events[0].title, 'Weekend Family Night');
  assert.equal(contentResponse.json().data.classes.length, 1);
  assert.equal(contentResponse.json().data.connect.length, 1);
  assert.equal(contentResponse.json().data.about.title, 'About Integration Mosque');

  const notificationResponse = await app.inject({
    method: 'PUT',
    url: '/api/v1/notifications/settings',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      mosqueId,
      settings: [
        {
          title: 'Broadcast Messages',
          description: 'Important community updates',
          isEnabled: true
        },
        {
          title: 'Events & Class Updates',
          description: 'Show new events and classes from this mosque',
          isEnabled: false
        }
      ]
    }
  });

  assert.equal(notificationResponse.statusCode, 200);
  assert.equal(notificationResponse.json().data.success, true);
  assert.equal(notificationResponse.json().data.settings.length, 2);

  const notificationReadResponse = await app.inject({
    method: 'GET',
    url: `/api/v1/notifications/settings?mosqueId=${mosqueId}`,
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });

  assert.equal(notificationReadResponse.statusCode, 200);
  assert.equal(notificationReadResponse.json().data.mosqueId, mosqueId);
  assert.equal(notificationReadResponse.json().data.settings.length, 2);
  assert.equal(notificationReadResponse.json().data.settings[0].title, 'Broadcast Messages');
  assert.equal(notificationReadResponse.json().data.settings[0].isEnabled, true);
  assert.equal(notificationReadResponse.json().data.settings[1].title, 'Events & Class Updates');
  assert.equal(notificationReadResponse.json().data.settings[1].isEnabled, false);

  const notificationMosquesResponse = await app.inject({
    method: 'GET',
    url: '/api/v1/notifications/mosques',
    headers: {
      authorization: `Bearer ${accessToken}`
    }
  });

  assert.equal(notificationMosquesResponse.statusCode, 200);
  assert.equal(notificationMosquesResponse.json().data.items.length, 1);
  assert.equal(notificationMosquesResponse.json().data.items[0].id, mosqueId);

  const unsupportedNotificationResponse = await app.inject({
    method: 'PUT',
    url: '/api/v1/notifications/settings',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json'
    },
    payload: {
      mosqueId,
      settings: [
        {
          title: 'Iqamah Time Reminders',
          description: 'Legacy reminder copy should not be accepted for launch.',
          isEnabled: true
        }
      ]
    }
  });

  assert.equal(unsupportedNotificationResponse.statusCode, 400);
  assert.equal(unsupportedNotificationResponse.json().error.code, 'VALIDATION_ERROR');

  await app.close();
});

test.after(async () => {
  await resetData();
  await pool.end();
});
