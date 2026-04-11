import '../../services/api_client.dart';
import 'business_registration_models.dart';

class BusinessRegistrationService {
  const BusinessRegistrationService();

  Future<BusinessRegistrationDraft?> fetchLatestListingStatus({
    required String bearerToken,
  }) async {
    final response = await ApiClient.get(
      '/api/v1/business-listings/me',
      bearerToken: bearerToken,
    );
    return _parseListing(response);
  }

  Future<BusinessRegistrationDraft> saveDraft({
    required BusinessRegistrationDraft draft,
    required String bearerToken,
  }) async {
    final response = await ApiClient.put(
      '/api/v1/business-listings/draft',
      bearerToken: bearerToken,
      body: draft.toRequestJson(),
    );

    final listing = _parseListing(response);
    if (listing == null) {
      throw ApiException('Invalid business listing response.');
    }
    return listing;
  }

  Future<BusinessRegistrationDraft> submitForReview({
    required BusinessRegistrationDraft draft,
    required String bearerToken,
  }) async {
    final response = await ApiClient.post(
      '/api/v1/business-listings/submit',
      bearerToken: bearerToken,
      body: draft.toRequestJson(),
    );

    final listing = _parseListing(response);
    if (listing == null) {
      throw ApiException('Invalid business listing response.');
    }
    return listing;
  }

  BusinessRegistrationDraft? _parseListing(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final listing = data['listing'];
    if (listing == null) {
      return null;
    }
    if (listing is! Map) {
      throw ApiException('Invalid business listing response.');
    }

    return BusinessRegistrationDraft.fromApiListing(
      listing.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }
}
