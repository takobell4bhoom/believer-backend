import 'package:flutter/material.dart';

import '../navigation/app_routes.dart';
import '../screens/location_setup_screen.dart';
import '../services/current_location_service.dart';
import '../services/location_preferences_service.dart';
import '../theme/app_colors.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.locationPreferencesService,
    this.currentLocationService,
  });

  final LocationPreferencesService? locationPreferencesService;
  final CurrentLocationService? currentLocationService;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final LocationPreferencesService _locationPreferencesService;
  late final CurrentLocationService _currentLocationService;

  SavedUserLocation? _savedLocation;

  @override
  void initState() {
    super.initState();
    _locationPreferencesService =
        widget.locationPreferencesService ?? LocationPreferencesService();
    _currentLocationService =
        widget.currentLocationService ?? createCurrentLocationService();
    _refreshSavedLocation();
  }

  Future<void> _refreshSavedLocation() async {
    final savedLocation = await _locationPreferencesService.loadSavedLocation();
    if (!mounted) {
      return;
    }

    setState(() => _savedLocation = savedLocation);
  }

  Future<void> _openCurrentLocationFlow() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.locationSetup,
      arguments: const LocationSetupFlowArgs(nextRoute: AppRoutes.map),
    );
    await _refreshSavedLocation();
  }

  Future<void> _openManualLocationFlow() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.locationSetupManual,
      arguments: const LocationSetupFlowArgs(nextRoute: AppRoutes.map),
    );
    await _refreshSavedLocation();
  }

  @override
  Widget build(BuildContext context) {
    final savedLocationLabel = _savedLocation?.label ?? 'No saved location yet';
    final supportsCurrentLocation = _currentLocationService.isSupported;
    final scopeDescription = supportsCurrentLocation
        ? 'Believer uses Google-backed typed place search plus current-location access on this platform. In-app map browsing is still out of scope for this launch.'
        : 'Believer uses Google-backed typed place search here. Current-location access is only available on supported browsers running in a secure context plus Android/iOS devices. In-app map browsing is still out of scope for this launch.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        title: const Text('Location'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_searching_outlined,
                    size: 40,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose how to update your location',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Figtree',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Saved location: $savedLocationLabel',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 15,
                      height: 1.5,
                      fontFamily: 'Figtree',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    scopeDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 15,
                      height: 1.5,
                      fontFamily: 'Figtree',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (supportsCurrentLocation) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openCurrentLocationFlow,
                        icon: const Icon(Icons.my_location_rounded),
                        label: const Text('Use my current location'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F1E8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2D8BE)),
                      ),
                      child: const Text(
                        'Current location is unavailable on this device here, so search for a location instead.',
                        key: Key('map-current-location-unavailable'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 14,
                          height: 1.45,
                          fontFamily: 'Figtree',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openManualLocationFlow,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Search for a location'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
