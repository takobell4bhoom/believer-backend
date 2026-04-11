import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/models/review.dart';
import 'package:believer/screens/business_review_screen.dart';
import 'package:believer/services/business_review_service.dart';

class _FakeBusinessReviewService extends BusinessReviewService {
  @override
  Future<ReviewFeed> getBusinessReviews(
    String businessListingId, {
    String? bearerToken,
  }) async {
    return const ReviewFeed(
      items: [
        Review(
          rating: 4.5,
          userName: 'Amina',
          comment: 'Clear communication and timely delivery.',
          timeAgo: '3 days ago',
        ),
      ],
      averageRating: 4.5,
      totalReviews: 1,
    );
  }
}

void main() {
  testWidgets('business review screen hydrates reviews from backend route args',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessReviewScreen(
          reviews: const <Review>[],
          businessListingId: '11111111-1111-1111-1111-111111111111',
          businessName: 'Community Business',
          reviewService: _FakeBusinessReviewService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Community Business'), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(
        find.text('Clear communication and timely delivery.'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);
  });
}
