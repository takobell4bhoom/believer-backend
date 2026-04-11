import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/review_confirmation.dart';

void main() {
  testWidgets('review confirmation routes back home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.home: (_) => const Scaffold(body: Text('home stub')),
        },
        home: const ReviewConfirmation(),
      ),
    );

    expect(find.text('Your review has been posted!'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-confirmation-home')));
    await tester.pumpAndSettle();

    expect(find.text('home stub'), findsOneWidget);
  });
}
