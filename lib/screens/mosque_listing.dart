import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_error_mapper.dart';
import '../data/auth_provider.dart';
import '../data/mosque_provider.dart';
import '../models/mosque_model.dart';
import '../navigation/mosque_detail_route_args.dart';
import '../navigation/app_startup.dart';
import '../navigation/app_routes.dart';
import '../services/location_preferences_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/mosque_prayer_summary.dart';
import '../widgets/common/async_states.dart';
import '../widgets/common/main_bottom_nav_bar.dart';
import '../widgets/mosque_image_frame.dart';

class MosqueListing extends ConsumerStatefulWidget {
  const MosqueListing({
    super.key,
    this.initialMosques = const <MosqueModel>[],
    this.locationPreferencesService,
  });

  final List<MosqueModel> initialMosques;
  final LocationPreferencesService? locationPreferencesService;

  @override
  ConsumerState<MosqueListing> createState() => _MosqueListingState();
}

class _MosqueListingState extends ConsumerState<MosqueListing> {
  static const _defaultSortBy = 'Nearest Mosque';
  static const _defaultRadiusMiles = 3.0;
  static const _defaultSect = 'Any';
  static const _defaultAsrTime = 'Any';
  static const _defaultReviewRating = 'Any';
  static const _defaultTiming = 'All mosques';

  late final LocationPreferencesService _locationPreferencesService;

  String _location = LocationPreferencesService.unsetLocationLabel;
  SavedUserLocation? _savedLocation;
  double _filterRadiusMiles = _defaultRadiusMiles;
  String _sortBy = _defaultSortBy;
  String _sect = _defaultSect;
  String _asrTime = _defaultAsrTime;
  String _reviewRating = _defaultReviewRating;
  String _timing = _defaultTiming;
  Set<String> _facilities = <String>{};
  Set<String> _classes = <String>{};
  Set<String> _events = <String>{};
  bool _requestedLoad = false;
  bool _redirectingToLogin = false;

  @override
  void initState() {
    super.initState();
    _locationPreferencesService =
        widget.locationPreferencesService ?? LocationPreferencesService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    await _loadLocation();
    await _loadMosques();
  }

  Future<void> _loadLocation() async {
    final savedLocation = await _locationPreferencesService.loadSavedLocation();
    if (!mounted) return;
    setState(() {
      _savedLocation = savedLocation;
      _location =
          savedLocation?.label ?? LocationPreferencesService.unsetLocationLabel;
    });
  }

  Future<void> _loadMosques() async {
    if (!_requestedLoad && mounted) {
      setState(() => _requestedLoad = true);
    } else {
      _requestedLoad = true;
    }

    final savedLocation = _savedLocation;
    if (savedLocation?.hasCoordinates != true) {
      return;
    }

    try {
      await ref.read(mosqueProvider.notifier).loadNearby(
            latitude: savedLocation!.latitude!,
            longitude: savedLocation.longitude!,
            radiusKm: 10,
          );
    } catch (_) {
      // Error UI is exposed through mosqueProvider.
    }
  }

  void _redirectToLogin() {
    if (_redirectingToLogin || !mounted) return;
    _redirectingToLogin = true;
    scheduleUnauthenticatedRedirect(context);
  }

  Future<void> _openFilters() async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.sortFilterMosque,
      arguments: <String, dynamic>{
        'sortBy': _sortBy,
        'radius': _filterRadiusMiles.round(),
        'sect': _sect,
        'asarTime': _asrTime,
        'reviewRating': _reviewRating,
        'timing': _timing,
        'facilities': _facilities.toList(growable: false),
        'classes': _classes.toList(growable: false),
        'events': _events.toList(growable: false),
      },
    );
    if (!mounted || result is! Map<String, dynamic>) return;
    _applyFilterPayload(result);
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(AppRoutes.home);
  }

  int get _activeFilterCount {
    var count = 1; // Figma base state starts with a radius filter applied.
    if (_sortBy != _defaultSortBy) count += 1;
    if (_sect != _defaultSect) count += 1;
    if (_asrTime != _defaultAsrTime) count += 1;
    if (_reviewRating != _defaultReviewRating) count += 1;
    if (_timing != _defaultTiming) count += 1;
    count += _facilities.length;
    count += _classes.length;
    count += _events.length;
    return count;
  }

  List<MosqueModel> _applyFilters(List<MosqueModel> mosques) {
    final filtered = mosques.where((mosque) {
      final matchesDistance = mosque.distanceMiles <= _filterRadiusMiles;
      final matchesSect = _sect == _defaultSect ||
          mosque.sect.toLowerCase().contains(_sect.toLowerCase());
      final matchesAsrTime = switch (_asrTime) {
        'Asr listed' => mosque.hasAsrTime,
        '5:00 PM or later' =>
          mosque.hasAsrTime && _minutesFromClock(mosque.asarTime) >= (17 * 60),
        _ => true,
      };
      final matchesReviewRating = switch (_reviewRating) {
        '4.0+' => mosque.hasCommunityRating && mosque.rating >= 4,
        '3.0+' => mosque.hasCommunityRating && mosque.rating >= 3,
        _ => true,
      };
      final matchesTiming =
          _timing != 'Prayer times listed' || mosque.hasListedPrayerTimes;
      final matchesFacilities = _facilities.every(
        (facility) => _matchesFacility(mosque, facility),
      );
      final matchesClasses = _classes.every(
        (item) => _matchesClass(mosque, item),
      );
      final matchesEvents = _events.every(
        (item) => _matchesEvent(mosque, item),
      );

      return matchesDistance &&
          matchesSect &&
          matchesAsrTime &&
          matchesReviewRating &&
          matchesTiming &&
          matchesFacilities &&
          matchesClasses &&
          matchesEvents;
    }).toList();

    switch (_sortBy) {
      case 'Earlier Dhuhr':
        filtered.sort(
          (left, right) => _minutesFromClock(left.duhrTime).compareTo(
            _minutesFromClock(right.duhrTime),
          ),
        );
        break;
      case 'Nearest Mosque':
      default:
        filtered.sort(
          (left, right) => left.distanceMiles.compareTo(right.distanceMiles),
        );
        break;
    }

    return filtered;
  }

  bool _matchesFacility(MosqueModel mosque, String facility) {
    return switch (facility) {
      'Women Prayer Area' => mosque.womenPrayerArea,
      'Parking' => mosque.parking,
      'Wudu' => mosque.wudu,
      _ => mosque.hasFacility(facility),
    };
  }

  bool _matchesClass(MosqueModel mosque, String classLabel) {
    final tags = mosque.classTags.map((tag) => tag.toLowerCase()).toList();
    return switch (classLabel) {
      'Classes listed' => mosque.classTags.isNotEmpty,
      'Qur\'an in title' => tags.any(
          (tag) =>
              tag.contains('quran') ||
              tag.contains('qur') ||
              tag.contains('tajwid'),
        ),
      'Halaqa in title' => tags.any((tag) => tag.contains('halaqa')),
      _ => true,
    };
  }

  bool _matchesEvent(MosqueModel mosque, String eventLabel) {
    final tags = mosque.eventTags.map((tag) => tag.toLowerCase()).toList();
    return switch (eventLabel) {
      'Events listed' => mosque.eventTags.isNotEmpty,
      'Family in title' => tags.any((tag) => tag.contains('family')),
      'Youth in title' => tags.any((tag) => tag.contains('youth')),
      _ => true,
    };
  }

  List<String> get _activeFilterLabels {
    final labels = <String>['Within ${_filterRadiusMiles.round()} miles'];
    if (_sortBy != _defaultSortBy) {
      labels.add(_sortBy);
    }
    if (_sect != _defaultSect) {
      labels.add(_sect);
    }
    if (_asrTime != _defaultAsrTime) {
      labels.add(_asrTime);
    }
    if (_reviewRating != _defaultReviewRating) {
      labels.add('Rating $_reviewRating');
    }
    if (_timing != _defaultTiming) {
      labels.add(_timing);
    }
    labels.addAll(_facilities);
    labels.addAll(_classes);
    labels.addAll(_events);
    return labels;
  }

  int _minutesFromClock(String value) {
    final match =
        RegExp(r'^\s*(\d{1,2})\s*:\s*(\d{2})\s*([AaPp][Mm])\s*$').firstMatch(
      value,
    );
    if (match == null) return 24 * 60;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)!.toUpperCase();

    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return (hour * 60) + minute;
  }

  void _applyFilterPayload(Map<String, dynamic> result) {
    final radius = result['radius'];
    final facilities = result['facilities'];
    final classes = result['classes'];
    final events = result['events'];

    setState(() {
      _sortBy = result['sortBy'] as String? ?? _defaultSortBy;
      _sect = result['sect'] as String? ?? _defaultSect;
      _asrTime = result['asarTime'] as String? ?? _defaultAsrTime;
      _reviewRating = result['reviewRating'] as String? ?? _defaultReviewRating;
      _timing = result['timing'] as String? ?? _defaultTiming;
      _facilities = facilities is List
          ? facilities.whereType<String>().toSet()
          : <String>{};
      _classes =
          classes is List ? classes.whereType<String>().toSet() : <String>{};
      _events =
          events is List ? events.whereType<String>().toSet() : <String>{};
      _filterRadiusMiles =
          radius is int ? radius.toDouble() : _defaultRadiusMiles;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final mosqueState = ref.watch(mosqueProvider);
    final hasSavedCoordinates = _savedLocation?.hasCoordinates == true;
    final hasSavedLabel = _savedLocation?.label.trim().isNotEmpty == true;

    if (authState.hasValue && authState.valueOrNull == null) {
      _redirectToLogin();
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: LoadingState(label: 'Redirecting...'),
      );
    }

    if (authState.isLoading || !_requestedLoad) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F7F4),
        body: LoadingState(label: 'Loading nearby mosques...'),
      );
    }

    if (!hasSavedCoordinates) {
      return _MosqueListingScaffold(
        location: _location,
        onBack: _goBack,
        onMenuTap: _openFilters,
        child: EmptyState(
          title: hasSavedLabel
              ? 'Precise location needed.'
              : 'Set your location first.',
          subtitle: hasSavedLabel
              ? 'We saved your location label, but nearby mosque reads need confirmed coordinates.'
              : 'Save a location to load nearby mosques honestly.',
        ),
      );
    }

    return mosqueState.when(
      loading: () => _MosqueListingScaffold(
        location: _location,
        child: const LoadingState(label: 'Loading nearby mosques...'),
      ),
      error: (error, _) => _MosqueListingScaffold(
        location: _location,
        onBack: _goBack,
        onMenuTap: _openFilters,
        child: ErrorState(
          message: ApiErrorMapper.toUserMessage(error),
          onRetry: _bootstrap,
        ),
      ),
      data: (mosques) {
        final source =
            widget.initialMosques.isNotEmpty ? widget.initialMosques : mosques;
        final filteredMosques = _applyFilters(source);

        if (filteredMosques.isEmpty) {
          return _MosqueListingScaffold(
            location: _location,
            onBack: _goBack,
            onMenuTap: _openFilters,
            child: const EmptyState(
              title: 'No mosques found nearby.',
              subtitle: 'Try adjusting the radius or filters.',
            ),
          );
        }

        return _MosqueListingScaffold(
          location: _location,
          onBack: _goBack,
          onMenuTap: _openFilters,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterRail(
                activeFilterCount: _activeFilterCount,
                activeFilterLabels: _activeFilterLabels,
                onFilterTap: _openFilters,
              ),
              const SizedBox(height: 12),
              _CountBar(
                mosqueCount: filteredMosques.length,
                activeFilterCount: _activeFilterCount,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: filteredMosques.length,
                  padding: const EdgeInsets.only(bottom: 20),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final mosque = filteredMosques[index];
                    return _MosqueCard(
                      mosque: mosque,
                      showClosestBadge: index == 0,
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.mosqueDetail,
                          arguments: MosqueDetailRouteArgs.fromMosque(mosque),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MosqueListingScaffold extends StatelessWidget {
  const _MosqueListingScaffold({
    required this.location,
    required this.child,
    this.onBack,
    this.onMenuTap,
  });

  final String location;
  final VoidCallback? onBack;
  final VoidCallback? onMenuTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      bottomNavigationBar:
          const MainBottomNavBar(activeTab: MainAppTab.discover),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ListingTopNav(
              location: location,
              onBack: onBack,
              onMenuTap: onMenuTap,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingTopNav extends StatelessWidget {
  const _ListingTopNav({
    required this.location,
    this.onBack,
    this.onMenuTap,
  });

  final String location;
  final VoidCallback? onBack;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.gps_fixed,
                        size: 16,
                        color: AppColors.accentSoft,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.accentSoft,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accentSoft,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open filters',
                        onPressed: onMenuTap,
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: const Icon(
                          Icons.menu,
                          size: 28,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: onBack,
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 30,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Nearby Mosques',
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
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

class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.activeFilterCount,
    required this.activeFilterLabels,
    required this.onFilterTap,
  });

  final int activeFilterCount;
  final List<String> activeFilterLabels;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterIconButton(
            active: activeFilterCount > 0,
            onTap: onFilterTap,
          ),
          for (var index = 0; index < activeFilterLabels.length; index++) ...[
            SizedBox(width: index == 0 ? 10 : 8),
            _ListingChip(
              label: activeFilterLabels[index],
              active: index == 0,
              leadingIcon: index == 0 ? Icons.close : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _CountBar extends StatelessWidget {
  const _CountBar({
    required this.mosqueCount,
    required this.activeFilterCount,
  });

  final int mosqueCount;
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$mosqueCount Mosques',
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
          ),
        ),
        const Spacer(),
        Text(
          activeFilterCount == 1
              ? '1 Filter Applied'
              : '$activeFilterCount Filters Applied',
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryText,
          ),
        ),
      ],
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.tune_rounded,
                  size: 26,
                  color: AppColors.secondaryText,
                ),
              ),
              if (active)
                Positioned(
                  right: 1,
                  top: 5,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighlight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF6F7F4),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingChip extends StatelessWidget {
  const _ListingChip({
    required this.label,
    this.active = false,
    this.leadingIcon,
  });

  final String label;
  final bool active;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE7E7E4) : Colors.transparent,
        border: Border.all(color: const Color(0xFF8A8A86)),
        borderRadius: BorderRadius.circular(44),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(
              leadingIcon,
              size: 14,
              color: const Color(0xFF444842),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF444842),
            ),
          ),
        ],
      ),
    );
  }
}

class _MosqueCard extends StatelessWidget {
  const _MosqueCard({
    required this.mosque,
    required this.showClosestBadge,
    required this.onTap,
  });

  final MosqueModel mosque;
  final bool showClosestBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locationLabel = _buildLocationLabel(mosque);
    final facilityLabels = _listingFacilityLabels(mosque);
    final prayerSummary = _buildPrayerSummary(mosque);
    final statusSummary = _buildStatusSummary(mosque);
    final hasRating = mosque.hasCommunityRating;
    final contentLabel = _buildContentLabel(mosque);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: EdgeInsets.only(top: showClosestBadge ? 12 : 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          mosque.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 16,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasRating) ...[
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              mosque.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            mosque.isBookmarked
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 20,
                            color: mosque.isBookmarked
                                ? AppColors.accent
                                : AppColors.secondaryText,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardImage(imageUrl: mosque.primaryImageUrl),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                _IconText(
                                  icon: Icons.location_on,
                                  text: locationLabel,
                                ),
                                _IconText(
                                  icon: Icons.near_me,
                                  text:
                                      '${mosque.distanceMiles.toStringAsFixed(1)} mi away',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (mosque.sect.trim().isNotEmpty)
                                  _AmenityChip(text: mosque.sect),
                                ...facilityLabels.map(
                                  (label) => _AmenityChip(text: label),
                                ),
                                if (mosque.isVerified)
                                  const _AmenityChip(text: 'Verified'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              prayerSummary,
                              style: const TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryText,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _StatusPill(text: statusSummary),
                                if (contentLabel != null)
                                  _StatusPill(
                                    text: contentLabel,
                                    backgroundColor: const Color(0xFFDDE5DF),
                                    textColor: AppColors.primaryText,
                                    iconColor: AppColors.primaryText,
                                    icon: Icons.menu_book_rounded,
                                  ),
                              ],
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
        if (showClosestBadge)
          const Positioned(
            left: 12,
            top: 0,
            child: _ClosestBadge(),
          ),
      ],
    );
  }
}

String _buildLocationLabel(MosqueModel mosque) {
  final cityState = [mosque.city, mosque.state]
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(', ');
  if (cityState.isNotEmpty) {
    return cityState;
  }
  if (mosque.city.trim().isNotEmpty) {
    return mosque.city.trim();
  }
  return 'Location pending';
}

List<String> _listingFacilityLabels(MosqueModel mosque) {
  final preferred = <String>[
    if (mosque.womenPrayerArea) 'Women Prayer Area',
    if (mosque.parking) 'Parking',
    if (mosque.wudu) 'Wudu',
  ];

  for (final facility in mosque.facilities) {
    final label = _friendlyFacilityLabel(facility);
    if (label == null || preferred.contains(label)) {
      continue;
    }
    preferred.add(label);
    if (preferred.length >= 3) {
      break;
    }
  }

  return preferred.take(3).toList(growable: false);
}

String? _friendlyFacilityLabel(String rawFacility) {
  return switch (rawFacility.trim().toLowerCase()) {
    'women_area' || 'women_prayer_area' => 'Women Prayer Area',
    'parking' => 'Parking',
    'wudu' => 'Wudu',
    'wheelchair' || 'wheelchair_access' => 'Wheelchair Access',
    'washroom' || 'restroom' => 'Washroom',
    _ => null,
  };
}

String _buildPrayerSummary(MosqueModel mosque) {
  return buildMosqueListingPrayerSummary(mosque);
}

String _buildStatusSummary(MosqueModel mosque) {
  if (mosque.isVerified) {
    return 'Verified listing';
  }
  return 'Community listed';
}

String? _buildContentLabel(MosqueModel mosque) {
  final contentLabels = <String>[
    if (mosque.classTags.isNotEmpty)
      '${mosque.classTags.length} ${mosque.classTags.length == 1 ? 'class' : 'classes'}',
    if (mosque.eventTags.isNotEmpty)
      '${mosque.eventTags.length} ${mosque.eventTags.length == 1 ? 'event' : 'events'}',
  ];
  if (contentLabels.isEmpty) {
    return null;
  }
  return contentLabels.join(' • ');
}

class _ClosestBadge extends StatelessWidget {
  const _ClosestBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Closest To You',
        style: TextStyle(
          fontFamily: 'Figtree',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return MosqueImageFrame(
      width: 104,
      borderRadius: BorderRadius.circular(9),
      child: imageUrl.isEmpty
          ? const _ImageFallback()
          : Image.network(
              key: const ValueKey('mosque-listing-card-image'),
              imageUrl,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.1),
              errorBuilder: (_, __, ___) => const _ImageFallback(),
            ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const MosqueImagePlaceholder(iconSize: 36);
  }
}

class _IconText extends StatelessWidget {
  const _IconText({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF535F56)),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF535F56),
          ),
        ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final icon = switch (text) {
      'Parking' => Icons.local_parking_rounded,
      'Wudu' => Icons.waves_rounded,
      'Women Prayer Area' => Icons.accessibility_new_rounded,
      'Wheelchair Access' => Icons.accessible_forward_rounded,
      'Washroom' => Icons.wc_rounded,
      'Verified' => Icons.verified_rounded,
      _ when text.startsWith('+') => Icons.add_rounded,
      _ => Icons.mosque_outlined,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: AppColors.primaryText,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 13,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    this.backgroundColor = AppColors.secondaryText,
    this.textColor = AppColors.white,
    this.iconColor = AppColors.white,
    this.icon = Icons.hourglass_bottom_outlined,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: iconColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
