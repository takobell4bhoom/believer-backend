import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/app_routes.dart';
import '../services/current_location_service.dart';
import '../services/location_preferences_service.dart';
import '../services/prayer_settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class LocationSetupFlowArgs {
  const LocationSetupFlowArgs({
    required this.nextRoute,
    this.clearStackOnComplete = false,
  });

  final String nextRoute;
  final bool clearStackOnComplete;
}

class LocationSetupMapArgs extends LocationSetupFlowArgs {
  const LocationSetupMapArgs({
    required super.nextRoute,
    required this.selectedLocation,
    super.clearStackOnComplete,
  });

  final ResolvedLocation selectedLocation;
}

enum _CurrentLocationRequestState { idle, loading, error }

class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({
    super.key,
    required this.flowArgs,
    this.locationPreferencesService,
    this.currentLocationService,
  });

  final LocationSetupFlowArgs flowArgs;
  final LocationPreferencesService? locationPreferencesService;
  final CurrentLocationService? currentLocationService;

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  static const String _unsupportedCurrentLocationMessage =
      'Automatic current-location lookup is not supported on this platform yet. Enter your location manually to keep nearby recommendations accurate.';

  late final LocationPreferencesService _locationPreferencesService;
  late final CurrentLocationService _currentLocationService;

  _CurrentLocationRequestState _requestState =
      _CurrentLocationRequestState.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _locationPreferencesService =
        widget.locationPreferencesService ?? LocationPreferencesService();
    _currentLocationService =
        widget.currentLocationService ?? createCurrentLocationService();
  }

  Future<void> _requestCurrentLocation() async {
    if (_requestState == _CurrentLocationRequestState.loading) {
      return;
    }

    setState(() {
      _requestState = _CurrentLocationRequestState.loading;
      _errorMessage = null;
    });

    try {
      final coordinates = await _currentLocationService.getCurrentCoordinates();
      var locationLabel = 'Current location';
      try {
        final resolvedLabel =
            await _locationPreferencesService.reverseResolveLocation(
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
        );
        if (resolvedLabel != null && resolvedLabel.isNotEmpty) {
          locationLabel = resolvedLabel;
        }
      } catch (_) {
        // The geolocation request succeeded, so we keep going with a fallback label.
      }

      await _locationPreferencesService.saveCurrentLocation(
        locationLabel,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed(
        AppRoutes.locationSetupAsar,
        arguments: widget.flowArgs,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _requestState = _CurrentLocationRequestState.error;
        _errorMessage = error is CurrentLocationException
            ? error.message
            : 'We could not access your current location right now. Please try again or enter it manually.';
      });
    }
  }

  void _openManualEntry() {
    Navigator.of(context).pushNamed(
      AppRoutes.locationSetupManual,
      arguments: widget.flowArgs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _requestState == _CurrentLocationRequestState.loading;
    final supportsCurrentLocation = _currentLocationService.isSupported;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3EF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  _SetupTopBar(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '2-Step Set Up',
                    style: TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SetupProgressIndicator(activeStep: 1),
                  const SizedBox(height: 64),
                  const _LocationSetupIllustration(),
                  const SizedBox(height: 28),
                  const Text(
                    'Set Location',
                    style: TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 26),
                    child: Text(
                      'Set a saved location so nearby mosque prayer times and event recommendations start from a real place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 18),
                    _SetupMessageCard(
                      key: const Key('location-setup-error'),
                      message: _errorMessage!,
                      tone: _SetupMessageTone.error,
                    ),
                  ] else if (!supportsCurrentLocation) ...[
                    const SizedBox(height: 18),
                    const _SetupMessageCard(
                      key: Key('location-setup-current-location-unavailable'),
                      message: _unsupportedCurrentLocationMessage,
                      tone: _SetupMessageTone.info,
                    ),
                  ],
                  const SizedBox(height: 34),
                  if (isLoading)
                    const _SetupLoadingButton(
                      key: Key('location-setup-loading-button'),
                    )
                  else if (!supportsCurrentLocation)
                    _SetupPrimaryButton(
                      key: const Key('location-setup-manual-primary'),
                      icon: Icons.search_rounded,
                      label: 'Enter location manually',
                      onTap: _openManualEntry,
                    )
                  else
                    _SetupPrimaryButton(
                      key: const Key('location-setup-current-location'),
                      icon: Icons.my_location_rounded,
                      label: _requestState == _CurrentLocationRequestState.error
                          ? 'Try current location again'
                          : 'Use my current location',
                      onTap: _requestCurrentLocation,
                    ),
                  const SizedBox(height: 18),
                  if (supportsCurrentLocation) ...[
                    const Text(
                      'OR',
                      style: TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5D675F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      key: const Key('location-setup-manual-entry'),
                      onPressed: isLoading ? null : _openManualEntry,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4C6E5C),
                        textStyle: const TextStyle(
                          fontFamily: AppTypography.figtreeFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationThickness: 2,
                        ),
                      ),
                      child: const Text('Enter location manually >'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ManualLocationSetupScreen extends StatefulWidget {
  const ManualLocationSetupScreen({
    super.key,
    required this.flowArgs,
    this.locationPreferencesService,
  });

  final LocationSetupFlowArgs flowArgs;
  final LocationPreferencesService? locationPreferencesService;

  @override
  State<ManualLocationSetupScreen> createState() =>
      _ManualLocationSetupScreenState();
}

class _ManualLocationSetupScreenState extends State<ManualLocationSetupScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final LocationPreferencesService _locationPreferencesService;
  Timer? _searchDebounce;
  List<LocationSuggestion> _suggestions = const <LocationSuggestion>[];
  LocationSuggestion? _selectedSuggestion;
  bool _isSearching = false;
  bool _isResolvingTypedLocation = false;
  String? _searchFeedback;
  bool _searchFeedbackIsError = false;

  @override
  void initState() {
    super.initState();
    _locationPreferencesService =
        widget.locationPreferencesService ?? LocationPreferencesService();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String get _typedQuery => _searchController.text.trim();

  bool get _canContinue =>
      _selectedSuggestion != null ||
      (_typedQuery.length >= 2 && !_isSearching && !_isResolvingTypedLocation);

  Future<void> _searchLocations(String rawValue) async {
    final query = rawValue.trim();
    _searchDebounce?.cancel();

    if (_selectedSuggestion != null &&
        _selectedSuggestion!.label.toLowerCase() != query.toLowerCase()) {
      setState(() => _selectedSuggestion = null);
    }

    if (query.length < 2) {
      setState(() {
        _suggestions = const <LocationSuggestion>[];
        _isSearching = false;
        _searchFeedback = query.isEmpty
            ? 'Type a city, area, or street to see real suggestions.'
            : 'Enter at least 2 characters to search.';
        _searchFeedbackIsError = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchFeedback = null;
      _searchFeedbackIsError = false;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results =
            await _locationPreferencesService.searchLocations(query);
        if (!mounted || _typedQuery != query) {
          return;
        }

        setState(() {
          _suggestions = results;
          _isSearching = false;
          if (results.isEmpty) {
            _searchFeedback =
                'No matches yet. Try a city, neighborhood, or street name.';
            _searchFeedbackIsError = false;
          } else {
            _searchFeedback = null;
          }
        });
      } catch (_) {
        if (!mounted || _typedQuery != query) {
          return;
        }

        setState(() {
          _suggestions = const <LocationSuggestion>[];
          _isSearching = false;
          _searchFeedback =
              'Location search is unavailable right now. You can still try an exact place search.';
          _searchFeedbackIsError = true;
        });
      }
    });
  }

  Future<void> _selectSuggestion(LocationSuggestion suggestion) async {
    await _locationPreferencesService.saveCurrentLocation(
      suggestion.label,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedSuggestion = suggestion;
      _searchController.value = TextEditingValue(
        text: suggestion.label,
        selection: TextSelection.collapsed(offset: suggestion.label.length),
      );
      _searchFeedback =
          'Location saved. Nearby mosques and events will use this point.';
      _searchFeedbackIsError = false;
    });
  }

  Future<void> _openMapConfirmation() async {
    final selectedSuggestion = _selectedSuggestion;
    if (selectedSuggestion != null) {
      _pushConfirmationScreen(
        ResolvedLocation(
          label: selectedSuggestion.label,
          latitude: selectedSuggestion.latitude,
          longitude: selectedSuggestion.longitude,
        ),
      );
      return;
    }

    final query = _typedQuery;
    if (query.length < 2 || _isResolvingTypedLocation) {
      return;
    }

    setState(() {
      _isResolvingTypedLocation = true;
      _searchFeedback = null;
      _searchFeedbackIsError = false;
    });

    try {
      final resolved = await _locationPreferencesService.resolveLocation(query);
      if (!mounted) {
        return;
      }

      if (resolved == null) {
        setState(() {
          _searchFeedback =
              'We could not confirm that place yet. Pick a suggestion or refine the search.';
          _searchFeedbackIsError = true;
          _isResolvingTypedLocation = false;
        });
        return;
      }

      await _locationPreferencesService.saveCurrentLocation(
        resolved.label,
        latitude: resolved.latitude,
        longitude: resolved.longitude,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedSuggestion = LocationSuggestion(
          label: resolved.label,
          latitude: resolved.latitude,
          longitude: resolved.longitude,
          primaryText: resolved.label,
        );
        _isResolvingTypedLocation = false;
      });
      _pushConfirmationScreen(resolved);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _searchFeedback =
            'We could not confirm this place right now. Try another search or go back.';
        _searchFeedbackIsError = true;
        _isResolvingTypedLocation = false;
      });
    }
  }

  void _pushConfirmationScreen(ResolvedLocation resolvedLocation) {
    Navigator.of(context).pushNamed(
      AppRoutes.locationSetupMap,
      arguments: LocationSetupMapArgs(
        nextRoute: widget.flowArgs.nextRoute,
        selectedLocation: resolvedLocation,
        clearStackOnComplete: widget.flowArgs.clearStackOnComplete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                compact ? 20 : 28,
                16,
                compact ? 18 : 26,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SetupTopBar(
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      SizedBox(height: compact ? 20 : 26),
                      const Text(
                        '2-Step Set Up',
                        style: TextStyle(
                          fontFamily: AppTypography.figtreeFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                      SizedBox(height: compact ? 16 : 20),
                      const _SetupProgressIndicator(activeStep: 1),
                      SizedBox(height: compact ? 26 : 34),
                      const Center(
                        child: Text(
                          'Enter Location',
                          style: TextStyle(
                            fontFamily: AppTypography.prozaLibreFamily,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                            height: 1.1,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 18 : 24),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: const Text(
                            'Choose the city or neighborhood you want to center the app around first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTypography.figtreeFamily,
                              fontSize: 14,
                              height: 1.45,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 22 : 30),
                      _LocationSearchField(
                        controller: _searchController,
                        onChanged: _searchLocations,
                      ),
                      SizedBox(height: compact ? 16 : 22),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E4DD)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x120F1F18),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (_isSearching)
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Finding matching locations...',
                                        style: TextStyle(
                                          fontFamily:
                                              AppTypography.figtreeFamily,
                                          fontSize: 14,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_suggestions.isNotEmpty)
                              for (var index = 0;
                                  index < _suggestions.length;
                                  index++) ...[
                                _LocationSuggestionTile(
                                  key: Key('location-option-$index'),
                                  suggestion: _suggestions[index],
                                  selected: _selectedSuggestion?.label
                                          .toLowerCase() ==
                                      _suggestions[index].label.toLowerCase(),
                                  onTap: () =>
                                      _selectSuggestion(_suggestions[index]),
                                ),
                                if (index != _suggestions.length - 1)
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFF0F1EB),
                                  ),
                              ]
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                                child: Text(
                                  _searchFeedback ??
                                      'Type a city, area, or street to see real suggestions.',
                                  key: const Key('location-search-feedback'),
                                  style: TextStyle(
                                    fontFamily: AppTypography.figtreeFamily,
                                    fontSize: 14,
                                    height: 1.45,
                                    color: _searchFeedbackIsError
                                        ? const Color(0xFF8C4C3A)
                                        : AppColors.secondaryText,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_searchFeedback != null &&
                          _suggestions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _searchFeedback!,
                          key: const Key('location-search-feedback'),
                          style: TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 13,
                            height: 1.45,
                            color: _searchFeedbackIsError
                                ? const Color(0xFF8C4C3A)
                                : const Color(0xFF466A57),
                          ),
                        ),
                      ],
                      SizedBox(height: compact ? 18 : 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const Key('location-setup-continue'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF466A57),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _canContinue ? _openMapConfirmation : null,
                          child: Text(
                            _isResolvingTypedLocation
                                ? 'Confirming...'
                                : 'Continue',
                            style: const TextStyle(
                              fontFamily: AppTypography.figtreeFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LocationSetupMapScreen extends StatefulWidget {
  const LocationSetupMapScreen({
    super.key,
    required this.flowArgs,
  });

  final LocationSetupMapArgs flowArgs;

  @override
  State<LocationSetupMapScreen> createState() => _LocationSetupMapScreenState();
}

class _LocationSetupMapScreenState extends State<LocationSetupMapScreen> {
  bool _isSaving = false;

  Future<void> _confirmLocation() async {
    if (_isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.locationSetupAsar,
      arguments: LocationSetupFlowArgs(
        nextRoute: widget.flowArgs.nextRoute,
        clearStackOnComplete: widget.flowArgs.clearStackOnComplete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = widget.flowArgs.selectedLocation;
    final latitudeLabel = selectedLocation.latitude.toStringAsFixed(4);
    final longitudeLabel = selectedLocation.longitude.toStringAsFixed(4);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SetupTopBar(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      '2-Step Set Up',
                      style: TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SetupProgressIndicator(activeStep: 1),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF7F1E7),
                          Color(0xFFE7EFE7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFF466A57),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontFamily: AppTypography.prozaLibreFamily,
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          selectedLocation.label,
                          style: const TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'We found a saved point for this search. Nearby mosques, events, and prayer context will start from these coordinates.',
                          style: TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E4DD)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x120F1F18),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saved coordinates',
                          style: TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                            color: Color(0xFF617164),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$latitudeLabel, $longitudeLabel',
                          key: const Key('location-confirmation-coordinates'),
                          style: const TextStyle(
                            fontFamily: AppTypography.prozaLibreFamily,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Need a different result? Go back and pick another suggestion or refine your search.',
                          style: TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('location-map-confirm'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: const Color(0xFF466A57),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isSaving ? null : _confirmLocation,
                      child: Text(
                        _isSaving
                            ? 'Continuing...'
                            : 'Continue with this location',
                        style: const TextStyle(
                          fontFamily: AppTypography.figtreeFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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

class LocationSetupAsarScreen extends StatefulWidget {
  const LocationSetupAsarScreen({
    super.key,
    required this.flowArgs,
    this.prayerSettingsService,
  });

  final LocationSetupFlowArgs flowArgs;
  final PrayerSettingsService? prayerSettingsService;

  @override
  State<LocationSetupAsarScreen> createState() =>
      _LocationSetupAsarScreenState();
}

class _LocationSetupAsarScreenState extends State<LocationSetupAsarScreen> {
  late final PrayerSettingsService _prayerSettingsService;

  PrayerSettings? _currentSettings;
  AsarTimeMode? _selectedMode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prayerSettingsService =
        widget.prayerSettingsService ?? PrayerSettingsService();
    Future.microtask(_loadPrayerSettings);
  }

  Future<void> _loadPrayerSettings() async {
    final settings = await _prayerSettingsService.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentSettings = settings;
      _selectedMode = settings.asarTimeMode;
    });
  }

  Future<void> _completeSetup() async {
    final selectedMode = _selectedMode;
    final currentSettings = _currentSettings;
    if (_isSaving || selectedMode == null || currentSettings == null) {
      return;
    }

    setState(() => _isSaving = true);
    await _prayerSettingsService.save(
      currentSettings.copyWith(asarTimeMode: selectedMode),
    );

    if (!mounted) {
      return;
    }

    _finishSetupFlow(context, widget.flowArgs);
  }

  @override
  Widget build(BuildContext context) {
    final selectedMode = _selectedMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3EF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  const Text(
                    '2-Step Set Up',
                    style: TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SetupProgressIndicator(activeStep: 2),
                  const SizedBox(height: 56),
                  const _AsarSetupIllustration(),
                  const SizedBox(height: 34),
                  const Text(
                    'Set Asar Time',
                    style: TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'Shows Asar time and mosque suggestions based on your selection. You can change this later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _AsarOptionCard(
                    key: const Key('asar-option-early'),
                    label: 'Early Asar (Maliki, Shafi & Hanbali)',
                    description:
                        'Begins when the shadow of an object is equal to its length plus its original shadow (after Dhuhr)',
                    selected: selectedMode == AsarTimeMode.early,
                    onTap: () {
                      setState(() => _selectedMode = AsarTimeMode.early);
                    },
                  ),
                  const SizedBox(height: 10),
                  _AsarOptionCard(
                    key: const Key('asar-option-late'),
                    label: 'Late Asar (Hanafi)',
                    description:
                        'Begins when the shadow of an object is twice its length plus its original shadow (after Dhuhr)',
                    selected: selectedMode == AsarTimeMode.late,
                    onTap: () {
                      setState(() => _selectedMode = AsarTimeMode.late);
                    },
                  ),
                  const SizedBox(height: 54),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('location-setup-asar-continue'),
                      onPressed: _isSaving || selectedMode == null
                          ? null
                          : _completeSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA7ABA6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFC7CAC5),
                        disabledForegroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isSaving ? 'Saving...' : 'Continue',
                        style: const TextStyle(
                          fontFamily: AppTypography.figtreeFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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

void _finishSetupFlow(BuildContext context, LocationSetupFlowArgs flowArgs) {
  final navigator = Navigator.of(context);
  if (flowArgs.clearStackOnComplete) {
    navigator.pushNamedAndRemoveUntil(flowArgs.nextRoute, (_) => false);
    return;
  }

  navigator.pushReplacementNamed(flowArgs.nextRoute);
}

class _SetupTopBar extends StatelessWidget {
  const _SetupTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onBack,
        padding: EdgeInsets.zero,
        splashRadius: 22,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 28,
          color: Color(0xFF30403A),
        ),
      ),
    );
  }
}

class _SetupProgressIndicator extends StatelessWidget {
  const _SetupProgressIndicator({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    final rightColor =
        activeStep >= 2 ? const Color(0xFFB7C9BF) : const Color(0xFF586C65);

    return Center(
      child: SizedBox(
        width: 220,
        child: Row(
          children: [
            const Expanded(
              child: _ProgressSegment(color: Color(0xFF586C65)),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: _ProgressSegment(color: rightColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}

enum _SetupMessageTone { error, info }

class _SetupMessageCard extends StatelessWidget {
  const _SetupMessageCard({
    super.key,
    required this.message,
    required this.tone,
  });

  final String message;
  final _SetupMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final isError = tone == _SetupMessageTone.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFCEDE8) : const Color(0xFFE8EFEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError ? const Color(0xFFE2B2A4) : const Color(0xFFD2DDD6),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: 13,
          height: 1.35,
          color: isError ? const Color(0xFF8A4D3F) : const Color(0xFF496357),
        ),
      ),
    );
  }
}

class _SetupPrimaryButton extends StatelessWidget {
  const _SetupPrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: const Color(0xFF4E6E5B),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SetupLoadingButton extends StatelessWidget {
  const _SetupLoadingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('location-setup-loading'),
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFA7ABA6),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

class _LocationSetupIllustration extends StatelessWidget {
  const _LocationSetupIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFC8D6CD),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: List.generate(
                  4,
                  (row) => Expanded(
                    child: Row(
                      children: List.generate(
                        5,
                        (column) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF536763),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
          Positioned(
            top: 58,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF536763),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AsarSetupIllustration extends StatelessWidget {
  const _AsarSetupIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 10,
            top: 2,
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFB8CBC2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 4,
            child: Container(
              width: 82,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF536763),
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
          Positioned(
            left: 30,
            bottom: 34,
            child: Container(
              width: 46,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF536763),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AsarOptionCard extends StatelessWidget {
  const _AsarOptionCard({
    super.key,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8EEE9) : const Color(0xFFDDE1DC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: const Color(0xFF4E6058),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: 12.5,
                        height: 1.28,
                        color: Color(0xFF5E6661),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSearchField extends StatelessWidget {
  const _LocationSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search city or neighborhood',
        hintStyle: const TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: 15,
          color: Color(0xFF809085),
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFF607063),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9DCD3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF466A57), width: 1.4),
        ),
      ),
      style: const TextStyle(
        fontFamily: AppTypography.figtreeFamily,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.primaryText,
      ),
    );
  }
}

class _LocationSuggestionTile extends StatelessWidget {
  const _LocationSuggestionTile({
    super.key,
    required this.suggestion,
    required this.selected,
    required this.onTap,
  });

  final LocationSuggestion suggestion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = suggestion.primaryText ?? suggestion.label;
    final subtitle =
        suggestion.secondaryText ?? 'Use this as your nearby discovery area.';

    return Material(
      color: selected ? const Color(0xFFF2F6F0) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF466A57)
                      : const Color(0xFFF0F2EB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: selected ? Colors.white : const Color(0xFF4B5A51),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: 13,
                        color: AppColors.secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? const Color(0xFF466A57)
                    : const Color(0xFF8A958E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
