import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/models/discovery_event.dart';
import 'package:believer/models/mosque_content.dart';
import 'package:believer/models/mosque_model.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/event_detail_screen.dart';
import 'package:believer/services/outbound_action_service.dart';

class _FakeOutboundActionService extends OutboundActionService {
  @override
  Future<OutboundActionResult> shareText(
    String text, {
    String? subject,
    String successMessage = 'Share options opened.',
    String fallbackMessage =
        'Could not open share options. Details copied to clipboard.',
    String unavailableMessage = 'Nothing to share yet.',
  }) async {
    return const OutboundActionResult(
      message: 'Share options opened for this event.',
      didLaunch: true,
    );
  }

  @override
  Future<OutboundActionResult> launchDirections({
    required String? address,
    double? latitude,
    double? longitude,
    String successMessage = 'Opening directions...',
    String fallbackMessage =
        'Could not open maps. Address copied to clipboard.',
    String unavailableMessage =
        'Directions are not available for this listing yet.',
  }) async {
    return const OutboundActionResult(
      message: 'Opening event directions...',
      didLaunch: true,
    );
  }

  @override
  Future<OutboundActionResult> launchExternalLink(
    String? rawValue, {
    String? type,
    String successMessage = 'Opening link...',
    String fallbackMessage =
        'Could not open the link. Details copied to clipboard.',
    String unavailableMessage = 'Link not available yet.',
  }) async {
    return const OutboundActionResult(
      message: 'Opening organizer website...',
      didLaunch: true,
    );
  }
}

MosqueModel _websiteMosque() {
  return const MosqueModel(
    id: 'event-mosque-1',
    name: 'Tampa Bay Knowledge Night',
    addressLine: '25 Unity Ave',
    city: 'Tampa',
    state: 'FL',
    country: 'US',
    latitude: 27.9506,
    longitude: -82.4572,
    imageUrl: '',
    rating: 4.5,
    distanceMiles: 1.4,
    sect: 'Sunni',
    websiteUrl: 'tampabaymosque.org/events',
    womenPrayerArea: true,
    parking: true,
    wudu: true,
    facilities: ['parking', 'wudu'],
    isVerified: true,
    isBookmarked: false,
    duhrTime: '01:15 PM',
    asarTime: '04:45 PM',
    isOpenNow: true,
    classTags: ['Seerah Circle'],
    eventTags: ['Community Lecture'],
  );
}

MosqueModel _fallbackMosque() {
  return const MosqueModel(
    id: 'event-mosque-2',
    name: 'Community Gathering',
    addressLine: '12 Peace Road',
    city: 'Orlando',
    state: 'FL',
    country: 'US',
    imageUrl: '',
    rating: 4.1,
    distanceMiles: 2.0,
    sect: 'Sunni',
    womenPrayerArea: true,
    parking: true,
    wudu: true,
    facilities: ['parking', 'wudu'],
    isVerified: true,
    isBookmarked: false,
    duhrTime: '01:15 PM',
    asarTime: '04:45 PM',
    isOpenNow: true,
    classTags: ['Community Circle'],
    eventTags: ['Family Night'],
  );
}

void main() {
  testWidgets(
      'event detail uses real share, directions, and organizer site actions',
      (tester) async {
    final mosque = _websiteMosque();
    final details = DiscoveryEvent.fromMosqueProgram(
      mosque,
      const MosqueProgramItem(
        id: 'event-1',
        title: 'Community Lecture Night',
        schedule: '',
        posterLabel: '',
        location: '25 Unity Ave',
        description:
            'Join the community for an evening reminder and post-Maghrib gathering.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          args: EventDetailRouteArgs(
            event: mosque,
            discoveryEvent: details,
          ),
          outboundActionService: _FakeOutboundActionService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Visit Organizer Site'), findsOneWidget);
    expect(find.text('EVENT SPEAKERS'), findsNothing);
    expect(find.text('Free'), findsNothing);
    expect(find.text('Schedule not published'), findsOneWidget);
    expect(find.text('Community Lecture Night'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Share options opened for this event.'), findsOneWidget);

    expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
  });

  testWidgets(
      'event detail shows an honest unavailable state when no real event payload exists',
      (tester) async {
    final mosque = _fallbackMosque();

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.mosqueDetail: (_) =>
              const Scaffold(body: Text('Organizer page stub')),
        },
        home: EventDetailScreen(
          args: EventDetailRouteArgs(event: mosque),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Event details unavailable'), findsOneWidget);
    expect(
      find.textContaining(
        'does not have a published mosque event or class to show yet',
      ),
      findsOneWidget,
    );
    expect(find.text('Open Organizer Page'), findsOneWidget);
    expect(find.text('Schedule not published'), findsNothing);

    await tester.tap(find.text('Open Organizer Page'));
    await tester.pumpAndSettle();

    expect(find.text('Organizer page stub'), findsOneWidget);
  });
}
