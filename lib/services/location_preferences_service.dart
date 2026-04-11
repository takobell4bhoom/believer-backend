import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class SavedUserLocation {
  const SavedUserLocation({
    required this.label,
    this.latitude,
    this.longitude,
  });

  final String label;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
}

class ResolvedLocation {
  const ResolvedLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

class LocationSuggestion {
  const LocationSuggestion({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.primaryText,
    this.secondaryText,
  });

  final String label;
  final double latitude;
  final double longitude;
  final String? primaryText;
  final String? secondaryText;
}

class LocationPreferencesService {
  static const _locationPrefsKey = 'user.location';
  static const _latitudePrefsKey = 'user.location.latitude';
  static const _longitudePrefsKey = 'user.location.longitude';
  static const defaultLocation = 'Bengaluru, Karnataka';
  static const unsetLocationLabel = 'Set location';

  Future<SavedUserLocation?> loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final label = _normalizeLocation(prefs.getString(_locationPrefsKey));
    final latitude = _readCoordinate(prefs, _latitudePrefsKey);
    final longitude = _readCoordinate(prefs, _longitudePrefsKey);

    if (label == null) {
      return null;
    }

    return SavedUserLocation(
      label: label,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<String> loadCurrentLocation() async {
    final savedLocation = await loadSavedLocation();
    return savedLocation?.label ?? defaultLocation;
  }

  Future<void> saveCurrentLocation(
    String location, {
    double? latitude,
    double? longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeLocation(location);
    if (normalized == null) {
      await prefs.remove(_locationPrefsKey);
      await prefs.remove(_latitudePrefsKey);
      await prefs.remove(_longitudePrefsKey);
      return;
    }

    await prefs.setString(_locationPrefsKey, normalized);
    if (latitude != null && longitude != null) {
      await prefs.setDouble(_latitudePrefsKey, latitude);
      await prefs.setDouble(_longitudePrefsKey, longitude);
    } else {
      await prefs.remove(_latitudePrefsKey);
      await prefs.remove(_longitudePrefsKey);
    }
  }

  Future<ResolvedLocation?> resolveLocation(String location) async {
    final normalized = _normalizeLocation(location);
    if (normalized == null) {
      return null;
    }

    final response = await ApiClient.get(
      '/api/v1/mosques/location-resolve',
      query: {'query': normalized},
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final latitude = _toFiniteDouble(data['latitude']);
    final longitude = _toFiniteDouble(data['longitude']);
    if (latitude == null || longitude == null) {
      return null;
    }

    final resolvedLabel =
        _normalizeLocation(data['label'] as String?) ?? normalized;
    return ResolvedLocation(
      label: resolvedLabel,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<LocationSuggestion>> searchLocations(
    String query, {
    int limit = 5,
  }) async {
    final normalized = _normalizeLocation(query);
    if (normalized == null) {
      return const <LocationSuggestion>[];
    }

    final response = await ApiClient.get(
      '/api/v1/mosques/location-suggest',
      query: {
        'query': normalized,
        'limit': '$limit',
      },
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final items = data['items'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final latitude = _toFiniteDouble(item['latitude']);
          final longitude = _toFiniteDouble(item['longitude']);
          final label = _normalizeLocation(item['label'] as String?);
          if (latitude == null || longitude == null || label == null) {
            return null;
          }

          return LocationSuggestion(
            label: label,
            latitude: latitude,
            longitude: longitude,
            primaryText: _normalizeLocation(item['primaryText'] as String?),
            secondaryText: _normalizeLocation(item['secondaryText'] as String?),
          );
        })
        .whereType<LocationSuggestion>()
        .toList(growable: false);
  }

  Future<String?> reverseResolveLocation({
    required double latitude,
    required double longitude,
  }) async {
    final response = await ApiClient.get(
      '/api/v1/mosques/location-reverse',
      query: <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return _normalizeLocation(data['label'] as String?);
  }

  double? _readCoordinate(SharedPreferences prefs, String key) {
    final directValue = prefs.getDouble(key);
    if (directValue != null && directValue.isFinite) {
      return directValue;
    }

    final stringValue = prefs.getString(key);
    return _toFiniteDouble(stringValue);
  }

  double? _toFiniteDouble(Object? value) {
    final parsed = switch (value) {
      final double v => v,
      final int v => v.toDouble(),
      final String v => double.tryParse(v.trim()),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite) {
      return null;
    }

    return parsed;
  }

  String? _normalizeLocation(String? location) {
    final normalized = location?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
