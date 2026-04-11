# API Contract

Last updated: 2026-04-09

This file documents the active backend contract implemented by the backend routes and automated tests. `backend/docs/openapi.yaml` mirrors most of this surface, but when the markdown contract and OpenAPI spec drift, verify against route code and tests before changing clients.

## Standard Response Shape

Success:

```json
{
  "data": {},
  "error": null,
  "meta": {}
}
```

Paginated success:

```json
{
  "data": {
    "items": []
  },
  "error": null,
  "meta": {
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 0,
      "hasNext": false
    }
  }
}
```

Error:

```json
{
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request payload",
    "details": []
  },
  "meta": {}
}
```

## Client Rules

- Base URL: `AppConfig.apiBaseUrl`
- Flutter callers should unwrap `response['data']`
- Paginated callers should read `response['meta']['pagination']`
- Protected routes require `Authorization: Bearer <jwt>`

## Auth

### `POST /api/v1/auth/signup`

Request body:

```json
{
  "fullName": "Ahmed Khan",
  "email": "ahmed@example.com",
  "password": "StrongPass@123",
  "accountType": "community"
}
```

Optional mosque-admin signup body:

```json
{
  "fullName": "Amina Yusuf",
  "email": "amina@example.com",
  "password": "StrongPass@123",
  "accountType": "admin"
}
```

Success `data`:

```json
{
  "user": {
    "id": "uuid",
    "fullName": "Ahmed Khan",
    "email": "ahmed@example.com",
    "role": "community"
  },
  "tokens": {
    "accessToken": "jwt",
    "refreshToken": "refresh-token"
  }
}
```

Notes:

- `accountType` defaults to `community`
- `accountType=admin` creates a mosque-admin account without an extra signup access code
- signup attempts a simple welcome email after the account is created; delivery failure does not roll back the created account or auth session

Errors: `VALIDATION_ERROR`, `EMAIL_ALREADY_EXISTS`

### `POST /api/v1/auth/login`

Request body:

```json
{
  "email": "ahmed@example.com",
  "password": "StrongPass@123"
}
```

Success `data`: same as signup.

Errors: `VALIDATION_ERROR`, `INVALID_CREDENTIALS`, `ACCOUNT_DISABLED`

### `POST /api/v1/auth/forgot-password`

Request body:

```json
{
  "email": "ahmed@example.com"
}
```

Success `data`:

```json
{
  "success": true,
  "message": "If an account exists for that email, a password reset link has been sent."
}
```

Notes:

- response stays non-enumerating for unknown or disabled accounts
- password reset email delivery requires `RESEND_API_KEY`, `EMAIL_FROM`, and either `APP_WEB_ORIGIN` or `PASSWORD_RESET_URL_BASE`
- when email delivery is not configured, the route fails honestly instead of faking success
- reset emails are sent through the backend email service/provider abstraction rather than inline route-level vendor calls

Errors: `VALIDATION_ERROR`, `EMAIL_NOT_CONFIGURED`, `PASSWORD_RESET_EMAIL_FAILED`

### `POST /api/v1/auth/reset-password`

Request body:

```json
{
  "token": "opaque-reset-token",
  "newPassword": "NewStrongPass@123"
}
```

Success `data`:

```json
{
  "success": true
}
```

Notes:

- reset tokens are single-use, stored hashed, and expire after `PASSWORD_RESET_TOKEN_TTL_MINUTES`
- successful reset revokes all refresh-token state for that user so previously issued refresh tokens cannot be reused

Errors: `VALIDATION_ERROR`, `INVALID_PASSWORD_RESET_TOKEN`, `ACCOUNT_DISABLED`

### `POST /api/v1/auth/refresh`

Request body:

```json
{
  "refreshToken": "refresh-token"
}
```

Success `data`:

```json
{
  "accessToken": "jwt",
  "refreshToken": "refresh-token"
}
```

Errors: `VALIDATION_ERROR`, `INVALID_REFRESH_TOKEN`, `ACCOUNT_DISABLED`

### `GET /api/v1/auth/me`

Success `data`:

```json
{
  "id": "uuid",
  "fullName": "Ahmed Khan",
  "email": "ahmed@example.com",
  "role": "community"
}
```

Errors: `UNAUTHORIZED`, `USER_NOT_FOUND`

### `PUT /api/v1/auth/me`

Minimal authenticated profile update used by the compact Profile & Settings flow.

Request body:

```json
{
  "fullName": "Ahmed Khan"
}
```

Success `data`:

```json
{
  "id": "uuid",
  "fullName": "Ahmed Khan",
  "email": "ahmed@example.com",
  "role": "community"
}
```

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `USER_NOT_FOUND`

### `POST /api/v1/auth/change-password`

Authenticated password rotation used by Profile & Settings.

Request body:

```json
{
  "currentPassword": "StrongPass@123",
  "newPassword": "NewStrongPass@123"
}
```

Success `data`: same as signup.

Notes:

- requires the current password
- revokes prior refresh-token state and returns a fresh token pair for the current session

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `INVALID_CURRENT_PASSWORD`, `ACCOUNT_DISABLED`

### `POST /api/v1/auth/deactivate`

Authenticated self-serve account deactivation used by the public Profile & Settings screen.

Request body:

```json
{
  "confirmation": "DEACTIVATE"
}
```

Success `data`:

```json
{
  "success": true,
  "message": "Your account has been deactivated."
}
```

Notes:

- this is a launch-safe soft-delete/deactivation path rather than irreversible hard delete
- successful deactivation sets `users.is_active=false`, revokes outstanding refresh tokens, and consumes outstanding password-reset tokens
- authenticated routes now reject inactive accounts at auth middleware, so a deactivated account cannot keep using an older access token on protected endpoints

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `USER_NOT_FOUND`, `ACCOUNT_DISABLED`

### `POST /api/v1/auth/logout`

Request body:

```json
{
  "refreshToken": "refresh-token"
}
```

Success `data`:

```json
{
  "success": true
}
```

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`

## Account Governance

### `POST /api/v1/account/support-requests`

Authenticated lightweight support/contact submission used by Profile & Settings.

Request body:

```json
{
  "subject": "Need help with my account",
  "message": "Please help me understand how to update my mosque details."
}
```

Success `data`:

```json
{
  "success": true,
  "message": "Your message has been received."
}
```

Notes:

- the backend stores the authenticated user id plus the current account name/email snapshot with the request
- this route is intentionally lightweight and does not depend on separate CMS or admin tooling in this slice

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `ACCOUNT_DISABLED`

### `POST /api/v1/account/mosque-suggestions`

Authenticated mosque suggestion submission used by Profile & Settings.

Request body:

```json
{
  "mosqueName": "Masjid Al Noor",
  "city": "Hyderabad",
  "country": "India",
  "addressLine": "123 Market Road",
  "notes": "Women prayer space and parking available."
}
```

Success `data`:

```json
{
  "success": true,
  "message": "Thanks for sharing this mosque suggestion."
}
```

Notes:

- the backend stores the authenticated user id plus the current account name/email snapshot with the suggestion
- the submission is only confirmed after the record is persisted

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `ACCOUNT_DISABLED`

## Business Listings

Status values used by the business-registration MVP:

- `draft`
- `under_review`
- `live`

### `PUT /api/v1/business-listings/draft`

Protected create/update route for the current user’s business listing draft.
The request body always uses the combined draft shape so the client can save either a partial step or the full flow.

Request body:

```json
{
  "basicDetails": {
    "businessName": "Noor Catering",
    "logo": {
      "fileName": "noor.png",
      "contentType": "image/png",
      "bytesBase64": "bm9vci1sb2dv",
      "tileBackgroundColor": 4293512350
    },
    "selectedType": {
      "groupId": "food",
      "groupLabel": "Halal Food",
      "itemId": "catering",
      "itemLabel": "Catering Services"
    },
    "tagline": "Trusted halal catering for family and community events.",
    "description": "We handle wedding catering, office lunches, and weekend dawat events."
  },
  "contactDetails": {
    "businessEmail": "hello@noorcatering.example",
    "phone": "+91 9988776655",
    "whatsapp": "+91 9988776655",
    "openingTime": { "hour": 9, "minute": 0 },
    "closingTime": { "hour": 18, "minute": 30 },
    "instagramUrl": "instagram.com/noorcatering",
    "facebookUrl": "facebook.com/noorcatering",
    "websiteUrl": "https://noorcatering.example",
    "address": "12 Crescent Road",
    "zipCode": "560001",
    "city": "Bengaluru",
    "onlineOnly": false
  }
}
```

Success `data`:

```json
{
  "listing": {
    "id": "uuid",
    "status": "draft",
    "basicDetails": {
      "businessName": "Noor Catering",
      "logo": {
        "fileName": "noor.png",
        "contentType": "image/png",
        "bytesBase64": "bm9vci1sb2dv",
        "tileBackgroundColor": 4293512350
      },
      "selectedType": {
        "groupId": "food",
        "groupLabel": "Halal Food",
        "itemId": "catering",
        "itemLabel": "Catering Services"
      },
      "tagline": "Trusted halal catering for family and community events.",
      "description": "We handle wedding catering, office lunches, and weekend dawat events."
    },
    "contactDetails": {
      "businessEmail": "hello@noorcatering.example",
      "phone": "+91 9988776655",
      "whatsapp": "+91 9988776655",
      "openingTime": { "hour": 9, "minute": 0 },
      "closingTime": { "hour": 18, "minute": 30 },
      "instagramUrl": "instagram.com/noorcatering",
      "facebookUrl": "facebook.com/noorcatering",
      "websiteUrl": "https://noorcatering.example",
      "address": "12 Crescent Road",
      "zipCode": "560001",
      "city": "Bengaluru",
      "onlineOnly": false
    },
    "submittedAt": null,
    "publishedAt": null,
    "createdAt": "2026-04-09T09:30:00.000Z",
    "lastUpdatedAt": "2026-04-09T09:30:00.000Z"
  }
}
```

Notes:

- first save returns `201`; later updates to the same user-owned draft return `200`
- draft saves accept partial step data, but any provided email/phone/hour fields are still validated explicitly
- persistence is now backend-owned in PostgreSQL instead of device-local-only storage

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `ACCOUNT_DISABLED`

### `POST /api/v1/business-listings/submit`

Protected route that persists the latest draft and moves the listing to `under_review`.

Request body: same shape as `PUT /api/v1/business-listings/draft`.

Success `data`: same `listing` shape as the draft route, with:

```json
{
  "listing": {
    "status": "under_review",
    "submittedAt": "2026-04-09T09:32:00.000Z"
  }
}
```

Notes:

- returns `202 Accepted`
- submit requires a review-ready listing: business name, logo, selected type, tagline, description, valid business email, valid phone number, operating hours, and either `onlineOnly=true` or full address details

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `ACCOUNT_DISABLED`

### `GET /api/v1/business-listings/me`

Protected read route for the current user’s latest business listing status.

Success `data`:

```json
{
  "listing": {
    "id": "uuid",
    "status": "under_review",
    "basicDetails": {},
    "contactDetails": {},
    "submittedAt": "2026-04-09T09:32:00.000Z",
    "publishedAt": null,
    "createdAt": "2026-04-09T09:30:00.000Z",
    "lastUpdatedAt": "2026-04-09T09:32:00.000Z"
  }
}
```

When no listing exists yet, `data.listing` is `null`.

Errors: `UNAUTHORIZED`, `ACCOUNT_DISABLED`

## Mosques

### `GET /api/v1/mosques`

Query params:

- `page?`
- `limit?`
- `search?`
- `city?`
- `facilities?`
- `sort?` = `name | recent | distance`
- `latitude?`
- `longitude?`
- `radius?`
- backward-compatible aliases: `lat?`, `lng?`, `radiusKm?`

Success `data.items[]`:

```json
{
  "id": "uuid",
  "name": "Jamia Masjid Bengaluru",
  "addressLine": "KR Market Road",
  "city": "Bengaluru",
  "state": "Karnataka",
  "country": "India",
  "postalCode": "560002",
  "latitude": 12.9635,
  "longitude": 77.5736,
  "imageUrl": "https://example.com/mosque.jpg",
  "imageUrls": [
    "https://example.com/mosque.jpg",
    "https://example.com/mosque-2.jpg"
  ],
  "sect": "Sunni",
  "contactName": "Amina Yusuf",
  "contactPhone": "+91-9000000000",
  "contactEmail": "info@example.com",
  "websiteUrl": "https://example.com",
  "duhrTime": "01:15 PM",
  "asrTime": "04:45 PM",
  "facilities": ["parking", "wudu", "women_area"],
  "averageRating": 4.7,
  "totalReviews": 18,
  "classTags": ["Quran Reflection Circle", "Weekend Halaqa"],
  "eventTags": ["Family Night", "Youth Service Day"],
  "isVerified": true,
  "distanceKm": 1.24,
  "isBookmarked": false,
  "canEdit": false
}
```

Notes:

- `canEdit` is an additive ownership-safe field
- `canEdit=true` only when the current authenticated admin owns that mosque

Success `meta.pagination`:

```json
{
  "page": 1,
  "limit": 20,
  "total": 42,
  "hasNext": true
}
```

Errors: `VALIDATION_ERROR`

### `POST /api/v1/mosques`

Protected admin-only create route used by the MVP Admin Add Mosque workflow.

Request body:

```json
{
  "name": "Admin Created Mosque",
  "addressLine": "15 Unity Street",
  "city": "Bengaluru",
  "state": "Karnataka",
  "country": "India",
  "postalCode": "560001",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "contactName": "Fatima Noor",
  "contactPhone": "+91-9999999999",
  "contactEmail": "fatima@example.com",
  "websiteUrl": "https://example.org",
  "imageUrl": "http://localhost:4000/uploads/mosques/admin-created.jpg",
  "imageUrls": [
    "http://localhost:4000/uploads/mosques/admin-created.jpg",
    "http://localhost:4000/uploads/mosques/admin-created-2.jpg"
  ],
  "sect": "Sunni",
  "prayerTimeConfig": {
    "enabled": true,
    "calculationMethod": 3,
    "school": "standard",
    "adjustments": {
      "fajr": 0,
      "sunrise": 0,
      "dhuhr": 2,
      "asr": 0,
      "maghrib": 0,
      "isha": 0
    }
  },
  "facilities": ["parking", "wudu", "women_area"],
  "content": {
    "events": [
      {
        "title": "Community Family Night",
        "schedule": "Fri, Apr 12 • 7:30 PM",
        "posterLabel": "Family",
        "location": "Main Prayer Hall",
        "description": "Dinner, reminders, and an open community gathering."
      }
    ],
    "classes": [],
    "connect": []
  }
}
```

Success `data`: one mosque object with the same shape as list items.

Notes:

- `imageUrl` may still be an existing remote URL for legacy records
- `imageUrls[]` is an additive gallery field with a current max of 10 images
- `imageUrl` remains the primary cover image and should match the first entry in `imageUrls[]` when that array is present
- the active admin add/edit web flow now uploads mosque images through `POST /api/v1/mosques/upload-image` and then reuses the returned `imageUrl` values here
- `content` is now also accepted on create so a new mosque can publish initial mosque-page events immediately
- persisted mosque content items now support additive `location` and `description` fields while preserving the existing title/schedule/posterLabel-first read model

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `FORBIDDEN`, `MOSQUE_ALREADY_EXISTS`

### `POST /api/v1/mosques/upload-image`

Protected admin-only multipart upload route used by the web/browser Admin Add Mosque and Admin Edit Mosque flows.

Request body:

- `multipart/form-data`
- file field: `file`
- allowed image types: `JPG`, `PNG`, `WebP`

Success `data`:

```json
{
  "imageUrl": "http://localhost:4000/uploads/mosques/1711900000000-uuid.jpg",
  "imagePath": "/uploads/mosques/1711900000000-uuid.jpg",
  "fileName": "1711900000000-uuid.jpg"
}
```

Notes:

- files are stored locally under `backend/uploads/mosques/`
- this is the current MVP storage strategy; future cloud storage can replace the backend-local path without changing the add/edit form shape
- the returned `imageUrl` is meant to be copied into the existing mosque `imageUrls[]` list on create/update payloads
- admins can currently attach up to 10 uploaded mosque images per mosque

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `FORBIDDEN`, `INVALID_UPLOAD_FILE`, `UPLOAD_TOO_LARGE`

### `GET /api/v1/mosques/mine`

Protected admin-only owned-mosques read used by the new admin management flow.

Success `data`:

```json
{
  "items": [
    {
      "id": "uuid",
      "name": "Admin Created Mosque",
      "canEdit": true
    }
  ]
}
```

Errors: `UNAUTHORIZED`, `FORBIDDEN`

### `PUT /api/v1/mosques/:id`

Protected admin-only update route used by the MVP mosque edit/content-enrichment workflow.
Only the admin who created the mosque may update it.

Request body:

```json
{
  "name": "Updated Mosque",
  "addressLine": "15 Unity Street",
  "city": "Bengaluru",
  "state": "Karnataka",
  "country": "India",
  "postalCode": "560001",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "contactName": "Fatima Noor",
  "contactPhone": "+91-9999999999",
  "contactEmail": "fatima@example.com",
  "websiteUrl": "https://example.org",
  "imageUrl": "http://localhost:4000/uploads/mosques/updated.jpg",
  "imageUrls": [
    "http://localhost:4000/uploads/mosques/updated.jpg",
    "http://localhost:4000/uploads/mosques/updated-2.jpg"
  ],
  "sect": "Community",
  "prayerTimeConfig": {
    "enabled": true,
    "calculationMethod": 3,
    "school": "hanafi",
    "adjustments": {
      "fajr": 1,
      "sunrise": 0,
      "dhuhr": 2,
      "asr": 0,
      "maghrib": -1,
      "isha": 0
    }
  },
  "facilities": ["parking", "wudu", "women_area"],
  "content": {
    "about": {
      "title": "About Updated Mosque",
      "body": "A welcoming mosque for prayer, study, and community connection."
    },
    "events": [
      {
        "title": "Weekend Family Night",
        "schedule": "This Sat",
        "posterLabel": "Family",
        "location": "Main Prayer Hall",
        "description": "Dinner, reminders, and an open community gathering."
      }
    ],
    "classes": [
      {
        "title": "Quran Reflection Circle",
        "schedule": "Tue 7 PM",
        "posterLabel": "Quran"
      }
    ],
    "connect": [
      {
        "type": "instagram",
        "label": "instagram.com/examplemosque",
        "value": "instagram.com/examplemosque"
      }
    ]
  }
}
```

Notes:

- existing mosques with older remote `imageUrl` values continue to work unchanged
- the active admin edit web flow can upload up to 10 images by calling `POST /api/v1/mosques/upload-image` repeatedly, then sending the ordered list through `imageUrls[]`
- `imageUrl` remains the primary cover image for backward-compatible listing/detail surfaces and should stay aligned with the first entry in `imageUrls[]`
- saved event items are treated as published content in this MVP; no separate visibility flag is required yet

Success `data`:

```json
{
  "mosque": {
    "id": "uuid",
    "name": "Updated Mosque"
  },
  "content": {
    "events": [],
    "classes": [],
    "connect": [],
    "about": {
      "title": "About Updated Mosque",
      "body": "A welcoming mosque for prayer, study, and community connection."
    }
  }
}
```

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `FORBIDDEN`, `MOSQUE_NOT_FOUND`, `MOSQUE_ALREADY_EXISTS`

### `GET /api/v1/mosques/nearby`

Query params:

- `latitude`
- `longitude`
- `radius?`
- `limit?`
- backward-compatible aliases: `lat?`, `lng?`, `radiusKm?`

Success `data`:

```json
{
  "items": [
    {
      "id": "uuid",
      "name": "Jamia Masjid Bengaluru",
      "averageRating": 4.7,
      "totalReviews": 18,
      "classTags": ["Quran Reflection Circle", "Weekend Halaqa"],
      "eventTags": ["Family Night", "Youth Service Day"]
    }
  ]
}
```

Errors: `VALIDATION_ERROR`

### `GET /api/v1/mosques/location-resolve`

Manual location search helper used by the onboarding/manual setup fallback.

Query params:

- `query`

Success `data`:

```json
{
  "label": "Tampa, FL, USA",
  "latitude": 27.9506,
  "longitude": -82.4572,
  "provider": "google_geocoding",
  "resolved": true
}
```

Notes:

- unresolved lookups return `label` as the original query, `latitude=null`, `longitude=null`, `provider=null`, and `resolved=false`

Errors: `VALIDATION_ERROR`, `LOCATION_LOOKUP_UNAVAILABLE`

### `GET /api/v1/mosques/location-suggest`

Autocomplete helper used by the manual location search flow.

Query params:

- `query`
- `limit` (optional, defaults in backend)

Success `data`:

```json
{
  "items": [
    {
      "label": "Tampa, FL, USA",
      "primaryText": "Tampa",
      "secondaryText": "FL, USA",
      "latitude": 27.9506,
      "longitude": -82.4572,
      "provider": "google_geocoding"
    }
  ]
}
```

Notes:

- results are ordered and limited by the backend location-lookup provider
- this route is implemented and covered by backend smoke tests even though the current OpenAPI file does not yet list it

Errors: `VALIDATION_ERROR`, `LOCATION_LOOKUP_UNAVAILABLE`

### `GET /api/v1/mosques/location-reverse`

Reverse-geocode helper used by the onboarding current-location path after browser geolocation succeeds.

Query params:

- `latitude`
- `longitude`

Success `data`:

```json
{
  "label": "Downtown Tampa, FL, USA",
  "latitude": 27.9506,
  "longitude": -82.4572,
  "provider": "google_geocoding",
  "resolved": true
}
```

Notes:

- unresolved reverse lookups keep the supplied coordinates, return `label=null`, `provider=null`, and `resolved=false`

Errors: `VALIDATION_ERROR`, `LOCATION_LOOKUP_UNAVAILABLE`

### `GET /api/v1/mosques/:id`

Success `data`: one mosque object with the same shape as list items.

Errors: `VALIDATION_ERROR`, `MOSQUE_NOT_FOUND`

### `GET /api/v1/mosques/:id/prayer-times`

Public backend-owned prayer-time read for one mosque on one date.

Query params:

- `date?` = `YYYY-MM-DD`
- defaults to the server's current date when omitted

Success `data`:

```json
{
  "mosqueId": "uuid",
  "date": "2026-03-30",
  "status": "ready",
  "isConfigured": true,
  "isAvailable": true,
  "source": "cache",
  "unavailableReason": null,
  "timezone": "Asia/Kolkata",
  "configuration": {
    "enabled": true,
    "latitude": 12.9716,
    "longitude": 77.5946,
    "calculationMethod": {
      "id": 3,
      "name": "Muslim World League"
    },
    "school": {
      "value": "hanafi",
      "label": "Hanafi"
    },
    "adjustments": {
      "fajr": 1,
      "sunrise": 0,
      "dhuhr": 2,
      "asr": 0,
      "maghrib": -1,
      "isha": 0
    }
  },
  "timings": {
    "fajr": "05:08 AM",
    "sunrise": "06:18 AM",
    "dhuhr": "12:31 PM",
    "asr": "04:02 PM",
    "maghrib": "06:41 PM",
    "isha": "07:55 PM"
  },
  "nextPrayer": "Asr",
  "nextPrayerTime": "04:02 PM",
  "cachedAt": "2026-03-30T04:00:00.000Z"
}
```

Unavailable but non-error examples:

- `status = "not_configured"` when the mosque has no saved prayer-time config yet
- `status = "disabled"` when the config exists but is intentionally disabled
- `status = "temporarily_unavailable"` when the backend could not get a live read and has no cached payload for that mosque/date

Errors: `VALIDATION_ERROR`, `MOSQUE_NOT_FOUND`

### `GET /api/v1/mosques/:id/content`

Public persisted mosque-page content read used by the mosque page and admin edit hydration.

Persisted `events[]` / `classes[]` items use this additive shape:

```json
{
  "id": "event-1",
  "title": "Community Family Night",
  "schedule": "Fri, Apr 12 • 7:30 PM",
  "posterLabel": "Family",
  "location": "Main Prayer Hall",
  "description": "Dinner, reminders, and an open community gathering."
}
```

Success `data`:

```json
{
  "events": [
    {
      "id": "event-1",
      "title": "Weekend Family Night",
      "schedule": "This Sat",
      "posterLabel": "Family",
      "location": "Main Prayer Hall",
      "description": "Dinner, reminders, and an open community gathering."
    }
  ],
  "classes": [
    {
      "id": "class-1",
      "title": "Quran Reflection Circle",
      "schedule": "Tue 7 PM",
      "posterLabel": "Quran",
      "location": "",
      "description": ""
    }
  ],
  "connect": [
    {
      "id": "connect-1",
      "type": "instagram",
      "label": "instagram.com/examplemosque",
      "value": "instagram.com/examplemosque"
    }
  ],
  "about": {
    "title": "About Updated Mosque",
    "body": "A welcoming mosque for prayer, study, and community connection."
  }
}
```

Errors: `VALIDATION_ERROR`, `MOSQUE_NOT_FOUND`

### `POST /api/v1/mosques/review`

Protected route used by the current app review flow.

Request body:

```json
{
  "mosqueId": "uuid",
  "rating": 5,
  "comments": "Warm welcome and clear prayer announcements."
}
```

Success `data`:

```json
{
  "id": "uuid",
  "mosqueId": "uuid",
  "rating": 5,
  "comments": "Warm welcome and clear prayer announcements.",
  "createdAt": "2026-03-28T10:00:00.000Z"
}
```

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `MOSQUE_NOT_FOUND`, `REVIEW_ALREADY_EXISTS`

### `POST /api/v1/mosques/:id/reviews`

Alias for the same review-create behavior. The route param can replace `mosqueId` in the body.

### `GET /api/v1/mosques/:id/reviews`

Public persisted review read used by the mosque page and review screen.

Success `data`:

```json
{
  "items": [
    {
      "id": "uuid",
      "userName": "Amina Yusuf",
      "rating": 5,
      "comment": "Warm welcome and clear prayer announcements.",
      "createdAt": "2026-03-28T10:00:00.000Z"
    }
  ],
  "summary": {
    "averageRating": 5,
    "totalReviews": 1
  }
}
```

Errors: `VALIDATION_ERROR`, `MOSQUE_NOT_FOUND`

### `GET /api/v1/mosques/:id/broadcasts`

Public persisted broadcast-message read used by the Mosque Page preview and the Mosque Broadcast route.

Success `data`:

```json
{
  "items": [
    {
      "id": "uuid",
      "title": "Jummah Parking Update",
      "description": "Overflow parking volunteers will guide arrivals from 12:15 PM this Friday.",
      "publishedAt": "2026-03-27T08:30:00.000Z"
    }
  ]
}
```

Errors: `VALIDATION_ERROR`, `MOSQUE_NOT_FOUND`

### `POST /api/v1/mosques/:id/broadcasts`

Protected admin-only publish route for mosque-page broadcast messages.
Only the admin who created the mosque may publish them.

Request body:

```json
{
  "title": "Jummah Parking Update",
  "message": "Overflow parking volunteers will guide arrivals from 12:15 PM this Friday."
}
```

Success `data`:

```json
{
  "id": "uuid",
  "title": "Jummah Parking Update",
  "description": "Overflow parking volunteers will guide arrivals from 12:15 PM this Friday.",
  "publishedAt": "2026-03-31T09:30:00.000Z"
}
```

Notes:

- This writes into the existing `mosque_broadcast_messages` persistence/read path
- The response shape matches the public broadcast read items so the app can prepend the published message immediately

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `FORBIDDEN`, `MOSQUE_NOT_FOUND`

### `DELETE /api/v1/mosques/:id/broadcasts/:broadcastId`

Protected admin-only lightweight remove route for an already published mosque broadcast message.
Only the admin who created the mosque may remove it.

Success `data`:

```json
{
  "success": true
}
```

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `FORBIDDEN`, `MOSQUE_NOT_FOUND`, `BROADCAST_NOT_FOUND`

## Bookmarks

### `GET /api/v1/bookmarks`

Success `data`:

```json
{
  "items": [
    {
      "id": "uuid",
      "name": "Jamia Masjid Bengaluru",
      "bookmarkedAt": "2026-03-18T05:20:10.193Z"
    }
  ]
}
```

Success `meta.pagination`: same pagination shape as mosque listing.

### `POST /api/v1/bookmarks`

Request body:

```json
{
  "mosqueId": "uuid"
}
```

Success `data`:

```json
{
  "id": "uuid",
  "mosqueId": "uuid",
  "createdAt": "2026-03-18T05:20:10.193Z",
  "status": "created"
}
```

Duplicate bookmark success `data`:

```json
{
  "mosqueId": "uuid",
  "status": "already_bookmarked"
}
```

### `DELETE /api/v1/bookmarks/:mosqueId`

Success `data`:

```json
{
  "success": true
}
```

## Notifications

### `GET /api/v1/notifications/mosques`

Protected persisted read used by the Notifications `My Mosques` tab and the authenticated Home `Others` mosque-alerts card.

Success `data`:

```json
{
  "items": [
    {
      "id": "uuid",
      "name": "Jamia Masjid Bengaluru"
    }
  ]
}
```

Errors: `UNAUTHORIZED`

### `GET /api/v1/notifications/settings`

Protected persisted read used by the mosque notification settings screen.

Query params:

- `mosqueId`

Success `data`:

```json
{
  "mosqueId": "uuid",
  "settings": [
    {
      "title": "Broadcast Messages",
      "description": "Important community updates",
      "isEnabled": true
    }
  ]
}
```

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `MOSQUE_NOT_FOUND`

### `PUT /api/v1/notifications/settings`

Protected route used by the current mosque notification settings screen.

Request body:

```json
{
  "mosqueId": "uuid",
  "settings": [
    {
      "title": "Broadcast Messages",
      "description": "Important community updates",
      "isEnabled": true
    }
  ]
}
```

Success `data`:

```json
{
  "success": true,
  "settings": [
    {
      "title": "Broadcast Messages",
      "description": "Important community updates",
      "isEnabled": true
    }
  ]
}
```

Errors: `VALIDATION_ERROR`, `UNAUTHORIZED`, `MOSQUE_NOT_FOUND`

## Services

### `GET /api/v1/services`

Query params:

- `category`
- `filters?` as comma-separated values

Success `data`:

```json
{
  "services": [
    {
      "name": "Barakah Kitchen",
      "location": "Koramangala, Bengaluru",
      "priceRange": "$$",
      "deliveryInfo": "Delivers in 30-40 mins",
      "rating": 4.8
    }
  ]
}
```

Errors: `VALIDATION_ERROR`
