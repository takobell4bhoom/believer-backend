import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/data/mock_provider.dart';
import 'package:believer/data/mosque_provider.dart';
import 'package:believer/models/discovery_event.dart';
import 'package:believer/models/mosque_content.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/event_detail_screen.dart';
import 'package:believer/screens/event_search_listing.dart';

MosqueModel _sampleEvent({
  required String id,
  required String name,
  required double distanceMiles,
  required List<String> classTags,
  required List<String> eventTags,
}) {
  return MosqueModel(
    id: id,
    name: name,
    addressLine: '123 Mercy Ave',
    city: 'Tampa',
    state: 'FL',
    country: 'US',
    imageUrl: '',
    rating: 4.8,
    distanceMiles: distanceMiles,
    sect: 'Sunni',
    womenPrayerArea: true,
    parking: true,
    wudu: true,
    facilities: const ['women_area', 'parking', 'wudu'],
    isVerified: true,
    isBookmarked: false,
    duhrTime: '1:15 PM',
    asarTime: '4:45 PM',
    isOpenNow: true,
    classes: classTags
        .map(
          (tag) => MosqueProgramItem(
            id: '$id-class-$tag',
            title: tag,
            schedule: 'Weekly',
            posterLabel: 'Class',
            location: '123 Mercy Ave',
            description: 'Class details for $tag.',
          ),
        )
        .toList(growable: false),
    events: eventTags
        .map(
          (tag) => MosqueProgramItem(
            id: '$id-event-$tag',
            title: tag,
            schedule: 'This Friday',
            posterLabel: 'Event',
            location: '123 Mercy Ave',
            description: 'Event details for $tag.',
          ),
        )
        .toList(growable: false),
    classTags: classTags,
    eventTags: eventTags,
  );
}

void main() {
  testWidgets(
      'event search listing renders discovery shell and opens event detail',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final events = [
      _sampleEvent(
        id: 'event-1',
        name: 'Harbor Community Iftar',
        distanceMiles: 2.3,
        classTags: const ['Community Reflections'],
        eventTags: const ['Harbor Sunset Iftar'],
      ),
      _sampleEvent(
        id: 'event-2',
        name: 'Seerah Essentials Weekend',
        distanceMiles: 3.1,
        classTags: const ['Quran Study'],
        eventTags: const ['Weekend Seerah Session'],
      ),
    ];

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
            AppRoutes.eventDetail: (_) =>
                const Scaffold(body: Text('Event detail stub')),
            AppRoutes.mosqueSearch: (_) =>
                const Scaffold(body: Text('Mosque search stub')),
            AppRoutes.profileSettings: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Profile settings stub'),
                ),
          },
          home: EventSearchListing(
            args: EventSearchListingRouteArgs(initialEvents: events),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Mosques'), findsOneWidget);
    expect(find.text('View published\nevents & classes'), findsOneWidget);
    expect(find.text('CHARITY'), findsOneWidget);
    expect(find.text('CELEBRATIONS'), findsOneWidget);
    expect(find.text('ISLAMIC KNOWLEDGE'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Profile settings stub'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('PUBLISHED NEAR YOU'), findsOneWidget);
    expect(find.text('Harbor Sunset Iftar'), findsOneWidget);
  });

  testWidgets('event detail renders in compact viewport without overflow',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          args: EventDetailRouteArgs(
            event: _sampleEvent(
              id: 'event-3',
              name: 'Seerah Learning Circle',
              distanceMiles: 2.3,
              classTags: const ['Quran Study'],
              eventTags: const ['Spiritual reflections'],
            ),
            discoveryEvent: DiscoveryEvent.fromMosqueProgram(
              _sampleEvent(
                id: 'event-3',
                name: 'Seerah Learning Circle',
                distanceMiles: 2.3,
                classTags: const ['Quran Study'],
                eventTags: const ['Spiritual reflections'],
              ),
              const MosqueProgramItem(
                id: 'program-1',
                title: 'Quran Study',
                schedule: 'Saturdays at 10:00 AM',
                posterLabel: 'Class',
                location: '123 Mercy Ave',
                description: 'Detailed Quran study session.',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Seerah Learning Circle'), findsWidgets);
    expect(find.text('EVENT SPEAKERS'), findsNothing);
    expect(find.text('ORGANIZER'), findsOneWidget);
    expect(find.text('Open Organizer Page'), findsOneWidget);
    expect(find.text('Islamic Knowledge'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
