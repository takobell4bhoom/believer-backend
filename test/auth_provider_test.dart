import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/data/auth_provider.dart';

void main() {
  test(
      'hydrates a session from secure token storage and shared prefs user data',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Amina',
      'auth.user.email': 'amina@example.com',
      'auth.user.role': 'community',
    });

    final tokenStore = _FakeAuthTokenStore(
      tokens: const AuthTokens(
        accessToken: 'secure-access',
        refreshToken: 'secure-refresh',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(tokenStore),
      ],
    );
    addTearDown(container.dispose);

    final session = await container.read(authProvider.future);

    expect(session, isNotNull);
    expect(session!.accessToken, 'secure-access');
    expect(session.refreshToken, 'secure-refresh');
    expect(session.user.email, 'amina@example.com');
  });

  test('migrates legacy shared-preferences tokens into secure storage',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth.access_token': 'legacy-access',
      'auth.refresh_token': 'legacy-refresh',
      'auth.user.id': 'user-1',
      'auth.user.name': 'Amina',
      'auth.user.email': 'amina@example.com',
      'auth.user.role': 'community',
    });

    final tokenStore = _FakeAuthTokenStore();
    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(tokenStore),
      ],
    );
    addTearDown(container.dispose);

    final session = await container.read(authProvider.future);
    final prefs = await SharedPreferences.getInstance();

    expect(session, isNotNull);
    expect(tokenStore.tokens?.accessToken, 'legacy-access');
    expect(tokenStore.tokens?.refreshToken, 'legacy-refresh');
    expect(prefs.getString('auth.access_token'), isNull);
    expect(prefs.getString('auth.refresh_token'), isNull);
  });

  test('setSession persists tokens separately from user fields', () async {
    SharedPreferences.setMockInitialValues({});

    final tokenStore = _FakeAuthTokenStore();
    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(tokenStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.read(authProvider.notifier).setSession(
          access: 'next-access',
          refresh: 'next-refresh',
          currentUser: const AuthUser(
            id: 'user-2',
            fullName: 'Khadijah Noor',
            email: 'khadijah@example.com',
            role: 'community',
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();

    expect(tokenStore.tokens?.accessToken, 'next-access');
    expect(tokenStore.tokens?.refreshToken, 'next-refresh');
    expect(prefs.getString('auth.user.id'), 'user-2');
    expect(prefs.getString('auth.user.name'), 'Khadijah Noor');
    expect(prefs.getString('auth.user.email'), 'khadijah@example.com');
    expect(prefs.getString('auth.user.role'), 'community');
    expect(prefs.getString('auth.access_token'), isNull);
    expect(prefs.getString('auth.refresh_token'), isNull);
  });

  test('updateUser keeps secure tokens while refreshing persisted profile data',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Amina',
      'auth.user.email': 'amina@example.com',
      'auth.user.role': 'community',
    });

    final tokenStore = _FakeAuthTokenStore(
      tokens: const AuthTokens(
        accessToken: 'secure-access',
        refreshToken: 'secure-refresh',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(tokenStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.read(authProvider.notifier).updateUser(
          const AuthUser(
            id: 'user-1',
            fullName: 'Amina Yusuf',
            email: 'amina.yusuf@example.com',
            role: 'admin',
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    final session = container.read(authProvider).valueOrNull;

    expect(tokenStore.tokens?.accessToken, 'secure-access');
    expect(tokenStore.tokens?.refreshToken, 'secure-refresh');
    expect(session?.user.fullName, 'Amina Yusuf');
    expect(prefs.getString('auth.user.name'), 'Amina Yusuf');
    expect(prefs.getString('auth.user.email'), 'amina.yusuf@example.com');
    expect(prefs.getString('auth.user.role'), 'admin');
  });

  test('clear removes secure tokens and persisted user fields', () async {
    SharedPreferences.setMockInitialValues({
      'auth.user.id': 'user-1',
      'auth.user.name': 'Amina',
      'auth.user.email': 'amina@example.com',
      'auth.user.role': 'community',
    });

    final tokenStore = _FakeAuthTokenStore(
      tokens: const AuthTokens(
        accessToken: 'secure-access',
        refreshToken: 'secure-refresh',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(tokenStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(authProvider.notifier).clear();

    final prefs = await SharedPreferences.getInstance();

    expect(container.read(authProvider).valueOrNull, isNull);
    expect(tokenStore.tokens, isNull);
    expect(prefs.getString('auth.user.id'), isNull);
    expect(prefs.getString('auth.user.name'), isNull);
    expect(prefs.getString('auth.user.email'), isNull);
    expect(prefs.getString('auth.user.role'), isNull);
  });
}

class _FakeAuthTokenStore implements AuthTokenStore {
  _FakeAuthTokenStore({
    this.tokens,
  });

  AuthTokens? tokens;

  @override
  Future<void> clearTokens() async {
    tokens = null;
  }

  @override
  Future<AuthTokens?> readTokens() async => tokens;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    tokens = AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}
