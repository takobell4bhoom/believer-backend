import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/mosque_provider.dart';

void main() {
  test('nearby mosque query defaults to the shared 50 mile radius', () {
    final query = buildNearbyMosquesQuery(
      latitude: 27.9506,
      longitude: -82.4572,
    );

    expect(query['radius'], '80.4672');
    expect(query['page'], '1');
    expect(query['limit'], '$nearbyMosquesPageSize');
  });

  test('nearby mosque query converts slider mile selections to backend km', () {
    const cases = <({double miles, String kilometers})>[
      (miles: 30, kilometers: '48.28032'),
      (miles: 50, kilometers: '80.4672'),
      (miles: 100, kilometers: '160.9344'),
      (miles: 150, kilometers: '241.4016'),
    ];

    for (final testCase in cases) {
      final query = buildNearbyMosquesQuery(
        latitude: 27.9506,
        longitude: -82.4572,
        radiusMiles: testCase.miles,
      );

      expect(
        double.parse(query['radius']!),
        closeTo(double.parse(testCase.kilometers), 0.000001),
      );
    }
  });

  test('nearby mosque query forwards explicit page and limit values', () {
    final query = buildNearbyMosquesQuery(
      latitude: 27.9506,
      longitude: -82.4572,
      page: 3,
      limit: 15,
    );

    expect(query['page'], '3');
    expect(query['limit'], '15');
  });
}
