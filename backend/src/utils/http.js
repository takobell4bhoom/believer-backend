import { ERROR_CODES } from './error-codes.js';

export class HttpError extends Error {
  constructor(statusCode, code, message, details) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}

export function errorResponse(error) {
  return {
    data: null,
    error: {
      code: error.code || ERROR_CODES.internalServerError,
      message: error.message || 'Something went wrong',
      details: error.details || undefined
    },
    meta: {}
  };
}

export function successResponse(data, meta = {}) {
  return {
    data,
    error: null,
    meta
  };
}

export function paginatedResponse(data, pagination) {
  return successResponse(data, {
    pagination
  });
}

export function parsePagination({ page = 1, limit = 20 }, maxLimit = 100) {
  const safePage = Number.isFinite(page) ? Math.max(1, Math.trunc(page)) : 1;
  const safeLimit = Number.isFinite(limit) ? Math.min(maxLimit, Math.max(1, Math.trunc(limit))) : 20;
  const offset = (safePage - 1) * safeLimit;
  return { page: safePage, limit: safeLimit, offset };
}
