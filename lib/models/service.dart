import 'dart:convert';
import 'dart:typed_data';

class Service {
  final String id;
  final String category;
  final String name;
  final String location;
  final String priceRange;
  final String deliveryInfo;
  final double rating;
  final String addressLine1;
  final String addressLine2;
  final String? phoneNumber;
  final String? whatsappNumber;
  final String? instagramHandle;
  final String? facebookPage;
  final String? websiteUrl;
  final String description;
  final String hoursLabel;
  final int savedCount;
  final int reviewCount;
  final List<String> tags;
  final List<String> servicesOffered;
  final List<String> specialties;
  final Uint8List? logoBytes;
  final int? logoTileBackgroundColor;
  final String? publishedAt;
  final String? createdAt;

  const Service({
    this.id = '',
    this.category = '',
    required this.name,
    required this.location,
    required this.priceRange,
    required this.deliveryInfo,
    required this.rating,
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.phoneNumber,
    this.whatsappNumber,
    this.instagramHandle,
    this.facebookPage,
    this.websiteUrl,
    this.description = '',
    this.hoursLabel = 'Hours unavailable',
    this.savedCount = 0,
    this.reviewCount = 0,
    this.tags = const <String>[],
    this.servicesOffered = const <String>[],
    this.specialties = const <String>[],
    this.logoBytes,
    this.logoTileBackgroundColor,
    this.publishedAt,
    this.createdAt,
  });

  factory Service.fromApi(Map<String, dynamic> json) {
    List<String> readStringList(dynamic value) {
      if (value is! List<dynamic>) {
        return const <String>[];
      }

      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    Uint8List? readLogoBytes(dynamic value) {
      if (value is! Map) {
        return null;
      }

      final bytesBase64 = value['bytesBase64'];
      if (bytesBase64 is! String || bytesBase64.trim().isEmpty) {
        return null;
      }

      try {
        return base64Decode(bytesBase64);
      } catch (_) {
        return null;
      }
    }

    int? readLogoTileBackgroundColor(dynamic value) {
      if (value is! Map) {
        return null;
      }

      final rawColor = value['tileBackgroundColor'];
      return rawColor is int ? rawColor : null;
    }

    return Service(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      name: json['name'] as String? ?? 'Service',
      location: json['location'] as String? ?? 'Location unavailable',
      priceRange: json['priceRange'] as String? ?? '--',
      deliveryInfo: json['deliveryInfo'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      addressLine1: json['addressLine1'] as String? ?? '',
      addressLine2: json['addressLine2'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      whatsappNumber: json['whatsappNumber'] as String?,
      instagramHandle: json['instagramHandle'] as String?,
      facebookPage: json['facebookPage'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      description: json['description'] as String? ?? '',
      hoursLabel: json['hoursLabel'] as String? ?? 'Hours unavailable',
      savedCount: json['savedCount'] as int? ?? 0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      tags: readStringList(json['tags']),
      servicesOffered: readStringList(json['servicesOffered']),
      specialties: readStringList(json['specialties']),
      logoBytes: readLogoBytes(json['logo']),
      logoTileBackgroundColor: readLogoTileBackgroundColor(json['logo']),
      publishedAt: json['publishedAt'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}
