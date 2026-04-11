import { z } from 'zod';
import { HttpError } from '../utils/http.js';

const querySchema = z.object({
  category: z.string().trim().min(1).max(120),
  filters: z.string().trim().optional(),
  sort: z.enum(['new', 'popular', 'top_rated']).optional()
});

function parseFilters(raw) {
  if (!raw) return [];
  return raw
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, 20);
}

export async function servicesRoutes(app) {
  const servicesCatalog = app.servicesCatalog;

  app.get(
    '/api/v1/services',
    {
      schema: {
        querystring: {
          type: 'object',
          required: ['category'],
          properties: {
            category: { type: 'string', minLength: 1, maxLength: 120 },
            filters: { type: 'string' },
            sort: {
              type: 'string',
              enum: ['new', 'popular', 'top_rated']
            }
          }
        }
      }
    },
    async (request) => {
      const parsed = querySchema.safeParse(request.query);
      if (!parsed.success) {
        throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid services query', parsed.error.issues);
      }

      const { category, filters: rawFilters, sort } = parsed.data;
      if (!servicesCatalog.isKnownServiceCategory(category)) {
        throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid Category');
      }

      const filters = parseFilters(rawFilters);
      const services = await servicesCatalog.fetchServices({
        category,
        filters,
        sort
      });

      if (!services.length) {
        return {
          data: { services: [] },
          error: null,
          meta: {}
        };
      }

      return {
        data: { services },
        error: null,
        meta: {}
      };
    }
  );
}
