import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/data/mosque_provider.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/mosque_search_screen.dart';

class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return null;
  }
}

class _GuestMosqueNotifier extends MosqueNotifier {
  static const mosques = <MosqueModel>[
    MosqueModel(
      id: 'search-mosque-1',
      name: 'Mercy Community Mosque',
      addressLine: '12 Peace Road',
      city: 'Tampa',
      state: 'FL',
      country: 'US',
      imageUrl: '',
      rating: 4.7,
      reviewCount: 9,
      distanceMiles: 1.1,
      sect: 'Community',
      womenPrayerArea: true,
      parking: true,
      wudu: true,
      facilities: ['women prayer area', 'parking', 'wudu'],
      isVerified: true,
      isBookmarked: false,
      duhrTime: '01:15 PM',
      asarTime: '04:45 PM',
      isOpenNow: true,
      classTags: ['Quran Study'],
      eventTags: ['Family Night'],
    ),
  ];

  @override
  Future<List<MosqueModel>> build() async {
    return mosques;
  }

  @override
  Future<List<MosqueModel>> loadNearby({
    required double latitude,
    required double longitude,
    double? radiusMiles,
    double? radiusKm,
    int page = 1,
    int limit = nearbyMosquesPageSize,
    bool append = false,
  }) async {
    updateNearbyPagination(
      page: page,
      limit: limit,
      hasMore: false,
      total: mosques.length,
    );
    state = const AsyncData(mosques);
    return mosques;
  }
}

void main() {
  testWidgets(
      'signed-out guests can browse mosque search and open public result flows',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'user.location': 'Tampa, FL, USA',
      'user.location.latitude': 27.9506,
      'user.location.longitude': -82.4572,
    });

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_SignedOutAuthNotifier.new),
        mosqueProvider.overrideWith(_GuestMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.mosquesAndEvents: (_) =>
                const Scaffold(body: Text('Mosque listing stub')),
            AppRoutes.nearbyEvents: (_) =>
                const Scaffold(body: Text('Event listing stub')),
          },
          home: const MosqueSearchScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mosques'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Women Friendly'), findsOneWidget);
    expect(find.text('Redirecting...'), findsNothing);

    await tester.tap(find.text('Women Friendly'));
    await tester.pumpAndSettle();

    expect(find.text('Mosque listing stub'), findsOneWidget);

    Navigator.of(tester.element(find.text('Mosque listing stub'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Charity Drives'));
    await tester.tap(find.text('Charity Drives'));
    await tester.pumpAndSettle();

    expect(find.text('Event listing stub'), findsOneWidget);
  });
}
