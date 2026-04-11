import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/location_setup_screen.dart';
import 'package:believer/services/current_location_service.dart';
import 'package:believer/services/location_preferences_service.dart';
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
