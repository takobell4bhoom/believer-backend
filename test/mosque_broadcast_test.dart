import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/models/broadcast_message.dart';
import 'package:believer/screens/mosque_broadcast.dart';
import 'package:believer/services/mosque_service.dart';

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: AuthUser(
        id: 'user-1',
        fullName: 'Test User',
        email: 'test@example.com',
        role: 'community',
      ),
    );
  }
}

class _FakeMosqueService extends MosqueService {
  @override
  Future<List<BroadcastMessage>> getMosqueBroadcastMessages(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const [
      BroadcastMessage(
        title: 'Volunteer Schedule Updated',
        description: 'The updated volunteer roster is posted for this Friday.',
        date: 'Today',
      ),
      BroadcastMessage(
        title: 'Lost & Found Table Set Up in Courtyard',
        description:
            'Please take a moment to check whether any recently misplaced items belong to you.',
        date: 'Jan 2',
      ),
    ];
  }
}

void main() {
  testWidgets('mosque broadcast screen renders persisted messages',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosqueBroadcast(
            args: const MosqueBroadcastRouteArgs(
              mosqueId: '11111111-1111-1111-1111-111111111111',
              mosqueName: 'Community Mosque',
            ),
            mosqueService: _FakeMosqueService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Community Mosque'), findsOneWidget);
    expect(find.text('BROADCAST MESSAGES'), findsOneWidget);
    expect(find.text('Volunteer Schedule Updated'), findsOneWidget);
    expect(find.text('Lost & Found Table Set Up in Courtyard'), findsOneWidget);
    expect(
      find.text('The updated volunteer roster is posted for this Friday.'),
      findsOneWidget,
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Jan 2'), findsOneWidget);
  });

  testWidgets('mosque broadcast screen stays scroll-safe on compact mobile',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_LoggedInAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MosqueBroadcast(
            args: const MosqueBroadcastRouteArgs(
              mosqueId: '11111111-1111-1111-1111-111111111111',
              mosqueName: 'Islamic Centre of South Florida',
            ),
            mosqueService: _FakeMosqueService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(SingleChildScrollView).last, const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(find.text('Islamic Centre of South Florida'), findsOneWidget);
    expect(find.text('Lost & Found Table Set Up in Courtyard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
