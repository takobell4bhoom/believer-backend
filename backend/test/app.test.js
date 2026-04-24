import test from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';

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
