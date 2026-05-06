import test from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';
import { pool } from '../src/db/pool.js';

function createNearbyRow({
  id,
  name,
  latitude,
  longitude,
  addressLine = '15 Mercy Road',
  city = 'Jacksonville',
  state = 'FL',
  country = 'US',
  isVerified = true
}) {
  return {
    id,
    name,
    address_line: addressLine,
    city,
    state,
    country,
    postal_code: '',
    latitude,
    longitude,
    image_url: '',
    image_urls: [],
    sect: 'Community',
    contact_name: '',
    contact_phone: '',
    contact_email: '',
    website_url: '',
    duhr_time: '01:15 PM',
    asr_time: '04:45 PM',
    facilities: [],
    is_verified: isVerified,
    average_rating: 4.6,
    total_reviews: 3,
    classes: [],
    events: [],
    is_bookmarked: false,
    can_edit: false
  };
}

test('GET / returns api metadata', async () => {
  const app = buildApp();
  const response = await app.inject({ method: 'GET', url: '/' });

  assert.equal(response.statusCode, 200);
  const body = response.json();
  assert.equal(body.name, 'Believer Backend API');
  assert.equal(body.status, 'ok');
  assert.equal(body.docs.openapi, '/docs/openapi.yaml');

  await app.close();
});

test('GET /health returns status ok', async () => {
  const app = buildApp();
  const response = await app.inject({ method: 'GET', url: '/health' });

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.json(), { status: 'ok' });

  await app.close();
});

test('GET /api/v1/health returns status ok', async () => {
  const app = buildApp();
  const response = await app.inject({ method: 'GET', url: '/api/v1/health' });

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.json(), { status: 'ok' });

  await app.close();
});

test('GET /api/v1/services returns enriched service payloads', async () => {
  const app = buildApp({
    servicesCatalog: {
      isKnownServiceCategory(category) {
        return category === 'Halal Food';
      },
      async fetchServices() {
        return [
          {
            id: 'service-3',
            category: 'Halal Food',
            name: 'Noor Catering',
            location: 'Frazer Town, Bengaluru',
            priceRange: '$$$',
            deliveryInfo: 'Large orders delivered same day',
            rating: 4.9,
            reviewCount: 12,
            websiteUrl: 'www.noorcatering.com',
            servicesOffered: ['Wedding and banquet catering'],
            logo: {
              fileName: 'noor.png',
              contentType: 'image/png',
              bytesBase64: 'bm9vci1sb2dv',
              tileBackgroundColor: 4293512350
            },
            publishedAt: '2026-04-09T10:00:00.000Z'
          }
        ];
      }
    }
  });
  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Halal%20Food&filters=Top%20Rated'
  });

  assert.equal(response.statusCode, 200);
  const body = response.json();
  assert.equal(body.error, null);
  assert.ok(Array.isArray(body.data.services));
  assert.equal(body.data.services[0].id, 'service-3');
  assert.equal(body.data.services[0].websiteUrl, 'www.noorcatering.com');
  assert.equal(body.data.services[0].reviewCount, 12);
  assert.equal(body.data.services[0].logo.fileName, 'noor.png');
  assert.equal(body.data.services[0].publishedAt, '2026-04-09T10:00:00.000Z');
  assert.ok(Array.isArray(body.data.services[0].servicesOffered));
  assert.ok(body.data.services[0].servicesOffered.length > 0);

  await app.close();
});

test('GET /api/v1/services rejects unsupported public categories', async () => {
  let fetchAttempted = false;
  const app = buildApp({
    servicesCatalog: {
      isKnownServiceCategory() {
        return false;
      },
      async fetchServices() {
        fetchAttempted = true;
        return [];
      }
    }
  });

  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/services?category=Health%20%26%20Wellness'
  });

  assert.equal(response.statusCode, 400);
  assert.equal(response.json().error.code, 'VALIDATION_ERROR');
  assert.equal(fetchAttempted, false);

  await app.close();
});

test('GET /api/v1/mosques/location-resolve returns resolved coordinates', async () => {
  const app = buildApp({
    locationLookupService: {
      async resolve(query) {
        assert.equal(query, 'Tampa, Florida');
        return {
          label: 'Tampa, FL, USA',
          latitude: 27.9506,
          longitude: -82.4572,
          provider: 'google_geocoding'
        };
      }
    }
  });

  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/location-resolve?query=Tampa%2C%20Florida'
  });

  assert.equal(response.statusCode, 200);
  const body = response.json();
  assert.equal(body.error, null);
  assert.equal(body.data.label, 'Tampa, FL, USA');
  assert.equal(body.data.latitude, 27.9506);
  assert.equal(body.data.longitude, -82.4572);
  assert.equal(body.data.provider, 'google_geocoding');
  assert.equal(body.data.resolved, true);

  await app.close();
});

test('GET /api/v1/mosques/location-resolve returns an honest unresolved payload', async () => {
  const app = buildApp({
    locationLookupService: {
      async resolve(query) {
        assert.equal(query, 'Unknown Place');
        return null;
      }
    }
  });

  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/location-resolve?query=Unknown%20Place'
  });

  assert.equal(response.statusCode, 200);
  const body = response.json();
  assert.equal(body.error, null);
  assert.equal(body.data.label, 'Unknown Place');
  assert.equal(body.data.latitude, null);
  assert.equal(body.data.longitude, null);
  assert.equal(body.data.provider, null);
  assert.equal(body.data.resolved, false);

  await app.close();
});

test('GET /api/v1/mosques/location-suggest returns typed suggestions with coordinates', async () => {
  const app = buildApp({
    locationLookupService: {
      async suggest(query, options) {
        assert.equal(query, 'Tampa');
        assert.equal(options.limit, 5);
        return [
          {
            label: 'Downtown Tampa, FL, USA',
            primaryText: 'Downtown Tampa',
            secondaryText: 'FL, USA',
            latitude: 27.9506,
            longitude: -82.4572,
            provider: 'google_places'
          },
          {
            label: 'Tampa Heights, Tampa, FL, USA',
            primaryText: 'Tampa Heights',
            secondaryText: 'Tampa, FL, USA',
            latitude: 27.9619,
            longitude: -82.4631,
            provider: 'google_places'
          }
        ];
      }
    }
  });

  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/location-suggest?query=Tampa'
  });

  assert.equal(response.statusCode, 200);
  const body = response.json();
  assert.equal(body.error, null);
  assert.deepEqual(body.data.items, [
    {
      label: 'Downtown Tampa, FL, USA',
      primaryText: 'Downtown Tampa',
      secondaryText: 'FL, USA',
      latitude: 27.9506,
      longitude: -82.4572,
      provider: 'google_places'
    },
    {
      label: 'Tampa Heights, Tampa, FL, USA',
      primaryText: 'Tampa Heights',
      secondaryText: 'Tampa, FL, USA',
      latitude: 27.9619,
      longitude: -82.4631,
      provider: 'google_places'
    }
  ]);

  await app.close();
});

test('GET /api/v1/mosques/location-reverse returns a reverse-geocoded label', async () => {
  const app = buildApp({
    locationLookupService: {
      async resolve() {
        throw new Error('resolve should not be called');
      },
      async reverseResolve(latitude, longitude) {
        assert.equal(latitude, 27.9506);
        assert.equal(longitude, -82.4572);
        return {
          label: 'Downtown Tampa, FL, USA',
          latitude,
          longitude,
          provider: 'google_geocoding'
        };
      }
    }
  });

  const response = await app.inject({
    method: 'GET',
    url: '/api/v1/mosques/location-reverse?latitude=27.9506&longitude=-82.4572'
  });

  assert.equal(response.statusCode, 200);
  const body = response.json();
  assert.equal(body.error, null);
  assert.equal(body.data.label, 'Downtown Tampa, FL, USA');
  assert.equal(body.data.latitude, 27.9506);
  assert.equal(body.data.longitude, -82.4572);
  assert.equal(body.data.provider, 'google_geocoding');
  assert.equal(body.data.resolved, true);

  await app.close();
});

test(
  'GET /api/v1/mosques/nearby keeps DB mosques, merges Google mosques, and exposes source metadata',
  { concurrency: false },
  async () => {
    const originalQuery = pool.query;
    pool.query = async () => ({
      rows: [
        createNearbyRow({
          id: 'db-mosque-1',
          name: 'Northside Community Mosque',
          latitude: 27.9506,
          longitude: -82.4572
        })
      ]
    });

    const app = buildApp({
      locationLookupService: {
        async discoverNearbyMosques({ latitude, longitude, radiusKm, limit }) {
          assert.equal(latitude, 27.9506);
          assert.equal(longitude, -82.4572);
          assert.equal(radiusKm, 5);
          assert.equal(limit, 2000);
          return [
            {
              id: 'google:place-1',
              externalPlaceId: 'place-1',
              name: 'Masjid Al Noor',
              addressLine: '25 Faith Avenue',
              city: 'Jacksonville',
              state: 'FL',
              country: 'US',
              postalCode: '',
              latitude: 27.9521,
              longitude: -82.4568,
              imageUrl: '',
              imageUrls: [],
              sect: 'Community',
              contactName: '',
              contactPhone: '',
              contactEmail: '',
              websiteUrl: '',
              duhrTime: '',
              asrTime: '',
              facilities: [],
              isVerified: false,
              averageRating: 0,
              totalReviews: 0,
              classes: [],
              events: [],
              classTags: [],
              eventTags: [],
              distanceKm: 0.18,
              isBookmarked: false,
              canEdit: false,
              sourceType: 'google_listed'
            }
          ];
        }
      }
    });

    try {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/mosques/nearby?latitude=27.9506&longitude=-82.4572&radius=5&limit=2'
      });

      assert.equal(response.statusCode, 200);
      const body = response.json();
      assert.equal(body.error, null);
      assert.equal(body.meta.pagination.page, 1);
      assert.equal(body.meta.pagination.limit, 2);
      assert.equal(body.meta.pagination.total, 2);
      assert.equal(body.meta.pagination.hasMore, false);
      assert.deepEqual(
        body.data.items.map((item) => [item.id, item.sourceType]),
        [
          ['db-mosque-1', 'believer_db'],
          ['google:place-1', 'google_listed']
        ]
      );
    } finally {
      pool.query = originalQuery;
      await app.close();
    }
  }
);

test(
  'GET /api/v1/mosques/nearby prefers the DB-backed mosque when a Google result looks duplicated',
  { concurrency: false },
  async () => {
    const originalQuery = pool.query;
    pool.query = async () => ({
      rows: [
        createNearbyRow({
          id: 'db-mosque-1',
          name: 'Masjid Al Noor',
          latitude: 27.9506,
          longitude: -82.4572,
          addressLine: '15 Mercy Road'
        })
      ]
    });

    const app = buildApp({
      locationLookupService: {
        async discoverNearbyMosques() {
          return [
            {
              id: 'google:place-duplicate',
              externalPlaceId: 'place-duplicate',
              name: 'Masjid Al Noor Mosque',
              addressLine: '15 Mercy Road',
              city: 'Jacksonville',
              state: 'FL',
              country: 'US',
              postalCode: '',
              latitude: 27.9507,
              longitude: -82.4573,
              imageUrl: '',
              imageUrls: [],
              sect: 'Community',
              contactName: '',
              contactPhone: '',
              contactEmail: '',
              websiteUrl: '',
              duhrTime: '',
              asrTime: '',
              facilities: [],
              isVerified: false,
              averageRating: 0,
              totalReviews: 0,
              classes: [],
              events: [],
              classTags: [],
              eventTags: [],
              distanceKm: 0.02,
              isBookmarked: false,
              canEdit: false,
              sourceType: 'google_listed'
            }
          ];
        }
      }
    });

    try {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/mosques/nearby?latitude=27.9506&longitude=-82.4572&radius=5&limit=5'
      });

      assert.equal(response.statusCode, 200);
      const payload = response.json();
      const items = payload.data.items;
      assert.equal(items.length, 1);
      assert.equal(items[0].id, 'db-mosque-1');
      assert.equal(items[0].sourceType, 'believer_db');
      assert.equal(payload.meta.pagination.hasMore, false);
    } finally {
      pool.query = originalQuery;
      await app.close();
    }
  }
);

test(
  'GET /api/v1/mosques/nearby keeps far Google mosques on large radius requests and dedupes them',
  { concurrency: false },
  async () => {
    const originalQuery = pool.query;
    pool.query = async () => ({
      rows: [
        createNearbyRow({
          id: 'db-mosque-1',
          name: 'Northside Community Mosque',
          latitude: 27.9506,
          longitude: -82.4572
        })
      ]
    });

    const app = buildApp({
      locationLookupService: {
        async discoverNearbyMosques({ radiusKm }) {
          assert.equal(radiusKm, 160.9344);
          return [
            {
              id: 'google:place-near',
              externalPlaceId: 'place-near',
              name: 'Masjid Al Noor',
              addressLine: '25 Faith Avenue',
              city: 'Jacksonville',
              state: 'FL',
              country: 'US',
              postalCode: '',
              latitude: 27.9521,
              longitude: -82.4568,
              imageUrl: '',
              imageUrls: [],
              sect: 'Community',
              contactName: '',
              contactPhone: '',
              contactEmail: '',
              websiteUrl: '',
              duhrTime: '',
              asrTime: '',
              facilities: [],
              isVerified: false,
              averageRating: 0,
              totalReviews: 0,
              classes: [],
              events: [],
              classTags: [],
              eventTags: [],
              distanceKm: 0.18,
              isBookmarked: false,
              canEdit: false,
              sourceType: 'google_listed'
            },
            {
              id: 'google:place-far',
              externalPlaceId: 'place-far',
              name: 'Regional Islamic Center',
              addressLine: '90 Unity Drive',
              city: 'Lakeland',
              state: 'FL',
              country: 'US',
              postalCode: '',
              latitude: 28.721,
              longitude: -82.4572,
              imageUrl: '',
              imageUrls: [],
              sect: 'Community',
              contactName: '',
              contactPhone: '',
              contactEmail: '',
              websiteUrl: '',
              duhrTime: '',
              asrTime: '',
              facilities: [],
              isVerified: false,
              averageRating: 0,
              totalReviews: 0,
              classes: [],
              events: [],
              classTags: [],
              eventTags: [],
              distanceKm: 85.7,
              isBookmarked: false,
              canEdit: false,
              sourceType: 'google_listed'
            },
            {
              id: 'google:place-far',
              externalPlaceId: 'place-far',
              name: 'Regional Islamic Center',
              addressLine: '90 Unity Drive',
              city: 'Lakeland',
              state: 'FL',
              country: 'US',
              postalCode: '',
              latitude: 28.721,
              longitude: -82.4572,
              imageUrl: '',
              imageUrls: [],
              sect: 'Community',
              contactName: '',
              contactPhone: '',
              contactEmail: '',
              websiteUrl: '',
              duhrTime: '',
              asrTime: '',
              facilities: [],
              isVerified: false,
              averageRating: 0,
              totalReviews: 0,
              classes: [],
              events: [],
              classTags: [],
              eventTags: [],
              distanceKm: 85.7,
              isBookmarked: false,
              canEdit: false,
              sourceType: 'google_listed'
            }
          ];
        }
      }
    });

    try {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/mosques/nearby?latitude=27.9506&longitude=-82.4572&radius=160.9344&limit=10'
      });

      assert.equal(response.statusCode, 200);
      const payload = response.json();
      assert.deepEqual(
        payload.data.items.map((item) => item.id),
        ['db-mosque-1', 'google:place-near', 'google:place-far']
      );
      assert.equal(payload.meta.pagination.total, 3);
      assert.equal(payload.meta.pagination.hasMore, false);
    } finally {
      pool.query = originalQuery;
      await app.close();
    }
  }
);

test(
  'GET /api/v1/mosques/nearby returns DB results when Google nearby lookup fails',
  { concurrency: false },
  async () => {
    const originalQuery = pool.query;
    pool.query = async () => ({
      rows: [
        createNearbyRow({
          id: 'db-mosque-1',
          name: 'Northside Community Mosque',
          latitude: 27.9506,
          longitude: -82.4572
        })
      ]
    });

    const app = buildApp({
      locationLookupService: {
        async discoverNearbyMosques() {
          throw new Error('google nearby is temporarily unavailable');
        }
      }
    });

    try {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/mosques/nearby?latitude=27.9506&longitude=-82.4572&radius=80.4672&limit=5'
      });

      assert.equal(response.statusCode, 200);
      const payload = response.json();
      assert.deepEqual(payload.data.items.map((item) => item.id), ['db-mosque-1']);
      assert.equal(payload.meta.pagination.hasMore, false);
    } finally {
      pool.query = originalQuery;
      await app.close();
    }
  }
);

test(
  'GET /api/v1/mosques/nearby returns an error instead of a false empty state when all lookup sources fail',
  { concurrency: false },
  async () => {
    const originalQuery = pool.query;
    pool.query = async () => ({ rows: [] });

    const app = buildApp({
      locationLookupService: {
        async discoverNearbyMosques() {
          throw new Error('google nearby is temporarily unavailable');
        }
      }
    });

    try {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/mosques/nearby?latitude=27.9506&longitude=-82.4572&radius=80.4672&limit=5'
      });

      assert.equal(response.statusCode, 502);
      assert.equal(
        response.json().error.code,
        'NEARBY_LOOKUP_UNAVAILABLE'
      );
    } finally {
      pool.query = originalQuery;
      await app.close();
    }
  }
);

test(
  'GET /api/v1/mosques/nearby accepts the supported mile-based radius conversions',
  { concurrency: false },
  async () => {
    const originalQuery = pool.query;
    pool.query = async () => ({ rows: [] });
    const seenRadiusKm = [];

    const app = buildApp({
      locationLookupService: {
        async discoverNearbyMosques({ radiusKm }) {
          seenRadiusKm.push(radiusKm);
          return [];
        }
      }
    });

    try {
      const cases = [
        { miles: 30, radiusKm: 48.28032 },
        { miles: 50, radiusKm: 80.4672 },
        { miles: 100, radiusKm: 160.9344 },
        { miles: 150, radiusKm: 241.4016 }
      ];

      for (const { radiusKm } of cases) {
        const response = await app.inject({
          method: 'GET',
          url: `/api/v1/mosques/nearby?latitude=27.9506&longitude=-82.4572&radius=${radiusKm}&limit=5`
        });

        assert.equal(response.statusCode, 200);
        assert.deepEqual(response.json().data.items, []);
      }

      assert.deepEqual(
        seenRadiusKm,
        cases.map(({ radiusKm }) => radiusKm)
      );
    } finally {
      pool.query = originalQuery;
      await app.close();
    }
  }
);

test(
  'GET /api/v1/mosques/nearby paginates merged DB and Google mosques without duplicates across pages',
  { concurrency: false },
  async () => {
    const originalQuery = pool.query;
    pool.query = async () => ({
      rows: [
        createNearbyRow({
          id: 'db-mosque-1',
          name: 'Alpha Mosque',
          latitude: 27.9506,
          longitude: -82.4572
        }),
        createNearbyRow({
          id: 'db-mosque-2',
          name: 'Bravo Mosque',
          latitude: 27.952,
          longitude: -82.4572
        })
      ]
    });

    const app = buildApp({
      locationLookupService: {
        async discoverNearbyMosques() {
          return [
            {
              id: 'google:place-duplicate',
              externalPlaceId: 'place-duplicate',
              name: 'Alpha Mosque Masjid',
              addressLine: '15 Mercy Road',
              city: 'Jacksonville',
              state: 'FL',
              country: 'US',
              postalCode: '',
              latitude: 27.95065,
              longitude: -82.45725,
              imageUrl: '',
              imageUrls: [],
              sect: 'Community',
              contactName: '',
              contactPhone: '',
              contactEmail: '',
              websiteUrl: '',
              duhrTime: '',
              asrTime: '',
              facilities: [],
              isVerified: false,
              averageRating: 0,
              totalReviews: 0,
              classes: [],
              events: [],
              classTags: [],
              eventTags: [],
              distanceKm: 0.02,
              isBookmarked: false,
              canEdit: false,
              sourceType: 'google_listed'
            },
            {
              id: 'google:place-1',
              externalPlaceId: 'place-1',
              name: 'Charlie Mosque',
              addressLine: '25 Faith Avenue',
              city: 'Jacksonville',
              state: 'FL',
              country: 'US',
              postalCode: '',
              latitude: 27.953,
              longitude: -82.4572,
              imageUrl: '',
              imageUrls: [],
              sect: 'Community',
              contactName: '',
              contactPhone: '',
              contactEmail: '',
              websiteUrl: '',
              duhrTime: '',
              asrTime: '',
              facilities: [],
              isVerified: false,
              averageRating: 0,
              totalReviews: 0,
              classes: [],
              events: [],
              classTags: [],
              eventTags: [],
              distanceKm: 0.27,
              isBookmarked: false,
              canEdit: false,
              sourceType: 'google_listed'
            },
            {
              id: 'google:place-2',
              externalPlaceId: 'place-2',
              name: 'Delta Mosque',
              addressLine: '40 Crescent Lane',
              city: 'Jacksonville',
              state: 'FL',
              country: 'US',
              postalCode: '',
              latitude: 27.955,
              longitude: -82.4572,
              imageUrl: '',
              imageUrls: [],
              sect: 'Community',
              contactName: '',
              contactPhone: '',
              contactEmail: '',
              websiteUrl: '',
              duhrTime: '',
              asrTime: '',
              facilities: [],
              isVerified: false,
              averageRating: 0,
              totalReviews: 0,
              classes: [],
              events: [],
              classTags: [],
              eventTags: [],
              distanceKm: 0.49,
              isBookmarked: false,
              canEdit: false,
              sourceType: 'google_listed'
            }
          ];
        }
      }
    });

    try {
      const firstPage = await app.inject({
        method: 'GET',
        url: '/api/v1/mosques/nearby?latitude=27.9506&longitude=-82.4572&radius=5&page=1&limit=2'
      });
      const secondPage = await app.inject({
        method: 'GET',
        url: '/api/v1/mosques/nearby?latitude=27.9506&longitude=-82.4572&radius=5&page=2&limit=2'
      });

      assert.equal(firstPage.statusCode, 200);
      assert.equal(secondPage.statusCode, 200);

      const firstPayload = firstPage.json();
      const secondPayload = secondPage.json();
      assert.deepEqual(
        firstPayload.data.items.map((item) => item.id),
        ['db-mosque-1', 'db-mosque-2']
      );
      assert.deepEqual(
        secondPayload.data.items.map((item) => item.id),
        ['google:place-1', 'google:place-2']
      );
      assert.equal(firstPayload.meta.pagination.total, 4);
      assert.equal(firstPayload.meta.pagination.hasMore, true);
      assert.equal(secondPayload.meta.pagination.total, 4);
      assert.equal(secondPayload.meta.pagination.hasMore, false);
    } finally {
      pool.query = originalQuery;
      await app.close();
    }
  }
);

test(
  'GET /api/v1/mosques/nearby keeps wide-radius responses batched instead of returning every mosque at once',
  { concurrency: false },
  async () => {
    const originalQuery = pool.query;
    pool.query = async () => ({
      rows: Array.from({ length: 25 }, (_, index) =>
        createNearbyRow({
          id: `db-mosque-${index + 1}`,
          name: `Wide Radius Mosque ${index + 1}`,
          latitude: 27.9506 + (index * 0.001),
          longitude: -82.4572
        })
      )
    });

    const app = buildApp({
      locationLookupService: {
        async discoverNearbyMosques() {
          return [];
        }
      }
    });

    try {
      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/mosques/nearby?latitude=27.9506&longitude=-82.4572&radius=160.9344&page=1&limit=20'
      });

      assert.equal(response.statusCode, 200);
      const payload = response.json();
      assert.equal(payload.data.items.length, 20);
      assert.equal(payload.meta.pagination.page, 1);
      assert.equal(payload.meta.pagination.limit, 20);
      assert.equal(payload.meta.pagination.total, 25);
      assert.equal(payload.meta.pagination.hasMore, true);
    } finally {
      pool.query = originalQuery;
      await app.close();
    }
  }
);
