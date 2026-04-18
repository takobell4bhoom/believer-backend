import '../../services/api_client.dart';

class MosqueModerationSubmitter {
  const MosqueModerationSubmitter({
    required this.id,
    required this.fullName,
    required this.email,
  });

  final String id;
  final String fullName;
  final String email;
}

class MosqueModerationItem {
  const MosqueModerationItem({
    required this.id,
    required this.status,
    required this.name,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.country,
    required this.sect,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.submitter,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  final String id;
  final String status;
  final String name;
  final String addressLine;
  final String city;
  final String state;
  final String country;
  final String sect;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final MosqueModerationSubmitter submitter;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  factory MosqueModerationItem.fromJson(Map<String, dynamic> json) {
    final submitterJson =
        (json['submitter'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    return MosqueModerationItem(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      name: json['name'] as String? ?? '',
      addressLine: json['addressLine'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      country: json['country'] as String? ?? '',
      sect: json['sect'] as String? ?? 'Community',
      contactName: json['contactName'] as String? ?? '',
      contactEmail: json['contactEmail'] as String? ?? '',
      contactPhone: json['contactPhone'] as String? ?? '',
      submitter: MosqueModerationSubmitter(
        id: submitterJson['id'] as String? ?? '',
        fullName: submitterJson['fullName'] as String? ?? '',
        email: submitterJson['email'] as String? ?? '',
      ),
      submittedAt: _parseDateTime(json['submittedAt']),
      reviewedAt: _parseDateTime(json['reviewedAt']),
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

class MosqueModerationService {
  const MosqueModerationService();

  Future<List<MosqueModerationItem>> fetchPendingMosques({
    required String bearerToken,
  }) async {
    final response = await ApiClient.get(
      '/api/v1/admin/mosques/pending',
      bearerToken: bearerToken,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid mosque moderation response.');
    }

    final items = data['items'];
    if (items is! List) {
      throw ApiException('Invalid mosque moderation response.');
    }

    return items
        .map((item) => MosqueModerationItem.fromJson(
              (item as Map).cast<String, dynamic>(),
            ))
        .toList(growable: false);
  }

  Future<MosqueModerationItem> approveMosque({
    required String mosqueId,
    required String bearerToken,
  }) async {
    final response = await ApiClient.post(
      '/api/v1/admin/mosques/$mosqueId/approve',
      bearerToken: bearerToken,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid mosque moderation response.');
    }

    final mosque = data['mosque'];
    if (mosque is! Map) {
      throw ApiException('Invalid mosque moderation response.');
    }

    return MosqueModerationItem.fromJson(
      mosque.cast<String, dynamic>(),
    );
  }

  Future<MosqueModerationItem> rejectMosque({
    required String mosqueId,
    required String rejectionReason,
    required String bearerToken,
  }) async {
    final response = await ApiClient.post(
      '/api/v1/admin/mosques/$mosqueId/reject',
      bearerToken: bearerToken,
      body: <String, dynamic>{
        'rejectionReason': rejectionReason,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid mosque moderation response.');
    }

    final mosque = data['mosque'];
    if (mosque is! Map) {
      throw ApiException('Invalid mosque moderation response.');
    }

    return MosqueModerationItem.fromJson(
      mosque.cast<String, dynamic>(),
    );
  }
}
