import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_provider_container.dart';
import '../data/auth_provider.dart';
import 'api_client.dart';
import 'onboarding_preferences_service.dart';

class AuthService {
  final OnboardingPreferencesService _onboardingPreferencesService =
      OnboardingPreferencesService();

  Future<void> signup({
    required String fullName,
    required String email,
    required String password,
    String accountType = 'community',
  }) async {
    final data = await ApiClient.post(
      '/api/v1/auth/signup',
      body: {
        'fullName': fullName,
        'email': email,
        'password': password,
        'accountType': accountType,
      },
    );

    _saveSession(data);
    await _onboardingPreferencesService.markAuthEntryPreferred();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final data = await ApiClient.post(
      '/api/v1/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    _saveSession(data);
    await _onboardingPreferencesService.markAuthEntryPreferred();
  }

  Future<void> requestPasswordReset({
    required String email,
  }) async {
    await ApiClient.post(
      '/api/v1/auth/forgot-password',
      body: {
        'email': email.trim(),
      },
    );
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await ApiClient.post(
      '/api/v1/auth/reset-password',
      body: {
        'token': token.trim(),
        'newPassword': newPassword,
      },
    );

    await appProviderContainer.read(authProvider.notifier).clear();
  }

  Future<void> logout() async {
    final session = appProviderContainer.read(authProvider).valueOrNull;
    final access = session?.accessToken;
    final refresh = session?.refreshToken;

    if (access != null && refresh != null) {
      try {
        await ApiClient.post(
          '/api/v1/auth/logout',
          bearerToken: access,
          body: {'refreshToken': refresh},
        );
      } catch (_) {
        // Best-effort server revoke; local clear should still happen.
      }
    }

    await appProviderContainer.read(authProvider.notifier).clear();
    await _onboardingPreferencesService.markLogoutReturnPreferred();
  }

  Future<AuthUser> getProfile() async {
    final session = appProviderContainer.read(authProvider).valueOrNull;
    final access = session?.accessToken;
    if (access == null || access.isEmpty) {
      throw ApiException('Please log in first.', statusCode: 401);
    }

    final payload = await ApiClient.get(
      '/api/v1/auth/me',
      bearerToken: access,
    );
    return _parseUser(payload['data'] as Map<String, dynamic>?);
  }

  Future<AuthUser> updateProfile({
    required String fullName,
  }) async {
    final session = appProviderContainer.read(authProvider).valueOrNull;
    final access = session?.accessToken;
    if (access == null || access.isEmpty) {
      throw ApiException('Please log in first.', statusCode: 401);
    }

    final payload = await ApiClient.put(
      '/api/v1/auth/me',
      bearerToken: access,
      body: {
        'fullName': fullName.trim(),
      },
    );
    final user = _parseUser(payload['data'] as Map<String, dynamic>?);
    appProviderContainer.read(authProvider.notifier).updateUser(user);
    return user;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = appProviderContainer.read(authProvider).valueOrNull;
    final access = session?.accessToken;
    if (access == null || access.isEmpty) {
      throw ApiException('Please log in first.', statusCode: 401);
    }

    final data = await ApiClient.post(
      '/api/v1/auth/change-password',
      bearerToken: access,
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );

    _saveSession(data);
  }

  void _saveSession(Map<String, dynamic> payload) {
    final data = payload['data'] as Map<String, dynamic>?;
    final userData = data?['user'] as Map<String, dynamic>?;
    final tokenData = data?['tokens'] as Map<String, dynamic>?;
    if (userData == null || tokenData == null) {
      throw ApiException('Invalid auth response');
    }

    final access = tokenData['accessToken'] as String?;
    final refresh = tokenData['refreshToken'] as String?;
    if (access == null || refresh == null) {
      throw ApiException('Missing auth tokens');
    }

    appProviderContainer.read(authProvider.notifier).setSession(
          access: access,
          refresh: refresh,
          currentUser: _parseUser(userData),
        );
  }

  AuthUser _parseUser(Map<String, dynamic>? userData) {
    if (userData == null) {
      throw ApiException('Invalid auth response');
    }

    return AuthUser(
      id: userData['id'] as String? ?? '',
      fullName: userData['fullName'] as String? ?? '',
      email: userData['email'] as String? ?? '',
      role: userData['role'] as String? ?? 'community',
    );
  }
}
