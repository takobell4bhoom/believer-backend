import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mosque_model.dart';
import 'auth_provider.dart';
import 'mock_data.dart';
import 'mosque_provider.dart';

class MockMosqueNotifier extends MosqueNotifier {
  @override
  Future<List<MosqueModel>> build() async {
    return MockData.mosques;
  }

  @override
  Future<List<MosqueModel>> loadNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    final items = MockData.mosques.take(limit).toList(growable: false);
    state = AsyncData(items);
    return items;
  }
}

class MockAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return MockData.currentSession;
  }

  @override
  void setSession({
    required String access,
    required String refresh,
    required AuthUser currentUser,
  }) {
    state = AsyncData(
      AuthSession(
        accessToken: access,
        refreshToken: refresh,
        user: currentUser,
      ),
    );
  }

  @override
  Future<void> hydrate() async {
    state = const AsyncLoading();
    state = const AsyncData(MockData.currentSession);
  }

  @override
  Future<void> clear() async {
    state = const AsyncData(MockData.currentSession);
  }
}

final mockMosqueProvider =
    AsyncNotifierProvider<MockMosqueNotifier, List<MosqueModel>>(
  MockMosqueNotifier.new,
);

final mockAuthProvider = AsyncNotifierProvider<MockAuthNotifier, AuthSession?>(
  MockAuthNotifier.new,
);

final mockAuthAccessTokenProvider = Provider<String?>((ref) {
  return ref.watch(mockAuthProvider).valueOrNull?.accessToken;
});

final mockAuthRefreshTokenProvider = Provider<String?>((ref) {
  return ref.watch(mockAuthProvider).valueOrNull?.refreshToken;
});

final mockAuthUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(mockAuthProvider).valueOrNull?.user;
});

final mockAuthIsLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(mockAuthProvider).valueOrNull?.accessToken != null;
});
