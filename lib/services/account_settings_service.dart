import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_provider_container.dart';
import '../data/auth_provider.dart';
import 'api_client.dart';
import 'onboarding_preferences_service.dart';

class AccountSettingsService {
  final OnboardingPreferencesService _onboardingPreferencesService =
      OnboardingPreferencesService();

  Future<void> deactivateAccount({
    required String confirmation,
  }) async {
    final session = appProviderContainer.read(authProvider).valueOrNull;
    final access = session?.accessToken;
    if (access == null || access.isEmpty) {
      throw ApiException('Please log in first.', statusCode: 401);
    }

    await ApiClient.post(
      '/api/v1/auth/deactivate',
      bearerToken: access,
      body: {
        'confirmation': confirmation.trim(),
      },
    );

    await appProviderContainer.read(authProvider.notifier).clear();
    await _onboardingPreferencesService.markLogoutReturnPreferred();
  }

  Future<void> submitSupportRequest({
    required String subject,
    required String message,
  }) async {
    final access = _requireAccessToken();
    await ApiClient.post(
      '/api/v1/account/support-requests',
      bearerToken: access,
      body: {
        'subject': subject.trim(),
        'message': message.trim(),
      },
    );
  }

  Future<void> submitMosqueSuggestion({
    required String mosqueName,
    required String city,
    required String country,
    String? addressLine,
    String? notes,
  }) async {
    final access = _requireAccessToken();
    await ApiClient.post(
      '/api/v1/account/mosque-suggestions',
      bearerToken: access,
      body: {
        'mosqueName': mosqueName.trim(),
        'city': city.trim(),
        'country': country.trim(),
        'addressLine': addressLine?.trim(),
        'notes': notes?.trim(),
      },
    );
  }

  String _requireAccessToken() {
    final session = appProviderContainer.read(authProvider).valueOrNull;
    final access = session?.accessToken;
    if (access == null || access.isEmpty) {
      throw ApiException('Please log in first.', statusCode: 401);
    }
    return access;
  }
}
