import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createLocationLookupService,
  GOOGLE_SAFE_NEARBY_RADIUS_KM
} from '../src/services/location-lookup.js';
import { haversineKm } from '../src/utils/geo-distance.js';

function createGooglePlace({ id, name, latitude, longitude, addressLine }) {
  return {
    id,
    displayName: { text: name },
    formattedAddress: addressLine,
    location: {
      latitude,
      longitude
    },
    addressComponents: [
      {
        longText: 'Jacksonville',
        shortText: 'Jacksonville',
        types: ['locality']
      },
      {
        longText: 'Florida',
        shortText: 'FL',
        types: ['administrative_area_level_1']
      },
      {
        longText: 'United States',
        shortText: 'US',
        types: ['country']
      }
    ]
  };
}

test('discoverNearbyMosques chunks large radii into safe Google nearby searches', async () => {
  const origin = {
    latitude: 27.9506,
    longitude: -82.4572
  };
  const visiblePlaces = [
    createGooglePlace({
      id: 'place-near',
      name: 'Masjid Al Noor',
      latitude: origin.latitude,
      longitude: origin.longitude,
      addressLine: '25 Faith Avenue'
    }),
    createGooglePlace({
      id: 'place-far',
      name: 'Regional Islamic Center',
      latitude: origin.latitude + 1.08,
      longitude: origin.longitude,
      addressLine: '90 Unity Drive'
    }),
    createGooglePlace({
      id: 'place-outside',
      name: 'Beyond Radius Mosque',
      latitude: origin.latitude + 2.4,
      longitude: origin.longitude,
      addressLine: '220 Horizon Road'
    })
  ];
  const seenRadiiMeters = [];
  let requestCount = 0;

  const service = createLocationLookupService({
    apiKey: 'test-key',
    fetchImpl: async (_url, options) => {
      requestCount += 1;
      const body = JSON.parse(options.body);
      const center = body.locationRestriction.circle.center;
      const radiusMeters = body.locationRestriction.circle.radius;
      const radiusKm = radiusMeters / 1000;
      seenRadiiMeters.push(radiusMeters);

      const places = visiblePlaces.filter((place) => {
        return haversineKm(
          center.latitude,
          center.longitude,
          place.location.latitude,
          place.location.longitude
        ) <= radiusKm;
      });

      return {
        ok: true,
        async json() {
          return { places };
        }
      };
    }
  });

  const discovered = await service.discoverNearbyMosques({
    latitude: origin.latitude,
    longitude: origin.longitude,
    radiusKm: 241.4016,
    limit: 20
  });

  assert.ok(requestCount > 1);
  assert.ok(
    seenRadiiMeters.every(
      (radiusMeters) => radiusMeters <= GOOGLE_SAFE_NEARBY_RADIUS_KM * 1000
    )
  );
  assert.deepEqual(
    discovered.map((mosque) => mosque.id),
    ['google:place-near', 'google:place-far']
  );
});

test('discoverNearbyMosques keeps partial results when some Google chunks fail', async () => {
  const origin = {
    latitude: 27.9506,
    longitude: -82.4572
  };
  let requestCount = 0;

  const service = createLocationLookupService({
    apiKey: 'test-key',
    fetchImpl: async (_url, options) => {
      requestCount += 1;
      const body = JSON.parse(options.body);
      const center = body.locationRestriction.circle.center;

      if (requestCount === 2) {
        throw new Error('temporary nearby failure');
      }

      const nearPlace = createGooglePlace({
        id: 'place-near',
        name: 'Masjid Al Noor',
        latitude: origin.latitude,
        longitude: origin.longitude,
        addressLine: '25 Faith Avenue'
      });

      const radiusKm = body.locationRestriction.circle.radius / 1000;
      const isVisible =
        haversineKm(
          center.latitude,
          center.longitude,
          nearPlace.location.latitude,
          nearPlace.location.longitude
        ) <= radiusKm;

      return {
        ok: true,
        async json() {
          return { places: isVisible ? [nearPlace] : [] };
        }
      };
    }
  });

  const discovered = await service.discoverNearbyMosques({
    latitude: origin.latitude,
    longitude: origin.longitude,
    radiusKm: 80.4672,
    limit: 20
  });

  assert.ok(requestCount > 1);
  assert.deepEqual(
    discovered.map((mosque) => mosque.id),
    ['google:place-near']
  );
});
