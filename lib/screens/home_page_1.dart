import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_provider.dart';
import '../data/mosque_content_refresh_provider.dart';
import '../data/mosque_provider.dart';
import '../features/business_registration/business_registration_flow_controller.dart';
import '../features/business_registration/business_registration_models.dart';
import '../models/discovery_event.dart';
import '../models/mosque_content.dart';
import '../models/mosque_model.dart';
import '../models/notification_enabled_mosque.dart';
import '../models/prayer_timings.dart';
import '../navigation/mosque_detail_route_args.dart';
import '../navigation/app_routes.dart';
import '../services/location_preferences_service.dart';
import '../services/mosque_service.dart';
import '../services/onboarding_preferences_service.dart';
import '../services/outbound_action_service.dart';
import '../services/prayer_settings_service.dart';
import '../services/user_prayer_timings_service.dart';
import 'event_detail_screen.dart';
import 'location_setup_screen.dart';
import '../widgets/mosque_image_frame.dart';
import '../widgets/common/figma_filter_chip.dart';
import '../widgets/common/figma_outline_action_button.dart';
import '../widgets/common/figma_section_heading.dart';
import '../widgets/common/figma_status_chip.dart';
import '../widgets/common/main_bottom_nav_bar.dart';

class HomePage1 extends ConsumerStatefulWidget {
  const HomePage1({
    super.key,
    this.mosqueService,
    this.locationPreferencesService,
    this.prayerSettingsService,
    this.userPrayerTimingsService,
    this.nowProvider,
    this.outboundActionService = const OutboundActionService(),
  });

  final MosqueService? mosqueService;
  final LocationPreferencesService? locationPreferencesService;
  final PrayerSettingsService? prayerSettingsService;
  final UserPrayerTimingsService? userPrayerTimingsService;
  final DateTime Function()? nowProvider;
  final OutboundActionService outboundActionService;

  @override
  ConsumerState<HomePage1> createState() => _HomePage1State();
}

class _HomePage1State extends ConsumerState<HomePage1> {
  static const _mosqueFilters = <String>[
    'Juma Prayers',
    'Women-Friendly',
    'Open 24/7',
  ];

  static const _eventFilters = <String>[
    'Newly Added',
    'This Weekend',
    'Free',
    'Community',
  ];

  var _selectedMosqueFilter = _mosqueFilters.first;
  var _selectedEventFilter = _eventFilters.first;
  var _dayIndex = 0;
  late final MosqueService _mosqueService;
  late final LocationPreferencesService _locationPreferencesService;
  late final PrayerSettingsService _prayerSettingsService;
  late final UserPrayerTimingsService _userPrayerTimingsService;
  String _currentLocation = LocationPreferencesService.unsetLocationLabel;
  SavedUserLocation? _savedLocation;
  String? _featuredContentMosqueId;
  List<_EventCardData>? _featuredEventCards;
  bool _isLoadingFeaturedContent = false;
  String? _selectedMosquePrayerRequestKey;
  PrayerTimings? _selectedMosquePrayerTimings;
  String? _locationPrayerRequestKey;
  PrayerTimings? _locationPrayerTimings;
  PrayerSettings? _prayerSettings;
  int _lastHandledContentRefreshTick = 0;
  String? _notificationMosquesRequestToken;
  List<NotificationEnabledMosque>? _notificationEnabledMosques;
  bool _isLoadingNotificationMosques = false;
  bool _notificationMosquesLoadFailed = false;
  final Set<String> _selectedMosquePrayerLoadingKeys = <String>{};
  final Set<String> _locationPrayerLoadingKeys = <String>{};
  int _selectedMosquePrayerRequestVersion = 0;
  int _locationPrayerRequestVersion = 0;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _mosqueService = widget.mosqueService ?? MosqueService();
    _locationPreferencesService =
        widget.locationPreferencesService ?? LocationPreferencesService();
    _prayerSettingsService =
        widget.prayerSettingsService ?? PrayerSettingsService();
    _userPrayerTimingsService =
        widget.userPrayerTimingsService ?? UserPrayerTimingsService();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    Future.microtask(_loadPrayerSettings);
    Future.microtask(_loadCurrentLocation);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    final savedLocation = await _locationPreferencesService.loadSavedLocation();
    if (!mounted) {
      return;
    }

    setState(() {
      _savedLocation = savedLocation;
      _currentLocation =
          savedLocation?.label ?? LocationPreferencesService.unsetLocationLabel;
    });

    if (savedLocation?.hasCoordinates == true) {
      await _loadNearbyMosques(savedLocation!);
    }
  }

  Future<void> _loadPrayerSettings() async {
    final prayerSettings = await _prayerSettingsService.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _prayerSettings = prayerSettings;
    });
  }

  Future<void> _loadNearbyMosques(SavedUserLocation savedLocation) async {
    try {
      await ref.read(mosqueProvider.notifier).loadNearby(
            latitude: savedLocation.latitude!,
            longitude: savedLocation.longitude!,
            radiusKm: 10,
          );
    } catch (_) {
      // Home keeps rendering its conservative shell even if nearby data fails.
    }
  }

  Future<void> _loadFeaturedEventsFor(MosqueModel mosque) async {
    if (_isLoadingFeaturedContent || _featuredContentMosqueId == mosque.id) {
      return;
    }

    _isLoadingFeaturedContent = true;
    try {
      List<_EventCardData>? nextCards;
      try {
        final content = await _mosqueService.getMosqueContent(mosque.id);
        nextCards = _mapHomeEventCards(mosque, content);
      } catch (_) {
        nextCards = null;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _featuredContentMosqueId = mosque.id;
        _featuredEventCards = nextCards;
      });
    } finally {
      _isLoadingFeaturedContent = false;
    }
  }

  Future<void> _loadSelectedMosquePrayerTimingsFor(MosqueModel mosque) async {
    final requestedDate = _requestedPrayerDateIso();
    final requestKey = '${mosque.id}:$requestedDate';
    if (_selectedMosquePrayerLoadingKeys.contains(requestKey) ||
        _selectedMosquePrayerRequestKey == requestKey) {
      return;
    }

    _selectedMosquePrayerLoadingKeys.add(requestKey);
    final requestVersion = ++_selectedMosquePrayerRequestVersion;
    try {
      PrayerTimings? nextPrayerTimings;
      try {
        nextPrayerTimings = await _mosqueService.getPrayerTimings(
          mosqueId: mosque.id,
          date: requestedDate,
        );
      } catch (_) {
        nextPrayerTimings = null;
      }

      if (!mounted) {
        return;
      }

      if (requestVersion == _selectedMosquePrayerRequestVersion) {
        setState(() {
          _selectedMosquePrayerRequestKey = requestKey;
          _selectedMosquePrayerTimings = nextPrayerTimings;
        });
      }
    } finally {
      _selectedMosquePrayerLoadingKeys.remove(requestKey);
    }
  }

  Future<void> _loadLocationPrayerTimings({
    required SavedUserLocation location,
    required PrayerSettings prayerSettings,
    required String requestedDate,
  }) async {
    final latitude = location.latitude;
    final longitude = location.longitude;
    if (latitude == null || longitude == null) {
      return;
    }

    final school = prayerSettings.asarTimeMode == AsarTimeMode.late
        ? 'hanafi'
        : 'standard';
    final requestKey = '$requestedDate:$latitude:$longitude:$school';
    if (_locationPrayerLoadingKeys.contains(requestKey) ||
        _locationPrayerRequestKey == requestKey) {
      return;
    }

    _locationPrayerLoadingKeys.add(requestKey);
    final requestVersion = ++_locationPrayerRequestVersion;
    try {
      PrayerTimings? nextPrayerTimings;
      try {
        nextPrayerTimings = await _userPrayerTimingsService.getDailyTimings(
          date: requestedDate,
          latitude: latitude,
          longitude: longitude,
          school: school,
        );
      } catch (_) {
        nextPrayerTimings = null;
      }

      if (!mounted) {
        return;
      }

      if (requestVersion == _locationPrayerRequestVersion) {
        setState(() {
          _locationPrayerRequestKey = requestKey;
          _locationPrayerTimings = nextPrayerTimings;
        });
      }
    } finally {
      _locationPrayerLoadingKeys.remove(requestKey);
    }
  }

  Future<void> _loadNotificationEnabledMosques(String bearerToken) async {
    if (_isLoadingNotificationMosques ||
        _notificationMosquesRequestToken == bearerToken) {
      return;
    }

    setState(() {
      _notificationMosquesRequestToken = bearerToken;
      _isLoadingNotificationMosques = true;
      _notificationMosquesLoadFailed = false;
    });

    try {
      final mosques = await _mosqueService.getNotificationEnabledMosques(
        bearerToken: bearerToken,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _notificationEnabledMosques = mosques;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _notificationEnabledMosques = null;
        _notificationMosquesLoadFailed = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingNotificationMosques = false;
        });
      }
    }
  }

  void _refreshFeaturedEventsFor(MosqueModel mosque) {
    if (_isLoadingFeaturedContent) {
      return;
    }

    setState(() {
      _featuredContentMosqueId = null;
    });
    _loadFeaturedEventsFor(mosque);
  }

  Future<void> _openMosqueDetail(MosqueModel mosque) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.mosqueDetail,
      arguments: MosqueDetailRouteArgs.fromMosque(mosque),
    );
  }

  Future<void> _openLoginEntry() async {
    await OnboardingPreferencesService().markAuthEntryPreferred();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.login);
  }

  Future<void> _openBusinessRegistrationEntry() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.businessRegistrationIntro,
      arguments: const BusinessRegistrationFlowRouteArgs(
        exitRouteName: AppRoutes.home,
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).pushNamed(AppRoutes.notifications);
  }

  void _shiftDay(int delta) {
    setState(() {
      _dayIndex += delta;
    });
  }

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  String _requestedPrayerDateIso() {
    return _isoDateFor(_now().add(Duration(days: _dayIndex)));
  }

  Future<void> _openMenu() async {
    Navigator.of(context).pushNamed(AppRoutes.profileSettings);
  }

  Future<void> _openLocation() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.locationSetup,
      arguments: const LocationSetupFlowArgs(
        nextRoute: AppRoutes.home,
        clearStackOnComplete: true,
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadCurrentLocation();
  }

  Future<void> _openDirectionsForMosque(MosqueModel mosque) async {
    final address = [
      mosque.addressLine.trim(),
      mosque.city.trim(),
      mosque.state.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    final result = await widget.outboundActionService.launchDirections(
      address: address,
      latitude: mosque.latitude,
      longitude: mosque.longitude,
      successMessage: 'Opening mosque directions...',
      fallbackMessage:
          'Could not open maps. Mosque address copied to clipboard.',
      unavailableMessage: 'This mosque does not have a mappable address yet.',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _openFeaturedEvent(_EventCardData event) async {
    final detailArgs = event.detailArgs;
    if (detailArgs == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRoutes.eventDetail,
      arguments: detailArgs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentRefreshTick = ref.watch(mosqueContentRefreshTickProvider);
    final nearbyState = ref.watch(mosqueProvider);
    final authSession = ref.watch(authProvider).valueOrNull;
    final businessRegistrationState =
        ref.watch(businessRegistrationFlowControllerProvider);
    final currentTime = _now();
    final hasPreciseLocation = _savedLocation?.hasCoordinates == true;
    final nearbyMosques = nearbyState.valueOrNull ?? const <MosqueModel>[];
    final featuredMosque = hasPreciseLocation && nearbyMosques.isNotEmpty
        ? nearbyMosques.first
        : null;
    final hasNearbyFeaturedMosque = featuredMosque != null;
    final selectedPrayerMosque = hasPreciseLocation
        ? _selectNearestFollowedMosque(
            nearbyMosques: nearbyMosques,
            notificationEnabledMosques: _notificationEnabledMosques,
          )
        : null;
    final requestedPrayerDate =
        _isoDateFor(currentTime.add(Duration(days: _dayIndex)));
    final mosquePrayerRequestKey = selectedPrayerMosque == null
        ? null
        : '${selectedPrayerMosque.id}:$requestedPrayerDate';
    final selectedMosquePrayerTimings =
        _selectedMosquePrayerRequestKey == mosquePrayerRequestKey
            ? _selectedMosquePrayerTimings
            : null;
    final locationPrayerRequestKey = _savedLocation?.hasCoordinates == true &&
            _savedLocation?.latitude != null &&
            _savedLocation?.longitude != null &&
            _prayerSettings != null
        ? '$requestedPrayerDate:${_savedLocation!.latitude}:${_savedLocation!.longitude}:${_prayerSettings!.asarTimeMode == AsarTimeMode.late ? 'hanafi' : 'standard'}'
        : null;
    final locationPrayerTimings =
        _locationPrayerRequestKey == locationPrayerRequestKey
            ? _locationPrayerTimings
            : null;
    final mosquePrayerTimingsUsable =
        _canUsePrayerTimings(selectedMosquePrayerTimings);
    final prayerCardMosque =
        mosquePrayerTimingsUsable ? selectedPrayerMosque : null;
    final prayerCardTimings = mosquePrayerTimingsUsable
        ? selectedMosquePrayerTimings
        : locationPrayerTimings;
    final isLoadingLocationPrayerTimings = locationPrayerRequestKey != null &&
        _locationPrayerRequestKey != locationPrayerRequestKey &&
        _locationPrayerLoadingKeys.contains(locationPrayerRequestKey);
    final featuredEventsReady =
        featuredMosque != null && _featuredContentMosqueId == featuredMosque.id;
    final liveEventCards = featuredEventsReady
        ? (_featuredEventCards ?? const <_EventCardData>[])
        : const <_EventCardData>[];
    final accessToken = authSession?.accessToken;

    if (accessToken != null &&
        accessToken.isNotEmpty &&
        _notificationMosquesRequestToken != accessToken &&
        !_isLoadingNotificationMosques) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadNotificationEnabledMosques(accessToken);
        }
      });
    }

    final othersStateCard = _buildOthersStateCard(
      authSession: authSession,
      mosques: _notificationEnabledMosques,
      isLoading: _isLoadingNotificationMosques,
      loadFailed: _notificationMosquesLoadFailed,
    );
    final utilityCard = _buildUtilityCard(
      authSession: authSession,
      businessRegistrationState: businessRegistrationState,
    );

    if (contentRefreshTick != _lastHandledContentRefreshTick) {
      _lastHandledContentRefreshTick = contentRefreshTick;
      final refreshedMosque = featuredMosque;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && refreshedMosque != null) {
          _refreshFeaturedEventsFor(refreshedMosque);
        }
      });
    }

    if (featuredMosque != null &&
        _featuredContentMosqueId != featuredMosque.id &&
        !_isLoadingFeaturedContent) {
      final contentMosque = featuredMosque;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadFeaturedEventsFor(contentMosque);
        }
      });
    }

    if (locationPrayerRequestKey != null &&
        _locationPrayerRequestKey != locationPrayerRequestKey &&
        !_locationPrayerLoadingKeys.contains(locationPrayerRequestKey) &&
        _savedLocation != null &&
        _prayerSettings != null) {
      final savedLocation = _savedLocation!;
      final prayerSettings = _prayerSettings!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadLocationPrayerTimings(
            location: savedLocation,
            prayerSettings: prayerSettings,
            requestedDate: requestedPrayerDate,
          );
        }
      });
    }

    if (selectedPrayerMosque != null &&
        mosquePrayerRequestKey != null &&
        _selectedMosquePrayerRequestKey != mosquePrayerRequestKey &&
        !_selectedMosquePrayerLoadingKeys.contains(mosquePrayerRequestKey)) {
      final prayerMosque = selectedPrayerMosque;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadSelectedMosquePrayerTimingsFor(prayerMosque);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      bottomNavigationBar: const MainBottomNavBar(activeTab: MainAppTab.home),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeTopBar(
              location: _currentLocation,
              onLocationTap: _openLocation,
              onMenuTap: _openMenu,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FigmaSectionHeading(title: 'PRAYER TIME'),
                        const SizedBox(height: 10),
                        _PrayerCard(
                          dayIndex: _dayIndex,
                          mosque: prayerCardMosque,
                          locationLabel: _currentLocation,
                          hasSavedCoordinates: hasPreciseLocation,
                          isLoadingPrayerTimings: hasPreciseLocation &&
                              isLoadingLocationPrayerTimings,
                          prayerTimings: prayerCardTimings,
                          requestedDateIso: requestedPrayerDate,
                          currentTime: currentTime,
                          onPreviousDay: () => _shiftDay(-1),
                          onNextDay: () => _shiftDay(1),
                          onManageTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.prayerSettings),
                        ),
                        const SizedBox(height: 22),
                        const FigmaSectionHeading(
                          title: 'DISCOVER MOSQUES NEAR YOU',
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _mosqueFilters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final label = _mosqueFilters[index];
                              return FigmaFilterChip(
                                label: label,
                                selected: label == _selectedMosqueFilter,
                                onTap: () {
                                  setState(() {
                                    _selectedMosqueFilter = label;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FeaturedMosqueCard(
                          mosque: featuredMosque,
                          locationLabel: _currentLocation,
                          hasSavedCoordinates: hasPreciseLocation,
                          isLoadingNearbyMosques:
                              hasPreciseLocation && nearbyState.isLoading,
                          onTap: featuredMosque == null
                              ? null
                              : () => _openMosqueDetail(featuredMosque),
                          onDirectionTap: featuredMosque == null
                              ? null
                              : () => _openDirectionsForMosque(featuredMosque),
                        ),
                        const SizedBox(height: 12),
                        FigmaOutlineActionButton(
                          label: 'View more nearby mosques',
                          onPressed: () => Navigator.of(context)
                              .pushNamed(AppRoutes.mosquesAndEvents),
                        ),
                        const SizedBox(height: 24),
                        const FigmaSectionHeading(title: 'EVENTS AROUND YOU'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _eventFilters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final label = _eventFilters[index];
                              return FigmaFilterChip(
                                label: label,
                                selected: label == _selectedEventFilter,
                                onTap: () {
                                  setState(() {
                                    _selectedEventFilter = label;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!hasPreciseLocation)
                          const _HomeEventRailEmptyState(
                            message:
                                'Save a location to load nearby published events.',
                          )
                        else if (featuredMosque == null)
                          Text(
                            'No nearby mosques are available for this location yet.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: const Color(0xFF66746B)),
                          )
                        else if (!featuredEventsReady &&
                            _isLoadingFeaturedContent)
                          Text(
                            'Loading published events...',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: const Color(0xFF66746B)),
                          )
                        else if (liveEventCards.isEmpty)
                          const _HomeEventRailEmptyState(
                            message:
                                'No nearby mosques have published public events yet.',
                          )
                        else
                          SizedBox(
                            height: 246,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: liveEventCards.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final event = liveEventCards[index];
                                return _EventCard(
                                  event: event,
                                  onTap: event.detailArgs == null
                                      ? null
                                      : () => _openFeaturedEvent(event),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 22),
                        const FigmaSectionHeading(title: 'OTHERS'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _PromoCard(
                                label: 'Explore\nMuslim-Owned\nBusinesses',
                                onTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.services),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PromoCard(
                                label: othersStateCard.title,
                                supportingText: othersStateCard.subtitle,
                                footerLabel: othersStateCard.footerLabel,
                                onTap: othersStateCard.onTap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _SupportCard(
                          label: utilityCard.label,
                          onTap: utilityCard.onTap,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _HomePromoCardState _buildOthersStateCard({
    required AuthSession? authSession,
    required List<NotificationEnabledMosque>? mosques,
    required bool isLoading,
    required bool loadFailed,
  }) {
    if (authSession == null) {
      return _HomePromoCardState(
        title: 'Follow mosques\nyou trust',
        subtitle: 'Log in to save mosques and manage prayer alerts.',
        footerLabel: 'Log in',
        onTap: _openLoginEntry,
      );
    }

    if (isLoading && mosques == null) {
      return _HomePromoCardState(
        title: 'Loading your\nfollowed mosques',
        subtitle: 'Checking the mosques where alerts are enabled.',
        footerLabel: 'Open notifications',
        onTap: _openNotifications,
      );
    }

    if (mosques != null && mosques.isNotEmpty) {
      final firstMosque = mosques.first.name.trim();
      final subtitle = mosques.length == 1
          ? firstMosque
          : '$firstMosque + ${mosques.length - 1} more';
      final countLabel =
          mosques.length == 1 ? '1 mosque' : '${mosques.length} mosques';
      return _HomePromoCardState(
        title: 'Following\n$countLabel',
        subtitle: subtitle,
        footerLabel: 'Manage alerts',
        onTap: _openNotifications,
      );
    }

    if (loadFailed) {
      return _HomePromoCardState(
        title: 'Your mosque\nalerts',
        subtitle: 'Open notifications to review followed mosques and settings.',
        footerLabel: 'Open notifications',
        onTap: _openNotifications,
      );
    }

    return _HomePromoCardState(
      title: 'No mosques\nfollowed yet',
      subtitle: 'Turn on alerts from a mosque page to see them here.',
      footerLabel: 'Browse mosques',
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.mosquesAndEvents),
    );
  }

  _HomeUtilityCardState _buildUtilityCard({
    required AuthSession? authSession,
    required AsyncValue<BusinessRegistrationFlowState>
        businessRegistrationState,
  }) {
    if (authSession?.user.role == 'admin') {
      return _HomeUtilityCardState(
        label: 'Manage owned mosques and publish updates',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.ownedMosques),
      );
    }

    if (authSession == null) {
      return _HomeUtilityCardState(
        label: 'List your business and reach nearby members',
        onTap: _openBusinessRegistrationEntry,
      );
    }

    return businessRegistrationState.when(
      data: (value) {
        final draft = value.draft;
        switch (draft.status) {
          case BusinessRegistrationSubmissionStatus.live:
            return _HomeUtilityCardState(
              label: 'Your business is live. Open listing status',
              onTap: _openBusinessRegistrationEntry,
            );
          case BusinessRegistrationSubmissionStatus.rejected:
            return _HomeUtilityCardState(
              label: 'Your business listing needs updates before approval',
              onTap: _openBusinessRegistrationEntry,
            );
          case BusinessRegistrationSubmissionStatus.underReview:
            return _HomeUtilityCardState(
              label: 'Your business listing is under review',
              onTap: _openBusinessRegistrationEntry,
            );
          case BusinessRegistrationSubmissionStatus.draft:
            if (draft.hasAnySavedInput) {
              return _HomeUtilityCardState(
                label: 'Resume your business listing draft',
                onTap: _openBusinessRegistrationEntry,
              );
            }
            return _HomeUtilityCardState(
              label: 'Register your business and get discovered',
              onTap: _openBusinessRegistrationEntry,
            );
        }
      },
      loading: () => _HomeUtilityCardState(
        label: 'Checking your business listing tools',
        onTap: _openBusinessRegistrationEntry,
      ),
      error: (_, __) => _HomeUtilityCardState(
        label: 'Open business listing tools',
        onTap: _openBusinessRegistrationEntry,
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.location,
    required this.onLocationTap,
    required this.onMenuTap,
  });

  final String location;
  final VoidCallback onLocationTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F3EE),
        border: Border(
          bottom: BorderSide(color: Color(0xFFDBDED6)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              key: const Key('home-location-button'),
              onPressed: onLocationTap,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5F6D63),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                shape: const RoundedRectangleBorder(),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 14,
                    color: Color(0xFF6B796F),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5F6D63),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onMenuTap,
            splashRadius: 20,
            icon: const Icon(
              Icons.menu,
              size: 22,
              color: Color(0xFF56655B),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
    required this.dayIndex,
    required this.locationLabel,
    required this.hasSavedCoordinates,
    required this.isLoadingPrayerTimings,
    required this.mosque,
    required this.prayerTimings,
    required this.requestedDateIso,
    required this.currentTime,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onManageTap,
  });

  final int dayIndex;
  final String locationLabel;
  final bool hasSavedCoordinates;
  final bool isLoadingPrayerTimings;
  final MosqueModel? mosque;
  final PrayerTimings? prayerTimings;
  final String requestedDateIso;
  final DateTime currentTime;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    final cardContent = _buildPrayerCardContent(
      mosque: mosque,
      locationLabel: locationLabel,
      hasSavedCoordinates: hasSavedCoordinates,
      isLoadingPrayerTimings: isLoadingPrayerTimings,
      prayerTimings: prayerTimings,
      requestedDateIso: requestedDateIso,
      dayIndex: dayIndex,
      currentTime: currentTime,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD7E2D3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              children: [
                Text(
                  cardContent.dayLabel,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3027),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _MiniIconButton(
                      icon: Icons.chevron_left,
                      onTap: onPreviousDay,
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          cardContent.dateLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF304137),
                          ),
                        ),
                      ),
                    ),
                    _MiniIconButton(
                      icon: Icons.chevron_right,
                      onTap: onNextDay,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  cardContent.mosqueLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF506257),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 114,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFDACB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      const Positioned(
                        right: 12,
                        top: 14,
                        child: _CloudLines(widths: [64, 38, 58]),
                      ),
                      const Positioned(
                        right: 18,
                        bottom: 18,
                        child: _CloudLines(widths: [56, 34]),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cardContent.eyebrowLabel,
                                    style: const TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 8,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF667669),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    cardContent.title,
                                    style: const TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 23,
                                      height: 1,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1F3027),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cardContent.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF24332A),
                                    ),
                                  ),
                                ],
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: FigmaStatusChip(
                                  icon: Icons.hourglass_bottom_rounded,
                                  label: cardContent.statusLabel,
                                  background: const Color(0xFF6E7C71),
                                  foreground: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _PrayerTimeline(items: cardContent.timelineItems),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextButton(
              onPressed: onManageTap,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF506257),
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size.fromHeight(22),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Manage prayer notifications & more',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF506257),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF506257),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: Color(0xFF506257),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudLines extends StatelessWidget {
  const _CloudLines({required this.widths});

  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: widths
          .map(
            (width) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Container(
                width: width,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

const _prayerTimelineOrder = <String>[
  'fajr',
  'dhuhr',
  'asr',
  'maghrib',
  'isha',
];

_PrayerCardContent _buildPrayerCardContent({
  required MosqueModel? mosque,
  required String locationLabel,
  required bool hasSavedCoordinates,
  required bool isLoadingPrayerTimings,
  required PrayerTimings? prayerTimings,
  required String requestedDateIso,
  required int dayIndex,
  required DateTime currentTime,
}) {
  final resolvedDate = prayerTimings?.date.isNotEmpty == true
      ? prayerTimings!.date
      : requestedDateIso;
  final dayLabel = _relativeDayLabel(dayIndex);
  if (mosque == null) {
    final savedLabel = locationLabel.trim();
    final hasSavedLabel = savedLabel.isNotEmpty &&
        savedLabel != LocationPreferencesService.unsetLocationLabel;
    if (!hasSavedCoordinates) {
      return _PrayerCardContent(
        dayLabel: dayLabel,
        dateLabel: _formatPrayerDate(resolvedDate),
        mosqueLabel: hasSavedLabel
            ? 'Saved location: $savedLabel'
            : 'No saved location yet',
        eyebrowLabel: 'LOCATION',
        title: hasSavedLabel ? 'Label Saved' : 'Set Location',
        subtitle: hasSavedLabel
            ? 'We need confirmed coordinates before loading nearby mosque prayer times.'
            : 'Save your location to load nearby mosque prayer times.',
        statusLabel: hasSavedLabel ? 'Coordinates needed' : 'Location needed',
        timelineItems: _buildPrayerTimelineItems(
          prayerTimings: null,
          isCurrentDate: true,
          currentTime: currentTime,
        ),
      );
    }

    return _buildResolvedPrayerCardContent(
      dayLabel: dayLabel,
      requestedDateIso: requestedDateIso,
      sourceLabel: hasSavedLabel
          ? 'Prayer times for $savedLabel'
          : 'Prayer times for your location',
      prayerTimings: prayerTimings,
      currentTime: currentTime,
      isLoadingPrayerTimings: isLoadingPrayerTimings,
      loadingEyebrowLabel: 'LOCATION',
      loadingSubtitle: 'Loading prayer times for your location.',
      unavailableFallbackSubtitle:
          'Location prayer times are unavailable right now.',
      unavailableStatusLabel: 'Location unavailable',
    );
  }

  return _buildResolvedPrayerCardContent(
    dayLabel: dayLabel,
    requestedDateIso: requestedDateIso,
    sourceLabel: 'Prayer times from ${mosque.name}',
    prayerTimings: prayerTimings,
    currentTime: currentTime,
    isLoadingPrayerTimings: false,
    loadingEyebrowLabel: 'MOSQUE',
    loadingSubtitle: 'Loading prayer times from ${mosque.name}.',
    unavailableFallbackSubtitle:
        'Mosque prayer times are unavailable right now.',
    unavailableStatusLabel: 'Mosque unavailable',
  );
}

_PrayerCardContent _buildResolvedPrayerCardContent({
  required String dayLabel,
  required String requestedDateIso,
  required String sourceLabel,
  required PrayerTimings? prayerTimings,
  required DateTime currentTime,
  required bool isLoadingPrayerTimings,
  required String loadingEyebrowLabel,
  required String loadingSubtitle,
  required String unavailableFallbackSubtitle,
  required String unavailableStatusLabel,
}) {
  final resolvedDate = prayerTimings?.date.isNotEmpty == true
      ? prayerTimings!.date
      : requestedDateIso;
  final isCurrentDate = resolvedDate == _isoDateFor(currentTime);
  final livePrayerWindow =
      isCurrentDate ? prayerTimings?.currentPrayerWindowAt(currentTime) : null;
  final timelineItems = _buildPrayerTimelineItems(
    prayerTimings: prayerTimings,
    isCurrentDate: isCurrentDate,
    currentTime: currentTime,
  );

  if (prayerTimings == null) {
    return _PrayerCardContent(
      dayLabel: dayLabel,
      dateLabel: _formatPrayerDate(resolvedDate),
      mosqueLabel: sourceLabel,
      eyebrowLabel: loadingEyebrowLabel,
      title: isLoadingPrayerTimings ? 'Prayer Times' : 'Unavailable',
      subtitle: isLoadingPrayerTimings
          ? loadingSubtitle
          : unavailableFallbackSubtitle,
      statusLabel:
          isLoadingPrayerTimings ? 'Loading timings' : unavailableStatusLabel,
      timelineItems: timelineItems,
    );
  }

  if (!prayerTimings.isConfigured) {
    return _PrayerCardContent(
      dayLabel: dayLabel,
      dateLabel: _formatPrayerDate(resolvedDate),
      mosqueLabel: sourceLabel,
      eyebrowLabel: 'NOTICE',
      title: 'Unavailable',
      subtitle: prayerTimings.unavailableReason ?? unavailableFallbackSubtitle,
      statusLabel: unavailableStatusLabel,
      timelineItems: timelineItems,
    );
  }

  if (!prayerTimings.isAvailable) {
    return _PrayerCardContent(
      dayLabel: dayLabel,
      dateLabel: _formatPrayerDate(resolvedDate),
      mosqueLabel: sourceLabel,
      eyebrowLabel: 'NOTICE',
      title: 'Unavailable',
      subtitle: prayerTimings.unavailableReason ?? unavailableFallbackSubtitle,
      statusLabel: unavailableStatusLabel,
      timelineItems: timelineItems,
    );
  }

  if (!isCurrentDate) {
    return _PrayerCardContent(
      dayLabel: dayLabel,
      dateLabel: _formatPrayerDate(resolvedDate),
      mosqueLabel: sourceLabel,
      eyebrowLabel: 'SCHEDULE',
      title: 'Prayer Times',
      subtitle:
          'Fajr ${prayerTimings.timeFor('fajr')} • Isha ${prayerTimings.timeFor('isha')}',
      statusLabel: _prayerSourceLabel(prayerTimings),
      timelineItems: timelineItems,
    );
  }

  if (livePrayerWindow != null) {
    final activePrayerLabel = _prayerShortLabel(livePrayerWindow.prayerKey);
    final activePrayerSubtitle = livePrayerWindow.endTime != null
        ? 'Until ${prayerTimings.timeFor(_nextPrayerKey(livePrayerWindow.prayerKey) ?? '')}'
        : 'Final listed prayer window for today.';
    return _PrayerCardContent(
      dayLabel: dayLabel,
      dateLabel: _formatPrayerDate(resolvedDate),
      mosqueLabel: sourceLabel,
      eyebrowLabel: 'LIVE NOW',
      title: activePrayerLabel,
      subtitle: activePrayerSubtitle,
      statusLabel: _prayerSourceLabel(prayerTimings),
      timelineItems: timelineItems,
    );
  }

  if (prayerTimings.nextPrayer.isNotEmpty &&
      prayerTimings.nextPrayerTime.isNotEmpty) {
    return _PrayerCardContent(
      dayLabel: dayLabel,
      dateLabel: _formatPrayerDate(resolvedDate),
      mosqueLabel: sourceLabel,
      eyebrowLabel: 'UP NEXT',
      title: prayerTimings.nextPrayer,
      subtitle: 'Starts at ${prayerTimings.nextPrayerTime}',
      statusLabel: _prayerSourceLabel(prayerTimings),
      timelineItems: timelineItems,
    );
  }

  return _PrayerCardContent(
    dayLabel: dayLabel,
    dateLabel: _formatPrayerDate(resolvedDate),
    mosqueLabel: sourceLabel,
    eyebrowLabel: 'TODAY',
    title: 'Prayer Times',
    subtitle: 'Final prayer listed below for this day.',
    statusLabel: _prayerSourceLabel(prayerTimings),
    timelineItems: timelineItems,
  );
}

List<_PrayerTimelineItem> _buildPrayerTimelineItems({
  required PrayerTimings? prayerTimings,
  required bool isCurrentDate,
  required DateTime currentTime,
}) {
  final livePrayerWindow =
      isCurrentDate ? prayerTimings?.currentPrayerWindowAt(currentTime) : null;
  final activePrayerKey = livePrayerWindow?.prayerKey;
  final activePrayerIndex = activePrayerKey == null
      ? null
      : _prayerTimelineOrder.indexOf(activePrayerKey);

  return _prayerTimelineOrder.map((prayer) {
    final prayerTime = prayerTimings?.timeFor(prayer).trim() ?? '';
    final prayerIndex = _prayerTimelineOrder.indexOf(prayer);
    final isActive = activePrayerIndex != null &&
        activePrayerIndex >= 0 &&
        prayerIndex == activePrayerIndex;
    final isPassed = activePrayerIndex != null &&
        activePrayerIndex >= 0 &&
        prayerIndex < activePrayerIndex;
    final progressToNext = activePrayerIndex == null
        ? 0.0
        : prayerIndex < activePrayerIndex
            ? 1.0
            : prayerIndex == activePrayerIndex
                ? livePrayerWindow?.progress ?? 0.0
                : 0.0;

    return _PrayerTimelineItem(
      label: _prayerShortLabel(prayer),
      time: prayerTime.isNotEmpty ? prayerTime : '--',
      icon: _prayerIcon(prayer),
      active: isActive,
      passed: isPassed,
      progressToNext: progressToNext,
    );
  }).toList(growable: false);
}

String _prayerSourceLabel(PrayerTimings prayerTimings) {
  return switch (prayerTimings.source) {
    'cache' => 'Cached timings',
    'aladhan' => 'Live timings',
    _ => 'Backend timings',
  };
}

String _relativeDayLabel(int dayIndex) {
  return switch (dayIndex) {
    0 => 'TODAY',
    1 => 'TOMORROW',
    -1 => 'YESTERDAY',
    _ => 'SELECTED DAY',
  };
}

String _formatPrayerDate(String isoDate) {
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) {
    return isoDate;
  }

  const weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${weekdays[parsed.weekday - 1]} ${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
}

String _isoDateFor(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

bool _canUsePrayerTimings(PrayerTimings? prayerTimings) {
  return prayerTimings != null &&
      prayerTimings.isConfigured &&
      prayerTimings.isAvailable;
}

MosqueModel? _selectNearestFollowedMosque({
  required List<MosqueModel> nearbyMosques,
  required List<NotificationEnabledMosque>? notificationEnabledMosques,
}) {
  final followedMosqueIds = <String>{
    for (final mosque in nearbyMosques)
      if (mosque.isBookmarked) mosque.id,
    for (final mosque
        in notificationEnabledMosques ?? const <NotificationEnabledMosque>[])
      mosque.id,
  };
  if (followedMosqueIds.isEmpty) {
    return null;
  }

  final matchingMosques = nearbyMosques
      .where((mosque) => followedMosqueIds.contains(mosque.id))
      .toList(growable: false);
  if (matchingMosques.isEmpty) {
    return null;
  }

  final sortedMosques = matchingMosques.toList(growable: false)
    ..sort((left, right) => left.distanceMiles.compareTo(right.distanceMiles));
  return sortedMosques.first;
}

String? _nextPrayerKey(String prayer) {
  final prayerIndex = _prayerTimelineOrder.indexOf(prayer);
  if (prayerIndex < 0 || prayerIndex >= _prayerTimelineOrder.length - 1) {
    return null;
  }

  return _prayerTimelineOrder[prayerIndex + 1];
}

String _prayerShortLabel(String prayer) {
  return switch (prayer) {
    'fajr' => 'Fajr',
    'dhuhr' => 'Dhuhr',
    'asr' => 'Asr',
    'maghrib' => 'Maghrib',
    'isha' => 'Isha',
    _ => prayer,
  };
}

IconData _prayerIcon(String prayer) {
  return switch (prayer) {
    'fajr' => Icons.wb_twilight_outlined,
    'dhuhr' => Icons.wb_sunny_outlined,
    'asr' => Icons.sunny,
    'maghrib' => Icons.nightlight_round,
    'isha' => Icons.dark_mode_outlined,
    _ => Icons.schedule,
  };
}

class _PrayerCardContent {
  const _PrayerCardContent({
    required this.dayLabel,
    required this.dateLabel,
    required this.mosqueLabel,
    required this.eyebrowLabel,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.timelineItems,
  });

  final String dayLabel;
  final String dateLabel;
  final String mosqueLabel;
  final String eyebrowLabel;
  final String title;
  final String subtitle;
  final String statusLabel;
  final List<_PrayerTimelineItem> timelineItems;
}

class _PrayerTimeline extends StatelessWidget {
  const _PrayerTimeline({
    required this.items,
  });

  final List<_PrayerTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(items.length * 2 - 1, (index) {
            if (index.isOdd) {
              final previous = items[index ~/ 2];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CAA9A),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        key: ValueKey(
                          'prayer-progress-fill-${previous.label.toLowerCase()}',
                        ),
                        widthFactor: previous.progressToNext,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF75836F),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            final item = items[index ~/ 2];
            return Container(
              key: ValueKey('prayer-timeline-dot-${item.label.toLowerCase()}'),
              width: item.active ? 10 : 8,
              height: item.active ? 10 : 8,
              decoration: BoxDecoration(
                color: item.active || item.passed
                    ? const Color(0xFF667564)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: item.active
                      ? const Color(0xFF667564)
                      : const Color(0xFF8A9686),
                  width: item.active ? 2.2 : 1.2,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (item) => Expanded(
                  child: Column(
                    children: [
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 8.5,
                          fontWeight:
                              item.active ? FontWeight.w700 : FontWeight.w500,
                          color: const Color(0xFF475148),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        item.icon,
                        size: 13,
                        color: const Color(0xFF667062),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.time,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 8.2,
                          fontWeight:
                              item.active ? FontWeight.w700 : FontWeight.w500,
                          color: const Color(0xFF667062),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _PrayerTimelineItem {
  const _PrayerTimelineItem({
    required this.label,
    required this.time,
    required this.icon,
    this.active = false,
    this.passed = false,
    this.progressToNext = 0,
  });

  final String label;
  final String time;
  final IconData icon;
  final bool active;
  final bool passed;
  final double progressToNext;
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        onPressed: onTap,
        splashRadius: 14,
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 18,
          color: const Color(0xFF44564D),
        ),
      ),
    );
  }
}

class _FeaturedMosqueCard extends StatelessWidget {
  const _FeaturedMosqueCard({
    required this.mosque,
    required this.locationLabel,
    required this.hasSavedCoordinates,
    required this.isLoadingNearbyMosques,
    required this.onTap,
    required this.onDirectionTap,
  });

  final MosqueModel? mosque;
  final String locationLabel;
  final bool hasSavedCoordinates;
  final bool isLoadingNearbyMosques;
  final VoidCallback? onTap;
  final VoidCallback? onDirectionTap;

  @override
  Widget build(BuildContext context) {
    if (mosque == null) {
      final savedLabel = locationLabel.trim();
      final hasSavedLabel = savedLabel.isNotEmpty &&
          savedLabel != LocationPreferencesService.unsetLocationLabel;
      final title = !hasSavedCoordinates
          ? (hasSavedLabel ? 'Coordinates still needed' : 'Set your location')
          : (isLoadingNearbyMosques
              ? 'Loading nearby mosques'
              : 'Nearby mosques unavailable');
      final subtitle = !hasSavedCoordinates
          ? (hasSavedLabel
              ? 'We saved $savedLabel, but nearby mosque reads need confirmed coordinates.'
              : 'Save a location to load nearby mosques honestly.')
          : (hasSavedLabel
              ? 'We are checking for mosques around $savedLabel.'
              : 'Nearby mosque data could not be loaded right now.');

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEAEFE9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC5CEC3)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF25342B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF58625A),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEAEFE9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC5CEC3)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            mosque!.name,
                            style: const TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF25342B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5E4B8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: Color(0xFFC4852A),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                mosque!.hasCommunityRating
                                    ? mosque!.rating.toStringAsFixed(1)
                                    : 'New',
                                style: const TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B5C2E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MosquePoster(imageUrl: mosque!.primaryImageUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 5,
                                      children: [
                                        _TinyInfoLabel(
                                          icon: Icons.location_on_outlined,
                                          label: mosque!.city,
                                        ),
                                        _TinyInfoLabel(
                                          icon: Icons.near_me_outlined,
                                          label:
                                              '${mosque!.distanceMiles.toStringAsFixed(1)} mi away',
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: IconButton(
                                      onPressed: onDirectionTap,
                                      splashRadius: 16,
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: Color(0xFF59655B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _AmenityBadge(
                                    label: mosque!.sect,
                                    icon: Icons.shield_outlined,
                                  ),
                                  const _AmenityBadge(
                                    label: 'Women Prayer',
                                    icon: Icons.person_outline,
                                  ),
                                  const _AmenityBadge(
                                    label: 'Wudu',
                                    icon: Icons.water_drop_outlined,
                                  ),
                                  const _AmenityBadge(
                                    label: 'Parking',
                                    icon: Icons.local_parking_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _PrayerTimeBanner(
                                time: mosque!.duhrTime,
                                onTap: onTap!,
                              ),
                              const SizedBox(height: 5),
                              const FigmaStatusChip(
                                icon: Icons.hourglass_top_rounded,
                                label: 'Starts in 8 mins',
                                background: Color(0xFF6E7C71),
                                foreground: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: -9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFC97865),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Text(
              'Closest To You',
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MosquePoster extends StatelessWidget {
  const _MosquePoster({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return MosqueImageFrame(
      width: 108,
      height: 126,
      aspectRatio: null,
      borderRadius: BorderRadius.circular(10),
      child: imageUrl.isEmpty
          ? const MosqueImagePlaceholder(iconSize: 30)
          : Image.network(
              key: const ValueKey('home-featured-mosque-image'),
              imageUrl,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.1),
              errorBuilder: (_, __, ___) =>
                  const MosqueImagePlaceholder(iconSize: 30),
            ),
    );
  }
}

class _TinyInfoLabel extends StatelessWidget {
  const _TinyInfoLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 11.5,
          color: const Color(0xFF58625A),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFF58625A),
          ),
        ),
      ],
    );
  }
}

class _AmenityBadge extends StatelessWidget {
  const _AmenityBadge({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD7DFD6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10.5,
            color: const Color(0xFF5E685F),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 8.2,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5A645B),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerTimeBanner extends StatelessWidget {
  const _PrayerTimeBanner({
    required this.time,
    required this.onTap,
  });

  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE2E8E0),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 12,
                color: Color(0xFF556056),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 9,
                      color: Color(0xFF3E483F),
                    ),
                    children: [
                      const TextSpan(text: 'Duhr Prayer at '),
                      TextSpan(
                        text: time,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onTap,
  });

  final _EventCardData event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Material(
        color: const Color(0xFFEDEFEA),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: _EventPoster(event: event),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: event.dateColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event.date,
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: Color(0xFF404A42),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 8.4,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        color: Color(0xFF7B847D),
                      ),
                    ),
                    if (event.category.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        event.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 8.2,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7B847D),
                        ),
                      ),
                    ],
                    if (event.price.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD1D6CD)),
                        ),
                        child: Text(
                          event.price,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5B665C),
                          ),
                        ),
                      ),
                    ],
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

class _HomeEventRailEmptyState extends StatelessWidget {
  const _HomeEventRailEmptyState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFEA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: const Color(0xFF66746B), height: 1.4),
      ),
    );
  }
}

class _EventPoster extends StatelessWidget {
  const _EventPoster({required this.event});

  final _EventCardData event;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: event.posterColors,
        ),
      ),
      child: switch (event.posterStyle) {
        _PosterStyle.seerah => const _SeerahPosterArtwork(),
        _PosterStyle.wellness => const _WellnessPosterArtwork(),
        _PosterStyle.charity => const _CharityPosterArtwork(),
        _PosterStyle.reflections => const _ReflectionsPosterArtwork(),
      },
    );
  }
}

class _SeerahPosterArtwork extends StatelessWidget {
  const _SeerahPosterArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 14,
          child: Column(
            children: [
              Text(
                'SEERAH',
                style: TextStyle(
                  fontFamily: 'Proza Libre',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.5,
                  color: Color(0xFF9A6D25),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'TRAIL',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: Color(0xFFB2853B),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 68,
          child: Transform.rotate(
            angle: -0.28,
            child: Container(
              height: 1.2,
              color: const Color(0xFFB88739),
            ),
          ),
        ),
        const Positioned(
          left: 26,
          right: 26,
          bottom: 18,
          child: Icon(
            Icons.auto_stories_outlined,
            size: 34,
            color: Color(0xFFD0A04E),
          ),
        ),
      ],
    );
  }
}

class _WellnessPosterArtwork extends StatelessWidget {
  const _WellnessPosterArtwork();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 10,
          top: 8,
          child: Text(
            'WHAT WOMEN\'S\nWELLNESS NEEDS',
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF2C954),
            ),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 24,
          child: _Blob(
            width: 46,
            height: 34,
            color: Color(0xFFFC6D5F),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 20,
          child: _Blob(
            width: 38,
            height: 42,
            color: Color(0xFF54B6A5),
          ),
        ),
        Positioned(
          right: 16,
          top: 38,
          child: Icon(
            Icons.self_improvement,
            size: 34,
            color: Color(0xFFF7F5F1),
          ),
        ),
      ],
    );
  }
}

class _CharityPosterArtwork extends StatelessWidget {
  const _CharityPosterArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 10,
          right: 10,
          top: 12,
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const Positioned(
          left: 12,
          top: 16,
          child: Text(
            'COMMUNITY\nCHARITY',
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF8D36A),
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 12,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFF102962),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2F73D7),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6A3DF0),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReflectionsPosterArtwork extends StatelessWidget {
  const _ReflectionsPosterArtwork();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 14,
          left: 8,
          right: 8,
          child: Text(
            'SPIRITUAL\nREFLECTIONS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: Color(0xFFFBECA3),
            ),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 16,
          child: _Blob(
            width: 34,
            height: 48,
            color: Color(0xFFF6A14D),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 16,
          child: _Blob(
            width: 44,
            height: 56,
            color: Color(0xFF3478B9),
          ),
        ),
        Positioned(
          left: 34,
          bottom: 32,
          child: Icon(
            Icons.mosque_outlined,
            size: 34,
            color: Color(0xFFF7F5F1),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(40),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.label,
    required this.onTap,
    this.supportingText,
    this.footerLabel,
  });

  final String label;
  final VoidCallback onTap;
  final String? supportingText;
  final String? footerLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFD1DDD0),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 100,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: Color(0xFF405046),
                  ),
                ),
                if (supportingText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    supportingText!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: Color(0xFF57675D),
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    if (footerLabel != null)
                      Expanded(
                        child: Text(
                          footerLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF445349),
                          ),
                        ),
                      ),
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: Color(0xFF445349),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePromoCardState {
  const _HomePromoCardState({
    required this.title,
    required this.subtitle,
    required this.footerLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String footerLabel;
  final VoidCallback onTap;
}

class _HomeUtilityCardState {
  const _HomeUtilityCardState({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFD1DDD0),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: double.infinity,
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF405046),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCardData {
  const _EventCardData({
    required this.date,
    required this.dateColor,
    required this.title,
    required this.location,
    required this.category,
    required this.price,
    required this.posterColors,
    required this.posterStyle,
    this.detailArgs,
  });

  final String date;
  final Color dateColor;
  final String title;
  final String location;
  final String category;
  final String price;
  final List<Color> posterColors;
  final _PosterStyle posterStyle;
  final EventDetailRouteArgs? detailArgs;

  factory _EventCardData.fromMosqueProgram(
    MosqueModel mosque,
    MosqueProgramItem item,
    int index,
  ) {
    const palettes = <({Color badge, List<Color> poster, _PosterStyle style})>[
      (
        badge: Color(0xFFE7B16E),
        poster: <Color>[Color(0xFFF7E2B6), Color(0xFFF2D19D)],
        style: _PosterStyle.seerah,
      ),
      (
        badge: Color(0xFFDE8B53),
        poster: <Color>[Color(0xFF1E345A), Color(0xFF0F172B)],
        style: _PosterStyle.wellness,
      ),
      (
        badge: Color(0xFFD89E5C),
        poster: <Color>[Color(0xFF192A66), Color(0xFF5B34E6)],
        style: _PosterStyle.charity,
      ),
      (
        badge: Color(0xFFAA6C56),
        poster: <Color>[Color(0xFF5641B8), Color(0xFF15365F)],
        style: _PosterStyle.reflections,
      ),
    ];

    final palette = palettes[index % palettes.length];
    final details = DiscoveryEvent.fromMosqueProgram(mosque, item);
    final location = item.location.trim().isNotEmpty
        ? item.location.trim()
        : (mosque.name.trim().isEmpty ? 'Nearby mosque' : mosque.name);
    final posterLabel = item.posterLabel.trim();
    final city = mosque.city.trim();
    final category = switch ((city.isNotEmpty, posterLabel.isNotEmpty)) {
      (true, true) => '$city • $posterLabel',
      (true, false) => city,
      (false, true) => posterLabel,
      (false, false) => '',
    };

    return _EventCardData(
      date: details.dateLabel,
      dateColor: palette.badge,
      title: item.title,
      location: location,
      category: category,
      price: details.priceLabel,
      posterColors: palette.poster,
      posterStyle: palette.style,
      detailArgs: EventDetailRouteArgs(
        event: mosque,
        discoveryEvent: details,
      ),
    );
  }
}

enum _PosterStyle {
  seerah,
  wellness,
  charity,
  reflections,
}

List<_EventCardData> _mapHomeEventCards(
  MosqueModel mosque,
  MosqueContent content,
) {
  return content.events
      .take(4)
      .toList(growable: false)
      .asMap()
      .entries
      .map(
        (entry) =>
            _EventCardData.fromMosqueProgram(mosque, entry.value, entry.key),
      )
      .toList(growable: false);
}
