import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createEmailService,
  EmailConfigurationError,
  EmailDeliveryError,
  ResendEmailProvider
} from '../src/services/email/index.js';

test('email service builds a Flutter web hash-route reset URL', () => {
  const service = createEmailService({
    provider: {
      isConfigured: true,
      async send() {
        return { id: 'email-1' };
      }
    },
    fromAddress: 'Believers Lens <no-reply@example.com>',
    passwordResetBaseUrl: 'https://app.example.com/#/reset-password',
    passwordResetTtlMinutes: 60
  });

  assert.equal(
    service.buildPasswordResetUrl('token-123'),
    'https://app.example.com/#/reset-password?token=token-123'
  );
});

test('email service rejects password reset sends when required config is missing', async () => {
  const service = createEmailService({
    provider: {
      isConfigured: false,
      async send() {
        return { id: 'email-1' };
      }
    },
    fromAddress: '',
    passwordResetBaseUrl: null,
    passwordResetTtlMinutes: 60
  });

  await assert.rejects(
    () =>
      service.sendPasswordResetEmail({
        to: 'user@example.com',
        fullName: 'User',
        resetToken: 'token-123'
      }),
    EmailConfigurationError
  );
});

test('email service sends a lightweight admin-aware welcome email', async () => {
  const sent = [];
  const service = createEmailService({
    provider: {
      isConfigured: true,
      async send(payload) {
        sent.push(payload);
        return { id: 'email-2' };
      }
    },
    fromAddress: 'Believers Lens <no-reply@example.com>',
    replyToAddress: 'support@example.com'
  });

  const result = await service.sendWelcomeEmail({
    to: 'admin@example.com',
    fullName: 'Amina Yusuf',
    role: 'admin'
  });

  assert.equal(result.id, 'email-2');
  assert.equal(sent.length, 1);
  assert.equal(sent[0].subject, 'Welcome to BelieversLens');
  assert.equal(sent[0].to, 'admin@example.com');
  assert.match(sent[0].html, /Hi Amina,/);
  assert.match(sent[0].html, /manage your mosque/i);
  assert.match(sent[0].text, /prayer times/i);
});

test('welcome email skips cleanly when transactional email is not configured', async () => {
  const service = createEmailService({
    provider: {
      isConfigured: false,
      async send() {
        throw new Error('should not send');
      }
    },
    fromAddress: ''
  });

  const result = await service.sendWelcomeEmail({
    to: 'user@example.com',
    fullName: 'User',
    role: 'community'
  });

  assert.deepEqual(result, {
    id: null,
    skipped: true,
    reason: 'not_configured'
  });
});

test('resend provider sends the documented replyTo field', async () => {
  let request = null;
  const provider = new ResendEmailProvider({
    apiKey: 're_test_key',
    fetchImpl: async (url, options) => {
      request = { url, options };
      return {
        ok: true,
        status: 200,
        async text() {
          return JSON.stringify({ id: 'email-123' });
        }
      };
    }
  });

  const result = await provider.send({
    from: 'Believers Lens <no-reply@example.com>',
    to: 'user@example.com',
    replyTo: 'support@example.com',
    subject: 'Subject',
    html: '<p>Hello</p>',
    text: 'Hello'
  });

  assert.equal(result.id, 'email-123');
  assert.equal(request.url, 'https://api.resend.com/emails');
  const body = JSON.parse(request.options.body);
  assert.equal(body.replyTo, 'support@example.com');
  assert.equal(body.reply_to, undefined);
  assert.deepEqual(body.to, ['user@example.com']);
});

test('resend provider includes provider response details in delivery errors', async () => {
  const provider = new ResendEmailProvider({
    apiKey: 're_test_key',
    fetchImpl: async () => ({
      ok: false,
      status: 422,
      async text() {
        return JSON.stringify({ message: 'Invalid replyTo field' });
      }
    })
  });

  await assert.rejects(
    () =>
      provider.send({
        from: 'Believers Lens <no-reply@example.com>',
        to: 'user@example.com',
        replyTo: 'support@example.com',
        subject: 'Subject',
        html: '<p>Hello</p>',
        text: 'Hello'
      }),
    (error) => {
      assert.ok(error instanceof EmailDeliveryError);
      assert.equal(error.statusCode, 422);
      assert.equal(error.responseBody, 'Invalid replyTo field');
      assert.match(error.message, /422/);
      assert.match(error.message, /Invalid replyTo field/);
      return true;
    }
  );
});
