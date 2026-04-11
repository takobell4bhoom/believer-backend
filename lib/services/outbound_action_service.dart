import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class OutboundActionResult {
  const OutboundActionResult({
    required this.message,
    this.didLaunch = false,
    this.usedFallback = false,
  });

  final String message;
  final bool didLaunch;
  final bool usedFallback;
}

class OutboundActionService {
  const OutboundActionService();

  Future<OutboundActionResult> shareText(
    String text, {
    String? subject,
    String successMessage = 'Share options opened.',
    String fallbackMessage =
        'Could not open share options. Details copied to clipboard.',
    String unavailableMessage = 'Nothing to share yet.',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return OutboundActionResult(message: unavailableMessage);
    }

    try {
      await Share.share(trimmed, subject: subject);
      return OutboundActionResult(message: successMessage, didLaunch: true);
    } catch (_) {
      return _copyFallback(trimmed, fallbackMessage);
    }
  }

  Future<OutboundActionResult> launchPhone(
    String? phoneNumber, {
    String successMessage = 'Opening phone app...',
    String fallbackMessage =
        'Could not open the phone app. Number copied to clipboard.',
    String unavailableMessage = 'Phone number not available yet.',
  }) async {
    final normalized = _normalizedPhone(phoneNumber);
    if (normalized == null) {
      return OutboundActionResult(message: unavailableMessage);
    }

    return _launchUri(
      Uri(scheme: 'tel', path: normalized),
      successMessage: successMessage,
      fallbackValue: phoneNumber!.trim(),
      fallbackMessage: fallbackMessage,
    );
  }

  Future<OutboundActionResult> launchEmail(
    String? email, {
    String? subject,
    String successMessage = 'Opening email app...',
    String fallbackMessage =
        'Could not open the email app. Email address copied to clipboard.',
    String unavailableMessage = 'Email address not available yet.',
  }) async {
    final trimmed = email?.trim() ?? '';
    if (trimmed.isEmpty) {
      return OutboundActionResult(message: unavailableMessage);
    }

    return _launchUri(
      Uri(
        scheme: 'mailto',
        path: trimmed,
        queryParameters: subject?.trim().isNotEmpty == true
            ? <String, String>{'subject': subject!.trim()}
            : null,
      ),
      successMessage: successMessage,
      fallbackValue: trimmed,
      fallbackMessage: fallbackMessage,
    );
  }

  Future<OutboundActionResult> launchWhatsApp(
    String? phoneNumber, {
    String? message,
    String successMessage = 'Opening WhatsApp...',
    String fallbackMessage =
        'Could not open WhatsApp. Contact copied to clipboard.',
    String unavailableMessage = 'WhatsApp contact not available yet.',
  }) async {
    final normalized = _normalizedPhone(phoneNumber, digitsOnly: true);
    if (normalized == null) {
      return OutboundActionResult(message: unavailableMessage);
    }

    final query = message?.trim().isNotEmpty == true
        ? <String, String>{'text': message!.trim()}
        : null;
    return _launchUri(
      Uri.https('wa.me', '/$normalized', query),
      successMessage: successMessage,
      fallbackValue: phoneNumber!.trim(),
      fallbackMessage: fallbackMessage,
    );
  }

  Future<OutboundActionResult> launchDirections({
    required String? address,
    double? latitude,
    double? longitude,
    String successMessage = 'Opening directions...',
    String fallbackMessage =
        'Could not open maps. Address copied to clipboard.',
    String unavailableMessage =
        'Directions are not available for this listing yet.',
  }) async {
    final trimmedAddress = address?.trim() ?? '';
    final hasCoordinates = latitude != null &&
        longitude != null &&
        latitude != 0 &&
        longitude != 0;
    if (!hasCoordinates && trimmedAddress.isEmpty) {
      return OutboundActionResult(message: unavailableMessage);
    }

    if (hasCoordinates) {
      final query =
          '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
      return _launchUri(
        Uri.https(
          'www.google.com',
          '/maps/search/',
          <String, String>{'api': '1', 'query': query},
        ),
        successMessage: successMessage,
        fallbackValue: trimmedAddress.isNotEmpty ? trimmedAddress : query,
        fallbackMessage: fallbackMessage,
      );
    }

    return _launchUri(
      Uri.https(
        'www.google.com',
        '/maps/search/',
        <String, String>{'api': '1', 'query': trimmedAddress},
      ),
      successMessage: successMessage,
      fallbackValue: trimmedAddress,
      fallbackMessage: fallbackMessage,
    );
  }

  Future<OutboundActionResult> launchExternalLink(
    String? rawValue, {
    String? type,
    String successMessage = 'Opening link...',
    String fallbackMessage =
        'Could not open the link. Details copied to clipboard.',
    String unavailableMessage = 'Link not available yet.',
  }) async {
    final trimmed = rawValue?.trim() ?? '';
    if (trimmed.isEmpty) {
      return OutboundActionResult(message: unavailableMessage);
    }

    final uri = _normalizedExternalUri(trimmed, type: type);
    if (uri == null) {
      return _copyFallback(trimmed, fallbackMessage);
    }

    return _launchUri(
      uri,
      successMessage: successMessage,
      fallbackValue: trimmed,
      fallbackMessage: fallbackMessage,
    );
  }

  Future<OutboundActionResult> _launchUri(
    Uri uri, {
    required String successMessage,
    required String fallbackValue,
    required String fallbackMessage,
  }) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return OutboundActionResult(message: successMessage, didLaunch: true);
      }
    } catch (_) {
      // Fall back to copying the value when the platform launch fails.
    }

    return _copyFallback(fallbackValue, fallbackMessage);
  }

  Future<OutboundActionResult> _copyFallback(
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    return OutboundActionResult(
      message: message,
      usedFallback: true,
    );
  }

  String? _normalizedPhone(String? value, {bool digitsOnly = false}) {
    final source = value?.trim() ?? '';
    if (source.isEmpty) {
      return null;
    }

    final cleaned = source.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) {
      return null;
    }

    if (!digitsOnly) {
      return cleaned;
    }

    return cleaned.replaceAll('+', '');
  }

  Uri? _normalizedExternalUri(String rawValue, {String? type}) {
    final lowerType = type?.trim().toLowerCase() ?? '';

    if (lowerType.contains('phone') || rawValue.contains('+')) {
      final normalizedPhone = _normalizedPhone(rawValue);
      if (normalizedPhone != null) {
        return Uri(scheme: 'tel', path: normalizedPhone);
      }
    }

    if (lowerType.contains('email') || rawValue.contains('@')) {
      return Uri(scheme: 'mailto', path: rawValue);
    }

    if (lowerType.contains('instagram')) {
      return _httpsUri(
          _normalizeSocialValue(rawValue, domain: 'instagram.com'));
    }

    if (lowerType.contains('facebook')) {
      return _httpsUri(_normalizeSocialValue(rawValue, domain: 'facebook.com'));
    }

    if (lowerType.contains('youtube')) {
      return _httpsUri(_normalizeSocialValue(rawValue, domain: 'youtube.com'));
    }

    if (lowerType.contains('website') ||
        rawValue.startsWith('http://') ||
        rawValue.startsWith('https://') ||
        rawValue.startsWith('www.') ||
        rawValue.contains('.')) {
      return _httpsUri(rawValue);
    }

    return null;
  }

  Uri? _httpsUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final withScheme =
        trimmed.startsWith(RegExp(r'https?://')) ? trimmed : 'https://$trimmed';
    return Uri.tryParse(withScheme);
  }

  String _normalizeSocialValue(String value, {required String domain}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('www.') || trimmed.contains(domain)) {
      return trimmed;
    }

    final withoutHandlePrefix =
        trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    return '$domain/$withoutHandlePrefix';
  }
}
