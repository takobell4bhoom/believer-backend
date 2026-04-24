import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/push_notification_config.dart';
import '../data/auth_provider.dart';
import '../navigation/app_routes.dart';
import '../screens/mosque_broadcast.dart';
import 'api_client.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class NotificationDeviceApi {
  Future<void> registerDevice({
    required String bearerToken,
    required String installationId,
    required String pushToken,
    required String platform,
    String? locale,
    String? appVersion,
  }) async {
    await ApiClient.put(
      '/api/v1/notifications/devices',
      bearerToken: bearerToken,
      body: {
        'installationId': installationId,
        'pushToken': pushToken,
        'platform': platform,
        if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
        if (appVersion != null && appVersion.trim().isNotEmpty)
          'appVersion': appVersion.trim(),
      },
    );
  }

  Future<void> deactivateDevice({
    required String bearerToken,
    required String installationId,
  }) async {
    await ApiClient.delete(
      '/api/v1/notifications/devices/$installationId',
      bearerToken: bearerToken,
    );
  }
}

class AppNotificationPayload {
  const AppNotificationPayload({
    required this.notificationType,
    this.eventId,
    this.mosqueId,
    this.mosqueName,
    this.broadcastId,
  });

  final String notificationType;
  final String? eventId;
  final String? mosqueId;
  final String? mosqueName;
  final String? broadcastId;

  factory AppNotificationPayload.fromMap(Map<String, dynamic> data) {
    return AppNotificationPayload(
      notificationType: (data['notificationType'] ?? '').toString(),
      eventId: data['eventId']?.toString(),
      mosqueId: data['mosqueId']?.toString(),
      mosqueName: data['mosqueName']?.toString(),
      broadcastId: data['broadcastId']?.toString(),
    );
  }

  factory AppNotificationPayload.fromEncoded(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      return const AppNotificationPayload(notificationType: '');
    }

    return AppNotificationPayload.fromMap(
      Map<String, dynamic>.from(decoded.cast<Object?, Object?>()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationType': notificationType,
      if (eventId != null) 'eventId': eventId,
      if (mosqueId != null) 'mosqueId': mosqueId,
      if (mosqueName != null) 'mosqueName': mosqueName,
      if (broadcastId != null) 'broadcastId': broadcastId,
    };
  }

  bool get isMosqueBroadcast =>
      notificationType == 'mosque_broadcast' &&
      mosqueId != null &&
      mosqueId!.trim().isNotEmpty;

  String encode() => jsonEncode(toMap());
}

class AppNotificationService {
  AppNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotificationsPlugin,
    NotificationDeviceApi? deviceApi,
  })  : _messaging = messaging,
        _localNotificationsPlugin =
            localNotificationsPlugin ?? FlutterLocalNotificationsPlugin(),
        _deviceApi = deviceApi ?? NotificationDeviceApi();

  static const String _installationIdKey = 'notifications.installation_id';
  static const String _mosqueUpdatesChannelId = 'mosque_updates';

  static final AppNotificationService instance = AppNotificationService();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin;
  final NotificationDeviceApi _deviceApi;

  bool _isInitialized = false;
  bool _remotePushAvailable = false;
  bool _localNotificationsAvailable = false;
  bool _permissionRequestAttempted = false;
  String? _lastRegisteredSignature;
  String? _currentAuthenticatedToken;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;

    await _initializeLocalNotifications();
    await _initializeRemotePush();
  }

  Future<void> synchronizeAuthSession(AuthSession? session) async {
    _currentAuthenticatedToken = session?.accessToken;

    if (session == null || session.accessToken.trim().isEmpty) {
      _lastRegisteredSignature = null;
      return;
    }

    if (!_remotePushAvailable) {
      return;
    }

    final hasPermission = await _ensureRemotePushPermission();
    if (!hasPermission) {
      return;
    }

    final token = await _safeGetToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    await _registerDeviceForToken(
      bearerToken: session.accessToken,
      pushToken: token,
    );
  }

  Future<void> unregisterCurrentDevice({
    required String bearerToken,
  }) async {
    if (!_remotePushAvailable || bearerToken.trim().isEmpty) {
      _lastRegisteredSignature = null;
      return;
    }

    try {
      final installationId = await _loadInstallationId();
      await _deviceApi.deactivateDevice(
        bearerToken: bearerToken,
        installationId: installationId,
      );
    } catch (_) {
      // Best-effort cleanup during logout.
    } finally {
      _lastRegisteredSignature = null;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.trim().isEmpty) {
            return;
          }
          _openPayload(AppNotificationPayload.fromEncoded(payload));
        },
      );

      const mosqueUpdatesChannel = AndroidNotificationChannel(
        _mosqueUpdatesChannelId,
        'Mosque updates',
        description: 'Remote community updates from mosques you follow.',
        importance: Importance.high,
      );
      final androidImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.createNotificationChannel(
        mosqueUpdatesChannel,
      );

      _localNotificationsAvailable = true;
    } catch (_) {
      _localNotificationsAvailable = false;
    }
  }

  Future<void> _initializeRemotePush() async {
    if (!PushNotificationConfig.supportsRemotePush) {
      return;
    }

    final options = PushNotificationConfig.currentPlatformOptions;
    if (options == null) {
      debugPrint(
        'Remote push is disabled: Firebase options were not provided for this platform.',
      );
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }

      _messaging ??= FirebaseMessaging.instance;

      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);
      _messaging!.onTokenRefresh.listen((token) async {
        final accessToken = _currentAuthenticatedToken;
        if (accessToken == null || accessToken.trim().isEmpty) {
          return;
        }
        await _registerDeviceForToken(
          bearerToken: accessToken,
          pushToken: token,
        );
      });

      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        scheduleMicrotask(() => _handleMessageOpen(initialMessage));
      }

      _remotePushAvailable = true;
    } on FirebaseException catch (error) {
      debugPrint('Remote push disabled: ${error.message ?? error.code}');
    } on MissingPluginException {
      debugPrint('Remote push disabled: Firebase plugins are unavailable.');
    } catch (error) {
      debugPrint('Remote push disabled: $error');
    }
  }

  Future<bool> _ensureRemotePushPermission() async {
    if (!_remotePushAvailable) {
      return false;
    }

    if (!_permissionRequestAttempted) {
      _permissionRequestAttempted = true;
    }

    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } on FirebaseException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<String?> _safeGetToken() async {
    try {
      return await _messaging!.getToken();
    } on FirebaseException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> _registerDeviceForToken({
    required String bearerToken,
    required String pushToken,
  }) async {
    final installationId = await _loadInstallationId();
    final signature = '$bearerToken::$installationId::$pushToken';
    if (_lastRegisteredSignature == signature) {
      return;
    }

    try {
      await _deviceApi.registerDevice(
        bearerToken: bearerToken,
        installationId: installationId,
        pushToken: pushToken,
        platform: _platformName(),
        locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      );
      _lastRegisteredSignature = signature;
    } catch (_) {
      // Best-effort registration. The app should continue normally.
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!_localNotificationsAvailable) {
      return;
    }

    final payload = AppNotificationPayload.fromMap(message.data);
    final notification = message.notification;
    final title = notification?.title?.trim().isNotEmpty == true
        ? notification!.title!.trim()
        : 'Mosque update';
    final body = notification?.body?.trim().isNotEmpty == true
        ? notification!.body!.trim()
        : 'Open Believers Lens to review the latest update.';

    await _localNotificationsPlugin.show(
      _foregroundNotificationId(payload),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _mosqueUpdatesChannelId,
          'Mosque updates',
          channelDescription:
              'Remote community updates from mosques you follow.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload.encode(),
    );
  }

  void _handleMessageOpen(RemoteMessage message) {
    _openPayload(AppNotificationPayload.fromMap(message.data));
  }

  void _openPayload(AppNotificationPayload payload) {
    if (!payload.isMosqueBroadcast) {
      return;
    }

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      scheduleMicrotask(() => _openPayload(payload));
      return;
    }

    navigator.pushNamed(
      AppRoutes.mosqueBroadcast,
      arguments: MosqueBroadcastRouteArgs(
        mosqueId: payload.mosqueId!,
        mosqueName: payload.mosqueName,
      ),
    );
  }

  Future<String> _loadInstallationId() async {
    final prefs = await SharedPreferences.getInstance();
    final existingId = prefs.getString(_installationIdKey);
    if (existingId != null && existingId.trim().isNotEmpty) {
      return existingId;
    }

    final nextId = _generateInstallationId();
    await prefs.setString(_installationIdKey, nextId);
    return nextId;
  }

  String _generateInstallationId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    final buffer = StringBuffer('install-');
    for (final value in values) {
      buffer.write(value.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  int _foregroundNotificationId(AppNotificationPayload payload) {
    final seed =
        payload.broadcastId ?? payload.eventId ?? payload.mosqueId ?? '';
    return seed.hashCode & 0x7fffffff;
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }
}

class AuthAwareNotificationBootstrap extends ConsumerStatefulWidget {
  const AuthAwareNotificationBootstrap({
    super.key,
    required this.child,
    this.notificationService,
  });

  final Widget child;
  final AppNotificationService? notificationService;

  @override
  ConsumerState<AuthAwareNotificationBootstrap> createState() =>
      _AuthAwareNotificationBootstrapState();
}

class _AuthAwareNotificationBootstrapState
    extends ConsumerState<AuthAwareNotificationBootstrap> {
  late final AppNotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService =
        widget.notificationService ?? AppNotificationService.instance;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapNotifications());
    });
  }

  Future<void> _bootstrapNotifications() async {
    try {
      await _notificationService.initialize(
        navigatorKey: appNavigatorKey,
      );

      final currentSession = ref.read(authProvider).valueOrNull;
      await _notificationService.synchronizeAuthSession(currentSession);
    } catch (error, stackTrace) {
      debugPrint('Notification bootstrap skipped during startup: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(authProvider, (previous, next) {
      unawaited(
        _notificationService.synchronizeAuthSession(next.valueOrNull),
      );
    });
    return widget.child;
  }
}
