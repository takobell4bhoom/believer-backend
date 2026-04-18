import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/models/prayer_timings.dart';
import 'package:believer/screens/prayer_notifications_settings_page.dart';
import 'package:believer/services/location_preferences_service.dart';
import 'package:believer/services/user_prayer_timings_service.dart';

class _FakeLocationPreferencesService extends LocationPreferencesService {
  _FakeLocationPreferencesService(this.savedLocation);

  SavedUserLocation? savedLocation;

  @override
  Future<SavedUserLocation?> loadSavedLocation() async => savedLocation;

  @override
  Future<String> loadCurrentLocation() async =>
      savedLocation?.label ?? LocationPreferencesService.defaultLocation;
}

class _FakeUserPrayerTimingsService extends UserPrayerTimingsService {
  _FakeUserPrayerTimingsService({
    this.standardTimings,
    this.hanafiTimings,
    this.error,
    this.onRequest,
  });

  PrayerTimings? standardTimings;
  PrayerTimings? hanafiTimings;
  Object? error;
  PrayerTimings Function(
    String school,
    double latitude,
    double longitude,
    int? calculationMethodId,
  )? onRequest;
  final List<Map<String, Object?>> requests = <Map<String, Object?>>[];

  @override
  Future<PrayerTimings> getDailyTimings({
    required String date,
    required double latitude,
    required double longitude,
    required String school,
    int? calculationMethodId,
  }) async {
    requests.add(<String, Object?>{
      'date': date,
      'latitude': latitude,
      'longitude': longitude,
      'school': school,
      'method': calculationMethodId,
    });
    if (error != null) {
      throw error!;
    }

    if (onRequest != null) {
      return onRequest!(school, latitude, longitude, calculationMethodId);
    }

    return school == 'hanafi'
        ? hanafiTimings ?? standardTimings!
        : standardTimings!;
  }
}

PrayerTimings _buildPrayerTimings({
  required String dateLabel,
  required Map<String, String> timings,
  required String nextPrayer,
  required String nextPrayerTime,
  int calculationMethodId = 3,
  String calculationMethodName = 'Muslim World League',
}) {
  return PrayerTimings(
    mosqueId: '',
    date: '2026-04-18',
    dateLabel: dateLabel,
    status: 'ready',
    isConfigured: true,
    isAvailable: true,
    source: 'aladhan',
    unavailableReason: null,
    timezone: 'Asia/Kolkata',
    configuration: PrayerTimeConfiguration(
      enabled: true,
      latitude: 12.9716,
      longitude: 77.5946,
      calculationMethodId: calculationMethodId,
      calculationMethodName: calculationMethodName,
      school: 'standard',
      schoolLabel: 'Standard',
      adjustments: const <String, int>{
        'fajr': 0,
        'sunrise': 0,
        'dhuhr': 0,
        'asr': 0,
        'maghrib': 0,
        'isha': 0,
      },
    ),
    timings: timings,
    nextPrayer: nextPrayer,
    nextPrayerTime: nextPrayerTime,
    cachedAt: '2026-04-18T08:40:00.000Z',
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required LocationPreferencesService locationPreferencesService,
  required UserPrayerTimingsService userPrayerTimingsService,
  DateTime Function()? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PrayerNotificationsSettingsPage(
        locationPreferencesService: locationPreferencesService,
        userPrayerTimingsService: userPrayerTimingsService,
        now: now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prayer settings renders in compact viewport without overflow',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 620);

    await _pumpPage(
      tester,
      locationPreferencesService: _FakeLocationPreferencesService(null),
      userPrayerTimingsService: _FakeUserPrayerTimingsService(),
      now: () => DateTime(2026, 4, 18, 14, 20),
    );

    expect(find.text('Prayer Notifications & Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'live timings render from service data instead of hardcoded values',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'prayer_settings.asar_time_mode': 'late',
    });
    final timingsService = _FakeUserPrayerTimingsService(
      hanafiTimings: _buildPrayerTimings(
        dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
        timings: const <String, String>{
          'fajr': '05:11 AM',
          'sunrise': '06:19 AM',
          'dhuhr': '01:17 PM',
          'asr': '04:42 PM',
          'maghrib': '06:33 PM',
          'isha': '07:46 PM',
        },
        nextPrayer: 'Asr',
        nextPrayerTime: '04:42 PM',
      ),
    );

    await _pumpPage(
      tester,
      locationPreferencesService: _FakeLocationPreferencesService(
        const SavedUserLocation(
          label: 'Bengaluru, Karnataka',
          latitude: 12.9716,
          longitude: 77.5946,
        ),
      ),
      userPrayerTimingsService: timingsService,
      now: () => DateTime(2026, 4, 18, 14, 20),
    );

    expect(find.text('20 Shawwal 1447 AH | Sat 18 Apr'), findsOneWidget);
    expect(find.text('Duhr'), findsWidgets);
    expect(find.text('01:17 PM - 04:42 PM'), findsOneWidget);
    expect(find.text('Ends in 2 hrs 22 mins'), findsOneWidget);
    expect(find.text('05:11 AM'), findsOneWidget);
    expect(find.text('04:42 PM'), findsWidgets);
    expect(find.text('Method: Muslim World League'), findsOneWidget);

    expect(find.text('10 Rajab 1446 AH | Fri 10 Jan'), findsNothing);
    expect(find.text('12:30 PM'), findsNothing);
    expect(find.text('03:51 PM'), findsNothing);
    expect(timingsService.requests.single['school'], 'hanafi');
    expect(timingsService.requests.single['method'], isNull);
  });

  testWidgets('asar mode change triggers school-based timing refresh',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'prayer_settings.asar_time_mode': 'early',
    });
    final timingsService = _FakeUserPrayerTimingsService(
      standardTimings: _buildPrayerTimings(
        dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
        timings: const <String, String>{
          'fajr': '05:09 AM',
          'sunrise': '06:17 AM',
          'dhuhr': '01:10 PM',
          'asr': '04:08 PM',
          'maghrib': '06:31 PM',
          'isha': '07:44 PM',
        },
        nextPrayer: 'Asr',
        nextPrayerTime: '04:08 PM',
      ),
      hanafiTimings: _buildPrayerTimings(
        dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
        timings: const <String, String>{
          'fajr': '05:09 AM',
          'sunrise': '06:17 AM',
          'dhuhr': '01:10 PM',
          'asr': '04:39 PM',
          'maghrib': '06:31 PM',
          'isha': '07:44 PM',
        },
        nextPrayer: 'Asr',
        nextPrayerTime: '04:39 PM',
      ),
    );

    await _pumpPage(
      tester,
      locationPreferencesService: _FakeLocationPreferencesService(
        const SavedUserLocation(
          label: 'Bengaluru, Karnataka',
          latitude: 12.9716,
          longitude: 77.5946,
        ),
      ),
      userPrayerTimingsService: timingsService,
      now: () => DateTime(2026, 4, 18, 14, 20),
    );

    expect(find.text('04:08 PM'), findsWidgets);
    expect(timingsService.requests.first['school'], 'standard');

    await tester.ensureVisible(find.byKey(const Key('asar-time-link')));
    await tester.tap(find.byKey(const Key('asar-time-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('asar-option-late')));
    await tester.pumpAndSettle();

    expect(find.text('04:39 PM'), findsWidgets);
    expect(timingsService.requests.last['school'], 'hanafi');
    expect(
      timingsService.requests.map((request) => request['method']).toList(),
      everyElement(isNull),
    );
  });

  testWidgets(
      'saved location coordinates drive location-specific rendered timings and method labels',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final locationService = _FakeLocationPreferencesService(
      const SavedUserLocation(
        label: 'Florida, USA',
        latitude: 27.9944,
        longitude: -81.7603,
      ),
    );
    final timingsService = _FakeUserPrayerTimingsService(
      onRequest: (school, latitude, longitude, calculationMethodId) {
        expect(calculationMethodId, isNull);
        if (latitude == 27.9944 && longitude == -81.7603) {
          return _buildPrayerTimings(
            dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
            timings: const <String, String>{
              'fajr': '05:48 AM',
              'sunrise': '06:58 AM',
              'dhuhr': '01:24 PM',
              'asr': '05:02 PM',
              'maghrib': '07:50 PM',
              'isha': '09:00 PM',
            },
            nextPrayer: 'Asr',
            nextPrayerTime: '05:02 PM',
            calculationMethodId: 2,
            calculationMethodName: 'Islamic Society of North America',
          );
        }

        return _buildPrayerTimings(
          dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
          timings: const <String, String>{
            'fajr': '04:54 AM',
            'sunrise': '06:08 AM',
            'dhuhr': '12:21 PM',
            'asr': '03:47 PM',
            'maghrib': '06:34 PM',
            'isha': '08:04 PM',
          },
          nextPrayer: 'Asr',
          nextPrayerTime: '03:47 PM',
          calculationMethodId: 4,
          calculationMethodName: 'Umm Al-Qura University, Makkah',
        );
      },
    );

    await _pumpPage(
      tester,
      locationPreferencesService: locationService,
      userPrayerTimingsService: timingsService,
      now: () => DateTime(2026, 4, 18, 14, 20),
    );

    expect(find.text('05:48 AM'), findsOneWidget);
    expect(find.text('05:02 PM'), findsWidgets);
    expect(find.text('Method: Islamic Society of North America'), findsOneWidget);

    locationService.savedLocation = const SavedUserLocation(
      label: 'Makkah, Saudi Arabia',
      latitude: 21.3891,
      longitude: 39.8579,
    );

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(find.text('04:54 AM'), findsOneWidget);
    expect(find.text('03:47 PM'), findsWidgets);
    expect(find.text('05:48 AM'), findsNothing);
    expect(find.text('05:02 PM'), findsNothing);
    expect(find.text('Method: Islamic Society of North America'), findsNothing);
    expect(find.text('Method: Umm Al-Qura University, Makkah'), findsOneWidget);
    expect(
      timingsService.requests.map((request) => request['latitude']).toList(),
      <Object?>[27.9944, 21.3891],
    );
  });

  testWidgets(
      'missing saved coordinates shows fallback state instead of fake timings',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final timingsService = _FakeUserPrayerTimingsService();

    await _pumpPage(
      tester,
      locationPreferencesService: _FakeLocationPreferencesService(
        const SavedUserLocation(label: 'Bengaluru, Karnataka'),
      ),
      userPrayerTimingsService: timingsService,
      now: () => DateTime(2026, 4, 18, 14, 20),
    );

    expect(find.text('Location Needed'), findsOneWidget);
    expect(
      find.text('Save your location coordinates to load today\'s timings'),
      findsOneWidget,
    );
    expect(find.text('--'), findsWidgets);
    expect(timingsService.requests, isEmpty);
  });

  testWidgets('failed timing read shows graceful unavailable state',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final timingsService = _FakeUserPrayerTimingsService(
      error: Exception('backend unavailable'),
    );

    await _pumpPage(
      tester,
      locationPreferencesService: _FakeLocationPreferencesService(
        const SavedUserLocation(
          label: 'Bengaluru, Karnataka',
          latitude: 12.9716,
          longitude: 77.5946,
        ),
      ),
      userPrayerTimingsService: timingsService,
      now: () => DateTime(2026, 4, 18, 14, 20),
    );

    expect(find.text('Unavailable'), findsOneWidget);
    expect(
      find.text(
        'Live prayer timings are temporarily unavailable. Please try again shortly.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again soon'), findsOneWidget);
  });

  testWidgets('show on homepage toggle persists across page reload',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'prayer_settings.asar_time_mode': 'late',
      'prayer_settings.show_suhoor_iftar': false,
    });

    final locationService = _FakeLocationPreferencesService(
      const SavedUserLocation(
        label: 'Bengaluru, Karnataka',
        latitude: 12.9716,
        longitude: 77.5946,
      ),
    );
    final timingsService = _FakeUserPrayerTimingsService(
      hanafiTimings: _buildPrayerTimings(
        dateLabel: '20 Shawwal 1447 AH | Sat 18 Apr',
        timings: const <String, String>{
          'fajr': '05:11 AM',
          'sunrise': '06:19 AM',
          'dhuhr': '01:17 PM',
          'asr': '04:42 PM',
          'maghrib': '06:33 PM',
          'isha': '07:46 PM',
        },
        nextPrayer: 'Asr',
        nextPrayerTime: '04:42 PM',
      ),
    );

    await _pumpPage(
      tester,
      locationPreferencesService: locationService,
      userPrayerTimingsService: timingsService,
      now: () => DateTime(2026, 4, 18, 14, 20),
    );

    final showHomeToggle = find.byKey(const Key('show-home-toggle'));
    await tester.ensureVisible(showHomeToggle);
    await tester.tap(showHomeToggle);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('prayer_settings.show_suhoor_iftar'), isTrue);

    await _pumpPage(
      tester,
      locationPreferencesService: locationService,
      userPrayerTimingsService: timingsService,
      now: () => DateTime(2026, 4, 18, 14, 20),
    );

    expect(prefs.getBool('prayer_settings.show_suhoor_iftar'), isTrue);
  });
}
