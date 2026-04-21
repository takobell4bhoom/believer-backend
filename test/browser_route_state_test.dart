import 'package:believer/navigation/app_routes.dart';
import 'package:believer/navigation/app_startup.dart';
import 'package:believer/navigation/browser_route_state.dart';
import 'package:believer/services/onboarding_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit route parsing recognizes direct reset-password links', () {
    final uri = Uri.parse(
      'https://app.example.com/reset-password?token=token-123',
    );

    expect(
      resolveExplicitBrowserRoute(currentUri: uri),
      AppRoutes.resetPassword,
    );
    expect(
      readBrowserTokenParameter('token', currentUri: uri),
      'token-123',
    );
  });

  test('explicit route parsing recognizes hash-route reset-password links', () {
    final uri = Uri.parse(
      'https://app.example.com/#/reset-password?token=token-123',
    );

    expect(
      resolveExplicitBrowserRoute(currentUri: uri),
      AppRoutes.resetPassword,
    );
    expect(
      readBrowserTokenParameter('token', currentUri: uri),
      'token-123',
    );
  });

  test('reset-token links at the app root still resolve to reset-password', () {
    final uri = Uri.parse('https://app.example.com/?token=token-123');

    expect(
      AppStartupPolicy.resolveExplicitEntryRoute(currentUri: uri),
      AppRoutes.resetPassword,
    );
    expect(
      readBrowserTokenParameter('token', currentUri: uri),
      'token-123',
    );
  });

  test('fragment query tokens resolve to reset-password even without a route',
      () {
    final uri = Uri.parse('https://app.example.com/#/?token=token-123');

    expect(
      AppStartupPolicy.resolveExplicitEntryRoute(currentUri: uri),
      AppRoutes.resetPassword,
    );
    expect(
      readBrowserTokenParameter('token', currentUri: uri),
      'token-123',
    );
  });

  test('reset-password explicit entry outranks normal startup home routing',
      () {
    final explicitRoute = AppStartupPolicy.resolveExplicitEntryRoute(
      currentUri: Uri.parse('https://app.example.com/?token=token-123'),
    );
    final normalRoute = AppStartupPolicy.resolveRoute(
      isAuthenticated: true,
      onboardingState: const OnboardingPreferencesState(
        onboardingCompleted: true,
        continueAsGuest: true,
        showOnboardingOnSignedOutEntry: false,
      ),
    );

    expect(explicitRoute, AppRoutes.resetPassword);
    expect(normalRoute, AppRoutes.home);
  });
}
