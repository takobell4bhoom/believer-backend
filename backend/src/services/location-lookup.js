import { env } from '../config/env.js';
import { haversineKm } from '../utils/geo-distance.js';
import { MOSQUE_SOURCE_TYPES } from './mosque-nearby.js';

const GOOGLE_GEOCODE_ENDPOINT = 'https://maps.googleapis.com/maps/api/geocode/json';
const GOOGLE_PLACE_AUTOCOMPLETE_ENDPOINT =
  'https://maps.googleapis.com/maps/api/place/autocomplete/json';
const GOOGLE_PLACE_DETAILS_ENDPOINT =
  'https://maps.googleapis.com/maps/api/place/details/json';
const GOOGLE_NEARBY_SEARCH_ENDPOINT =
  'https://places.googleapis.com/v1/places:searchNearby';

export function createLocationLookupService({
  apiKey = env.GOOGLE_MAPS_API_KEY,
  fetchImpl = globalThis.fetch
} = {}) {
  function assertConfigured() {
    if (!apiKey) {
      throw new Error('Google Maps API key is not configured');
    }

    if (typeof fetchImpl !== 'function') {
      throw new Error('Fetch is not available for geocoding');
    }
  }

  async function requestGoogleJson(
    endpoint,
    {
      searchParams,
      method = 'GET',
      headers = {},
      body
    } = {}
  ) {
    assertConfigured();

    const url = new URL(endpoint);
    if (searchParams) {
      for (const [key, value] of Object.entries(searchParams)) {
        url.searchParams.set(key, value);
      }
      url.searchParams.set('key', apiKey);
    }

    const response = await fetchImpl(url, {
      method,
      headers: searchParams
        ? headers
        : {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            ...headers
          },
      body
    });
    if (!response.ok) {
      throw new Error(`Geocoding request failed (${response.status})`);
    }

    return response.json();
  }

  async function lookup(searchParams) {
    const payload = await requestGoogleJson(
      GOOGLE_GEOCODE_ENDPOINT,
      {
        searchParams
      }
    );
    if (payload?.status === 'ZERO_RESULTS') {
      return null;
    }

    if (payload?.status !== 'OK') {
      throw new Error(`Geocoding failed with status ${payload?.status ?? 'UNKNOWN'}`);
    }

    const firstResult = Array.isArray(payload.results) ? payload.results[0] : null;
    const geometry = firstResult?.geometry?.location;
    const latitude = Number(geometry?.lat);
    const longitude = Number(geometry?.lng);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      throw new Error('Geocoding response did not include valid coordinates');
    }

    const label =
      typeof firstResult?.formatted_address === 'string' &&
          firstResult.formatted_address.trim().length > 0
        ? firstResult.formatted_address.trim()
        : null;

    return {
      label,
      latitude,
      longitude,
      provider: 'google_geocoding'
    };
  }

  return {
    async suggest(query, { limit = 5 } = {}) {
      const normalizedQuery = typeof query === 'string' ? query.trim() : '';
      if (!normalizedQuery) {
        return [];
      }

      const normalizedLimit = Number.isFinite(limit)
        ? Math.max(1, Math.min(8, Math.trunc(limit)))
        : 5;
      const payload = await requestGoogleJson(
        GOOGLE_PLACE_AUTOCOMPLETE_ENDPOINT,
        {
          searchParams: {
            input: normalizedQuery
          }
        }
      );

      if (payload?.status === 'ZERO_RESULTS') {
        return [];
      }

      if (payload?.status !== 'OK') {
        throw new Error(
          `Places autocomplete failed with status ${payload?.status ?? 'UNKNOWN'}`
        );
      }

      const predictions = Array.isArray(payload.predictions)
        ? payload.predictions.slice(0, normalizedLimit)
        : [];
      const places = await Promise.all(
        predictions.map(async (prediction) => {
          const placeId =
            typeof prediction?.place_id === 'string' ? prediction.place_id : '';
          if (!placeId) {
            return null;
          }

          const detailsPayload = await requestGoogleJson(
            GOOGLE_PLACE_DETAILS_ENDPOINT,
            {
              searchParams: {
                place_id: placeId,
                fields: 'formatted_address,geometry'
              }
            }
          );
          if (detailsPayload?.status !== 'OK') {
            return null;
          }

          const result = detailsPayload.result;
          const geometry = result?.geometry?.location;
          const latitude = Number(geometry?.lat);
          const longitude = Number(geometry?.lng);
          if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
            return null;
          }

          const description =
            typeof prediction?.description === 'string'
              ? prediction.description.trim()
              : '';
          const formattedAddress =
            typeof result?.formatted_address === 'string'
              ? result.formatted_address.trim()
              : '';
          const structuredFormatting =
            prediction?.structured_formatting ?? {};
          const primaryText =
            typeof structuredFormatting?.main_text === 'string'
              ? structuredFormatting.main_text.trim()
              : '';
          const secondaryText =
            typeof structuredFormatting?.secondary_text === 'string'
              ? structuredFormatting.secondary_text.trim()
              : '';
          const label = formattedAddress || description || primaryText;
          if (!label) {
            return null;
          }

          return {
            placeId,
            label,
            primaryText: primaryText || label,
            secondaryText: secondaryText || null,
            latitude,
            longitude,
            provider: 'google_places'
          };
        })
      );

      return places.filter(Boolean);
    },

    async resolve(query) {
      const normalizedQuery = typeof query === 'string' ? query.trim() : '';
      if (!normalizedQuery) {
        return null;
      }

      const resolved = await lookup({ address: normalizedQuery });
      if (resolved == null) {
        return null;
      }

      return {
        ...resolved,
        label: resolved.label ?? normalizedQuery
      };
    },

    async reverseResolve(latitude, longitude) {
      const normalizedLatitude = Number(latitude);
      const normalizedLongitude = Number(longitude);
      if (!Number.isFinite(normalizedLatitude) || !Number.isFinite(normalizedLongitude)) {
        return null;
      }

      return lookup({
        latlng: `${normalizedLatitude},${normalizedLongitude}`
      });
    },

    async discoverNearbyMosques({
      latitude,
      longitude,
      radiusKm,
      limit
    }) {
      const normalizedLatitude = Number(latitude);
      const normalizedLongitude = Number(longitude);
      const normalizedRadiusKm = Number(radiusKm);
      const normalizedLimit = Number.isFinite(limit)
        ? Math.max(1, Math.min(20, Math.trunc(limit)))
        : 20;

      if (
        !Number.isFinite(normalizedLatitude) ||
        !Number.isFinite(normalizedLongitude) ||
        !Number.isFinite(normalizedRadiusKm)
      ) {
        return [];
      }

      const payload = await requestGoogleJson(GOOGLE_NEARBY_SEARCH_ENDPOINT, {
        method: 'POST',
        headers: {
          'X-Goog-FieldMask': [
            'places.id',
            'places.displayName',
            'places.formattedAddress',
            'places.addressComponents',
            'places.location',
            'places.websiteUri',
            'places.internationalPhoneNumber'
          ].join(',')
        },
        body: JSON.stringify({
          includedTypes: ['mosque'],
          maxResultCount: normalizedLimit,
          rankPreference: 'DISTANCE',
          locationRestriction: {
            circle: {
              center: {
                latitude: normalizedLatitude,
                longitude: normalizedLongitude
              },
              radius: Math.max(1, Math.round(normalizedRadiusKm * 1000))
            }
          }
        })
      });

      const places = Array.isArray(payload?.places) ? payload.places : [];
      return places
        .map((place) => {
          const placeId = typeof place?.id === 'string' ? place.id.trim() : '';
          const name = typeof place?.displayName?.text === 'string'
            ? place.displayName.text.trim()
            : '';
          const latitudeValue = Number(place?.location?.latitude);
          const longitudeValue = Number(place?.location?.longitude);
          if (!placeId || !name || !Number.isFinite(latitudeValue) || !Number.isFinite(longitudeValue)) {
            return null;
          }

          const addressComponents = Array.isArray(place?.addressComponents)
            ? place.addressComponents
            : [];
          const city =
            addressComponents.find((component) =>
              Array.isArray(component?.types) && component.types.includes('locality')
            )?.longText ??
            '';
          const state =
            addressComponents.find((component) =>
              Array.isArray(component?.types) &&
                component.types.includes('administrative_area_level_1')
            )?.shortText ??
            '';
          const country =
            addressComponents.find((component) =>
              Array.isArray(component?.types) && component.types.includes('country')
            )?.longText ??
            '';

          return {
            id: `google:${placeId}`,
            externalPlaceId: placeId,
            name,
            addressLine:
              typeof place?.formattedAddress === 'string'
                ? place.formattedAddress.trim()
                : '',
            city: typeof city === 'string' ? city.trim() : '',
            state: typeof state === 'string' ? state.trim() : '',
            country: typeof country === 'string' ? country.trim() : '',
            postalCode: '',
            latitude: latitudeValue,
            longitude: longitudeValue,
            imageUrl: '',
            imageUrls: [],
            sect: 'Community',
            contactName: '',
            contactPhone:
              typeof place?.internationalPhoneNumber === 'string'
                ? place.internationalPhoneNumber.trim()
                : '',
            contactEmail: '',
            websiteUrl:
              typeof place?.websiteUri === 'string' ? place.websiteUri.trim() : '',
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
            distanceKm: Number(
              haversineKm(
                normalizedLatitude,
                normalizedLongitude,
                latitudeValue,
                longitudeValue
              ).toFixed(3)
            ),
            isBookmarked: false,
            canEdit: false,
            sourceType: MOSQUE_SOURCE_TYPES.googleListed
          };
        })
        .filter(Boolean)
        .sort((left, right) => left.distanceKm - right.distanceKm);
    }
  };
}
