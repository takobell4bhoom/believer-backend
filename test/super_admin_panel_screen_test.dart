import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/features/business_moderation/business_moderation_service.dart';
import 'package:believer/features/mosque_moderation/mosque_moderation_service.dart';
import 'package:believer/features/super_admin/super_admin_models.dart';
import 'package:believer/features/super_admin/super_admin_panel_screen.dart';
import 'package:believer/features/super_admin/super_admin_service.dart';

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

class _CommunityAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'community-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 'community-1',
        fullName: 'Community User',
        email: 'community@example.com',
        role: 'community',
      ),
    );
  }
}

class _FakeSuperAdminService extends SuperAdminService {
  _FakeSuperAdminService({
    this.mosques = const <MosqueModerationItem>[],
    this.businesses = const <BusinessModerationListing>[],
    this.customers = const <SuperAdminCustomer>[],
  });

  final List<MosqueModerationItem> mosques;
  final List<BusinessModerationListing> businesses;
  final List<SuperAdminCustomer> customers;

  @override
  Future<List<MosqueModerationItem>> fetchPendingMosques({
    required String bearerToken,
  }) async {
    return mosques;
  }

  @override
  Future<List<BusinessModerationListing>> fetchPendingBusinesses({
    required String bearerToken,
  }) async {
    return businesses;
  }

  @override
  Future<SuperAdminCustomerPage> fetchCustomers({
    required String bearerToken,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final query = search?.trim().toLowerCase() ?? '';
    final filtered = query.isEmpty
        ? customers
        : customers
            .where(
              (customer) =>
                  customer.fullName.toLowerCase().contains(query) ||
                  customer.email.toLowerCase().contains(query),
            )
            .toList(growable: false);

    return SuperAdminCustomerPage(
      items: filtered,
      page: page,
      limit: limit,
      total: filtered.length,
      totalPages: filtered.isEmpty ? 0 : 1,
    );
  }
}

MosqueModerationItem _mosqueItem() {
  return MosqueModerationItem(
    id: 'mosque-1',
    status: 'pending',
    name: 'Unity Mosque',
    addressLine: '15 Unity Street',
    city: 'Bengaluru',
    state: 'Karnataka',
    country: 'India',
    sect: 'Community',
    contactName: 'Fatima Noor',
    contactEmail: 'fatima@example.com',
    contactPhone: '+91 9999999999',
    submitter: MosqueModerationSubmitter(
      id: 'admin-1',
      fullName: 'Ayesha Admin',
      email: 'admin@example.com',
    ),
    submittedAt: DateTime.utc(2026, 4, 10, 8, 30),
  );
}

BusinessModerationListing _businessItem() {
  return BusinessModerationListing(
    id: 'business-1',
    status: 'under_review',
    businessName: 'Noor Catering',
    tagline: 'Trusted halal catering',
    description: 'Detailed listing description',
    city: 'Bengaluru',
    businessEmail: 'owner@example.com',
    phone: '+91 9988776655',
    submittedAt: DateTime.utc(2026, 4, 11, 8, 30),
    submitter: BusinessModerationSubmitter(
      id: 'user-1',
      fullName: 'Ayesha Owner',
      email: 'owner@example.com',
    ),
  );
}

List<SuperAdminCustomer> _customerItems() {
  return <SuperAdminCustomer>[
    SuperAdminCustomer(
      id: 'customer-1',
      fullName: 'Amina Khan',
      email: 'amina@example.com',
      role: 'community',
      isActive: true,
      createdAt: DateTime.utc(2026, 4, 1),
    ),
    SuperAdminCustomer(
      id: 'customer-2',
      fullName: 'Bilal Ahmed',
      email: 'bilal@example.com',
      role: 'community',
      isActive: false,
      createdAt: DateTime.utc(2026, 3, 28),
    ),
  ];
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required AuthNotifier Function() authFactory,
  required SuperAdminService service,
  Map<String, WidgetBuilder> routes = const <String, WidgetBuilder>{},
}) async {
  final container = ProviderContainer(
    overrides: [authProvider.overrideWith(authFactory)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        routes: routes,
        home: SuperAdminPanelScreen(service: service),
      ),
    ),
  );
}

void main() {
  testWidgets('non-super-admin users cannot access the admin panel',
      (tester) async {
    await _pumpScreen(
      tester,
      authFactory: _CommunityAuthNotifier.new,
      service: _FakeSuperAdminService(),
    );

    await tester.pumpAndSettle();

    expect(
      find.text(
        'Only super admins can open this panel. Your current account does not have access.',
      ),
      findsOneWidget,
    );
    expect(find.text('Customers'), findsNothing);
  });

  testWidgets('summary cards render correctly and moderation shortcuts work',
      (tester) async {
    await _pumpScreen(
      tester,
      authFactory: _SuperAdminAuthNotifier.new,
      service: _FakeSuperAdminService(
        mosques: <MosqueModerationItem>[_mosqueItem()],
        businesses: <BusinessModerationListing>[_businessItem()],
        customers: _customerItems(),
      ),
      routes: {
        AppRoutes.mosqueModeration: (_) =>
            const Scaffold(body: Text('Mosque moderation stub')),
        AppRoutes.businessModeration: (_) =>
            const Scaffold(body: Text('Business moderation stub')),
      },
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('super-admin-summary-mosques')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('super-admin-summary-businesses')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('super-admin-summary-customers')),
      findsOneWidget,
    );
    expect(find.text('Pending mosques'), findsOneWidget);
    expect(find.text('Pending business listings'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();
    expect(find.text('Mosque moderation stub'), findsOneWidget);

    Navigator.of(tester.element(find.text('Mosque moderation stub'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Queue').first);
    await tester.pumpAndSettle();
    expect(find.text('Business moderation stub'), findsOneWidget);
  });

  testWidgets('admin panel stays usable on narrow mobile widths',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 900));

    await _pumpScreen(
      tester,
      authFactory: _SuperAdminAuthNotifier.new,
      service: _FakeSuperAdminService(
        mosques: <MosqueModerationItem>[_mosqueItem()],
        businesses: <BusinessModerationListing>[_businessItem()],
        customers: _customerItems(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Admin Panel'), findsOneWidget);
    expect(find.text('Pending mosques'), findsOneWidget);
    expect(find.text('Pending business listings'), findsOneWidget);
    expect(find.text('Customer Management'), findsOneWidget);
    expect(find.text('Unity Mosque'), findsWidgets);
    expect(find.text('Noor Catering'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer actions render safely without mobile overflow',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 800));

    await _pumpScreen(
      tester,
      authFactory: _SuperAdminAuthNotifier.new,
      service: _FakeSuperAdminService(
        customers: _customerItems(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Amina Khan'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('super-admin-panel-deactivate-customer-1')),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('super-admin-panel-password-reset-customer-1')),
      findsOneWidget,
    );

    expect(find.text('Bilal Ahmed'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('super-admin-panel-reactivate-customer-2')),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('super-admin-panel-password-reset-customer-2')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
