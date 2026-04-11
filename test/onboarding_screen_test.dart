import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/location_setup_screen.dart';
import 'package:believer/screens/onboarding_screen.dart';

void main() {
  testWidgets('onboarding route shows splash then onboarding pages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(
          splashDuration: Duration(milliseconds: 10),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('splash-frame')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('onboarding-page-0')), findsOneWidget);
    expect(find.bySemanticsLabel('Next'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-page-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-page-2')), findsOneWidget);

    expect(find.bySemanticsLabel('Log In or Sign Up'), findsOneWidget);
    expect(find.bySemanticsLabel('Explore as Guest'), findsOneWidget);
  });

  testWidgets('primary onboarding action opens login directly from onboarding',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.login: (_) => const Scaffold(body: Text('Login stub')),
        },
        home: const OnboardingScreen(
          splashDuration: Duration(milliseconds: 10),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-next-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-login-signup')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding.completed'), isTrue);
    expect(prefs.getBool('onboarding.continue_as_guest'), isFalse);
    expect(find.text('Login stub'), findsOneWidget);
  });

  testWidgets('secondary onboarding action opens setup flow before guest home',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.locationSetup) {
            final args = settings.arguments! as LocationSetupFlowArgs;
            return MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Text('Setup stub -> ${args.nextRoute}'),
              ),
            );
          }
          return null;
        },
        home: const OnboardingScreen(
          splashDuration: Duration(milliseconds: 10),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-next-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-explore-guest')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding.completed'), isTrue);
    expect(prefs.getBool('onboarding.continue_as_guest'), isTrue);
    expect(find.text('Setup stub -> ${AppRoutes.home}'), findsOneWidget);
  });
}
