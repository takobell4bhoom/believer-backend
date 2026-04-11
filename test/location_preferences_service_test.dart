import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/services/location_preferences_service.dart';

void main() {
  test('location preferences service saves label and coordinates together',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = LocationPreferencesService();

    expect(
      await service.loadCurrentLocation(),
      LocationPreferencesService.defaultLocation,
    );

    await service.saveCurrentLocation(
      '  Tampa, Florida  ',
      latitude: 27.9506,
      longitude: -82.4572,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user.location'), 'Tampa, Florida');
    expect(prefs.getDouble('user.location.latitude'), 27.9506);
    expect(prefs.getDouble('user.location.longitude'), -82.4572);
    expect(await service.loadCurrentLocation(), 'Tampa, Florida');

    final savedLocation = await service.loadSavedLocation();
    expect(savedLocation, isNotNull);
    expect(savedLocation!.label, 'Tampa, Florida');
    expect(savedLocation.latitude, 27.9506);
    expect(savedLocation.longitude, -82.4572);
    expect(savedLocation.hasCoordinates, isTrue);
  });

  test('location preferences service keeps legacy text-only saves compatible',
      () async {
    SharedPreferences.setMockInitialValues({
      'user.location': 'Legacy City',
    });
    final service = LocationPreferencesService();

    final savedLocation = await service.loadSavedLocation();

    expect(savedLocation, isNotNull);
    expect(savedLocation!.label, 'Legacy City');
    expect(savedLocation.latitude, isNull);
    expect(savedLocation.longitude, isNull);
    expect(savedLocation.hasCoordinates, isFalse);
  });
}
