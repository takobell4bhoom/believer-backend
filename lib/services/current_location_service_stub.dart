class CurrentLocationCoordinates {
  const CurrentLocationCoordinates({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}

class CurrentLocationException implements Exception {
  const CurrentLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class CurrentLocationService {
  bool get isSupported;
  Future<CurrentLocationCoordinates> getCurrentCoordinates();
}

CurrentLocationService createCurrentLocationService() {
  return const _UnsupportedCurrentLocationService();
}

class _UnsupportedCurrentLocationService implements CurrentLocationService {
  const _UnsupportedCurrentLocationService();

  @override
  bool get isSupported => false;

  @override
  Future<CurrentLocationCoordinates> getCurrentCoordinates() async {
    throw const CurrentLocationException(
      'Current-location setup is not supported on this platform yet. Enter your location manually instead.',
    );
  }
}
