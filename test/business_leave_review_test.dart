import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/business_leave_review.dart';
import 'package:believer/services/api_client.dart';
import 'package:believer/services/business_review_service.dart';

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

class _RecordingBusinessReviewService extends BusinessReviewService {
  int submitCalls = 0;
  String? lastBusinessListingId;
  int? lastRating;
  String? lastComments;
  String? lastBearerToken;
  Object? error;

  @override
  Future<void> submitReview({
    required String businessListingId,
    required int rating,
    required String comments,
    String? bearerToken,
  }) async {
    submitCalls += 1;
    lastBusinessListingId = businessListingId;
    lastRating = rating;
    lastComments = comments;
    lastBearerToken = bearerToken;

    if (error != null) {
      throw error!;
    }
  }
}

void main() {
  testWidgets('business leave review submits and routes to confirmation', (
    tester,
  ) async {
    final service = _RecordingBusinessReviewService();
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
          home: BusinessLeaveReview(
            businessListingId: 'business-123',
            businessName: 'Business Listing',
            reviewService: service,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('business-leave-review-star-4')));
    await tester.enterText(
      find.byKey(const ValueKey('business-leave-review-comments')),
      '  Helpful owner and smooth process.  ',
    );
    await tester
        .tap(find.byKey(const ValueKey('business-leave-review-submit')));
    await tester.pumpAndSettle();

    expect(service.submitCalls, 1);
    expect(service.lastBusinessListingId, 'business-123');
    expect(service.lastRating, 4);
    expect(service.lastComments, 'Helpful owner and smooth process.');
    expect(service.lastBearerToken, 'token');
    expect(find.text('review confirmation stub'), findsOneWidget);
  });

  testWidgets('business leave review shows service errors and stays on page', (
    tester,
  ) async {
    final service = _RecordingBusinessReviewService()
      ..error = ApiException('Server is unavailable right now.');
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_LoggedInAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BusinessLeaveReview(reviewService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('business-leave-review-star-5')));
    await tester
        .tap(find.byKey(const ValueKey('business-leave-review-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Server is unavailable right now.'), findsOneWidget);
    expect(find.byType(BusinessLeaveReview), findsOneWidget);
  });
}
