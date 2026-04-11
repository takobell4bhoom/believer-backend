import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/features/business_registration/business_registration_flow_controller.dart';
import 'package:believer/features/business_registration/business_registration_models.dart';
import 'package:believer/features/business_registration/business_registration_service.dart';
import 'package:believer/screens/business_registration_basic/business_registration_basic_models.dart';
import 'package:believer/screens/business_registration_contact/business_registration_contact_model.dart';
import 'package:believer/models/service.dart';
import 'package:believer/screens/services_search.dart';
import 'package:believer/services/services_search_service.dart';

class _FakeServicesSearchService extends ServicesSearchService {
  _FakeServicesSearchService({
    this.defaultResults,
    this.resultsByCategory = const <String, List<Service>>{},
  });

  final List<Service>? defaultResults;
  final Map<String, List<Service>> resultsByCategory;
  final List<({String category, List<String> filters, String sort})> requests =
      <({String category, List<String> filters, String sort})>[];

  @override
  Future<List<Service>> fetchServices({
    required String category,
    required List<String> filters,
    String sort = 'new',
  }) async {
    requests.add((
      category: category,
      filters: List<String>.from(filters),
      sort: sort,
    ));

    final items = <Service>[
      const Service(
        name: 'Barakah Caterers',
        location: 'Orlando, FL',
        priceRange: '\$\$',
        deliveryInfo: 'Large orders delivered same day',
        rating: 4.8,
      ),
      const Service(
        name: 'Safa Meals',
        location: 'Winter Park, FL',
        priceRange: '\$',
        deliveryInfo: 'Pickup and delivery available',
        rating: 4.4,
      ),
      const Service(
        name: 'Noor Catering',
        location: 'Tampa, FL',
        priceRange: '\$\$\$',
        deliveryInfo: 'Delivers in 30-40 mins',
        rating: 4.9,
      ),
      const Service(
        id: 'listing-1',
        category: 'Halal Food',
        name: 'Fresh Tandoor',
        location: 'Bengaluru',
        priceRange: '--',
        deliveryInfo: 'Contact for availability',
        rating: 0,
        tags: <String>['Halal Food & Restaurants', 'Catering Services'],
      ),
    ];

    final fallbackItems = defaultResults ??
        <Service>[
          items[3],
          items[0],
          items[2],
        ];
    final defaultItems = resultsByCategory[category] ?? fallbackItems;

    if (filters.contains('Top Rated')) {
      return defaultItems.where((service) => service.rating >= 4.7).toList();
    }

    if (filters.contains('Fast Delivery')) {
      return defaultItems
          .where(
            (service) =>
                service.deliveryInfo.contains('30-40') ||
                service.deliveryInfo.toLowerCase().contains('same day'),
          )
          .toList();
    }

    return defaultItems;
  }
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 'user-1',
        fullName: 'Service Owner',
        email: 'owner@example.com',
        role: 'community',
      ),
    );
  }
}

class _FakeBusinessRegistrationService extends BusinessRegistrationService {
  _FakeBusinessRegistrationService({
    this.latestListing,
  });

  BusinessRegistrationDraft? latestListing;

  @override
  Future<BusinessRegistrationDraft?> fetchLatestListingStatus({
    required String bearerToken,
  }) async {
    return latestListing;
  }
}

BusinessRegistrationDraft _buildListing({
  required BusinessRegistrationSubmissionStatus status,
  BusinessRegistrationSelectedType? selectedType,
  BusinessRegistrationPublicCategory? publicCategory,
  bool clearPublicCategory = false,
}) {
  const defaultSelectedType = BusinessRegistrationSelectedType(
    groupId: 'food',
    groupLabel: 'Halal Food & Restaurants',
    itemId: 'catering-services',
    itemLabel: 'Catering Services',
  );

  return BusinessRegistrationDraft(
    id: 'listing-1',
    basicDetails: BusinessRegistrationBasicDraft(
      businessName: 'Owner Listing',
      selectedType: selectedType ?? defaultSelectedType,
    ),
    publicCategory: clearPublicCategory
        ? null
        : (publicCategory ??
            const BusinessRegistrationPublicCategory(
              groupId: 'food',
              groupLabel: 'Halal Food & Restaurants',
              itemId: 'catering-services',
              itemLabel: 'Catering Services',
            )),
    contactDetails: const BusinessRegistrationContactDraft(
      city: 'Bengaluru',
    ),
    status: status,
  );
}

Future<void> _openServicesFilterPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('services-filter-toggle')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('services search renders figma-style results and filter states',
      (tester) async {
    final fakeService = _FakeServicesSearchService();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ServicesSearch(
            servicesSearchService: fakeService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(fakeService.requests.first.category, 'Halal Food & Restaurants');
    expect(fakeService.requests.first.filters, isEmpty);
    expect(fakeService.requests.first.sort, 'new');

    expect(find.text('Halal Food & Restaurants'), findsAtLeastNWidgets(1));
    expect(find.text('Location unavailable'), findsOneWidget);
    expect(find.text('Sorted by New'), findsOneWidget);
    expect(find.text('3 Results'), findsOneWidget);
    expect(find.text('Fresh Tandoor'), findsOneWidget);
    expect(find.text('Browse categories'), findsNothing);
    expect(find.text('Health & Wellness'), findsNothing);

    await _openServicesFilterPanel(tester);

    expect(find.text('Browse categories'), findsOneWidget);
    expect(find.text('Sort & filter'), findsOneWidget);
    expect(find.text('Health & Wellness'), findsOneWidget);

    await tester.tap(find.text('Top Rated'));
    await tester.pumpAndSettle();

    expect(fakeService.requests.last.filters, <String>['Top Rated']);
    expect(find.text('1 Filter Applied'), findsOneWidget);
    expect(find.text('2 Results'), findsOneWidget);
    expect(find.text('Fresh Tandoor'), findsNothing);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    expect(fakeService.requests.last.filters, isEmpty);
    expect(fakeService.requests.last.sort, 'new');
    expect(find.text('Sorted by New'), findsOneWidget);
    expect(find.text('3 Results'), findsOneWidget);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    expect(fakeService.requests.last.filters, isEmpty);
    expect(fakeService.requests.last.sort, 'new');
    expect(find.text('Sorted by New'), findsOneWidget);
    expect(find.text('3 Results'), findsOneWidget);
  });

  testWidgets('services search lets users browse a non-default live category',
      (tester) async {
    final fakeService = _FakeServicesSearchService(
      resultsByCategory: const <String, List<Service>>{
        'Halal Food & Restaurants': <Service>[
          Service(
            id: 'listing-1',
            category: 'Halal Food & Restaurants',
            name: 'Fresh Tandoor',
            location: 'Bengaluru',
            priceRange: '--',
            deliveryInfo: 'Contact for availability',
            rating: 0,
          ),
        ],
        'Health & Wellness': <Service>[
          Service(
            id: 'listing-2',
            category: 'Health & Wellness',
            name: 'Shifa Clinic',
            location: 'Hyderabad',
            priceRange: '--',
            deliveryInfo: 'Contact for availability',
            rating: 0,
            tags: <String>['Health & Wellness', 'Medical Clinics'],
          ),
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ServicesSearch(
            servicesSearchService: fakeService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _openServicesFilterPanel(tester);
    await tester.ensureVisible(find.text('Health & Wellness'));
    await tester.tap(find.text('Health & Wellness'));
    await tester.pumpAndSettle();

    expect(fakeService.requests.last.category, 'Health & Wellness');
    expect(find.text('Shifa Clinic'), findsOneWidget);
    expect(find.text('Fresh Tandoor'), findsNothing);
    expect(find.text('Health & Wellness'), findsAtLeastNWidgets(1));
  });

  testWidgets(
      'services filter toggle reveals and hides category and sort controls',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ServicesSearch(
            servicesSearchService: _FakeServicesSearchService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Browse categories'), findsNothing);
    expect(find.text('Top Rated'), findsNothing);

    await _openServicesFilterPanel(tester);

    expect(find.text('Browse categories'), findsOneWidget);
    expect(find.text('Top Rated'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('services-filter-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Browse categories'), findsNothing);
    expect(find.text('Top Rated'), findsNothing);
  });

  testWidgets('services search remains compact-layout safe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ServicesSearch(
            servicesSearchService: _FakeServicesSearchService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('services search shows honest empty state for public launch',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ServicesSearch(
            servicesSearchService: _FakeServicesSearchService(
              defaultResults: const <Service>[],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text(
          'No approved listings are live in Halal Food & Restaurants yet.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Try another category or check back later as more businesses complete review.',
      ),
      findsOneWidget,
    );
    expect(find.text('Run a business like this?'), findsOneWidget);
    expect(find.text('Sign in to register'), findsOneWidget);
  });

  testWidgets('services search keeps empty categories honest when browsing',
      (tester) async {
    final fakeService = _FakeServicesSearchService(
      resultsByCategory: const <String, List<Service>>{
        'Halal Food & Restaurants': <Service>[
          Service(
            id: 'listing-1',
            category: 'Halal Food & Restaurants',
            name: 'Fresh Tandoor',
            location: 'Bengaluru',
            priceRange: '--',
            deliveryInfo: 'Contact for availability',
            rating: 0,
          ),
        ],
        'Professional & Business Services': <Service>[],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ServicesSearch(
            servicesSearchService: fakeService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _openServicesFilterPanel(tester);
    await tester.ensureVisible(find.text('Professional & Business Services'));
    await tester.tap(find.text('Professional & Business Services'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No approved listings are live in Professional & Business Services yet.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Try another category or check back later as more businesses complete review.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('services search refreshes stale owner status on mount',
      (tester) async {
    final fakeSearchService = _FakeServicesSearchService();
    final fakeBusinessRegistrationService = _FakeBusinessRegistrationService(
      latestListing: _buildListing(
        status: BusinessRegistrationSubmissionStatus.underReview,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        businessRegistrationServiceProvider.overrideWithValue(
          fakeBusinessRegistrationService,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(businessRegistrationFlowControllerProvider.future);
    fakeBusinessRegistrationService.latestListing = _buildListing(
      status: BusinessRegistrationSubmissionStatus.live,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ServicesSearch(
            servicesSearchService: fakeSearchService,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Your listing is live'), findsOneWidget);
    expect(
      find.text(
        'It is currently showing in Halal Food & Restaurants. Open your listing status to confirm the published details are in good shape.',
      ),
      findsOneWidget,
    );
    expect(fakeSearchService.requests.first.filters, isEmpty);
    expect(fakeSearchService.requests.first.sort, 'new');
  });

  testWidgets(
      'services search keeps a live owner listing visible by default and uses an honest filtered empty state',
      (tester) async {
    final fakeSearchService = _FakeServicesSearchService(
      defaultResults: const <Service>[
        Service(
          id: 'listing-1',
          category: 'Halal Food & Restaurants',
          name: 'Fresh Tandoor',
          location: 'Bengaluru',
          priceRange: '--',
          deliveryInfo: 'Contact for availability',
          rating: 0,
          tags: <String>['Halal Food & Restaurants', 'Catering Services'],
        ),
      ],
    );
    final fakeBusinessRegistrationService = _FakeBusinessRegistrationService(
      latestListing: _buildListing(
        status: BusinessRegistrationSubmissionStatus.live,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        businessRegistrationServiceProvider.overrideWithValue(
          fakeBusinessRegistrationService,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ServicesSearch(
            servicesSearchService: fakeSearchService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Your listing is live'), findsOneWidget);
    expect(
      find.text(
        'It is currently showing in Halal Food & Restaurants. Open your listing status to confirm the published details are in good shape.',
      ),
      findsOneWidget,
    );
    expect(find.text('Fresh Tandoor'), findsOneWidget);
    expect(find.text('1 Results'), findsOneWidget);
    expect(find.text('Sorted by New'), findsOneWidget);

    await _openServicesFilterPanel(tester);
    await tester.tap(find.text('Top Rated'));
    await tester.pumpAndSettle();

    expect(fakeSearchService.requests.last.filters, <String>['Top Rated']);
    expect(
      find.text(
        'No live listings match Top Rated in Halal Food & Restaurants.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Clear the active filter to browse all approved live listings in this category.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No approved listings are live in Halal Food & Restaurants yet.',
      ),
      findsNothing,
    );

    await tester.tap(find.text('Top Rated'));
    await tester.pumpAndSettle();

    expect(fakeSearchService.requests.last.filters, isEmpty);
    expect(find.text('Fresh Tandoor'), findsOneWidget);
  });

  testWidgets(
      'services search uses the approved public category when draft taxonomy diverges',
      (tester) async {
    final fakeSearchService = _FakeServicesSearchService(
      defaultResults: const <Service>[],
    );
    final fakeBusinessRegistrationService = _FakeBusinessRegistrationService(
      latestListing: _buildListing(
        status: BusinessRegistrationSubmissionStatus.live,
        selectedType: const BusinessRegistrationSelectedType(
          groupId: 'food',
          groupLabel: 'Halal Food & Restaurants',
          itemId: 'catering-services',
          itemLabel: 'Catering Services',
        ),
        publicCategory: const BusinessRegistrationPublicCategory(
          groupId: 'health-wellness',
          groupLabel: 'Health & Wellness',
          itemId: 'medical-clinics',
          itemLabel: 'Medical Clinics',
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        businessRegistrationServiceProvider.overrideWithValue(
          fakeBusinessRegistrationService,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ServicesSearch(
            servicesSearchService: fakeSearchService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Your listing is live in Health & Wellness'),
      findsOneWidget,
    );
    expect(
      find.text(
        'You are currently browsing Halal Food & Restaurants. Switch to Health & Wellness to find your public listing on this screen.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No approved listings are live in Halal Food & Restaurants yet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'services search avoids naming a live category when no public category is available',
      (tester) async {
    final fakeSearchService = _FakeServicesSearchService(
      defaultResults: const <Service>[],
    );
    final fakeBusinessRegistrationService = _FakeBusinessRegistrationService(
      latestListing: _buildListing(
        status: BusinessRegistrationSubmissionStatus.live,
        selectedType: const BusinessRegistrationSelectedType(
          groupId: 'health-wellness',
          groupLabel: 'Health & Wellness',
          itemId: 'medical-clinics',
          itemLabel: 'Medical Clinics',
        ),
        clearPublicCategory: true,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
        businessRegistrationServiceProvider.overrideWithValue(
          fakeBusinessRegistrationService,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ServicesSearch(
            servicesSearchService: fakeSearchService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Your listing is live'), findsOneWidget);
    expect(find.textContaining('Your listing is live in'), findsNothing);
    expect(
      find.text(
        'Open your listing status to confirm the published category and details are in good shape.',
      ),
      findsOneWidget,
    );
  });
}
