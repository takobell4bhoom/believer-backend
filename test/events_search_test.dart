import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/data/mock_provider.dart';
import 'package:believer/data/mosque_provider.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/event_search_listing.dart';
import 'package:believer/screens/events_search.dart';

class _EmptyMosqueNotifier extends MosqueNotifier {
  @override
  Future<List<MosqueModel>> build() async {
    return const <MosqueModel>[];
  }

  @override
  Future<List<MosqueModel>> loadNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    state = const AsyncData(<MosqueModel>[]);
    return const <MosqueModel>[];
  }
}

void main() {
  testWidgets(
      'events search asks users to save a location before loading nearby events',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(_EmptyMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.nearbyEvents: (context) => EventSearchListing(
                  args: ModalRoute.of(context)!.settings.arguments!
                      as EventSearchListingRouteArgs,
                ),
            AppRoutes.mosqueSearch: (_) =>
                const Scaffold(body: Text('Mosque search stub')),
            AppRoutes.map: (_) =>
                Scaffold(appBar: AppBar(), body: const Text('Map stub')),
            AppRoutes.profileSettings: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Profile settings stub'),
                ),
          },
          home: const EventsSearch(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Mosques'), findsOneWidget);
    expect(find.text('Location unavailable'), findsOneWidget);
    expect(find.text('View published\nevents & classes'), findsOneWidget);
    expect(find.text('CHARITY'), findsOneWidget);
    expect(find.text('CELEBRATIONS'), findsOneWidget);
    expect(find.text('ISLAMIC KNOWLEDGE'), findsOneWidget);
    expect(find.text('Zakat &\nsadaqah'), findsOneWidget);
    expect(find.text('Qur’anic\nstudies'), findsOneWidget);

    await tester.tap(find.text('View published\nevents & classes'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();

    expect(find.text('PUBLISHED NEAR YOU'), findsOneWidget);
    expect(
      find.textContaining(
        'Save a location to load nearby mosques with published events and classes.',
      ),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.byType(EventSearchListing))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Location unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Map stub'), findsOneWidget);

    Navigator.of(tester.element(find.text('Map stub'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Profile settings stub'), findsOneWidget);
  });

  testWidgets(
      'events search shows an honest empty state when a saved location has no published events',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'user.location': 'Tampa, FL, USA',
      'user.location.latitude': 27.9506,
      'user.location.longitude': -82.4572,
    });

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
        mosqueProvider.overrideWith(_EmptyMosqueNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.nearbyEvents: (context) => EventSearchListing(
                  args: ModalRoute.of(context)!.settings.arguments!
                      as EventSearchListingRouteArgs,
                ),
            AppRoutes.mosqueSearch: (_) =>
                const Scaffold(body: Text('Mosque search stub')),
            AppRoutes.map: (_) =>
                Scaffold(appBar: AppBar(), body: const Text('Map stub')),
            AppRoutes.profileSettings: (_) =>
                const Scaffold(body: Text('Profile settings stub')),
          },
          home: const EventsSearch(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tampa, FL, USA'), findsOneWidget);

    await tester.tap(find.text('View published\nevents & classes'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'No nearby mosques have published public event or class details for Tampa, FL, USA yet.',
      ),
      findsOneWidget,
    );
  });
}
