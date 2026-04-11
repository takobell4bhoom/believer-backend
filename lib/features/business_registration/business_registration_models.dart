import 'dart:convert';

import 'package:flutter/material.dart';

import '../../screens/business_registration_basic/business_registration_basic_models.dart';
import '../../screens/business_registration_contact/business_registration_contact_model.dart';

enum BusinessRegistrationFlowStep {
  intro,
  basicDetails,
  contactAndLocation,
  underReview,
  live,
}

enum BusinessRegistrationSubmissionStatus {
  draft('draft'),
  underReview('under_review'),
  live('live'),
  rejected('rejected');

  const BusinessRegistrationSubmissionStatus(this.apiValue);

  final String apiValue;

  static BusinessRegistrationSubmissionStatus fromApiValue(String? value) {
    return BusinessRegistrationSubmissionStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => BusinessRegistrationSubmissionStatus.draft,
    );
  }
}

@immutable
class BusinessRegistrationFlowRouteArgs {
  const BusinessRegistrationFlowRouteArgs({
    this.exitRouteName,
  });

  final String? exitRouteName;

  BusinessRegistrationFlowRouteArgs copyWith({
    String? exitRouteName,
    bool clearExitRouteName = false,
  }) {
    return BusinessRegistrationFlowRouteArgs(
      exitRouteName:
          clearExitRouteName ? null : (exitRouteName ?? this.exitRouteName),
    );
  }
}

@immutable
class BusinessRegistrationPublicCategory {
  const BusinessRegistrationPublicCategory({
    this.groupId,
    this.groupLabel,
    this.itemId,
    this.itemLabel,
  });

  final String? groupId;
  final String? groupLabel;
  final String? itemId;
  final String? itemLabel;

  bool get hasAnyValue =>
      groupId != null ||
      groupLabel != null ||
      itemId != null ||
      itemLabel != null;
}

@immutable
class BusinessRegistrationDraft {
  const BusinessRegistrationDraft({
    this.id,
    this.basicDetails = const BusinessRegistrationBasicDraft(),
    this.contactDetails = const BusinessRegistrationContactDraft(),
    this.publicCategory,
    this.status = BusinessRegistrationSubmissionStatus.draft,
    this.createdAt,
    this.submittedAt,
    this.publishedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.lastUpdatedAt,
  });

  final String? id;
  final BusinessRegistrationBasicDraft basicDetails;
  final BusinessRegistrationContactDraft contactDetails;
  final BusinessRegistrationPublicCategory? publicCategory;
  final BusinessRegistrationSubmissionStatus status;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final DateTime? publishedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime? lastUpdatedAt;

  bool get hasAnySavedInput =>
      basicDetails.isDirty || _contactDraftHasAnyInput(contactDetails);

  bool get shouldResumeContactStep =>
      basicDetails.isComplete &&
      (_contactDraftHasAnyInput(contactDetails) ||
          contactDetails.isSubmitReady);

  BusinessRegistrationDraft copyWith({
    String? id,
    bool clearId = false,
    BusinessRegistrationBasicDraft? basicDetails,
    BusinessRegistrationContactDraft? contactDetails,
    BusinessRegistrationPublicCategory? publicCategory,
    bool clearPublicCategory = false,
    BusinessRegistrationSubmissionStatus? status,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    DateTime? submittedAt,
    bool clearSubmittedAt = false,
    DateTime? publishedAt,
    bool clearPublishedAt = false,
    DateTime? reviewedAt,
    bool clearReviewedAt = false,
    String? rejectionReason,
    bool clearRejectionReason = false,
    DateTime? lastUpdatedAt,
    bool clearLastUpdatedAt = false,
  }) {
    return BusinessRegistrationDraft(
      id: clearId ? null : (id ?? this.id),
      basicDetails: basicDetails ?? this.basicDetails,
      contactDetails: contactDetails ?? this.contactDetails,
      publicCategory:
          clearPublicCategory ? null : (publicCategory ?? this.publicCategory),
      status: status ?? this.status,
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
      submittedAt: clearSubmittedAt ? null : (submittedAt ?? this.submittedAt),
      publishedAt: clearPublishedAt ? null : (publishedAt ?? this.publishedAt),
      reviewedAt: clearReviewedAt ? null : (reviewedAt ?? this.reviewedAt),
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
      lastUpdatedAt:
          clearLastUpdatedAt ? null : (lastUpdatedAt ?? this.lastUpdatedAt),
    );
  }

  Map<String, dynamic> toRequestJson() {
    return <String, dynamic>{
      'basicDetails': <String, dynamic>{
        'businessName': basicDetails.businessName,
        'logo': _encodeLogo(basicDetails.logo),
        'selectedType': _encodeSelectedType(basicDetails.selectedType),
        'tagline': basicDetails.tagline,
        'description': basicDetails.description,
      },
      'contactDetails': <String, dynamic>{
        'businessEmail': contactDetails.businessEmail,
        'phone': contactDetails.phone,
        'whatsapp': contactDetails.whatsapp,
        'openingTime': _encodeTimeOfDay(contactDetails.openingTime),
        'closingTime': _encodeTimeOfDay(contactDetails.closingTime),
        'instagramUrl': contactDetails.instagramUrl,
        'facebookUrl': contactDetails.facebookUrl,
        'websiteUrl': contactDetails.websiteUrl,
        'address': contactDetails.address,
        'zipCode': contactDetails.zipCode,
        'city': contactDetails.city,
        'onlineOnly': contactDetails.onlineOnly,
      },
    };
  }

  factory BusinessRegistrationDraft.fromApiListing(Map<String, dynamic> json) {
    final basicJson = _readMap(json['basicDetails']);
    final contactJson = _readMap(json['contactDetails']);
    final publicCategoryJson = _readMap(json['publicCategory']);

    return BusinessRegistrationDraft(
      id: _readNullableString(json['id']),
      basicDetails: BusinessRegistrationBasicDraft(
        businessName: _readString(basicJson['businessName']),
        logo: _decodeLogo(basicJson['logo']),
        selectedType: _decodeSelectedType(basicJson['selectedType']),
        tagline: _readString(basicJson['tagline']),
        description: _readString(basicJson['description']),
      ),
      contactDetails: BusinessRegistrationContactDraft(
        businessEmail: _readString(contactJson['businessEmail']),
        phone: _readString(contactJson['phone']),
        whatsapp: _readString(contactJson['whatsapp']),
        openingTime: _decodeTimeOfDay(contactJson['openingTime']),
        closingTime: _decodeTimeOfDay(contactJson['closingTime']),
        instagramUrl: _readString(contactJson['instagramUrl']),
        facebookUrl: _readString(contactJson['facebookUrl']),
        websiteUrl: _readString(contactJson['websiteUrl']),
        address: _readString(contactJson['address']),
        zipCode: _readString(contactJson['zipCode']),
        city: _readString(contactJson['city']),
        onlineOnly: contactJson['onlineOnly'] == true,
      ),
      publicCategory: _decodePublicCategory(publicCategoryJson),
      status: BusinessRegistrationSubmissionStatus.fromApiValue(
        _readNullableString(json['status']),
      ),
      createdAt: _decodeDateTime(json['createdAt']),
      submittedAt: _decodeDateTime(json['submittedAt']),
      publishedAt: _decodeDateTime(json['publishedAt']),
      reviewedAt: _decodeDateTime(json['reviewedAt']),
      rejectionReason: _readNullableString(json['rejectionReason']),
      lastUpdatedAt: _decodeDateTime(json['lastUpdatedAt']),
    );
  }

  static BusinessRegistrationPublicCategory? _decodePublicCategory(
    Map<String, dynamic> json,
  ) {
    if (json.isEmpty) {
      return null;
    }

    final publicCategory = BusinessRegistrationPublicCategory(
      groupId: _readNullableString(json['groupId']),
      groupLabel: _readNullableString(json['groupLabel']),
      itemId: _readNullableString(json['itemId']),
      itemLabel: _readNullableString(json['itemLabel']),
    );

    return publicCategory.hasAnyValue ? publicCategory : null;
  }

  static bool _contactDraftHasAnyInput(BusinessRegistrationContactDraft draft) {
    return draft.businessEmail.trim().isNotEmpty ||
        draft.phone.trim().isNotEmpty ||
        draft.whatsapp.trim().isNotEmpty ||
        draft.openingTime != null ||
        draft.closingTime != null ||
        draft.instagramUrl.trim().isNotEmpty ||
        draft.facebookUrl.trim().isNotEmpty ||
        draft.websiteUrl.trim().isNotEmpty ||
        draft.address.trim().isNotEmpty ||
        draft.zipCode.trim().isNotEmpty ||
        draft.city.trim().isNotEmpty ||
        draft.onlineOnly;
  }

  static Map<String, dynamic>? _encodeLogo(
    BusinessRegistrationLogoAsset? logo,
  ) {
    if (logo == null) {
      return null;
    }

    return <String, dynamic>{
      'fileName': logo.fileName,
      'bytesBase64': logo.bytes == null ? null : base64Encode(logo.bytes!),
      'contentType': logo.contentType,
      'tileBackgroundColor': logo.tileBackgroundColor.toARGB32(),
    };
  }

  static BusinessRegistrationLogoAsset? _decodeLogo(dynamic value) {
    final json = _readMap(value);
    if (json.isEmpty) {
      return null;
    }

    final bytesBase64 = _readNullableString(json['bytesBase64']);
    return BusinessRegistrationLogoAsset(
      fileName: _readNullableString(json['fileName']),
      bytes: bytesBase64 == null ? null : base64Decode(bytesBase64),
      contentType: _readNullableString(json['contentType']),
      tileBackgroundColor: Color(
        (json['tileBackgroundColor'] as int?) ??
            const Color(0xFFE9C49E).toARGB32(),
      ),
    );
  }

  static Map<String, dynamic>? _encodeSelectedType(
    BusinessRegistrationSelectedType? selectedType,
  ) {
    if (selectedType == null) {
      return null;
    }

    return <String, dynamic>{
      'groupId': selectedType.groupId,
      'groupLabel': selectedType.groupLabel,
      'itemId': selectedType.itemId,
      'itemLabel': selectedType.itemLabel,
    };
  }

  static BusinessRegistrationSelectedType? _decodeSelectedType(dynamic value) {
    final json = _readMap(value);
    if (json.isEmpty) {
      return null;
    }

    return BusinessRegistrationSelectedType(
      groupId: _readString(json['groupId']),
      groupLabel: _readString(json['groupLabel']),
      itemId: _readString(json['itemId']),
      itemLabel: _readString(json['itemLabel']),
    );
  }

  static Map<String, dynamic>? _encodeTimeOfDay(TimeOfDay? value) {
    if (value == null) {
      return null;
    }

    return <String, dynamic>{
      'hour': value.hour,
      'minute': value.minute,
    };
  }

  static TimeOfDay? _decodeTimeOfDay(dynamic value) {
    final json = _readMap(value);
    if (json.isEmpty) {
      return null;
    }

    final hour = json['hour'];
    final minute = json['minute'];
    if (hour is! int || minute is! int) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  static DateTime? _decodeDateTime(dynamic value) {
    final dateTimeString = _readNullableString(value);
    if (dateTimeString == null) {
      return null;
    }
    return DateTime.tryParse(dateTimeString);
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
    }
    return const <String, dynamic>{};
  }

  static String _readString(dynamic value) {
    return value is String ? value : '';
  }

  static String? _readNullableString(dynamic value) {
    return value is String && value.isNotEmpty ? value : null;
  }
}

@immutable
class BusinessRegistrationFlowState {
  const BusinessRegistrationFlowState({
    this.draft = const BusinessRegistrationDraft(),
    this.isSavingDraft = false,
    this.isSubmitting = false,
  });

  final BusinessRegistrationDraft draft;
  final bool isSavingDraft;
  final bool isSubmitting;

  BusinessRegistrationFlowState copyWith({
    BusinessRegistrationDraft? draft,
    bool? isSavingDraft,
    bool? isSubmitting,
  }) {
    return BusinessRegistrationFlowState(
      draft: draft ?? this.draft,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}
