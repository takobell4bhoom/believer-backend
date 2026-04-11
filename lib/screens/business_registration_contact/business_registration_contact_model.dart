import 'package:flutter/material.dart';

@immutable
class BusinessRegistrationContactDraft {
  const BusinessRegistrationContactDraft({
    this.businessEmail = '',
    this.phone = '',
    this.whatsapp = '',
    this.openingTime,
    this.closingTime,
    this.instagramUrl = '',
    this.facebookUrl = '',
    this.websiteUrl = '',
    this.address = '',
    this.zipCode = '',
    this.city = '',
    this.onlineOnly = false,
  });

  final String businessEmail;
  final String phone;
  final String whatsapp;
  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;
  final String instagramUrl;
  final String facebookUrl;
  final String websiteUrl;
  final String address;
  final String zipCode;
  final String city;
  final bool onlineOnly;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _digitPattern = RegExp(r'\d');

  static bool isValidEmail(String value) {
    return _emailPattern.hasMatch(value.trim());
  }

  static bool isValidPhone(String value) {
    return _digitPattern.allMatches(value).length >= 7;
  }

  bool get hasOperatingHours => openingTime != null && closingTime != null;

  bool get hasLocationDetails =>
      onlineOnly ||
      (address.trim().isNotEmpty &&
          zipCode.trim().isNotEmpty &&
          city.trim().isNotEmpty);

  bool get isSubmitReady =>
      isValidEmail(businessEmail) &&
      isValidPhone(phone) &&
      hasOperatingHours &&
      hasLocationDetails;
}
