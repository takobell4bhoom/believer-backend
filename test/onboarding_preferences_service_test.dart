import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/navigation/app_routes.dart';
import 'package:believer/navigation/app_startup.dart';
import 'package:believer/services/onboarding_preferences_service.dart';

void main() {
  test(
      'logout return preference sends the next signed-out startup to onboarding',
      () async {
    SharedPreferences.setMockInitialValues({
      'onboarding.completed': true,
      'onboarding.continue_as_guest': true,
    });

    final service = OnboardingPreferencesService();

    await service.markLogoutReturnPreferred();

    final state = await service.loadState();

    expect(state.onboardingCompleted, isTrue);
    expect(state.continueAsGuest, isFalse);
    expect(state.showOnboardingOnSignedOutEntry, isTrue);
    expect(
      AppStartupPolicy.resolveRoute(
        isAuthenticated: false,
        onboardingState: state,
      ),
      AppRoutes.onboarding,
    );
  });
}
