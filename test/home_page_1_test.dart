import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/data/mosque_content_refresh_provider.dart';
import 'package:believer/data/mock_provider.dart';
import 'package:believer/data/mosque_provider.dart';
import 'package:believer/models/mosque_content.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/models/notification_enabled_mosque.dart';
import 'package:believer/models/prayer_timings.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/home_page_1.dart';
import 'package:believer/screens/event_detail_screen.dart';
import 'package:believer/screens/location_setup_screen.dart';
import 'package:believer/screens/map_screen.dart';
import 'package:believer/services/current_location_service.dart';
import 'package:believer/services/location_preferences_service.dart';
import 'package:believer/services/mosque_service.dart';

String _todayIsoDate() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

DateTime _todayAt(int hour, int minute) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

class _PrayerTimeRequest {
  const _PrayerTimeRequest({
    required this.mosqueId,
    required this.date,
  });

  final String mosqueId;
  final String date;
}

class _FakeMosqueService extends MosqueService {
  _FakeMosqueService({
    List<String>? eventTitles,
    this.publishedEvents,
    List<NotificationEnabledMosque>? notificationMosques,
    this.nowProvider,
    this.nonTodayDelay = Duration.zero,
  })  : _eventTitles = eventTitles ??
            const <String>[
              'Backend Community Iftar',
              'Backend Community Iftar'
            ],
        _notificationMosques = notificationMosques ??
            const <NotificationEnabledMosque>[
              NotificationEnabledMosque(
                id: 'mosque-001',
                name: 'East London Mosque and London Muslim Centre',
              ),
              NotificationEnabledMosque(
                id: 'mosque-002',
                name: 'Masjid Al-Noor',
              ),
            ];

  final List<String> _eventTitles;
  final List<MosqueProgramItem>? publishedEvents;
  final List<NotificationEnabledMosque> _notificationMosques;
  final DateTime Function()? nowProvider;
  final Duration nonTodayDelay;
  int _contentCallCount = 0;
  final List<_PrayerTimeRequest> prayerTimeRequests = [];

  @override
  Future<MosqueContent> getMosqueContent(
    String mosqueId, {
    String? bearerToken,
  }) async {
    _contentCallCount += 1;
    if (publishedEvents != null) {
      return MosqueContent(
        events: publishedEvents!,
        classes: [],
        connect: [],
      );
    }

    final titleIndex =
        (_contentCallCount - 1).clamp(0, _eventTitles.length - 1);
    final title = _eventTitles[titleIndex];
    return MosqueContent(
      events: [
        MosqueProgramItem(
          id: 'event-1',
          title: title,
          schedule:
              title == 'Updated Community Iftar' ? 'Next Fri' : 'This Fri',
          posterLabel: 'Iftar',
          location: 'Community Hall, 82-92 Whitechapel Road',
          description:
              'Join local families for a hosted iftar with a short reminder after Maghrib.',
        ),
      ],
      classes: [],
      connect: [],
    );
  }

  @override
  Future<PrayerTimings> getPrayerTimings({
    required String mosqueId,
    required String date,
    String? bearerToken,
  }) async {
    prayerTimeRequests.add(
      _PrayerTimeRequest(
        mosqueId: mosqueId,
        date: date,
      ),
    );

    final now = nowProvider?.call() ?? DateTime.now();
    final isToday = date == _todayIsoDate();
    if (!isToday && nonTodayDelay > Duration.zero) {
      await Future<void>.delayed(nonTodayDelay);
    }
    final nextPrayer = isToday ? _nextPrayerFor(now) : null;

    return PrayerTimings(
      mosqueId: mosqueId,
      date: date,
      status: 'ready',
      isConfigured: true,
      isAvailable: true,
      source: 'cache',
      unavailableReason: null,
      timezone: 'Europe/London',
      configuration: const PrayerTimeConfiguration(
        enabled: true,
        latitude: 51.5194,
        longitude: -0.0632,
        calculationMethodId: 3,
        calculationMethodName: 'Muslim World League',
        school: 'standard',
        schoolLabel: 'Standard',
        adjustments: {
          'fajr': 0,
          'sunrise': 0,
          'dhuhr': 0,
          'asr': 0,
          'maghrib': 0,
          'isha': 0,
        },
      ),
      timings: const {
        'fajr': '05:08 AM',
        'sunrise': '06:18 AM',
        'dhuhr': '12:31 PM',
        'asr': '04:02 PM',
        'maghrib': '06:41 PM',
        'isha': '07:55 PM',
      },
      nextPrayer: nextPrayer?.$1 ?? '',
      nextPrayerTime: nextPrayer?.$2 ?? '',
      cachedAt: '2026-03-30T04:00:00.000Z',
    );
  }

  @override
  Future<List<NotificationEnabledMosque>> getNotificationEnabledMosques({
    String? bearerToken,
  }) async {
    return _notificationMosques;
  }
}

(String, String)? _nextPrayerFor(DateTime now) {
  final prayerStarts = <({String prayer, DateTime time, String label})>[
    (
      prayer: 'Fajr',
      time: DateTime(now.year, now.month, now.day, 5, 8),
      label: '05:08 AM',
    ),
    (
      prayer: 'Dhuhr',
      time: DateTime(now.year, now.month, now.day, 12, 31),
      label: '12:31 PM',
    ),
    (
      prayer: 'Asr',
      time: DateTime(now.year, now.month, now.day, 16, 2),
      label: '04:02 PM',
    ),
    (
      prayer: 'Maghrib',
      time: DateTime(now.year, now.month, now.day, 18, 41),
      label: '06:41 PM',
    ),
    (
      prayer: 'Isha',
      time: DateTime(now.year, now.month, now.day, 19, 55),
      label: '07:55 PM',
    ),
  ];

  for (final prayer in prayerStarts) {
    if (now.isBefore(prayer.time)) {
      return (prayer.prayer, prayer.label);
    }
  }

  return null;
}

class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return null;
  }
}

class _CoverImageMosqueNotifier extends MosqueNotifier {
  static List<MosqueModel> mosques = const <MosqueModel>[];

  @override
  Future<List<MosqueModel>> build() async {
    return mosques;
  }

  @override
  Future<List<MosqueModel>> loadNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    state = AsyncData(mosques);
    return mosques;
  }
}

class _TrackingMosqueNotifier extends MosqueNotifier {
  static List<MosqueModel> mosques = const <MosqueModel>[];
  static double? lastLatitude;
  static double? lastLongitude;

  @override
  Future<List<MosqueModel>> build() async {
    return mosques;
  }

  @override
  Future<List<MosqueModel>> loadNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    lastLatitude = latitude;
    lastLongitude = longitude;
    state = AsyncData(mosques);
    return mosques;
  }
}

class _FakeLocationPreferencesService extends LocationPreferencesService {
  _FakeLocationPreferencesService(this.savedLocation);

  final SavedUserLocation? savedLocation;

  @override
  Future<SavedUserLocation?> loadSavedLocation() async => savedLocation;

  @override
  Future<String> loadCurrentLocation() async {
    return savedLocation?.label ?? LocationPreferencesService.defaultLocation;
  }
}

class _FakeCurrentLocationService implements CurrentLocationService {
  const _FakeCurrentLocationService({required this.isSupported});

  @override
  final bool isSupported;

  @override
  Future<CurrentLocationCoordinates> getCurrentCoordinates() {
    throw UnimplementedError();
  }
}

LocationPreferencesService _preciseLocationService() {
  return _FakeLocationPreferencesService(
    const SavedUserLocation(
      label: 'Tampa, Florida',
      latitude: 27.9506,
      longitude: -82.4572,
    ),
  );
}

void main() {
  testWidgets('home page renders redesigned home shell and routes to key flows',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    SharedPreferences.setMockInitialValues(
      {'user.location': 'Tampa, Florida'},
    );
    final service = _FakeMosqueService(
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.prayerSettings: (_) =>
                const Scaffold(body: Text('Prayer settings stub')),
            AppRoutes.notifications: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Notifications stub'),
                ),
            AppRoutes.login: (_) => const Scaffold(body: Text('Login stub')),
            AppRoutes.profileSettings: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Profile settings stub'),
                ),
            AppRoutes.services: (_) =>
                Scaffold(appBar: AppBar(), body: const Text('Services stub')),
            AppRoutes.eventDetail: (context) {
              final args = ModalRoute.of(context)!.settings.arguments!
                  as EventDetailRouteArgs;
              final details = args.discoveryEvent!;
              return Scaffold(
                appBar: AppBar(),
                body: Column(
                  children: [
                    Text(details.title),
                    Text(details.locationLine),
                    Text(details.description),
                  ],
                ),
              );
            },
          },
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tampa, Florida'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Closest To You'), findsOneWidget);
    expect(find.text('EVENTS AROUND YOU'), findsOneWidget);
    expect(find.text('OTHERS'), findsOneWidget);
    expect(
      find.text('East London Mosque and London Muslim Centre'),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.text(
        'For East London Mosque and London Muslim Centre • London, England',
      ),
      findsOneWidget,
    );
    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.text('Dhuhr'), findsWidgets);
    expect(find.text('Until 04:02 PM'), findsOneWidget);
    expect(service.prayerTimeRequests, isNotEmpty);
    expect(service.prayerTimeRequests.first.mosqueId, 'mosque-001');
    expect(service.prayerTimeRequests.first.date, _todayIsoDate());
    expect(find.text('Backend Community Iftar'), findsOneWidget);
    expect(find.text('View more nearby mosques'), findsOneWidget);
    expect(find.text('Following\n2 mosques'), findsOneWidget);
    expect(
      find.text('East London Mosque and London Muslim Centre + 1 more'),
      findsOneWidget,
    );
    expect(find.text('Manage alerts'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Profile settings stub'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Women-Friendly'));
    await tester.tap(find.text('Women-Friendly'));
    await tester.pumpAndSettle();

    expect(find.text('Women-Friendly'), findsOneWidget);

    await tester.ensureVisible(find.text('Backend Community Iftar'));
    await tester.tap(find.text('Backend Community Iftar'));
    await tester.pumpAndSettle();

    expect(find.text('Community Hall, 82-92 Whitechapel Road'), findsOneWidget);
    expect(
      find.text(
        'Join local families for a hosted iftar with a short reminder after Maghrib.',
      ),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Explore\nMuslim-Owned\nBusinesses'));
    await tester.tap(find.text('Explore\nMuslim-Owned\nBusinesses'));
    await tester.pumpAndSettle();

    expect(find.text('Services stub'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Following\n2 mosques'));
    await tester.tap(find.text('Following\n2 mosques'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications stub'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Manage prayer notifications & more'));
    await tester.tap(
      find.text('Manage prayer notifications & more'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prayer settings stub'), findsOneWidget);
  });

  testWidgets(
      'home page shows an honest empty state when nearby mosques have no published events',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    SharedPreferences.setMockInitialValues({});
    final service = _FakeMosqueService(
      publishedEvents: const <MosqueProgramItem>[],
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('No nearby mosques have published public events yet.'),
      findsOneWidget,
    );
    expect(find.text('Backend Community Iftar'), findsNothing);
  });

  testWidgets(
      'home page keeps unpublished schedules honest instead of showing This week',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    SharedPreferences.setMockInitialValues({});
    final service = _FakeMosqueService(
      publishedEvents: const <MosqueProgramItem>[
        MosqueProgramItem(
          id: 'event-1',
          title: 'Community Iftar',
          schedule: '',
          posterLabel: '',
          location: 'Community Hall, 82-92 Whitechapel Road',
          description:
              'Join local families for a hosted iftar with a short reminder after Maghrib.',
        ),
      ],
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Community Iftar'), findsOneWidget);
    expect(find.text('Schedule not published'), findsOneWidget);
    expect(find.text('This week'), findsNothing);
  });

  testWidgets('home page shows honest guest CTAs for mosque alerts',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    SharedPreferences.setMockInitialValues({});
    final service = _FakeMosqueService(
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_SignedOutAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.login: (_) => const Scaffold(body: Text('Login stub')),
          },
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Follow mosques\nyou trust'), findsOneWidget);
    expect(
      find.text('Log in to save mosques and manage prayer alerts.'),
      findsOneWidget,
    );
    expect(find.text('Log in'), findsOneWidget);

    await tester.ensureVisible(find.text('Follow mosques\nyou trust'));
    await tester.tap(find.text('Follow mosques\nyou trust'));
    await tester.pumpAndSettle();

    expect(find.text('Login stub'), findsOneWidget);
  });

  testWidgets(
      'home page uses the mosque primary uploaded image as the card thumbnail',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    SharedPreferences.setMockInitialValues(
      {'user.location': 'Tampa, Florida'},
    );
    _CoverImageMosqueNotifier.mosques = const <MosqueModel>[
      MosqueModel(
        id: 'cover-image-mosque',
        name: 'Cover Image Mosque',
        addressLine: '12 Mercy Road',
        city: 'London',
        state: 'England',
        country: 'UK',
        imageUrl: '',
        imageUrls: <String>[
          'https://example.org/mosque-cover.jpg',
          'https://example.org/mosque-gallery-2.jpg',
        ],
        rating: 4.5,
        reviewCount: 12,
        distanceMiles: 0.8,
        sect: 'Community',
        womenPrayerArea: true,
        parking: true,
        wudu: true,
        facilities: <String>['women_area', 'parking', 'wudu'],
        isVerified: true,
        isBookmarked: false,
        duhrTime: '01:15 PM',
        asarTime: '04:06 PM',
        isOpenNow: true,
        classTags: <String>['Quran Study'],
        eventTags: <String>['Family Night'],
      ),
    ];
    final service = _FakeMosqueService(
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(_CoverImageMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('home-featured-mosque-image')),
    );
    final provider = image.image as NetworkImage;
    expect(provider.url, 'https://example.org/mosque-cover.jpg');
  });

  testWidgets('home page reloads prayer timings when the selected day changes',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    SharedPreferences.setMockInitialValues({});
    final service = _FakeMosqueService(
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final initialCallCount = service.prayerTimeRequests.length;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowIso =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(service.prayerTimeRequests.length, greaterThan(initialCallCount));
    expect(service.prayerTimeRequests.last.date, tomorrowIso);
    expect(find.text('TOMORROW'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsOneWidget);
  });

  testWidgets(
      'home page keeps today prayer state stable when day navigation goes forward then back',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    SharedPreferences.setMockInitialValues({});
    final service = _FakeMosqueService(
      nowProvider: () => fixedNow,
      nonTodayDelay: const Duration(milliseconds: 150),
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pump();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.text('Dhuhr'), findsWidgets);

    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('LIVE NOW'), findsOneWidget);
  });

  testWidgets('home page live progress bar reflects current prayer window',
      (tester) async {
    final fixedNow = _todayAt(14, 16);
    SharedPreferences.setMockInitialValues({});
    final service = _FakeMosqueService(
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final progressFill = tester.widget<FractionallySizedBox>(
      find.byKey(const ValueKey('prayer-progress-fill-dhuhr')),
    );

    expect(progressFill.widthFactor, greaterThan(0));
    expect(progressFill.widthFactor, lessThan(1));
  });

  testWidgets(
      'home page refreshes featured events after mosque content updates',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    SharedPreferences.setMockInitialValues({});
    final service = _FakeMosqueService(
      eventTitles: const <String>[
        'Backend Community Iftar',
        'Backend Community Iftar',
        'Updated Community Iftar',
      ],
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(MockMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Backend Community Iftar'), findsOneWidget);
    expect(find.text('Updated Community Iftar'), findsNothing);

    container.read(mosqueContentRefreshTickProvider.notifier).state += 1;
    for (var index = 0; index < 8; index++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (service._contentCallCount >= 2) {
        break;
      }
    }

    expect(service._contentCallCount, greaterThanOrEqualTo(2));
    expect(find.textContaining('Community Iftar'), findsOneWidget);
  });

  testWidgets('home page uses saved coordinates for nearby mosque loading',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    _TrackingMosqueNotifier.mosques = const <MosqueModel>[
      MosqueModel(
        id: 'tracked-mosque',
        name: 'Tracked Mosque',
        addressLine: '10 Mercy Road',
        city: 'Tampa',
        state: 'FL',
        country: 'US',
        imageUrl: '',
        rating: 4.7,
        distanceMiles: 1.1,
        sect: 'Community',
        womenPrayerArea: true,
        parking: true,
        wudu: true,
        facilities: <String>['women_area', 'parking', 'wudu'],
        isVerified: true,
        isBookmarked: false,
        duhrTime: '01:15 PM',
        asarTime: '04:06 PM',
        isOpenNow: true,
        classTags: <String>['Quran Study'],
        eventTags: <String>['Family Night'],
      ),
    ];
    _TrackingMosqueNotifier.lastLatitude = null;
    _TrackingMosqueNotifier.lastLongitude = null;
    final service = _FakeMosqueService(
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_TrackingMosqueNotifier.lastLatitude, 27.9506);
    expect(_TrackingMosqueNotifier.lastLongitude, -82.4572);
    expect(service.prayerTimeRequests, isNotEmpty);
    expect(service.prayerTimeRequests.first.mosqueId, 'tracked-mosque');
  });

  testWidgets(
      'home page keeps nearby sections honest when no location is saved',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    final service = _FakeMosqueService(
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _FakeLocationPreferencesService(null),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Set location'), findsOneWidget);
    expect(find.text('Set your location'), findsOneWidget);
    expect(find.text('Save your location to load nearby mosque prayer times.'),
        findsOneWidget);
    expect(service.prayerTimeRequests, isEmpty);
  });

  testWidgets('home page location header opens the location setup flow',
      (tester) async {
    final fixedNow = _todayAt(15, 0);
    final service = _FakeMosqueService(
      nowProvider: () => fixedNow,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(_TrackingMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.locationSetup) {
              final args = settings.arguments! as LocationSetupFlowArgs;
              return MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Text(
                    'Setup -> ${args.nextRoute} / clear=${args.clearStackOnComplete}',
                  ),
                ),
              );
            }
            if (settings.name == AppRoutes.profileSettings) {
              return MaterialPageRoute<void>(
                builder: (_) =>
                    const Scaffold(body: Text('Profile settings stub')),
              );
            }
            return null;
          },
          home: HomePage1(
            mosqueService: service,
            locationPreferencesService: _preciseLocationService(),
            nowProvider: () => fixedNow,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-location-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Setup -> ${AppRoutes.home} / clear=true'),
      findsOneWidget,
    );
  });

  testWidgets('map screen explains the launch-safe location scope',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          locationPreferencesService: _FakeLocationPreferencesService(null),
          currentLocationService:
              const _FakeCurrentLocationService(isSupported: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Choose how to update your location'),
      findsOneWidget,
    );
    expect(
      find.textContaining('current-location access on this platform'),
      findsOneWidget,
    );
    expect(find.text('Use my current location'), findsOneWidget);
    expect(find.text('Search for a location'), findsOneWidget);
  });

  testWidgets('map screen hides current-location CTA when unsupported',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          locationPreferencesService: _FakeLocationPreferencesService(null),
          currentLocationService:
              const _FakeCurrentLocationService(isSupported: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Use my current location'), findsNothing);
    expect(find.text('Search for a location'), findsOneWidget);
    expect(
      find.byKey(const Key('map-current-location-unavailable')),
      findsOneWidget,
    );
    expect(
      find.textContaining('supported browsers running in a secure context'),
      findsOneWidget,
    );
  });

  testWidgets('map screen launches current-location setup back to home',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.locationSetup) {
            final args = settings.arguments! as LocationSetupFlowArgs;
            return MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Text(
                  'Setup -> ${args.nextRoute} / clear=${args.clearStackOnComplete}',
                ),
              ),
            );
          }
          return null;
        },
        home: MapScreen(
          locationPreferencesService: _FakeLocationPreferencesService(null),
          currentLocationService:
              const _FakeCurrentLocationService(isSupported: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();

    expect(
      find.text('Setup -> ${AppRoutes.home} / clear=true'),
      findsOneWidget,
    );
  });

  testWidgets('map screen launches manual setup back to home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.locationSetupManual) {
            final args = settings.arguments! as LocationSetupFlowArgs;
            return MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Text(
                  'Manual setup -> ${args.nextRoute} / clear=${args.clearStackOnComplete}',
                ),
              ),
            );
          }
          return null;
        },
        home: MapScreen(
          locationPreferencesService: _FakeLocationPreferencesService(null),
          currentLocationService:
              const _FakeCurrentLocationService(isSupported: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search for a location'));
    await tester.pumpAndSettle();

    expect(
      find.text('Manual setup -> ${AppRoutes.home} / clear=true'),
      findsOneWidget,
    );
  });
}
