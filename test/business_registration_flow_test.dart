import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/features/business_registration/business_registration_flow_controller.dart';
import 'package:believer/features/business_registration/business_registration_flow_screen.dart';
import 'package:believer/features/business_registration/business_registration_models.dart';
import 'package:believer/features/business_registration/business_registration_service.dart';
import 'package:believer/screens/business_registration_basic/business_registration_basic_models.dart';
import 'package:believer/screens/business_registration_contact/business_registration_contact_model.dart';

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 'user-1',
        fullName: 'Test Owner',
        email: 'owner@example.com',
        role: 'community',
      ),
    );
  }
}

class _FakeBusinessRegistrationService extends BusinessRegistrationService {
  _FakeBusinessRegistrationService({
    this.latestListing,
    this.savedListing,
    this.submittedListing,
  });

  BusinessRegistrationDraft? latestListing;
  BusinessRegistrationDraft? savedListing;
  BusinessRegistrationDraft? submittedListing;
  final List<BusinessRegistrationDraft> savedDrafts =
      <BusinessRegistrationDraft>[];
  final List<BusinessRegistrationDraft> submittedDrafts =
      <BusinessRegistrationDraft>[];

  @override
  Future<BusinessRegistrationDraft?> fetchLatestListingStatus({
    required String bearerToken,
  }) async {
    return latestListing;
  }

  @override
  Future<BusinessRegistrationDraft> saveDraft({
    required BusinessRegistrationDraft draft,
    required String bearerToken,
  }) async {
    savedDrafts.add(draft);
    return savedListing ?? draft;
  }

  @override
  Future<BusinessRegistrationDraft> submitForReview({
    required BusinessRegistrationDraft draft,
    required String bearerToken,
  }) async {
    submittedDrafts.add(draft);
    return submittedListing ?? draft;
  }
}

BusinessRegistrationDraft _buildListing({
  String? id,
  required BusinessRegistrationSubmissionStatus status,
  BusinessRegistrationBasicDraft basicDetails =
      const BusinessRegistrationBasicDraft(),
  BusinessRegistrationContactDraft contactDetails =
      const BusinessRegistrationContactDraft(),
  String? rejectionReason,
}) {
  return BusinessRegistrationDraft(
    id: id ?? 'listing-1',
    basicDetails: basicDetails,
    contactDetails: contactDetails,
    status: status,
    createdAt: DateTime.utc(2026, 4, 9, 9, 30),
    lastUpdatedAt: DateTime.utc(2026, 4, 9, 9, 32),
    submittedAt: status == BusinessRegistrationSubmissionStatus.underReview
        ? DateTime.utc(2026, 4, 9, 9, 32)
        : null,
    publishedAt: status == BusinessRegistrationSubmissionStatus.live
        ? DateTime.utc(2026, 4, 9, 10, 0)
        : null,
    reviewedAt: status == BusinessRegistrationSubmissionStatus.rejected
        ? DateTime.utc(2026, 4, 9, 11, 0)
        : null,
    rejectionReason: rejectionReason,
  );
}

void main() {
  test('flow controller loads latest listing and persists draft + submit',
      () async {
    final savedBasicDraft = BusinessRegistrationBasicDraft(
      businessName: 'Noor Catering',
      logo: BusinessRegistrationLogoAsset(
        fileName: 'noor.png',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        contentType: 'image/png',
      ),
      selectedType: const BusinessRegistrationSelectedType(
        groupId: 'food',
        groupLabel: 'Halal Food',
        itemId: 'catering',
        itemLabel: 'Catering Services',
      ),
      tagline: 'Trusted halal catering.',
      description: 'We cater weddings and community events.',
    );
    const submittedContactDraft = BusinessRegistrationContactDraft(
      businessEmail: 'owner@example.com',
      phone: '+91 9988776655',
      whatsapp: '+91 9988776655',
      openingTime: TimeOfDay(hour: 9, minute: 0),
      closingTime: TimeOfDay(hour: 18, minute: 30),
      address: '12 Crescent Road',
      zipCode: '560001',
      city: 'Bengaluru',
      onlineOnly: false,
    );

    final fakeService = _FakeBusinessRegistrationService(
      latestListing: null,
      savedListing: _buildListing(
        status: BusinessRegistrationSubmissionStatus.draft,
        basicDetails: savedBasicDraft,
      ),
      submittedListing: _buildListing(
        status: BusinessRegistrationSubmissionStatus.underReview,
        basicDetails: savedBasicDraft,
        contactDetails: submittedContactDraft,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        businessRegistrationServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    final initialState =
        await container.read(businessRegistrationFlowControllerProvider.future);
    expect(
        initialState.draft.status, BusinessRegistrationSubmissionStatus.draft);

    await container
        .read(businessRegistrationFlowControllerProvider.notifier)
        .saveBasicDraft(savedBasicDraft);

    expect(fakeService.savedDrafts, hasLength(1));
    expect(
      fakeService.savedDrafts.single.basicDetails.businessName,
      'Noor Catering',
    );
    expect(
      container
          .read(businessRegistrationFlowControllerProvider)
          .valueOrNull
          ?.draft
          .status,
      BusinessRegistrationSubmissionStatus.draft,
    );

    await container
        .read(businessRegistrationFlowControllerProvider.notifier)
        .submitForReview(submittedContactDraft);

    expect(fakeService.submittedDrafts, hasLength(1));
    expect(
      fakeService.submittedDrafts.single.basicDetails.businessName,
      'Noor Catering',
    );
    expect(
      fakeService.submittedDrafts.single.contactDetails.city,
      'Bengaluru',
    );
    expect(
      container
          .read(businessRegistrationFlowControllerProvider)
          .valueOrNull
          ?.draft
          .status,
      BusinessRegistrationSubmissionStatus.underReview,
    );
  });

  testWidgets('flow screen lands on live status when backend listing is live',
      (tester) async {
    final fakeService = _FakeBusinessRegistrationService(
      latestListing: _buildListing(
        status: BusinessRegistrationSubmissionStatus.live,
        basicDetails: const BusinessRegistrationBasicDraft(
          businessName: 'Live Listing',
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        businessRegistrationServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: BusinessRegistrationFlowScreen(
            step: BusinessRegistrationFlowStep.underReview,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Your business listing is live'), findsOneWidget);
    expect(find.text('Update Listing'), findsOneWidget);
    expect(find.text('Go to Home Page'), findsOneWidget);
    expect(
      find.text(
        'Customers can now discover your listing on BelieversLens. If you need to change published details, update the listing and resubmit it for moderation.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('flow screen refreshes stale moderation status on mount',
      (tester) async {
    final fakeService = _FakeBusinessRegistrationService(
      latestListing: _buildListing(
        status: BusinessRegistrationSubmissionStatus.underReview,
        basicDetails: const BusinessRegistrationBasicDraft(
          businessName: 'Status Refresh Listing',
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        businessRegistrationServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    await container.read(businessRegistrationFlowControllerProvider.future);
    fakeService.latestListing = _buildListing(
      status: BusinessRegistrationSubmissionStatus.live,
      basicDetails: const BusinessRegistrationBasicDraft(
        businessName: 'Status Refresh Listing',
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: BusinessRegistrationFlowScreen(
            step: BusinessRegistrationFlowStep.underReview,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Your business listing is live'), findsOneWidget);
    expect(find.text('Update Listing'), findsOneWidget);
  });

  testWidgets('flow screen shows rejected status and review feedback',
      (tester) async {
    final fakeService = _FakeBusinessRegistrationService(
      latestListing: _buildListing(
        status: BusinessRegistrationSubmissionStatus.rejected,
        basicDetails: const BusinessRegistrationBasicDraft(
          businessName: 'Needs Updates',
          tagline: 'Fresh baked goods',
        ),
        contactDetails: const BusinessRegistrationContactDraft(
          city: 'Bengaluru',
        ),
        rejectionReason:
            'Please add clearer operating hours before resubmitting.',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        businessRegistrationServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: BusinessRegistrationFlowScreen(
            step: BusinessRegistrationFlowStep.intro,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Your business listing needs changes'), findsOneWidget);
    expect(
      find.text('Please add clearer operating hours before resubmitting.'),
      findsOneWidget,
    );
    expect(find.text('Update Listing'), findsOneWidget);
  });
}
