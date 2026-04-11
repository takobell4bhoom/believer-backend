import 'package:flutter/material.dart';

import '../services/onboarding_preferences_service.dart';
import 'app_routes.dart';
import 'browser_route_state.dart';

class AppStartupPolicy {
  AppStartupPolicy({
    OnboardingPreferencesService? onboardingPreferencesService,
  }) : _onboardingPreferencesService =
            onboardingPreferencesService ?? OnboardingPreferencesService();

  final OnboardingPreferencesService _onboardingPreferencesService;

  Future<OnboardingPreferencesState> loadState() {
    return _onboardingPreferencesService.loadState();
  }

  static String resolveRoute({
    required bool isAuthenticated,
    required OnboardingPreferencesState onboardingState,
  }) {
    if (isAuthenticated) {
      return AppRoutes.home;
    }
    if (onboardingState.showOnboardingOnSignedOutEntry) {
      return AppRoutes.onboarding;
    }
    if (!onboardingState.onboardingCompleted) {
      return AppRoutes.onboarding;
    }
    return onboardingState.continueAsGuest ? AppRoutes.home : AppRoutes.login;
  }

  static String? resolveExplicitEntryRoute() {
    return resolveExplicitBrowserRoute();
  }

  Future<String> resolveUnauthenticatedRoute() async {
    final onboardingState = await loadState();
    return resolveRoute(
      isAuthenticated: false,
      onboardingState: onboardingState,
    );
  }
}

void scheduleUnauthenticatedRedirect(
  BuildContext context, {
  AppStartupPolicy? startupPolicy,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final route = await (startupPolicy ?? AppStartupPolicy())
        .resolveUnauthenticatedRoute();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  });
}
