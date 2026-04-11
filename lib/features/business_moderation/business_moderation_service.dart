import '../../services/api_client.dart';

class BusinessModerationSubmitter {
  const BusinessModerationSubmitter({
    required this.id,
    required this.fullName,
    required this.email,
  });

  final String id;
  final String fullName;
  final String email;
}

class BusinessModerationListing {
  const BusinessModerationListing({
    required this.id,
    required this.status,
    required this.businessName,
    required this.tagline,
    required this.description,
    required this.city,
    required this.businessEmail,
    required this.phone,
    required this.submittedAt,
    required this.submitter,
    this.rejectionReason,
  });

  final String id;
  final String status;
  final String businessName;
  final String tagline;
  final String description;
  final String city;
  final String businessEmail;
  final String phone;
  final DateTime? submittedAt;
  final BusinessModerationSubmitter submitter;
  final String? rejectionReason;

  factory BusinessModerationListing.fromJson(Map<String, dynamic> json) {
    final basicDetails =
        (json['basicDetails'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final contactDetails =
        (json['contactDetails'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final submitterJson =
        (json['submitter'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    return BusinessModerationListing(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      businessName: basicDetails['businessName'] as String? ?? '',
      tagline: basicDetails['tagline'] as String? ?? '',
      description: basicDetails['description'] as String? ?? '',
      city: contactDetails['city'] as String? ?? '',
      businessEmail: contactDetails['businessEmail'] as String? ?? '',
      phone: contactDetails['phone'] as String? ?? '',
      submittedAt: _parseDateTime(json['submittedAt']),
      submitter: BusinessModerationSubmitter(
        id: submitterJson['id'] as String? ?? '',
        fullName: submitterJson['fullName'] as String? ?? '',
        email: submitterJson['email'] as String? ?? '',
      ),
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }
}

class BusinessModerationService {
  const BusinessModerationService();

  Future<List<BusinessModerationListing>> fetchPendingListings({
    required String bearerToken,
  }) async {
    final response = await ApiClient.get(
      '/api/v1/admin/business-listings/pending',
      bearerToken: bearerToken,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid moderation response.');
    }

    final items = data['items'];
    if (items is! List) {
      throw ApiException('Invalid moderation response.');
    }

    return items
        .map((item) => BusinessModerationListing.fromJson(
            (item as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<BusinessModerationListing> approveListing({
    required String listingId,
    required String bearerToken,
  }) async {
    final response = await ApiClient.post(
      '/api/v1/admin/business-listings/$listingId/approve',
      bearerToken: bearerToken,
    );
    return _parseListing(response);
  }

  Future<BusinessModerationListing> rejectListing({
    required String listingId,
    required String rejectionReason,
    required String bearerToken,
  }) async {
    final response = await ApiClient.post(
      '/api/v1/admin/business-listings/$listingId/reject',
      bearerToken: bearerToken,
      body: <String, dynamic>{
        'rejectionReason': rejectionReason,
      },
    );
    return _parseListing(response);
  }

  BusinessModerationListing _parseListing(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid moderation response.');
    }

    final listing = data['listing'];
    if (listing is! Map) {
      throw ApiException('Invalid moderation response.');
    }

    return BusinessModerationListing.fromJson(
      listing.cast<String, dynamic>(),
    );
  }
}
