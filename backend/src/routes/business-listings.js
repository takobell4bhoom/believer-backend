import { z } from 'zod';
import {
  approveBusinessListing,
  createBusinessListingReview,
  fetchBusinessListingForModeration,
  fetchLiveBusinessListingSummary,
  fetchLatestBusinessListingStatus,
  listBusinessListingReviews,
  listBusinessListingsForModeration,
  rejectBusinessListing,
  saveBusinessListingDraft,
  submitBusinessListingForReview,
  BUSINESS_LISTING_STATUSES
} from '../services/businessListingsService.js';
import { ERROR_CODES } from '../utils/error-codes.js';
import { HttpError, successResponse } from '../utils/http.js';

const defaultTileBackgroundColor = 0xffe9c49e;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const digitPattern = /\d/g;

const emptyBasicDetails = {
  businessName: '',
  logo: null,
  selectedType: null,
  tagline: '',
  description: ''
};

const emptyContactDetails = {
  businessEmail: '',
  phone: '',
  whatsapp: '',
  openingTime: null,
  closingTime: null,
  instagramUrl: '',
  facebookUrl: '',
  websiteUrl: '',
  address: '',
  zipCode: '',
  city: '',
  onlineOnly: false
};

function trimmedString(maxLength) {
  return z.string().trim().max(maxLength);
}

function optionalTrimmedString(maxLength) {
  return trimmedString(maxLength).optional();
}

function isValidEmail(value) {
  return emailPattern.test(value);
}

function isValidPhone(value) {
  return (value.match(digitPattern) || []).length >= 7;
}

const timeOfDaySchema = z.object({
  hour: z.number().int().min(0).max(23),
  minute: z.number().int().min(0).max(59)
});

const logoSchema = z.object({
  fileName: optionalTrimmedString(255).nullable(),
  bytesBase64: z.string().max(2_000_000).optional().nullable(),
  contentType: optionalTrimmedString(120).nullable(),
  tileBackgroundColor: z.number().int().default(defaultTileBackgroundColor)
});

const selectedTypeSchema = z.object({
  groupId: trimmedString(120).min(1),
  groupLabel: trimmedString(120).min(1),
  itemId: trimmedString(120).min(1),
  itemLabel: trimmedString(120).min(1)
});

const basicDetailsSchema = z
  .object({
    businessName: trimmedString(180).default(''),
    logo: logoSchema.nullable().default(null),
    selectedType: selectedTypeSchema.nullable().default(null),
    tagline: trimmedString(160).default(''),
    description: trimmedString(4000).default('')
  })
  .default(emptyBasicDetails);

const contactDetailsSchema = z
  .object({
    businessEmail: trimmedString(254)
      .refine((value) => value === '' || isValidEmail(value), 'Enter a valid business email.')
      .default(''),
    phone: trimmedString(40)
      .refine((value) => value === '' || isValidPhone(value), 'Enter a valid phone number.')
      .default(''),
    whatsapp: trimmedString(40)
      .refine((value) => value === '' || isValidPhone(value), 'Enter a valid WhatsApp number.')
      .default(''),
    openingTime: timeOfDaySchema.nullable().default(null),
    closingTime: timeOfDaySchema.nullable().default(null),
    instagramUrl: trimmedString(240).default(''),
    facebookUrl: trimmedString(240).default(''),
    websiteUrl: trimmedString(240).default(''),
    address: trimmedString(240).default(''),
    zipCode: trimmedString(20).default(''),
    city: trimmedString(120).default(''),
    onlineOnly: z.boolean().default(false)
  })
  .default(emptyContactDetails)
  .superRefine((value, context) => {
    if ((value.openingTime == null) !== (value.closingTime == null)) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: value.openingTime == null ? ['openingTime'] : ['closingTime'],
        message: 'Opening and closing time must be provided together.'
      });
    }
  });

const draftRequestSchema = z
  .object({
    basicDetails: basicDetailsSchema,
    contactDetails: contactDetailsSchema
  })
  .transform((value) => ({
    basicDetails: {
      ...emptyBasicDetails,
      ...value.basicDetails
    },
    contactDetails: {
      ...emptyContactDetails,
      ...value.contactDetails
    }
  }));

const submitRequestSchema = draftRequestSchema.superRefine((value, context) => {
  const { basicDetails, contactDetails } = value;

  if (basicDetails.businessName.length < 2) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['basicDetails', 'businessName'],
      message: 'Business name is required.'
    });
  }

  if (basicDetails.selectedType == null) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['basicDetails', 'selectedType'],
      message: 'Business type is required.'
    });
  }

  if (!basicDetails.tagline) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['basicDetails', 'tagline'],
      message: 'Business tagline is required.'
    });
  }

  if (!basicDetails.description) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['basicDetails', 'description'],
      message: 'Business description is required.'
    });
  }

  if (!isValidEmail(contactDetails.businessEmail)) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['contactDetails', 'businessEmail'],
      message: 'Enter a valid business email.'
    });
  }

  if (!isValidPhone(contactDetails.phone)) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['contactDetails', 'phone'],
      message: 'Enter a valid phone number.'
    });
  }

  if (contactDetails.openingTime == null || contactDetails.closingTime == null) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['contactDetails', 'openingTime'],
      message: 'Operating hours are required.'
    });
  }

  if (
    !contactDetails.onlineOnly &&
    (!contactDetails.address || !contactDetails.zipCode || !contactDetails.city)
  ) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['contactDetails', 'address'],
      message: 'Address, zip code, and city are required unless the business is online only.'
    });
  }
});

const moderationRejectionSchema = z.object({
  rejectionReason: trimmedString(1000).min(3)
});

const reviewParamSchema = z.object({
  id: z.string().uuid()
});

const reviewBodySchema = z.object({
  rating: z.number().int().min(1).max(5),
  comments: trimmedString(2000).default('')
});

function toValidationError(message, error) {
  return new HttpError(400, ERROR_CODES.validation, message, error.issues);
}

function requireSuperAdmin(request) {
  if (request.authAccount?.role !== 'super_admin') {
    throw new HttpError(
      403,
      ERROR_CODES.forbidden,
      'Only super admins can moderate business listings'
    );
  }
}

export async function businessListingsRoutes(app) {
  app.put(
    '/api/v1/business-listings/draft',
    {
      preHandler: [app.authenticate],
      config: { rateLimit: { max: 20, timeWindow: '1 minute' } }
    },
    async (request, reply) => {
      const parsed = draftRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        throw toValidationError('Invalid business listing draft payload', parsed.error);
      }

      const result = await saveBusinessListingDraft({
        userId: request.user.sub,
        draft: parsed.data
      });

      return reply
        .code(result.created ? 201 : 200)
        .send(successResponse({ listing: result.listing }));
    }
  );

  app.post(
    '/api/v1/business-listings/submit',
    {
      preHandler: [app.authenticate],
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } }
    },
    async (request, reply) => {
      const parsed = submitRequestSchema.safeParse(request.body);
      if (!parsed.success) {
        throw toValidationError('Invalid business listing submission payload', parsed.error);
      }

      const result = await submitBusinessListingForReview({
        userId: request.user.sub,
        draft: parsed.data
      });

      return reply.code(202).send(
        successResponse({
          listing: result.listing
        })
      );
    }
  );

  app.get('/api/v1/business-listings/me', { preHandler: [app.authenticate] }, async (request) => {
    const listing = await fetchLatestBusinessListingStatus({
      userId: request.user.sub
    });

    return successResponse({
      listing
    });
  });

  app.get('/api/v1/business-listings/:id/reviews', async (request) => {
    const parsed = reviewParamSchema.safeParse(request.params);
    if (!parsed.success) {
      throw toValidationError('Invalid business listing id', parsed.error);
    }

    const listing = await fetchLiveBusinessListingSummary({
      listingId: parsed.data.id
    });
    if (listing == null || listing.status !== BUSINESS_LISTING_STATUSES.live) {
      throw new HttpError(
        404,
        ERROR_CODES.businessListingNotFound,
        'Business listing not found'
      );
    }

    const reviews = await listBusinessListingReviews({
      listingId: parsed.data.id
    });

    return successResponse(reviews);
  });

  app.post(
    '/api/v1/business-listings/:id/reviews',
    { preHandler: [app.authenticate] },
    async (request, reply) => {
      const paramsParsed = reviewParamSchema.safeParse(request.params);
      if (!paramsParsed.success) {
        throw toValidationError('Invalid business listing id', paramsParsed.error);
      }

      const bodyParsed = reviewBodySchema.safeParse(request.body);
      if (!bodyParsed.success) {
        throw toValidationError('Invalid business review payload', bodyParsed.error);
      }

      const listing = await fetchLiveBusinessListingSummary({
        listingId: paramsParsed.data.id
      });
      if (listing == null || listing.status !== BUSINESS_LISTING_STATUSES.live) {
        throw new HttpError(
          404,
          ERROR_CODES.businessListingNotFound,
          'Business listing not found'
        );
      }

      try {
        const review = await createBusinessListingReview({
          listingId: paramsParsed.data.id,
          userId: request.user.sub,
          rating: bodyParsed.data.rating,
          comments: bodyParsed.data.comments
        });

        return reply.code(201).send(
          successResponse({
            ...review,
            businessListingId: paramsParsed.data.id
          })
        );
      } catch (error) {
        if (error?.code === '23505') {
          throw new HttpError(
            409,
            ERROR_CODES.reviewAlreadyExists,
            'You have already reviewed this business'
          );
        }

        throw error;
      }
    }
  );

  app.get(
    '/api/v1/admin/business-listings/pending',
    { preHandler: [app.authenticate] },
    async (request) => {
      requireSuperAdmin(request);

      const items = await listBusinessListingsForModeration();
      return successResponse({ items });
    }
  );

  app.get(
    '/api/v1/admin/business-listings/:id',
    { preHandler: [app.authenticate] },
    async (request) => {
      requireSuperAdmin(request);

      const listing = await fetchBusinessListingForModeration({
        listingId: request.params.id
      });

      if (listing == null) {
        throw new HttpError(
          404,
          ERROR_CODES.businessListingNotFound,
          'Business listing not found'
        );
      }

      return successResponse({ listing });
    }
  );

  app.post(
    '/api/v1/admin/business-listings/:id/approve',
    { preHandler: [app.authenticate] },
    async (request) => {
      requireSuperAdmin(request);

      const existingListing = await fetchBusinessListingForModeration({
        listingId: request.params.id
      });
      if (existingListing == null) {
        throw new HttpError(
          404,
          ERROR_CODES.businessListingNotFound,
          'Business listing not found'
        );
      }

      if (existingListing.status !== BUSINESS_LISTING_STATUSES.underReview) {
        throw new HttpError(
          409,
          ERROR_CODES.validation,
          'Only listings under review can be approved'
        );
      }

      const listing = await approveBusinessListing({
        listingId: request.params.id,
        reviewerUserId: request.authAccount.id
      });

      if (listing == null) {
        throw new HttpError(
          409,
          ERROR_CODES.validation,
          'This listing is no longer available for approval'
        );
      }

      return successResponse({ listing });
    }
  );

  app.post(
    '/api/v1/admin/business-listings/:id/reject',
    { preHandler: [app.authenticate] },
    async (request) => {
      requireSuperAdmin(request);

      const parsed = moderationRejectionSchema.safeParse(request.body);
      if (!parsed.success) {
        throw toValidationError('Invalid business listing rejection payload', parsed.error);
      }

      const existingListing = await fetchBusinessListingForModeration({
        listingId: request.params.id
      });
      if (existingListing == null) {
        throw new HttpError(
          404,
          ERROR_CODES.businessListingNotFound,
          'Business listing not found'
        );
      }

      if (existingListing.status !== BUSINESS_LISTING_STATUSES.underReview) {
        throw new HttpError(
          409,
          ERROR_CODES.validation,
          'Only listings under review can be rejected'
        );
      }

      const listing = await rejectBusinessListing({
        listingId: request.params.id,
        reviewerUserId: request.authAccount.id,
        rejectionReason: parsed.data.rejectionReason
      });

      if (listing == null) {
        throw new HttpError(
          409,
          ERROR_CODES.validation,
          'This listing is no longer available for rejection'
        );
      }

      return successResponse({ listing });
    }
  );
}
