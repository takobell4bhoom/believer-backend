// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

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
  return const _BrowserCurrentLocationService();
}

class _BrowserCurrentLocationService implements CurrentLocationService {
  const _BrowserCurrentLocationService();

  @override
  bool get isSupported => html.window.isSecureContext ?? false;

  @override
  Future<CurrentLocationCoordinates> getCurrentCoordinates() async {
    if (!isSupported) {
      throw const CurrentLocationException(
        'Current-location setup requires a secure browser context such as HTTPS or localhost. Enter your location manually instead.',
      );
    }

    final geolocation = html.window.navigator.geolocation;
    try {
      final position = await geolocation.getCurrentPosition(
        enableHighAccuracy: true,
        timeout: const Duration(seconds: 15),
        maximumAge: const Duration(seconds: 30),
      );
      final coords = position.coords;
      final latitude = coords?.latitude;
      final longitude = coords?.longitude;
      if (latitude == null || longitude == null) {
        throw const CurrentLocationException(
          'Your device returned an incomplete location. Please try again or enter it manually.',
        );
      }

      return CurrentLocationCoordinates(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
        accuracyMeters: coords?.accuracy?.toDouble(),
      );
    } catch (error) {
      throw CurrentLocationException(_messageFromError(error));
    }
  }

  String _messageFromError(Object error) {
    final raw = error.toString().trim();
    final lower = raw.toLowerCase();
    if (lower.contains('permission')) {
      return 'Location permission was denied. Please allow access and try again, or enter your location manually.';
    }
    if (lower.contains('timeout')) {
      return 'We could not get your current location in time. Please try again or enter it manually.';
    }
    if (lower.contains('unavailable')) {
      return 'Your device could not determine a current location right now. Please try again or enter it manually.';
    }
    return 'We could not access your current location right now. Please try again or enter it manually.';
  }
}
