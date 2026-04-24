import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class PushNotificationConfig {
  static const String _firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String _firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String _firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String _firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '',
  );
  static const String _firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '',
  );
  static const String _firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: '',
  );
  static const String _firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );

  static bool get supportsRemotePush {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static FirebaseOptions? get currentPlatformOptions {
    if (!supportsRemotePush) {
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (_firebaseProjectId.isEmpty ||
            _firebaseMessagingSenderId.isEmpty ||
            _firebaseApiKey.isEmpty ||
            _firebaseAndroidAppId.isEmpty) {
          return null;
        }
        return FirebaseOptions(
          apiKey: _firebaseApiKey,
          appId: _firebaseAndroidAppId,
          messagingSenderId: _firebaseMessagingSenderId,
          projectId: _firebaseProjectId,
          storageBucket:
              _firebaseStorageBucket.isEmpty ? null : _firebaseStorageBucket,
        );
      case TargetPlatform.iOS:
        if (_firebaseProjectId.isEmpty ||
            _firebaseMessagingSenderId.isEmpty ||
            _firebaseApiKey.isEmpty ||
            _firebaseIosAppId.isEmpty) {
          return null;
        }
        return FirebaseOptions(
          apiKey: _firebaseApiKey,
          appId: _firebaseIosAppId,
          messagingSenderId: _firebaseMessagingSenderId,
          projectId: _firebaseProjectId,
          storageBucket:
              _firebaseStorageBucket.isEmpty ? null : _firebaseStorageBucket,
          iosBundleId:
              _firebaseIosBundleId.isEmpty ? null : _firebaseIosBundleId,
        );
      default:
        return null;
    }
  }
}
