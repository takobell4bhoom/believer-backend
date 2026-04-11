import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AuthUser {
  final String id;
  final String fullName;
  final String email;
  final String role;

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });
}

@immutable
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}

@immutable
class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });
}

abstract class AuthTokenStore {
  Future<AuthTokens?> readTokens();
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clearTokens();
}

class SecureAuthTokenStore implements AuthTokenStore {
  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  const SecureAuthTokenStore();

  @override
  Future<AuthTokens?> readTokens() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

final authTokenStoreProvider = Provider<AuthTokenStore>((ref) {
  return const SecureAuthTokenStore();
});

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';
  static const _userIdKey = 'auth.user.id';
  static const _userNameKey = 'auth.user.name';
  static const _userEmailKey = 'auth.user.email';
  static const _userRoleKey = 'auth.user.role';

  @override
  Future<AuthSession?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final tokens = await _loadTokens(
      prefs,
      ref.read(authTokenStoreProvider),
    );
    final id = prefs.getString(_userIdKey);
    final name = prefs.getString(_userNameKey);
    final email = prefs.getString(_userEmailKey);
    final role = prefs.getString(_userRoleKey);

    if (tokens == null ||
        id == null ||
        name == null ||
        email == null ||
        role == null) {
      return null;
    }

    return AuthSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: AuthUser(id: id, fullName: name, email: email, role: role),
    );
  }

  void setSession({
    required String access,
    required String refresh,
    required AuthUser currentUser,
  }) {
    final session = AuthSession(
      accessToken: access,
      refreshToken: refresh,
      user: currentUser,
    );

    state = AsyncData(session);
    unawaited(_persistSession());
  }

  Future<void> hydrate() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> clear() async {
    state = const AsyncData(null);

    final prefs = await SharedPreferences.getInstance();
    await ref.read(authTokenStoreProvider).clearTokens();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userRoleKey);
  }

  void updateUser(AuthUser currentUser) {
    final session = state.valueOrNull;
    if (session == null) {
      return;
    }

    state = AsyncData(
      AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: currentUser,
      ),
    );
    unawaited(_persistSession());
  }

  Future<void> _persistSession() async {
    final session = state.valueOrNull;
    if (session == null) return;

    final prefs = await SharedPreferences.getInstance();
    await ref.read(authTokenStoreProvider).writeTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
    await prefs.setString(_userIdKey, session.user.id);
    await prefs.setString(_userNameKey, session.user.fullName);
    await prefs.setString(_userEmailKey, session.user.email);
    await prefs.setString(_userRoleKey, session.user.role);
  }

  Future<AuthTokens?> _loadTokens(
    SharedPreferences prefs,
    AuthTokenStore tokenStore,
  ) async {
    final storedTokens = await tokenStore.readTokens();
    if (storedTokens != null) {
      return storedTokens;
    }

    final legacyAccessToken = prefs.getString(_accessTokenKey);
    final legacyRefreshToken = prefs.getString(_refreshTokenKey);
    if (legacyAccessToken == null ||
        legacyAccessToken.isEmpty ||
        legacyRefreshToken == null ||
        legacyRefreshToken.isEmpty) {
      return null;
    }

    await tokenStore.writeTokens(
      accessToken: legacyAccessToken,
      refreshToken: legacyRefreshToken,
    );
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    return AuthTokens(
      accessToken: legacyAccessToken,
      refreshToken: legacyRefreshToken,
    );
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);

final authAccessTokenProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).valueOrNull?.accessToken;
});

final authRefreshTokenProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).valueOrNull?.refreshToken;
});

final authUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authProvider).valueOrNull?.user;
});

final authIsLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).valueOrNull?.accessToken != null;
});
