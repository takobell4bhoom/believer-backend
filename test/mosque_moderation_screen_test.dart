import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/features/mosque_moderation/mosque_moderation_screen.dart';
import 'package:believer/features/mosque_moderation/mosque_moderation_service.dart';

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

class _FakeMosqueModerationService extends MosqueModerationService {
  _FakeMosqueModerationService(this.items);

  List<MosqueModerationItem> items;
  final List<String> approvedIds = <String>[];
  final List<String> rejectedIds = <String>[];
  final List<String> rejectionReasons = <String>[];

  @override
  Future<List<MosqueModerationItem>> fetchPendingMosques({
    required String bearerToken,
  }) async {
    return items;
  }

  @override
  Future<MosqueModerationItem> approveMosque({
    required String mosqueId,
    required String bearerToken,
  }) async {
    approvedIds.add(mosqueId);
    return items.firstWhere((item) => item.id == mosqueId);
  }

  @override
  Future<MosqueModerationItem> rejectMosque({
    required String mosqueId,
    required String rejectionReason,
    required String bearerToken,
  }) async {
    rejectedIds.add(mosqueId);
    rejectionReasons.add(rejectionReason);
    return items.firstWhere((item) => item.id == mosqueId);
  }
}

MosqueModerationItem _mosque({
  required String id,
  required String name,
}) {
  return MosqueModerationItem(
    id: id,
    status: 'pending',
    name: name,
    addressLine: '15 Unity Street',
    city: 'Bengaluru',
    state: 'Karnataka',
    country: 'India',
    sect: 'Sunni',
    contactName: 'Fatima Noor',
    contactEmail: 'fatima@example.com',
    contactPhone: '+91 9999999999',
    submittedAt: DateTime.utc(2026, 4, 10, 8, 30),
    submitter: const MosqueModerationSubmitter(
      id: 'admin-1',
      fullName: 'Ayesha Admin',
      email: 'admin@example.com',
    ),
  );
}

void main() {
  testWidgets('mosque moderation screen is visible for super admin users',
      (tester) async {
    final service = _FakeMosqueModerationService(
      <MosqueModerationItem>[
        _mosque(id: 'mosque-1', name: 'Pending Mosque'),
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
          home: MosqueModerationScreen(service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mosque Moderation'), findsOneWidget);
    expect(find.text('Pending Mosque'), findsWidgets);
    expect(find.text('Status: Pending approval'), findsOneWidget);
  });

  testWidgets('approve flow removes the mosque from the moderation queue',
      (tester) async {
    final service = _FakeMosqueModerationService(
      <MosqueModerationItem>[
        _mosque(id: 'mosque-1', name: 'Pending Mosque'),
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
          home: MosqueModerationScreen(service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('mosque-moderation-approve')),
    );
    await tester.tap(find.byKey(const ValueKey('mosque-moderation-approve')));
    await tester.pumpAndSettle();

    expect(service.approvedIds, <String>['mosque-1']);
    expect(
      find.byKey(const ValueKey('mosque-moderation-empty')),
      findsOneWidget,
    );
  });

  testWidgets('reject flow removes the mosque from the moderation queue',
      (tester) async {
    final service = _FakeMosqueModerationService(
      <MosqueModerationItem>[
        _mosque(id: 'mosque-1', name: 'Pending Mosque'),
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
          home: MosqueModerationScreen(service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('mosque-moderation-reject')),
    );
    await tester.tap(find.byKey(const ValueKey('mosque-moderation-reject')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mosque-moderation-rejection-reason')),
      'Please add a clearer contact phone number.',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Reject'),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.rejectedIds, <String>['mosque-1']);
    expect(
      service.rejectionReasons,
      <String>['Please add a clearer contact phone number.'],
    );
    expect(
      find.byKey(const ValueKey('mosque-moderation-empty')),
      findsOneWidget,
    );
  });

  testWidgets(
      'non-super-admin users cannot access the mosque moderation screen',
      (tester) async {
    final service = _FakeMosqueModerationService(
      <MosqueModerationItem>[
        _mosque(id: 'mosque-1', name: 'Pending Mosque'),
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
          home: MosqueModerationScreen(service: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Only super admins can access the mosque approval queue.'),
      findsOneWidget,
    );
    expect(find.text('Pending Mosque'), findsNothing);
  });
}
