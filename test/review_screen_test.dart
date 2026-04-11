import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/models/review.dart';
import 'package:believer/screens/review_screen.dart';
import 'package:believer/services/mosque_service.dart';

class _FakeMosqueService extends MosqueService {
  @override
  Future<ReviewFeed> getMosqueReviews(
    String mosqueId, {
    String? bearerToken,
  }) async {
    return const ReviewFeed(
      items: [
        Review(
          rating: 4.5,
          userName: 'Amina',
          comment: 'Well organized and welcoming.',
          timeAgo: '3 days ago',
        ),
      ],
      averageRating: 4.5,
      totalReviews: 1,
    );
  }
}

void main() {
  testWidgets('review screen hydrates reviews from backend route args',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewScreen(
          reviews: const <Review>[],
          mosqueId: '11111111-1111-1111-1111-111111111111',
          mosqueName: 'Community Mosque',
          mosqueService: _FakeMosqueService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Community Mosque'), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Well organized and welcoming.'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);
  });
}
