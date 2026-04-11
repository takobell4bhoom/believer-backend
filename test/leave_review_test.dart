import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/leave_review.dart';
import 'package:believer/services/api_client.dart';
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

class _RecordingMosqueService extends MosqueService {
  int submitCalls = 0;
  String? lastMosqueId;
  int? lastRating;
  String? lastComments;
  String? lastBearerToken;
  Object? error;

  @override
  Future<void> submitReview({
    required String mosqueId,
    required int rating,
    required String comments,
    String? bearerToken,
  }) async {
    submitCalls += 1;
    lastMosqueId = mosqueId;
    lastRating = rating;
    lastComments = comments;
    lastBearerToken = bearerToken;

    if (error != null) {
      throw error!;
    }
  }
}

void main() {
  testWidgets('leave review submits and routes to confirmation', (
    tester,
  ) async {
    final service = _RecordingMosqueService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_LoggedInAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.reviewConfirmation: (_) =>
                const Scaffold(body: Text('review confirmation stub')),
          },
          home: LeaveReview(
            mosqueId: 'mosque-123',
            mosqueName: 'Islamic Center of South Florida',
            mosqueService: service,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('leave-review-star-4')));
    await tester.enterText(
      find.byKey(const ValueKey('leave-review-comments')),
      '  Helpful staff and a welcoming atmosphere.  ',
    );
    await tester.tap(find.byKey(const ValueKey('leave-review-submit')));
    await tester.pumpAndSettle();

    expect(service.submitCalls, 1);
    expect(service.lastMosqueId, 'mosque-123');
    expect(service.lastRating, 4);
    expect(
      service.lastComments,
      'Helpful staff and a welcoming atmosphere.',
    );
    expect(service.lastBearerToken, 'token');
    expect(find.text('review confirmation stub'), findsOneWidget);
  });

  testWidgets('leave review shows rating validation before submit', (
    tester,
  ) async {
    final service = _RecordingMosqueService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_LoggedInAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: LeaveReview(mosqueService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('leave-review-submit')));
    await tester.pumpAndSettle();

    expect(service.submitCalls, 0);
    expect(
      find.text('Please select a star rating before submitting.'),
      findsOneWidget,
    );
  });

  testWidgets('leave review shows service errors and stays on page', (
    tester,
  ) async {
    final service = _RecordingMosqueService()
      ..error = ApiException('Server is unavailable right now.');
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_LoggedInAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: LeaveReview(mosqueService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('leave-review-star-5')));
    await tester.tap(find.byKey(const ValueKey('leave-review-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Server is unavailable right now.'), findsOneWidget);
    expect(find.byType(LeaveReview), findsOneWidget);
  });

  testWidgets('leave review stays overflow-safe in compact viewport', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_LoggedInAuthNotifier.new)],
    );
    addTearDown(container.dispose);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: LeaveReview(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.byKey(const ValueKey('leave-review-submit')));
    expect(find.textContaining('Been to this mosque'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
