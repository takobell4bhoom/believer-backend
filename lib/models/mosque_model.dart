import 'mosque_content.dart';

class MosqueModel {
  final String id;
  final String name;
  final String addressLine;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final List<String> imageUrls;
  final double rating;
  final int reviewCount;
  final double distanceMiles;
  final String sect;
  final String contactName;
  final String contactPhone;
  final String contactEmail;
  final String websiteUrl;
  final bool womenPrayerArea;
  final bool parking;
  final bool wudu;
  final List<String> facilities;
  final bool isVerified;
  final bool isBookmarked;
  final bool canEdit;
  final String duhrTime;
  final String asarTime;
  final bool isOpenNow;
  final List<MosqueProgramItem> classes;
  final List<MosqueProgramItem> events;
  final List<String> classTags;
  final List<String> eventTags;

  const MosqueModel({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.country,
    this.postalCode = '',
    this.latitude = 0,
    this.longitude = 0,
    required this.imageUrl,
    this.imageUrls = const <String>[],
    required this.rating,
    this.reviewCount = 0,
    required this.distanceMiles,
    required this.sect,
    this.contactName = '',
    this.contactPhone = '',
    this.contactEmail = '',
    this.websiteUrl = '',
    required this.womenPrayerArea,
    required this.parking,
    required this.wudu,
    required this.facilities,
    required this.isVerified,
    required this.isBookmarked,
    this.canEdit = false,
    required this.duhrTime,
    required this.asarTime,
    required this.isOpenNow,
    this.classes = const <MosqueProgramItem>[],
    this.events = const <MosqueProgramItem>[],
    required this.classTags,
    required this.eventTags,
  });

  MosqueModel copyWith({
    String? id,
    String? name,
    String? addressLine,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? imageUrl,
    List<String>? imageUrls,
    double? rating,
    int? reviewCount,
    double? distanceMiles,
    String? sect,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? websiteUrl,
    bool? womenPrayerArea,
    bool? parking,
    bool? wudu,
    List<String>? facilities,
    bool? isVerified,
    bool? isBookmarked,
    bool? canEdit,
    String? duhrTime,
    String? asarTime,
    bool? isOpenNow,
    List<MosqueProgramItem>? classes,
    List<MosqueProgramItem>? events,
    List<String>? classTags,
    List<String>? eventTags,
  }) {
    return MosqueModel(
      id: id ?? this.id,
      name: name ?? this.name,
      addressLine: addressLine ?? this.addressLine,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      sect: sect ?? this.sect,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      womenPrayerArea: womenPrayerArea ?? this.womenPrayerArea,
      parking: parking ?? this.parking,
      wudu: wudu ?? this.wudu,
      facilities: facilities ?? this.facilities,
      isVerified: isVerified ?? this.isVerified,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      canEdit: canEdit ?? this.canEdit,
      duhrTime: duhrTime ?? this.duhrTime,
      asarTime: asarTime ?? this.asarTime,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      classes: classes ?? this.classes,
      events: events ?? this.events,
      classTags: classTags ?? this.classTags,
      eventTags: eventTags ?? this.eventTags,
    );
  }

  bool hasFacility(String label) {
    final normalizedLabel = _normalizeToken(label);
    return facilities
        .any((facility) => _normalizeToken(facility) == normalizedLabel);
  }

  bool hasClassTag(String label) {
    final normalizedLabel = _normalizeToken(label);
    return classTags.any((tag) => _normalizeToken(tag) == normalizedLabel);
  }

  bool hasEventTag(String label) {
    final normalizedLabel = _normalizeToken(label);
    return eventTags.any((tag) => _normalizeToken(tag) == normalizedLabel);
  }

  bool get hasCommunityRating => reviewCount > 0 && rating > 0;

  bool get hasListedPrayerTimes => hasDhuhrTime || hasAsrTime;

  String get primaryImageUrl {
    for (final imageUrl in imageUrls) {
      final trimmed = imageUrl.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return imageUrl.trim();
  }

  bool get hasDhuhrTime => _hasPrayerTime(duhrTime);

  bool get hasAsrTime => _hasPrayerTime(asarTime);
}

MosqueModel fromApi(Map<String, dynamic> row) {
  final facilities = (row['facilities'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .map((e) => e.toLowerCase())
      .toSet();
  final classTags = _readStringList(
    row['classTags'] ?? row['classes'] ?? row['class_tags'],
  );
  final eventTags = _readStringList(
    row['eventTags'] ?? row['events'] ?? row['event_tags'],
  );
  final classes = _readProgramItems(row['classes']);
  final events = _readProgramItems(row['events']);
  final imageUrls = _readStringList(
    row['imageUrls'] ?? row['image_urls'],
  );
  final imageUrl =
      row['imageUrl'] as String? ?? row['image_url'] as String? ?? '';
  final resolvedImageUrls = {
    if (imageUrl.trim().isNotEmpty) imageUrl.trim(),
    ...imageUrls,
  }.toList(growable: false);
  final resolvedPrimaryImageUrl =
      resolvedImageUrls.isNotEmpty ? resolvedImageUrls.first : imageUrl.trim();

  final distanceKm = (row['distanceKm'] as num?)?.toDouble() ?? 0;
  const kmToMiles = 0.621371;

  return MosqueModel(
    id: row['id'] as String? ?? '',
    name: row['name'] as String? ?? 'Mosque',
    addressLine: row['addressLine'] as String? ?? '',
    city: row['city'] as String? ?? '',
    state: row['state'] as String? ?? '',
    country: row['country'] as String? ?? '',
    postalCode:
        row['postalCode'] as String? ?? row['postal_code'] as String? ?? '',
    latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
    imageUrl: resolvedPrimaryImageUrl,
    imageUrls: resolvedImageUrls,
    rating: (row['averageRating'] as num?)?.toDouble() ??
        (row['average_rating'] as num?)?.toDouble() ??
        (row['rating'] as num?)?.toDouble() ??
        0,
    reviewCount: (row['totalReviews'] as num?)?.toInt() ??
        (row['total_reviews'] as num?)?.toInt() ??
        0,
    distanceMiles: distanceKm * kmToMiles,
    sect: row['sect'] as String? ?? row['madhab'] as String? ?? 'Community',
    contactName:
        row['contactName'] as String? ?? row['contact_name'] as String? ?? '',
    contactPhone:
        row['contactPhone'] as String? ?? row['contact_phone'] as String? ?? '',
    contactEmail:
        row['contactEmail'] as String? ?? row['contact_email'] as String? ?? '',
    websiteUrl:
        row['websiteUrl'] as String? ?? row['website_url'] as String? ?? '',
    womenPrayerArea: facilities.contains('women_area'),
    parking: facilities.contains('parking'),
    wudu: facilities.contains('wudu'),
    facilities: facilities.toList(),
    isVerified: row['isVerified'] as bool? ?? false,
    isBookmarked: row['isBookmarked'] as bool? ?? false,
    canEdit: row['canEdit'] as bool? ?? row['can_edit'] as bool? ?? false,
    duhrTime: _readPrayerTime(
      row,
      const ['duhrTime', 'duhr_time', 'dhuhrTime', 'dhuhr_time'],
    ),
    asarTime: _readPrayerTime(
      row,
      const ['asarTime', 'asar_time', 'asrTime', 'asr_time'],
      fallback: '--',
    ),
    isOpenNow:
        row['isOpenNow'] as bool? ?? row['is_open_now'] as bool? ?? false,
    classes: classes,
    events: events,
    classTags: classTags,
    eventTags: eventTags,
  );
}

String _readPrayerTime(
  Map<String, dynamic> row,
  List<String> keys, {
  String fallback = '--',
}) {
  for (final key in keys) {
    final value = row[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return fallback;
}

List<String> _readStringList(dynamic value) {
  if (value is! List<dynamic>) {
    return const <String>[];
  }

  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<MosqueProgramItem> _readProgramItems(dynamic value) {
  final items = value as List<dynamic>? ?? const <dynamic>[];

  return items
      .whereType<Map>()
      .map(
        (item) => MosqueProgramItem.fromJson(
          Map<String, dynamic>.from(item.cast<Object?, Object?>()),
        ),
      )
      .where((item) => item.title.trim().isNotEmpty)
      .toList(growable: false);
}

String _normalizeToken(String value) {
  return switch (value.trim().toLowerCase()) {
    'wheelchair access' => 'wheelchair',
    _ => value.trim().toLowerCase().replaceAll(' ', '_'),
  };
}

bool _hasPrayerTime(String value) {
  final normalized = value.trim();
  return normalized.isNotEmpty && normalized != '--';
}
