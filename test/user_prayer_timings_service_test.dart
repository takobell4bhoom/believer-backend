import 'package:flutter_test/flutter_test.dart';

import 'package:believer/models/prayer_timings.dart';
import 'package:believer/services/user_prayer_timings_service.dart';

class _FakeUserPrayerTimingsApiGateway extends UserPrayerTimingsApiGateway {
  const _FakeUserPrayerTimingsApiGateway(this.response, {this.onGet});

  final Map<String, dynamic> response;
  final void Function(String path, Map<String, String>? query)? onGet;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    onGet?.call(path, query);
    return response;
  }
}

void main() {
  test('UserPrayerTimingsService parses user-location prayer timing payloads',
      () async {
    final service = UserPrayerTimingsService(
      apiGateway: _FakeUserPrayerTimingsApiGateway(
        <String, dynamic>{
          'data': <String, dynamic>{
            'mosqueId': '',
            'date': '2026-04-18',
            'dateLabel': '20 Shawwal 1447 AH | Sat 18 Apr',
            'status': 'ready',
            'isConfigured': true,
            'isAvailable': true,
            'source': 'aladhan',
            'unavailableReason': null,
            'timezone': 'Asia/Kolkata',
            'configuration': <String, dynamic>{
              'enabled': true,
              'latitude': 12.9716,
              'longitude': 77.5946,
              'calculationMethod': <String, dynamic>{
                'id': 3,
                'name': 'Muslim World League',
              },
              'school': <String, dynamic>{
                'value': 'hanafi',
                'label': 'Hanafi',
              },
              'adjustments': <String, dynamic>{
                'fajr': 0,
                'sunrise': 0,
                'dhuhr': 0,
                'asr': 0,
                'maghrib': 0,
                'isha': 0,
              },
            },
            'timings': <String, dynamic>{
              'fajr': '05:08 AM',
              'sunrise': '06:18 AM',
              'dhuhr': '12:31 PM',
              'asr': '04:02 PM',
              'maghrib': '06:41 PM',
              'isha': '07:55 PM',
            },
            'nextPrayer': 'Asr',
            'nextPrayerTime': '04:02 PM',
            'cachedAt': '2026-04-18T08:50:00.000Z',
          },
          'error': null,
          'meta': <String, dynamic>{},
        },
        onGet: (path, query) {
          expect(path, '/api/v1/prayer-times/daily');
          expect(query, <String, String>{
            'date': '2026-04-18',
            'latitude': '12.9716',
            'longitude': '77.5946',
            'school': 'hanafi',
          });
        },
      ),
    );

    final timings = await service.getDailyTimings(
      date: '2026-04-18',
      latitude: 12.9716,
      longitude: 77.5946,
      school: 'hanafi',
    );

    expect(timings, isA<PrayerTimings>());
    expect(timings.dateLabel, '20 Shawwal 1447 AH | Sat 18 Apr');
    expect(timings.timeFor('asr'), '04:02 PM');
    expect(timings.configuration?.school, 'hanafi');
  });

  test('UserPrayerTimingsService only sends method when explicitly overridden',
      () async {
    final capturedQueries = <Map<String, String>?>[];
    final service = UserPrayerTimingsService(
      apiGateway: _FakeUserPrayerTimingsApiGateway(
        const <String, dynamic>{
          'data': <String, dynamic>{},
          'error': null,
          'meta': <String, dynamic>{},
        },
        onGet: (_, query) => capturedQueries.add(query),
      ),
    );

    await service.getDailyTimings(
      date: '2026-04-18',
      latitude: 27.9944,
      longitude: -81.7603,
      school: 'standard',
    );
    await service.getDailyTimings(
      date: '2026-04-18',
      latitude: 27.9944,
      longitude: -81.7603,
      school: 'standard',
      calculationMethodId: 4,
    );

    expect(capturedQueries, <Map<String, String>?>[
      <String, String>{
        'date': '2026-04-18',
        'latitude': '27.9944',
        'longitude': '-81.7603',
        'school': 'standard',
      },
      <String, String>{
        'date': '2026-04-18',
        'latitude': '27.9944',
        'longitude': '-81.7603',
        'school': 'standard',
        'method': '4',
      },
    ]);
  });
}
