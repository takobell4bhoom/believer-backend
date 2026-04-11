import 'package:flutter_test/flutter_test.dart';

import 'package:believer/models/prayer_timings.dart';
import 'package:believer/services/mosque_service.dart';

class _FakeMosqueApiGateway extends MosqueApiGateway {
  const _FakeMosqueApiGateway(this.response);

  final Map<String, dynamic> response;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    String? bearerToken,
  }) async {
    expect(path, '/api/v1/mosques/mosque-1/prayer-times');
    expect(query, <String, String>{'date': '2026-03-30'});
    return response;
  }
}

void main() {
  test('MosqueService parses backend prayer-time payloads', () async {
    final service = MosqueService(
      apiGateway: const _FakeMosqueApiGateway(
        <String, dynamic>{
          'data': <String, dynamic>{
            'mosqueId': 'mosque-1',
            'date': '2026-03-30',
            'status': 'ready',
            'isConfigured': true,
            'isAvailable': true,
            'source': 'cache',
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
                'fajr': 1,
                'sunrise': 0,
                'dhuhr': 2,
                'asr': 0,
                'maghrib': -1,
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
            'cachedAt': '2026-03-30T04:00:00.000Z',
          },
          'error': null,
          'meta': <String, dynamic>{},
        },
      ),
    );

    final timings = await service.getPrayerTimings(
      mosqueId: 'mosque-1',
      date: '2026-03-30',
    );

    expect(timings, isA<PrayerTimings>());
    expect(timings.isAvailable, isTrue);
    expect(timings.timeFor('dhuhr'), '12:31 PM');
    expect(timings.configuration?.calculationMethodId, 3);
    expect(timings.configuration?.school, 'hanafi');
    expect(timings.configuration?.adjustments['maghrib'], -1);
    expect(timings.nextPrayer, 'Asr');
  });
}
