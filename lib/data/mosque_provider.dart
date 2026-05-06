import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/nearby_radius.dart';
import '../models/mosque_model.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

const nearbyMosquesPageSize = 20;

Map<String, String> buildNearbyMosquesQuery({
  required double latitude,
  required double longitude,
  double? radiusMiles,
  double? radiusKm,
  int page = 1,
  int limit = nearbyMosquesPageSize,
}) {
  final normalizedRadiusKm =
      radiusKm ?? milesToKilometers(radiusMiles ?? defaultNearbyRadiusMiles);

  return {
    'latitude': '$latitude',
    'longitude': '$longitude',
    'radius': '$normalizedRadiusKm',
    'page': '$page',
    'limit': '$limit',
  };
}

class MosqueNotifier extends AsyncNotifier<List<MosqueModel>> {
  int _nearbyRequestVersion = 0;
  int _currentNearbyPage = 0;
  int _currentNearbyLimit = nearbyMosquesPageSize;
  bool _hasMoreNearby = false;
  int? _totalNearby;

  @override
  Future<List<MosqueModel>> build() async {
    return const <MosqueModel>[];
  }

  int get currentNearbyPage => _currentNearbyPage;

  int get currentNearbyLimit => _currentNearbyLimit;

  bool get hasMoreNearby => _hasMoreNearby;

  int? get totalNearby => _totalNearby;

  void updateNearbyPagination({
    required int page,
    required int limit,
    required bool hasMore,
    int? total,
  }) {
    _currentNearbyPage = page;
    _currentNearbyLimit = limit;
    _hasMoreNearby = hasMore;
    _totalNearby = total;
  }

  String? _readBearerToken() {
    final authState = ref.read(authProvider);
    return authState.valueOrNull?.accessToken;
  }

  List<MosqueModel> _dedupeMosques(Iterable<MosqueModel> mosques) {
    final seenIds = <String>{};
    final deduped = <MosqueModel>[];

    for (final mosque in mosques) {
      if (seenIds.add(mosque.id)) {
        deduped.add(mosque);
      }
    }

    return deduped;
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
    double? radiusMiles,
    double? radiusKm,
    int page = 1,
    int limit = nearbyMosquesPageSize,
    bool append = false,
  }) async {
    final requestVersion = ++_nearbyRequestVersion;
    final normalizedPage = page < 1 ? 1 : page;
    final normalizedLimit = limit < 1 ? nearbyMosquesPageSize : limit;
    final previousItems = state.valueOrNull ?? const <MosqueModel>[];
    final shouldAppend =
        append && normalizedPage > 1 && previousItems.isNotEmpty;

    if (!shouldAppend) {
      state = const AsyncLoading();
    }

    try {
      final token = _readBearerToken();
      final response = await ApiClient.get(
        '/api/v1/mosques/nearby',
        query: buildNearbyMosquesQuery(
          latitude: latitude,
          longitude: longitude,
          radiusMiles: radiusMiles,
          radiusKm: radiusKm,
          page: normalizedPage,
          limit: normalizedLimit,
        ),
        bearerToken: token,
      );
      final data = response['data'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final meta = response['meta'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final pagination = meta['pagination'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(fromApi)
          .toList();
      final resolvedItems = shouldAppend
          ? _dedupeMosques([...previousItems, ...items])
          : _dedupeMosques(items);
      final hasMore = pagination['hasMore'] as bool? ??
          pagination['hasNext'] as bool? ??
          false;
      final total = (pagination['total'] as num?)?.toInt();

      if (requestVersion != _nearbyRequestVersion) {
        return state.valueOrNull ?? previousItems;
      }

      updateNearbyPagination(
        page: (pagination['page'] as num?)?.toInt() ?? normalizedPage,
        limit: (pagination['limit'] as num?)?.toInt() ?? normalizedLimit,
        hasMore: hasMore,
        total: total,
      );
      state = AsyncData(resolvedItems);
      return resolvedItems;
    } catch (error, stackTrace) {
      if (requestVersion != _nearbyRequestVersion) {
        rethrow;
      }

      if (shouldAppend) {
        state = AsyncData(previousItems);
      } else {
        updateNearbyPagination(
          page: 0,
          limit: normalizedLimit,
          hasMore: false,
        );
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }
}

final mosqueProvider = AsyncNotifierProvider<MosqueNotifier, List<MosqueModel>>(
    MosqueNotifier.new);
