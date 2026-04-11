import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mosque_model.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

class MosqueNotifier extends AsyncNotifier<List<MosqueModel>> {
  @override
  Future<List<MosqueModel>> build() async {
    return const <MosqueModel>[];
  }

  String? _readBearerToken() {
    final authState = ref.read(authProvider);
    return authState.valueOrNull?.accessToken;
  }

  void addMosque(MosqueModel mosque) {
    upsertMosque(mosque);
  }

  void upsertMosque(MosqueModel mosque) {
    final current = state.valueOrNull ?? const <MosqueModel>[];
    final existingIndex = current.indexWhere((item) => item.id == mosque.id);
    if (existingIndex == -1) {
      state = AsyncData([mosque, ...current]);
      return;
    }

    final updated = current.toList(growable: false);
    updated[existingIndex] = mosque;
    state = AsyncData(updated);
  }

  void setBookmarked(String mosqueId, bool value) {
    final current = state.valueOrNull ?? const <MosqueModel>[];
    if (current.isEmpty) {
      return;
    }
    state = AsyncData(
      current
          .map(
            (mosque) => mosque.id == mosqueId
                ? mosque.copyWith(isBookmarked: value)
                : mosque,
          )
          .toList(),
    );
  }

  Future<List<MosqueModel>> loadNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    state = const AsyncLoading();

    try {
      final token = _readBearerToken();
      final response = await ApiClient.get(
        '/api/v1/mosques/nearby',
        query: {
          'latitude': '$latitude',
          'longitude': '$longitude',
          'radius': '$radiusKm',
          'limit': '$limit',
        },
        bearerToken: token,
      );
      final data = response['data'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(fromApi)
          .toList();

      state = AsyncData(items);
      return items;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final mosqueProvider = AsyncNotifierProvider<MosqueNotifier, List<MosqueModel>>(
    MosqueNotifier.new);
