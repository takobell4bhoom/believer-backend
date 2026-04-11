import 'dart:typed_data';

import 'package:flutter/material.dart';

@immutable
class BusinessRegistrationLogoAsset {
  const BusinessRegistrationLogoAsset({
    this.fileName,
    this.bytes,
    this.contentType,
    this.imageProvider,
    this.tileBackgroundColor = const Color(0xFFE9C49E),
  });

  final String? fileName;
  final Uint8List? bytes;
  final String? contentType;
  final ImageProvider<Object>? imageProvider;
  final Color tileBackgroundColor;

  ImageProvider<Object>? get previewImage {
    if (imageProvider != null) {
      return imageProvider;
    }
    if (bytes != null) {
      return MemoryImage(bytes!);
    }
    return null;
  }
}

@immutable
class BusinessRegistrationTaxonomyItem {
  const BusinessRegistrationTaxonomyItem({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

@immutable
class BusinessRegistrationTaxonomyGroup {
  const BusinessRegistrationTaxonomyGroup({
    required this.id,
    required this.label,
    required this.items,
  });

  final String id;
  final String label;
  final List<BusinessRegistrationTaxonomyItem> items;
}

@immutable
class BusinessRegistrationSelectedType {
  const BusinessRegistrationSelectedType({
    required this.groupId,
    required this.groupLabel,
    required this.itemId,
    required this.itemLabel,
  });

  final String groupId;
  final String groupLabel;
  final String itemId;
  final String itemLabel;

  String get displayLabel => '$groupLabel/$itemLabel';
}

@immutable
class BusinessRegistrationBasicDraft {
  const BusinessRegistrationBasicDraft({
    this.businessName = '',
    this.logo,
    this.selectedType,
    this.tagline = '',
    this.description = '',
  });

  final String businessName;
  final BusinessRegistrationLogoAsset? logo;
  final BusinessRegistrationSelectedType? selectedType;
  final String tagline;
  final String description;

  bool get isDirty =>
      businessName.trim().isNotEmpty ||
      logo != null ||
      selectedType != null ||
      tagline.trim().isNotEmpty ||
      description.trim().isNotEmpty;

  bool get isComplete =>
      businessName.trim().isNotEmpty &&
      logo != null &&
      selectedType != null &&
      tagline.trim().isNotEmpty &&
      description.trim().isNotEmpty;

  BusinessRegistrationBasicDraft copyWith({
    String? businessName,
    BusinessRegistrationLogoAsset? logo,
    bool clearLogo = false,
    BusinessRegistrationSelectedType? selectedType,
    bool clearSelectedType = false,
    String? tagline,
    String? description,
  }) {
    return BusinessRegistrationBasicDraft(
      businessName: businessName ?? this.businessName,
      logo: clearLogo ? null : (logo ?? this.logo),
      selectedType:
          clearSelectedType ? null : (selectedType ?? this.selectedType),
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
    );
  }
}
