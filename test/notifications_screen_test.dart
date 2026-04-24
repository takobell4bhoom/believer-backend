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
    this.notificationMosques = const [
      NotificationEnabledMosque(
        id: 'mosque-followed-api-1',
        name: 'Persisted Notification Mosque',
      ),
    ],
    this.notificationSettingsByMosqueId = const {},
    this.contentByMosqueId = const {},
    this.broadcastsByMosqueId = const {},
    this.detailByMosqueId = const {},
  });

  final List<NotificationSetting> notificationSettings;
  final List<NotificationEnabledMosque> notificationMosques;
  final Map<String, List<NotificationSetting>> notificationSettingsByMosqueId;
  final Map<String, MosqueContent> contentByMosqueId;
  final Map<String, List<BroadcastMessage>> broadcastsByMosqueId;
  final Map<String, MosqueModel> detailByMosqueId;

  @override
  Future<MosqueModel> getMosqueDetail(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return detailByMosqueId[mosqueId] ??
        const MosqueModel(
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
    return contentByMosqueId[mosqueId] ??
        const MosqueContent(
          events: [
            MosqueProgramItem(
              id: 'event-1',
              title: 'Community Family Night',
              schedule: 'Fri, May 9',
              posterLabel: 'Community',
              location: 'Main prayer hall',
              description:
                  'A published family event from the backend-backed feed.',
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
    return broadcastsByMosqueId[mosqueId] ??
        const [
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
    return notificationMosques;
  }

  @override
  Future<List<NotificationSetting>> getNotificationSettings({
    required String mosqueId,
    String? bearerToken,
  }) async {
    return notificationSettingsByMosqueId[mosqueId] ?? notificationSettings;
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

  testWidgets(
      'notifications feed filters each mosque by its own enabled update categories',
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
              notificationMosques: const [
                NotificationEnabledMosque(
                  id: 'broadcast-mosque',
                  name: 'Broadcast Mosque',
                ),
                NotificationEnabledMosque(
                  id: 'program-mosque',
                  name: 'Program Mosque',
                ),
              ],
              notificationSettingsByMosqueId: const {
                'broadcast-mosque': [
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
                'program-mosque': [
                  NotificationSetting(
                    title: 'Broadcast Messages',
                    description: 'Important community announcements',
                    isEnabled: false,
                  ),
                  NotificationSetting(
                    title: 'Events & Class Updates',
                    description: 'Events and class updates',
                    isEnabled: true,
                  ),
                ],
              },
              detailByMosqueId: const {
                'broadcast-mosque': MosqueModel(
                  id: 'broadcast-mosque',
                  name: 'Broadcast Mosque',
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
                  eventTags: [],
                  classTags: [],
                ),
                'program-mosque': MosqueModel(
                  id: 'program-mosque',
                  name: 'Program Mosque',
                  addressLine: '48 Noor Street',
                  city: 'Orlando',
                  state: 'FL',
                  country: 'US',
                  latitude: 28.54,
                  longitude: -81.38,
                  imageUrl: '',
                  rating: 4.8,
                  distanceMiles: 2.4,
                  sect: 'Sunni',
                  womenPrayerArea: true,
                  parking: true,
                  wudu: true,
                  facilities: ['parking', 'wudu'],
                  isVerified: true,
                  isBookmarked: false,
                  duhrTime: '01:20 PM',
                  asarTime: '04:50 PM',
                  isOpenNow: true,
                  eventTags: ['Youth Halaqa'],
                  classTags: ['Weekend Tafsir'],
                ),
              },
              broadcastsByMosqueId: const {
                'broadcast-mosque': [
                  BroadcastMessage(
                    id: 'broadcast-1',
                    title: 'Parking update',
                    description: 'Please use the south lot for Friday prayers.',
                    date: 'Today',
                  ),
                ],
                'program-mosque': [
                  BroadcastMessage(
                    id: 'broadcast-2',
                    title: 'Should be hidden',
                    description: 'Program-only mosques should not show this.',
                    date: 'Today',
                  ),
                ],
              },
              contentByMosqueId: const {
                'broadcast-mosque': MosqueContent(
                  events: [
                    MosqueProgramItem(
                      id: 'event-hidden',
                      title: 'Should stay hidden',
                      schedule: 'Fri, May 9',
                      posterLabel: 'Community',
                      location: 'Main prayer hall',
                      description:
                          'Broadcast-only mosques should hide programs.',
                    ),
                  ],
                  classes: [],
                  connect: [],
                ),
                'program-mosque': MosqueContent(
                  events: [
                    MosqueProgramItem(
                      id: 'event-1',
                      title: 'Youth Halaqa',
                      schedule: 'Fri, May 9',
                      posterLabel: 'Community',
                      location: 'Main prayer hall',
                      description: 'A published event from persisted content.',
                    ),
                  ],
                  classes: [
                    MosqueProgramItem(
                      id: 'class-1',
                      title: 'Weekend Tafsir',
                      schedule: 'Every Sat',
                      posterLabel: 'Class',
                      location: 'Library room',
                      description: 'A published class from persisted content.',
                    ),
                  ],
                  connect: [],
                ),
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('BROADCAST MESSAGES'), findsOneWidget);
    expect(find.text('EVENTS & CLASSES'), findsOneWidget);
    expect(find.text('Parking update'), findsOneWidget);
    expect(find.text('Youth Halaqa'), findsOneWidget);
    expect(find.text('Weekend Tafsir'), findsOneWidget);
    expect(find.text('Should be hidden'), findsNothing);
    expect(find.text('Should stay hidden'), findsNothing);
  });
}
