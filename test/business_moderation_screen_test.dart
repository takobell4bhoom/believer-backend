import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/features/business_moderation/business_moderation_screen.dart';
import 'package:believer/features/business_moderation/business_moderation_service.dart';

class _SuperAdminAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'super-admin-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 'super-admin-1',
        fullName: 'Super Admin',
        email: 'super-admin@example.com',
        role: 'super_admin',
      ),
    );
  }
}

class _AdminAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'admin-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 'admin-1',
        fullName: 'Mosque Admin',
        email: 'admin@example.com',
        role: 'admin',
      ),
    );
  }
}

class _FakeBusinessModerationService extends BusinessModerationService {
  _FakeBusinessModerationService(this.items);

  List<BusinessModerationListing> items;
  final List<String> approvedIds = <String>[];
  final List<String> rejectedIds = <String>[];
  final List<String> rejectionReasons = <String>[];

  @override
  Future<List<BusinessModerationListing>> fetchPendingListings({
    required String bearerToken,
  }) async {
    return items;
  }

  @override
  Future<BusinessModerationListing> approveListing({
    required String listingId,
    required String bearerToken,
  }) async {
    approvedIds.add(listingId);
    return items.firstWhere((item) => item.id == listingId);
  }

  @override
  Future<BusinessModerationListing> rejectListing({
    required String listingId,
    required String rejectionReason,
    required String bearerToken,
  }) async {
    rejectedIds.add(listingId);
    rejectionReasons.add(rejectionReason);
    return items.firstWhere((item) => item.id == listingId);
  }
}

BusinessModerationListing _listing({
  required String id,
  required String businessName,
}) {
  return BusinessModerationListing(
    id: id,
    status: 'under_review',
    businessName: businessName,
    tagline: 'Trusted halal catering',
    description: 'Detailed listing description',
    city: 'Bengaluru',
    businessEmail: 'owner@example.com',
    phone: '+91 9988776655',
    submittedAt: DateTime.utc(2026, 4, 10, 8, 30),
    submitter: const BusinessModerationSubmitter(
      id: 'user-1',
      fullName: 'Ayesha Owner',
      email: 'owner@example.com',
    ),
  );
}

void main() {
  testWidgets('moderation screen is visible for super admin users',
      (tester) async {
    final service = _FakeBusinessModerationService(
      <BusinessModerationListing>[
        _listing(id: 'listing-1', businessName: 'Noor Catering'),
      ],
    );
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_SuperAdminAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BusinessModerationScreen(service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Business Moderation'), findsOneWidget);
    expect(find.text('Noor Catering'), findsWidgets);
    expect(find.text('Detailed listing description'), findsOneWidget);
  });

  testWidgets('approve flow removes the moderated listing from the queue',
      (tester) async {
    final service = _FakeBusinessModerationService(
      <BusinessModerationListing>[
        _listing(id: 'listing-1', businessName: 'Noor Catering'),
      ],
    );
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_SuperAdminAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BusinessModerationScreen(service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('business-moderation-approve')),
    );
    await tester.tap(find.byKey(const ValueKey('business-moderation-approve')));
    await tester.pumpAndSettle();

    expect(service.approvedIds, <String>['listing-1']);
    expect(
      find.byKey(const ValueKey('business-moderation-empty')),
      findsOneWidget,
    );
  });

  testWidgets('reject flow removes the moderated listing from the queue',
      (tester) async {
    final service = _FakeBusinessModerationService(
      <BusinessModerationListing>[
        _listing(id: 'listing-1', businessName: 'Noor Catering'),
      ],
    );
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_SuperAdminAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BusinessModerationScreen(service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('business-moderation-reject')),
    );
    await tester.tap(find.byKey(const ValueKey('business-moderation-reject')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('business-moderation-rejection-reason')),
      'Please add clearer operating hours.',
    );
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();

    expect(service.rejectedIds, <String>['listing-1']);
    expect(
      service.rejectionReasons,
      <String>['Please add clearer operating hours.'],
    );
    expect(
      find.byKey(const ValueKey('business-moderation-empty')),
      findsOneWidget,
    );
  });

  testWidgets('non-super-admin users cannot access the moderation screen',
      (tester) async {
    final service = _FakeBusinessModerationService(
      <BusinessModerationListing>[
        _listing(id: 'listing-1', businessName: 'Noor Catering'),
      ],
    );
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_AdminAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BusinessModerationScreen(service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text(
          'Only super admins can access the business listing review queue.'),
      findsOneWidget,
    );
    expect(find.text('Noor Catering'), findsNothing);
  });
}
