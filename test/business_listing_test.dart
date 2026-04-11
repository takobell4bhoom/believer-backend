import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/data/mock_provider.dart';
import 'package:believer/models/service.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/business_listing.dart';
import 'package:believer/services/outbound_action_service.dart';

class _FakeOutboundActionService extends OutboundActionService {
  @override
  Future<OutboundActionResult> launchExternalLink(
    String? rawValue, {
    String? type,
    String successMessage = 'Opening link...',
    String fallbackMessage =
        'Could not open the link. Details copied to clipboard.',
    String unavailableMessage = 'Link not available yet.',
  }) async {
    return OutboundActionResult(message: successMessage);
  }
}

class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return null;
  }
}

final _sampleService = Service(
  id: 'service-1',
  category: 'Halal Food & Restaurants',
  name: 'Barakah Caterers',
  location: 'Orlando, FL',
  priceRange: '\$\$',
  deliveryInfo: 'Large orders delivered same day',
  rating: 4.8,
  addressLine1: '1218 Crescent Blvd',
  addressLine2: 'Orlando, FL',
  phoneNumber: '+1 (407) 555-0148',
  whatsappNumber: '+1 (407) 555-0148',
  instagramHandle: 'instagram.com/barakahcaterers',
  websiteUrl: 'www.barakahcaterers.com',
  description:
      'At Barakah Caterers, we bring halal-certified menus to weddings, family gatherings, and community events.',
  hoursLabel: '10:00 PM to 4:00 PM',
  savedCount: 14,
  reviewCount: 6,
  tags: const <String>['Halal Food & Restaurants', 'Catering Services'],
  servicesOffered: const <String>[
    'Event catering for weddings, conferences, and iftar gatherings.',
  ],
  specialties: const <String>[
    'Traditional Middle Eastern and South Asian cuisine.',
  ],
  logoBytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l8N6GQAAAABJRU5ErkJggg==',
  ),
  logoTileBackgroundColor: 0xFFE9C49E,
);

void main() {
  testWidgets('business listing renders redesigned business page and actions',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.reviews: (_) =>
                const Scaffold(body: Text('business reviews route')),
            AppRoutes.leaveReview: (_) =>
                const Scaffold(body: Text('business leave review route')),
          },
          home: BusinessListing(
            args: BusinessListingRouteArgs(service: _sampleService),
            outboundActionService: _FakeOutboundActionService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Business Details'), findsOneWidget);
    expect(find.text('Barakah Caterers'), findsOneWidget);
    expect(find.text('Hours'), findsOneWidget);
    expect(find.text('10:00 PM to 4:00 PM'), findsOneWidget);
    expect(find.text('14 users have saved this business'), findsOneWidget);
    expect(find.text('Halal Food & Restaurants'), findsOneWidget);
    expect(find.text('Live listing'), findsOneWidget);
    expect(find.text('CONNECT'), findsOneWidget);
    expect(find.text('REVIEWS'), findsOneWidget);
    expect(
        find.text(
            'This listing currently includes the published rating summary only.'),
        findsOneWidget);
    expect(find.text('Read all reviews'), findsOneWidget);
    expect(find.text('Leave review'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.ensureVisible(find.text('instagram.com/barakahcaterers'));
    await tester.tap(find.text('instagram.com/barakahcaterers'));
    await tester.pumpAndSettle();

    expect(find.text('Opening Instagram...'), findsOneWidget);
  });

  testWidgets('business listing stays publicly browsable for signed-out users',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_SignedOutAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BusinessListing(
            args: BusinessListingRouteArgs(service: _sampleService),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Barakah Caterers'), findsOneWidget);
    expect(find.text('Redirecting...'), findsNothing);
    expect(find.text('Login to leave review'), findsOneWidget);
  });

  testWidgets('business listing shows honest empty state without a service',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: BusinessListing(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Business Details'), findsOneWidget);
    expect(find.text('Business details unavailable'), findsOneWidget);
    expect(
      find.text(
        'Open a business from Services to view the latest listing details.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('business listing stays scroll-safe on compact mobile layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(MockAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BusinessListing(
            args: BusinessListingRouteArgs(service: _sampleService),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(
        'This listing currently includes the published rating summary only.'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
