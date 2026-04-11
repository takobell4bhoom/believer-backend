import 'package:believer/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps explicit API base URL overrides', () {
    expect(
      AppConfig.resolveApiBaseUrl(
        overrideValue: 'http://api.example.com:5000',
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      'http://api.example.com:5000',
    );
  });

  test('defaults Flutter web to localhost', () {
    expect(
      AppConfig.resolveApiBaseUrl(
        overrideValue: '',
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      'http://localhost:4000',
    );
  });

  test('defaults Android local development to the emulator bridge host', () {
    expect(
      AppConfig.resolveApiBaseUrl(
        overrideValue: '',
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      'http://10.0.2.2:4000',
    );
  });

  test('keeps desktop and iOS local development on localhost', () {
    expect(
      AppConfig.resolveApiBaseUrl(
        overrideValue: '',
        isWeb: false,
        platform: TargetPlatform.iOS,
      ),
      'http://localhost:4000',
    );
    expect(
      AppConfig.resolveApiBaseUrl(
        overrideValue: '',
        isWeb: false,
        platform: TargetPlatform.macOS,
      ),
      'http://localhost:4000',
    );
  });
}
