import { env } from '../../config/env.js';

export class EmailConfigurationError extends Error {}

export class EmailDeliveryError extends Error {
  constructor(message, { statusCode = null, responseBody = null, cause } = {}) {
    super(message);
    this.name = 'EmailDeliveryError';
    this.statusCode = statusCode;
    this.responseBody = responseBody;
    if (cause !== undefined) {
      this.cause = cause;
    }
  }
}

function parseJsonPayload(body) {
  if (!body) {
    return null;
  }

  try {
    return JSON.parse(body);
  } catch {
    return null;
  }
}

class DisabledEmailProvider {
  get isConfigured() {
    return false;
  }

  async send() {
    throw new EmailConfigurationError('Email delivery is not configured');
  }
}

export class ResendEmailProvider {
  constructor({ apiKey, fetchImpl = fetch }) {
    this.apiKey = apiKey;
    this.fetchImpl = fetchImpl;
  }

  get isConfigured() {
    return Boolean(this.apiKey);
  }

  async send({ from, to, replyTo, subject, html, text }) {
    const response = await this.fetchImpl('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from,
        to: [to],
        subject,
        html,
        text,
        ...(replyTo ? { replyTo } : {})
      })
    });

    const responseText = await response.text();
    const payload = parseJsonPayload(responseText);

    if (!response.ok) {
      const responseBody =
        (typeof payload?.message === 'string' && payload.message.trim()) ||
        responseText.trim() ||
        null;
      const detailSuffix = responseBody ? `: ${responseBody}` : '';
      throw new EmailDeliveryError(
        `Resend email request failed with status ${response.status}${detailSuffix}`,
        {
          statusCode: response.status,
          responseBody
        }
      );
    }

    return {
      id: payload?.id ?? null
    };
  }
}

function resolvePasswordResetBaseUrl() {
  if (env.PASSWORD_RESET_URL_BASE) {
    return env.PASSWORD_RESET_URL_BASE;
  }

  if (!env.APP_WEB_ORIGIN) {
    return null;
  }

  return `${env.APP_WEB_ORIGIN.replace(/\/+$/, '')}/#\/reset-password`;
}

function buildUrlWithQuery(baseUrl, params) {
  if (baseUrl.includes('#')) {
    const [prefix, fragment = ''] = baseUrl.split('#', 2);
    const normalizedFragment = fragment.startsWith('/') ? fragment : `/${fragment}`;
    const fragmentUrl = new URL(normalizedFragment, 'https://placeholder.local');
    Object.entries(params).forEach(([key, value]) => {
      fragmentUrl.searchParams.set(key, value);
    });
    return `${prefix}#${fragmentUrl.pathname}${fragmentUrl.search}`;
  }

  const url = new URL(baseUrl);
  Object.entries(params).forEach(([key, value]) => {
    url.searchParams.set(key, value);
  });
  return url.toString();
}

function formatExpiryWindow(minutes) {
  if (minutes % 60 === 0) {
    const hours = minutes / 60;
    return hours === 1 ? '1 hour' : `${hours} hours`;
  }

  return minutes === 1 ? '1 minute' : `${minutes} minutes`;
}

export class EmailService {
  constructor({
    provider,
    fromAddress,
    replyToAddress,
    passwordResetBaseUrl,
    passwordResetTtlMinutes
  }) {
    this.provider = provider;
    this.fromAddress = fromAddress;
    this.replyToAddress = replyToAddress;
    this.passwordResetBaseUrl = passwordResetBaseUrl;
    this.passwordResetTtlMinutes = passwordResetTtlMinutes;
  }

  get isTransactionalEmailConfigured() {
    return Boolean(this.provider?.isConfigured && this.fromAddress);
  }

  ensurePasswordResetAvailable() {
    if (!this.isTransactionalEmailConfigured || !this.passwordResetBaseUrl) {
      throw new EmailConfigurationError('Password reset email is not configured');
    }
  }

  async sendTransactionalEmail({ to, subject, html, text }) {
    if (!this.isTransactionalEmailConfigured) {
      throw new EmailConfigurationError('Email delivery is not configured');
    }

    return this.provider.send({
      from: this.fromAddress,
      to,
      replyTo: this.replyToAddress,
      subject,
      html,
      text
    });
  }

  buildPasswordResetUrl(resetToken) {
    this.ensurePasswordResetAvailable();
    return buildUrlWithQuery(this.passwordResetBaseUrl, { token: resetToken });
  }

  async sendPasswordResetEmail({ to, fullName, resetToken }) {
    const resetUrl = this.buildPasswordResetUrl(resetToken);
    const greeting = fullName?.trim().length ? `Hi ${fullName.trim()},` : 'Hi,';
    const expiryWindow = formatExpiryWindow(this.passwordResetTtlMinutes);
    const subject = 'Reset your Believers Lens password';
    const html = [
      `<p>${greeting}</p>`,
      '<p>We received a request to reset the password for your Believers Lens account.</p>',
      `<p><a href="${resetUrl}">Reset your password</a></p>`,
      `<p>This link expires in ${expiryWindow} and can only be used once.</p>`,
      '<p>If you did not request this, you can ignore this email.</p>'
    ].join('');
    const text = [
      greeting,
      '',
      'We received a request to reset the password for your Believers Lens account.',
      `Reset your password: ${resetUrl}`,
      `This link expires in ${expiryWindow} and can only be used once.`,
      '',
      'If you did not request this, you can ignore this email.'
    ].join('\n');

    return this.sendTransactionalEmail({
      to,
      subject,
      html,
      text
    });
  }

  async sendWelcomeEmail({ to, fullName, role }) {
    if (!this.isTransactionalEmailConfigured) {
      return {
        id: null,
        skipped: true,
        reason: 'not_configured'
      };
    }

    const trimmedName = fullName?.trim() ?? '';
    const firstName = trimmedName.split(/\s+/).filter(Boolean)[0] ?? '';
    const greeting = firstName ? `Hi ${firstName},` : trimmedName ? `Hi ${trimmedName},` : 'Hi,';
    const explorationLine =
      'You can now explore nearby mosques, prayer times, and community content.';
    const adminLine =
      role === 'admin'
        ? 'After you sign in, you can also manage your mosque and keep its community details up to date.'
        : null;
    const subject = 'Welcome to BelieversLens';
    const html = [
      `<p>${greeting}</p>`,
      '<p>Thank you for joining BelieversLens.</p>',
      `<p>${explorationLine}</p>`,
      ...(adminLine ? [`<p>${adminLine}</p>`] : []),
      '<p>We are glad to have you with us.</p>'
    ].join('');
    const text = [
      greeting,
      '',
      'Thank you for joining BelieversLens.',
      explorationLine,
      ...(adminLine ? ['', adminLine] : []),
      '',
      'We are glad to have you with us.'
    ].join('\n');

    return this.sendTransactionalEmail({
      to,
      subject,
      html,
      text
    });
  }
}

export function createEmailService({
  provider,
  fromAddress = env.EMAIL_FROM,
  replyToAddress = env.EMAIL_REPLY_TO,
  passwordResetBaseUrl = resolvePasswordResetBaseUrl(),
  passwordResetTtlMinutes = env.PASSWORD_RESET_TOKEN_TTL_MINUTES
} = {}) {
  const resolvedProvider =
    provider ??
    (env.RESEND_API_KEY
      ? new ResendEmailProvider({ apiKey: env.RESEND_API_KEY })
      : new DisabledEmailProvider());

  return new EmailService({
    provider: resolvedProvider,
    fromAddress,
    replyToAddress,
    passwordResetBaseUrl,
    passwordResetTtlMinutes
  });
}
