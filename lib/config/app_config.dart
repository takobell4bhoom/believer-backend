import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _localhostApiBaseUrl = 'http://localhost:4000';
  static const String _androidEmulatorApiBaseUrl = 'http://10.0.2.2:4000';

  // Override with: --dart-define=API_BASE_URL=http://<host>:4000
  static String get apiBaseUrl => resolveApiBaseUrl(
        overrideValue: _apiBaseUrlOverride,
        isWeb: kIsWeb,
        platform: defaultTargetPlatform,
      );

  static String get localApiTroubleshootingHint =>
      resolveLocalApiTroubleshootingHint(
        isWeb: kIsWeb,
        platform: defaultTargetPlatform,
      );

  static String resolveApiBaseUrl({
    required String overrideValue,
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    final trimmedOverride = overrideValue.trim();
    if (trimmedOverride.isNotEmpty) {
      return trimmedOverride;
    }

    if (isWeb) {
      return _localhostApiBaseUrl;
    }

    return switch (platform) {
      TargetPlatform.android => _androidEmulatorApiBaseUrl,
      _ => _localhostApiBaseUrl,
    };
  }

  static String resolveLocalApiTroubleshootingHint({
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    if (isWeb) {
      return 'Check API_BASE_URL or start the backend on $_localhostApiBaseUrl.';
    }

    return switch (platform) {
      TargetPlatform.android =>
        'Android emulator should use $_androidEmulatorApiBaseUrl. '
            "For a physical device, set API_BASE_URL to your computer's LAN IP.",
      _ => 'Check API_BASE_URL or start the backend on $_localhostApiBaseUrl.',
    };
  }
}
