import { z } from 'zod';
import { ERROR_CODES } from '../utils/error-codes.js';
import { HttpError, successResponse } from '../utils/http.js';

function isValidIsoDate(value) {
  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime())) {
    return false;
  }

  const [year, month, day] = value.split('-').map(Number);
  return (
    parsed.getUTCFullYear() === year &&
    parsed.getUTCMonth() === month - 1 &&
    parsed.getUTCDate() === day
  );
}

const dailyPrayerTimesQuerySchema = z.object({
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .refine((value) => isValidIsoDate(value), {
      message: 'date must be a valid YYYY-MM-DD value'
    }),
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
  school: z.enum(['standard', 'hanafi']),
  method: z.coerce.number().int().min(0).max(99).optional()
});

export async function prayerTimesRoutes(app) {
  app.get('/api/v1/prayer-times/daily', async (request) => {
    const queryParsed = dailyPrayerTimesQuerySchema.safeParse(request.query);
    if (!queryParsed.success) {
      throw new HttpError(400, ERROR_CODES.validation, 'Invalid prayer-times query', queryParsed.error.issues);
    }

    const { date, latitude, longitude, school, method } = queryParsed.data;
    const data = await app.prayerTimeService.readLocationDailyTimings({
      date,
      latitude,
      longitude,
      school,
      calculationMethodId: method
    });

    return successResponse(data);
  });
}
