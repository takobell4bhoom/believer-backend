import 'package:believer/navigation/app_routes.dart';
import 'package:believer/widgets/common/app_top_nav_bar.dart';
import 'package:believer/widgets/common/main_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app top nav renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: AppTopNavBar(
              title: 'Services',
              subtitle: 'Halal Food',
              showLeading: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Halal Food'), findsOneWidget);
  });

  testWidgets('main bottom nav opens destination routes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.home: (_) => const Scaffold(body: Text('Home stub')),
          AppRoutes.mosqueSearch: (_) =>
              const Scaffold(body: Text('Discover stub')),
          AppRoutes.notifications: (_) =>
              const Scaffold(body: Text('Notifications stub')),
          AppRoutes.services: (_) =>
              const Scaffold(body: Text('Services stub')),
        },
        home: const Scaffold(
          body: SizedBox.shrink(),
          bottomNavigationBar:
              MainBottomNavBar(activeTab: MainAppTab.notifications),
        ),
      ),
    );

    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home stub'), findsOneWidget);
  });
}
