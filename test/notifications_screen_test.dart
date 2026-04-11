import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/models/broadcast_message.dart';
import 'package:believer/models/mosque_content.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/models/notification_enabled_mosque.dart';
import 'package:believer/models/notification_setting.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/notifications_screen.dart';
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

class _FakeMosqueService extends MosqueService {
  _FakeMosqueService({
    this.notificationSettings = const [
      NotificationSetting(
        title: 'Broadcast Messages',
        description: 'Important community announcements',
        isEnabled: true,
      ),
      NotificationSetting(
        title: 'Events & Class Updates',
        description: 'Events and class updates',
        isEnabled: true,
      ),
    ],
  });

  final List<NotificationSetting> notificationSettings;

  @override
  Future<MosqueModel> getMosqueDetail(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const MosqueModel(
      id: 'mosque-followed-api-1',
      name: 'Persisted Notification Mosque',
      addressLine: '25 Unity Ave',
      city: 'Tampa',
      state: 'FL',
      country: 'US',
      latitude: 27.95,
      longitude: -82.45,
      imageUrl: '',
      rating: 4.6,
      distanceMiles: 1.2,
      sect: 'Sunni',
      womenPrayerArea: true,
      parking: true,
      wudu: true,
      facilities: ['parking', 'wudu'],
      isVerified: true,
      isBookmarked: false,
      duhrTime: '01:15 PM',
      asarTime: '04:45 PM',
      isOpenNow: true,
      eventTags: ['Community Family Night'],
      classTags: ['Quran Study Circle'],
    );
  }

  @override
  Future<MosqueContent> getMosqueContent(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const MosqueContent(
      events: [
        MosqueProgramItem(
          id: 'event-1',
          title: 'Community Family Night',
          schedule: 'Fri, May 9',
          posterLabel: 'Community',
          location: 'Main prayer hall',
          description: 'A published family event from the backend-backed feed.',
        ),
      ],
      classes: [
        MosqueProgramItem(
          id: 'class-1',
          title: 'Quran Study Circle',
          schedule: 'Every Sat',
          posterLabel: 'Class',
          location: 'Library room',
          description: 'Weekly study circle details.',
        ),
      ],
      connect: [],
    );
  }

  @override
  Future<List<BroadcastMessage>> getMosqueBroadcastMessages(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const [
      BroadcastMessage(
        id: 'broadcast-1',
        title: 'Parking update',
        description: 'Please use the south lot for Friday prayers.',
        date: 'Today',
      ),
    ];
  }

  @override
  Future<List<NotificationEnabledMosque>> getNotificationEnabledMosques({
    String? bearerToken,
  }) async {
    return const [
      NotificationEnabledMosque(
        id: 'mosque-followed-api-1',
        name: 'Persisted Notification Mosque',
      ),
    ];
  }

  @override
  Future<List<NotificationSetting>> getNotificationSettings({
    required String mosqueId,
    String? bearerToken,
  }) async {
    return notificationSettings;
  }
}

void main() {
  testWidgets(
      'notifications screen shows real update sections and stable routes',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.home: (_) => const Scaffold(body: Text('Home stub')),
            AppRoutes.mosquesAndEvents: (_) =>
                const Scaffold(body: Text('Mosques stub')),
            AppRoutes.eventDetail: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Event detail stub'),
                ),
            AppRoutes.mosqueBroadcast: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Mosque broadcast stub'),
                ),
            AppRoutes.mosqueNotificationSettings: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Mosque notification settings stub'),
                ),
            AppRoutes.profileSettings: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Profile settings stub'),
                ),
            AppRoutes.services: (_) =>
                const Scaffold(body: Text('Services stub')),
          },
          home: NotificationsScreen(
            mosqueService: _FakeMosqueService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('BROADCAST MESSAGES'), findsOneWidget);
    expect(find.text('EVENTS & CLASSES'), findsOneWidget);
    expect(find.text('Parking update'), findsOneWidget);
    expect(find.text('Community Family Night'), findsOneWidget);

    await tester.tap(find.text('My Mosques'));
    await tester.pumpAndSettle();
    expect(find.text('Persisted Notification Mosque'), findsOneWidget);

    await tester.tap(find.text('Notifications').first);
    await tester.pumpAndSettle();
    expect(find.text('BROADCAST MESSAGES'), findsOneWidget);

    await tester.tap(find.text('Community Family Night').first);
    await tester.pumpAndSettle();
    expect(find.text('Event detail stub'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parking update').first);
    await tester.pumpAndSettle();
    expect(find.text('Mosque broadcast stub'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Profile settings stub'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Mosques'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_active_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Mosque notification settings stub'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home stub'), findsOneWidget);
  });

  testWidgets('notifications feed respects supported in-app update settings',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NotificationsScreen(
            mosqueService: _FakeMosqueService(
              notificationSettings: const [
                NotificationSetting(
                  title: 'Broadcast Messages',
                  description: 'Important community announcements',
                  isEnabled: true,
                ),
                NotificationSetting(
                  title: 'Events & Class Updates',
                  description: 'Events and class updates',
                  isEnabled: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('BROADCAST MESSAGES'), findsOneWidget);
    expect(find.text('Parking update'), findsOneWidget);
    expect(find.text('EVENTS & CLASSES'), findsNothing);
    expect(find.text('Community Family Night'), findsNothing);
    expect(find.text('Quran Study Circle'), findsNothing);
  });
}
