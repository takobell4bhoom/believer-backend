import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/data/mosque_provider.dart';
import 'package:believer/models/mosque_content.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/models/prayer_timings.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/home_page_1.dart';
import 'package:believer/screens/location_setup_screen.dart';
import 'package:believer/services/current_location_service.dart';
import 'package:believer/services/location_preferences_service.dart';
import 'package:believer/services/mosque_service.dart';
import 'package:believer/services/prayer_settings_service.dart';

class _FakeLocationPreferencesService extends LocationPreferencesService {
  _FakeLocationPreferencesService({
    this.resolvedLocation,
    this.reverseResolvedLabel,
    this.suggestions = const <LocationSuggestion>[],
  });

  final ResolvedLocation? resolvedLocation;
  final String? reverseResolvedLabel;
  final List<LocationSuggestion> suggestions;

  String? lastResolvedQuery;
  String? lastSearchedQuery;

  @override
  Future<ResolvedLocation?> resolveLocation(String location) async {
    lastResolvedQuery = location;
    return resolvedLocation;
  }

  @override
  Future<List<LocationSuggestion>> searchLocations(
    String query, {
    int limit = 5,
  }) async {
    lastSearchedQuery = query;
    return suggestions.take(limit).toList(growable: false);
  }

  @override
  Future<String?> reverseResolveLocation({
    required double latitude,
    required double longitude,
  }) async {
    return reverseResolvedLabel;
  }
}

class _FakeCurrentLocationService implements CurrentLocationService {
  _FakeCurrentLocationService({this.isSupported = true});

  @override
  final bool isSupported;

  int requestCount = 0;
  Future<CurrentLocationCoordinates> Function()? onRequest;

  @override
  Future<CurrentLocationCoordinates> getCurrentCoordinates() async {
    requestCount += 1;
    final handler = onRequest;
    if (handler != null) {
      return handler();
    }
    throw const CurrentLocationException('Location failed');
  }
}

class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async => null;
}

class _TrackingMosqueNotifier extends MosqueNotifier {
  _TrackingMosqueNotifier(this._mosques);

  final List<MosqueModel> _mosques;
  double? lastLatitude;
  double? lastLongitude;

  @override
  Future<List<MosqueModel>> build() async => _mosques;

  @override
  Future<List<MosqueModel>> loadNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    lastLatitude = latitude;
    lastLongitude = longitude;
    state = AsyncData(_mosques);
    return _mosques;
  }
}

class _FakeMosqueService extends MosqueService {
  @override
  Future<MosqueContent> getMosqueContent(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const MosqueContent(events: [], classes: [], connect: []);
  }

  @override
  Future<PrayerTimings> getPrayerTimings({
    required String mosqueId,
    required String date,
    String? bearerToken,
  }) async {
    return PrayerTimings(
      mosqueId: mosqueId,
      date: date,
      status: 'ready',
      isConfigured: true,
      isAvailable: true,
      source: 'test',
      unavailableReason: null,
      timezone: 'America/New_York',
      configuration: const PrayerTimeConfiguration(
        enabled: true,
        latitude: 27.9506,
        longitude: -82.4572,
        calculationMethodId: 3,
        calculationMethodName: 'Muslim World League',
        school: 'hanafi',
        schoolLabel: 'Hanafi',
        adjustments: <String, int>{
          'fajr': 0,
          'sunrise': 0,
          'dhuhr': 0,
          'asr': 0,
          'maghrib': 0,
          'isha': 0,
        },
      ),
      timings: const <String, String>{
        'fajr': '05:08 AM',
        'sunrise': '06:18 AM',
        'dhuhr': '12:31 PM',
        'asr': '04:02 PM',
        'maghrib': '06:41 PM',
        'isha': '07:55 PM',
      },
      nextPrayer: 'Asr',
      nextPrayerTime: '04:02 PM',
      cachedAt: '2026-04-15T00:00:00.000Z',
    );
  }
}

const _nearbyMosques = <MosqueModel>[
  MosqueModel(
    id: 'mosque-001',
    name: 'East London Mosque and London Muslim Centre',
    addressLine: '82-92 Whitechapel Road',
    city: 'London',
    state: 'England',
    country: 'United Kingdom',
    latitude: 51.5194,
    longitude: -0.0632,
    imageUrl: 'https://example.com/mosque-1.jpg',
    rating: 4.8,
    distanceMiles: 0.7,
    sect: 'Sunni',
    womenPrayerArea: true,
    parking: true,
    wudu: true,
    facilities: <String>['parking', 'wudu'],
    isVerified: true,
    isBookmarked: false,
    duhrTime: '12:31 PM',
    asarTime: '04:02 PM',
    isOpenNow: true,
    classTags: <String>['Quran'],
    eventTags: <String>['Community'],
  ),
];

LocationPreferencesService _testLocationPreferencesService =
    _FakeLocationPreferencesService(
  resolvedLocation: const ResolvedLocation(
    label: 'Tampa, Florida',
    latitude: 27.9506,
    longitude: -82.4572,
  ),
  suggestions: const <LocationSuggestion>[
    LocationSuggestion(
      label: 'Downtown Tampa, FL, USA',
      primaryText: 'Downtown Tampa',
      secondaryText: 'FL, USA',
      latitude: 27.9506,
      longitude: -82.4572,
    ),
  ],
  reverseResolvedLabel: 'Downtown Tampa, FL, USA',
);

PrayerSettingsService _testPrayerSettingsService = PrayerSettingsService();
_FakeCurrentLocationService _testCurrentLocationService =
    _FakeCurrentLocationService();

ProviderContainer _createHomeContainer(_TrackingMosqueNotifier notifier) {
  return ProviderContainer(
    overrides: [
      authProvider.overrideWith(_SignedOutAuthNotifier.new),
      mosqueProvider.overrideWith(() => notifier),
    ],
  );
}

MaterialApp _buildHomeFlowApp({
  required ProviderContainer container,
  required RouteFactory routeFactory,
  String initialRoute = AppRoutes.locationSetup,
}) {
  return MaterialApp(
    onGenerateRoute: (settings) {
      if (settings.name == AppRoutes.home) {
        return MaterialPageRoute<void>(
          builder: (_) => UncontrolledProviderScope(
            container: container,
            child: HomePage1(
              mosqueService: _FakeMosqueService(),
              locationPreferencesService: LocationPreferencesService(),
            ),
          ),
          settings: settings,
        );
      }

      return routeFactory(settings);
    },
    initialRoute: initialRoute,
  );
}

void main() {
  testWidgets('location setup renders in compact viewport without overflow',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _testLocationPreferencesService = _FakeLocationPreferencesService(
      reverseResolvedLabel: 'Downtown Tampa, FL, USA',
    );
    _testPrayerSettingsService = PrayerSettingsService();
    _testCurrentLocationService = _FakeCurrentLocationService()
      ..onRequest = () async => const CurrentLocationCoordinates(
            latitude: 27.9506,
            longitude: -82.4572,
          );

    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 620);

    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: _routeFactory,
        initialRoute: AppRoutes.locationSetup,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2-Step Set Up'), findsOneWidget);
    expect(find.text('Set Location'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tapping current location requests geolocation and shows the loading screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final completer = Completer<CurrentLocationCoordinates>();
    _testLocationPreferencesService = _FakeLocationPreferencesService(
      reverseResolvedLabel: 'Downtown Tampa, FL, USA',
    );
    _testPrayerSettingsService = PrayerSettingsService();
    _testCurrentLocationService = _FakeCurrentLocationService()
      ..onRequest = () => completer.future;

    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: _routeFactory,
        initialRoute: AppRoutes.locationSetup,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('location-setup-current-location')));
    await tester.pump();

    expect(_testCurrentLocationService.requestCount, 1);
    expect(find.byKey(const Key('location-setup-loading')), findsOneWidget);

    completer.complete(
      const CurrentLocationCoordinates(
        latitude: 27.9506,
        longitude: -82.4572,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
      'successful current-location setup persists coordinates and advances to Asar step',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _testLocationPreferencesService = _FakeLocationPreferencesService(
      reverseResolvedLabel: 'Downtown Tampa, FL, USA',
    );
    _testPrayerSettingsService = PrayerSettingsService();
    _testCurrentLocationService = _FakeCurrentLocationService()
      ..onRequest = () async => const CurrentLocationCoordinates(
            latitude: 27.9506,
            longitude: -82.4572,
          );

    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: _routeFactory,
        initialRoute: AppRoutes.locationSetup,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('location-setup-current-location')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user.location'), 'Downtown Tampa, FL, USA');
    expect(prefs.getDouble('user.location.latitude'), 27.9506);
    expect(prefs.getDouble('user.location.longitude'), -82.4572);
    expect(find.text('Set Asar Time'), findsOneWidget);
  });

  testWidgets(
      'denied current-location setup stays honest and allows retry or manual entry',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _testLocationPreferencesService = _FakeLocationPreferencesService();
    _testPrayerSettingsService = PrayerSettingsService();
    _testCurrentLocationService = _FakeCurrentLocationService()
      ..onRequest = () async {
        throw const CurrentLocationException(
          'Location permission was denied. Please allow access and try again, or enter your location manually.',
        );
      };

    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: _routeFactory,
        initialRoute: AppRoutes.locationSetup,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('location-setup-current-location')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Location permission was denied'),
      findsOneWidget,
    );
    expect(find.text('Try current location again'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('location-setup-manual-entry')),
    );
    await tester.tap(find.byKey(const Key('location-setup-manual-entry')));
    await tester.pumpAndSettle();

    expect(find.text('Enter Location'), findsOneWidget);
    expect(_testCurrentLocationService.requestCount, 1);
  });

  testWidgets('unsupported current-location platforms lead with manual setup',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _testLocationPreferencesService = _FakeLocationPreferencesService();
    _testPrayerSettingsService = PrayerSettingsService();
    _testCurrentLocationService =
        _FakeCurrentLocationService(isSupported: false);

    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: _routeFactory,
        initialRoute: AppRoutes.locationSetup,
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('location-setup-current-location')), findsNothing);
    expect(
      find.byKey(const Key('location-setup-current-location-unavailable')),
      findsOneWidget,
    );
    expect(
        find.byKey(const Key('location-setup-manual-primary')), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const Key('location-setup-manual-primary')));
    await tester.tap(find.byKey(const Key('location-setup-manual-primary')));
    await tester.pumpAndSettle();

    expect(find.text('Enter Location'), findsOneWidget);
    expect(_testCurrentLocationService.requestCount, 0);
  });

  testWidgets('manual location flow persists selection and continues to Asar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _testLocationPreferencesService = _FakeLocationPreferencesService(
      resolvedLocation: const ResolvedLocation(
        label: 'Downtown Tampa, FL, USA',
        latitude: 27.9506,
        longitude: -82.4572,
      ),
      suggestions: const <LocationSuggestion>[
        LocationSuggestion(
          label: 'Downtown Tampa, FL, USA',
          primaryText: 'Downtown Tampa',
          secondaryText: 'FL, USA',
          latitude: 27.9506,
          longitude: -82.4572,
        ),
      ],
    );
    _testPrayerSettingsService = PrayerSettingsService();
    _testCurrentLocationService = _FakeCurrentLocationService();

    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: _routeFactory,
        initialRoute: AppRoutes.locationSetupManual,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Downtown Tampa',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Downtown Tampa'), findsAtLeastNWidgets(1));
    expect(find.text('FL, USA'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('location-option-0')));
    await tester.tap(find.byKey(const Key('location-option-0')));
    await tester.pumpAndSettle();

    final prefsAfterSelection = await SharedPreferences.getInstance();
    expect(prefsAfterSelection.getString('user.location'),
        'Downtown Tampa, FL, USA');
    expect(prefsAfterSelection.getDouble('user.location.latitude'), 27.9506);
    expect(prefsAfterSelection.getDouble('user.location.longitude'), -82.4572);

    await tester
        .ensureVisible(find.byKey(const Key('location-setup-continue')));
    await tester.tap(find.byKey(const Key('location-setup-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Location'), findsOneWidget);
    expect(find.text('Downtown Tampa, FL, USA'), findsWidgets);
    expect(
      find.byKey(const Key('location-confirmation-coordinates')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('location-map-confirm')));
    await tester.tap(find.byKey(const Key('location-map-confirm')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user.location'), 'Downtown Tampa, FL, USA');
    expect(prefs.getDouble('user.location.latitude'), 27.9506);
    expect(prefs.getDouble('user.location.longitude'), -82.4572);
    expect(find.text('Set Asar Time'), findsOneWidget);
  });

  testWidgets('Asar choice persists and completes setup handoff',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _testLocationPreferencesService = _FakeLocationPreferencesService();
    _testPrayerSettingsService = PrayerSettingsService();
    _testCurrentLocationService = _FakeCurrentLocationService();

    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: _routeFactory,
        initialRoute: AppRoutes.locationSetupAsar,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('asar-option-early')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('location-setup-asar-continue')),
    );
    await tester.tap(find.byKey(const Key('location-setup-asar-continue')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('prayer_settings.asar_time_mode'),
      AsarTimeMode.early.name,
    );
    expect(find.text('Home stub'), findsOneWidget);
  });

  testWidgets(
      'current-location flow lands on Home and Home loads nearby mosques from saved coordinates',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _testLocationPreferencesService = _FakeLocationPreferencesService(
      reverseResolvedLabel: 'Downtown Tampa, FL, USA',
    );
    _testPrayerSettingsService = PrayerSettingsService();
    _testCurrentLocationService = _FakeCurrentLocationService()
      ..onRequest = () async => const CurrentLocationCoordinates(
            latitude: 27.9506,
            longitude: -82.4572,
          );

    final notifier = _TrackingMosqueNotifier(_nearbyMosques);
    final container = _createHomeContainer(notifier);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHomeFlowApp(
        container: container,
        routeFactory: _routeFactory,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('location-setup-current-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('asar-option-early')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('location-setup-asar-continue')),
    );
    await tester.tap(find.byKey(const Key('location-setup-asar-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Downtown Tampa, FL, USA'), findsWidgets);
    expect(
      find.text('East London Mosque and London Muslim Centre'),
      findsAtLeastNWidgets(1),
    );
    expect(notifier.lastLatitude, 27.9506);
    expect(notifier.lastLongitude, -82.4572);
  });

  testWidgets(
      'manual-location flow lands on Home and Home loads nearby mosques from saved coordinates',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _testLocationPreferencesService = _FakeLocationPreferencesService(
      resolvedLocation: const ResolvedLocation(
        label: 'Downtown Tampa, FL, USA',
        latitude: 27.9506,
        longitude: -82.4572,
      ),
      suggestions: const <LocationSuggestion>[
        LocationSuggestion(
          label: 'Downtown Tampa, FL, USA',
          primaryText: 'Downtown Tampa',
          secondaryText: 'FL, USA',
          latitude: 27.9506,
          longitude: -82.4572,
        ),
      ],
    );
    _testPrayerSettingsService = PrayerSettingsService();
    _testCurrentLocationService = _FakeCurrentLocationService();

    final notifier = _TrackingMosqueNotifier(_nearbyMosques);
    final container = _createHomeContainer(notifier);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHomeFlowApp(
        container: container,
        routeFactory: _routeFactory,
        initialRoute: AppRoutes.locationSetupManual,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Downtown Tampa');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-option-0')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('location-setup-continue')));
    await tester.tap(find.byKey(const Key('location-setup-continue')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('location-map-confirm')));
    await tester.tap(find.byKey(const Key('location-map-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('asar-option-early')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('location-setup-asar-continue')),
    );
    await tester.tap(find.byKey(const Key('location-setup-asar-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Downtown Tampa, FL, USA'), findsWidgets);
    expect(
      find.text('East London Mosque and London Muslim Centre'),
      findsAtLeastNWidgets(1),
    );
    expect(notifier.lastLatitude, 27.9506);
    expect(notifier.lastLongitude, -82.4572);
  });
}

Route<dynamic>? _routeFactory(RouteSettings settings) {
  if (settings.name == AppRoutes.home) {
    return MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Home stub')),
      settings: settings,
    );
  }
  if (settings.name == AppRoutes.login) {
    return MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Login stub')),
      settings: settings,
    );
  }
  if (settings.name == AppRoutes.locationSetup) {
    final args = settings.arguments;
    return MaterialPageRoute<void>(
      builder: (_) => LocationSetupScreen(
        flowArgs: args is LocationSetupFlowArgs
            ? args
            : const LocationSetupFlowArgs(nextRoute: AppRoutes.home),
        locationPreferencesService: _testLocationPreferencesService,
        currentLocationService: _testCurrentLocationService,
      ),
      settings: settings,
    );
  }
  if (settings.name == AppRoutes.locationSetupManual) {
    final args = settings.arguments;
    return MaterialPageRoute<void>(
      builder: (_) => ManualLocationSetupScreen(
        flowArgs: args is LocationSetupFlowArgs
            ? args
            : const LocationSetupFlowArgs(nextRoute: AppRoutes.home),
        locationPreferencesService: _testLocationPreferencesService,
      ),
      settings: settings,
    );
  }
  if (settings.name == AppRoutes.locationSetupMap &&
      settings.arguments is LocationSetupMapArgs) {
    return MaterialPageRoute<void>(
      builder: (_) => LocationSetupMapScreen(
        flowArgs: settings.arguments as LocationSetupMapArgs,
      ),
      settings: settings,
    );
  }
  if (settings.name == AppRoutes.locationSetupAsar) {
    final args = settings.arguments;
    return MaterialPageRoute<void>(
      builder: (_) => LocationSetupAsarScreen(
        flowArgs: args is LocationSetupFlowArgs
            ? args
            : const LocationSetupFlowArgs(nextRoute: AppRoutes.home),
        prayerSettingsService: _testPrayerSettingsService,
      ),
      settings: settings,
    );
  }
  return null;
}
