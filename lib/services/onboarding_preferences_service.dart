import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class OnboardingPreferencesState {
  const OnboardingPreferencesState({
    required this.onboardingCompleted,
    required this.continueAsGuest,
    required this.showOnboardingOnSignedOutEntry,
  });

  final bool onboardingCompleted;
  final bool continueAsGuest;
  final bool showOnboardingOnSignedOutEntry;
}

class OnboardingPreferencesService {
  static const _onboardingCompletedKey = 'onboarding.completed';
  static const _continueAsGuestKey = 'onboarding.continue_as_guest';
  static const _showOnboardingOnSignedOutEntryKey =
      'onboarding.show_on_signed_out_entry';

  Future<OnboardingPreferencesState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingPreferencesState(
      onboardingCompleted: prefs.getBool(_onboardingCompletedKey) ?? false,
      continueAsGuest: prefs.getBool(_continueAsGuestKey) ?? false,
      showOnboardingOnSignedOutEntry:
          prefs.getBool(_showOnboardingOnSignedOutEntryKey) ?? false,
    );
  }

  Future<bool> isCompleted() async {
    final state = await loadState();
    return state.onboardingCompleted;
  }

  Future<void> markCompleted({
    bool continueAsGuest = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    await prefs.setBool(_continueAsGuestKey, continueAsGuest);
    await prefs.setBool(_showOnboardingOnSignedOutEntryKey, false);
  }

  Future<void> markAuthEntryPreferred() async {
    await markCompleted(continueAsGuest: false);
  }

  Future<void> markGuestReturnPreferred() async {
    await markCompleted(continueAsGuest: true);
  }

  Future<void> markLogoutReturnPreferred() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_continueAsGuestKey, false);
    await prefs.setBool(_showOnboardingOnSignedOutEntryKey, true);
  }

  Future<void> clearGuestReturnPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_continueAsGuestKey, false);
    await prefs.setBool(_showOnboardingOnSignedOutEntryKey, false);
  }
}
