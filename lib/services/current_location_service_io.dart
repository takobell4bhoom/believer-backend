import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

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
  return const _DeviceCurrentLocationService();
}

class _DeviceCurrentLocationService implements CurrentLocationService {
  const _DeviceCurrentLocationService();

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<CurrentLocationCoordinates> getCurrentCoordinates() async {
    if (!isSupported) {
      throw const CurrentLocationException(
        'Current-location setup is not supported on this platform yet. Enter your location manually instead.',
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const CurrentLocationException(
        'Location services are turned off on this device. Turn them on and try again, or enter your location manually.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const CurrentLocationException(
        'Location permission was denied. Please allow access and try again, or enter your location manually.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const CurrentLocationException(
        'Location permission is turned off for this app. Re-enable it in system settings or enter your location manually.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return CurrentLocationCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on LocationServiceDisabledException {
      throw const CurrentLocationException(
        'Location services are turned off on this device. Turn them on and try again, or enter your location manually.',
      );
    } on TimeoutException {
      throw const CurrentLocationException(
        'We could not get your current location in time. Please try again or enter it manually.',
      );
    } catch (_) {
      throw const CurrentLocationException(
        'We could not access your current location right now. Please try again or enter it manually.',
      );
    }
  }
}
