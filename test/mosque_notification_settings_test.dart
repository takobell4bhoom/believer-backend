import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/models/notification_setting.dart';
import 'package:believer/screens/mosque_notification_settings.dart';
import 'package:believer/services/mosque_notification_settings_service.dart';
import 'package:believer/services/mosque_service.dart';

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(
        id: 'user-1',
        fullName: 'Test User',
        email: 'test@example.com',
        role: 'community',
      ),
    );
  }
}

class _FakeMosqueNotificationSettingsService
    extends MosqueNotificationSettingsService {
  List<NotificationSetting> stored = const <NotificationSetting>[];

  @override
  Future<List<NotificationSetting>> load({
    required String mosqueId,
    required List<NotificationSetting> defaults,
  }) async {
    if (stored.isEmpty) {
      stored = defaults;
    }
    return stored;
  }

  @override
  Future<void> save({
    required String mosqueId,
    required List<NotificationSetting> settings,
  }) async {
    stored = settings;
  }
}

class _FakeMosqueService extends MosqueService {
  List<NotificationSetting> storedSettings = const <NotificationSetting>[];
  List<NotificationSetting>? lastSavedSettings;

  @override
  Future<List<NotificationSetting>> getNotificationSettings({
    required String mosqueId,
    String? bearerToken,
  }) async {
    return storedSettings;
  }

  @override
  Future<void> updateNotificationSettings({
    required String mosqueId,
    required List<NotificationSetting> settings,
    String? bearerToken,
  }) async {
    storedSettings = settings;
    lastSavedSettings = settings;
  }
}

void main() {
  testWidgets(
      'mosque notification settings keeps only supported in-app update categories',
      (tester) async {
    final fakeSettingsService = _FakeMosqueNotificationSettingsService();
    final fakeMosqueService = _FakeMosqueService();
    fakeMosqueService.storedSettings = const [
      NotificationSetting(
        title: 'Broadcast Messages',
        description: 'Important community announcements',
        isEnabled: false,
      ),
      NotificationSetting(
        title: 'Iqamah Time Reminders',
        description: 'Legacy reminder copy should stay hidden.',
        isEnabled: true,
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 620);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosqueNotificationSettings(
            mosqueId: 'mosque-1',
            mosqueName: 'Islamic Center of South Florida',
            settingsService: fakeSettingsService,
            mosqueService: fakeMosqueService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Islamic Center of South Florida'), findsOneWidget);
    expect(find.text('Broadcast Messages'), findsOneWidget);
    expect(find.text('Events & Class Updates'), findsOneWidget);
    expect(find.text('Iqamah Time Reminders'), findsNothing);
    expect(find.text('Changes in Iqamah Time'), findsNothing);
    expect(tester.takeException(), isNull);

    final toggle = find.byKey(const Key('mosque-notification-toggle-0'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(fakeMosqueService.lastSavedSettings, isNotNull);
    expect(fakeMosqueService.lastSavedSettings!.first.isEnabled, isTrue);
    expect(fakeMosqueService.lastSavedSettings!.length, 2);
    expect(
      fakeMosqueService.lastSavedSettings!
          .map((setting) => setting.title)
          .toList(growable: false),
      const ['Broadcast Messages', 'Events & Class Updates'],
    );
    expect(fakeSettingsService.stored.first.isEnabled, isTrue);
    expect(tester.takeException(), isNull);
  });
}
