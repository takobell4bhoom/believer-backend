import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/api_error_mapper.dart';
import '../data/auth_provider.dart';
import '../data/mosque_provider.dart';
import '../models/mosque_model.dart';
import '../navigation/app_startup.dart';
import '../navigation/app_routes.dart';
import '../screens/event_search_listing.dart';
import '../services/location_preferences_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/common/async_states.dart';
import '../widgets/common/main_bottom_nav_bar.dart';

class MosqueSearchScreen extends ConsumerStatefulWidget {
  const MosqueSearchScreen({super.key});

  @override
  ConsumerState<MosqueSearchScreen> createState() => _MosqueSearchScreenState();
}

class _MosqueSearchScreenState extends ConsumerState<MosqueSearchScreen> {
  static const _mosqueFilters = <_SearchFilter>[
    _SearchFilter(
      label: 'Women Friendly',
      searchTag: 'women prayer area',
      assetPath: 'assets/illustrations/filter_women_friendly.png',
      fallbackIcon: Icons.accessibility_new_rounded,
    ),
    _SearchFilter(
      label: 'Open 24 Hours',
      searchTag: 'open now',
      assetPath: 'assets/illustrations/filter_open_24.png',
      fallbackIcon: Icons.schedule_rounded,
    ),
    _SearchFilter(
      label: 'Has Parking',
      searchTag: 'parking',
      assetPath: 'assets/illustrations/filter_has_parking.png',
      fallbackIcon: Icons.local_parking_rounded,
    ),
    _SearchFilter(
      label: 'Wheelchair',
      searchTag: 'wheelchair access',
      assetPath: 'assets/illustrations/filter_wheelchair.png',
      fallbackIcon: Icons.accessible_forward_rounded,
    ),
    _SearchFilter(
      label: 'Classes & Halaqas',
      searchTag: 'halaqa',
      assetPath: 'assets/illustrations/filter_classes_halaqas.png',
      fallbackIcon: Icons.menu_book_rounded,
    ),
    _SearchFilter(
      label: 'Event Active',
      searchTag: 'event',
      assetPath: 'assets/illustrations/filter_event_active.png',
      fallbackIcon: Icons.event_note_rounded,
    ),
  ];

  static const _eventFilters = <_SearchFilter>[
    _SearchFilter(
      label: 'Charity Drives',
      searchTag: 'zakat',
      assetPath: 'assets/illustrations/filter_event_active.png',
      fallbackIcon: Icons.volunteer_activism_rounded,
      eventType: 'Charity',
    ),
    _SearchFilter(
      label: 'Community Meals',
      searchTag: 'food',
      assetPath: 'assets/illustrations/filter_open_24.png',
      fallbackIcon: Icons.restaurant_rounded,
      eventType: 'Charity',
    ),
    _SearchFilter(
      label: 'Family Gatherings',
      searchTag: 'family',
      assetPath: 'assets/illustrations/filter_women_friendly.png',
      fallbackIcon: Icons.groups_rounded,
      eventType: 'Celebration',
    ),
    _SearchFilter(
      label: 'Quran Studies',
      searchTag: 'quran',
      assetPath: 'assets/illustrations/filter_classes_halaqas.png',
      fallbackIcon: Icons.auto_stories_rounded,
      eventType: 'Islamic Knowledge',
    ),
    _SearchFilter(
      label: 'Lectures',
      searchTag: 'lecture',
      assetPath: 'assets/illustrations/filter_has_parking.png',
      fallbackIcon: Icons.campaign_rounded,
      eventType: 'Islamic Knowledge',
    ),
    _SearchFilter(
      label: 'Eid & Ramadan',
      searchTag: 'eid',
      assetPath: 'assets/illustrations/filter_wheelchair.png',
      fallbackIcon: Icons.celebration_rounded,
      eventType: 'Celebration',
    ),
  ];

  final LocationPreferencesService _locationPreferencesService =
      LocationPreferencesService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  int _selectedTab = 0;
  String _location = LocationPreferencesService.defaultLocation;
  SavedUserLocation? _savedLocation;
  bool _requestedLoad = false;
  bool _redirectingToLogin = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_syncSearchQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_syncSearchQuery)
      ..dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadLocation();
    await _loadNearbyData();
  }

  Future<void> _loadLocation() async {
    final savedLocation = await _locationPreferencesService.loadSavedLocation();
    if (!mounted) return;
    setState(() {
      _savedLocation = savedLocation;
      _location =
          savedLocation?.label ?? LocationPreferencesService.defaultLocation;
    });
  }

  Future<void> _loadNearbyData() async {
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
      // Error state is surfaced by mosqueProvider.
    }
  }

  void _syncSearchQuery() {
    final value = _searchController.text;
    if (value == _searchQuery) return;
    setState(() => _searchQuery = value);
  }

  void _redirectToLogin() {
    if (_redirectingToLogin || !mounted) return;
    _redirectingToLogin = true;
    scheduleUnauthenticatedRedirect(context);
  }

  void _selectTab(int value) {
    if (_selectedTab == value) return;
    setState(() => _selectedTab = value);
  }

  List<_SearchFilter> get _filtersForTab {
    return _selectedTab == 0 ? _mosqueFilters : _eventFilters;
  }

  String get _bannerLabel {
    return _selectedTab == 0 ? 'NEARBY MOSQUES' : 'NEARBY EVENTS';
  }

  String get _searchPlaceholder {
    return _selectedTab == 0 ? 'Search mosques' : 'Search events';
  }

  List<MosqueModel> _filterItems(
    List<MosqueModel> items, {
    String? overrideQuery,
  }) {
    final query = (overrideQuery ?? _searchQuery).trim().toLowerCase();
    final baseItems = _selectedTab == 0
        ? items
        : items
            .where(
              (item) => item.eventTags.isNotEmpty || item.classTags.isNotEmpty,
            )
            .toList();

    if (query.isEmpty) {
      return baseItems;
    }

    return baseItems.where((item) {
      final haystack = [
        item.name,
        item.addressLine,
        item.city,
        item.state,
        item.country,
        item.sect,
        item.duhrTime,
        item.asarTime,
        ...item.facilities,
        ...item.classTags,
        ...item.eventTags,
        if (item.womenPrayerArea) 'women prayer area',
        if (item.parking) 'parking',
        if (item.wudu) 'wudu',
        if (item.isOpenNow) 'open now',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  Future<void> _handleFilterTap(
    _SearchFilter filter,
    List<MosqueModel> items,
  ) async {
    _searchController.value = TextEditingValue(
      text: filter.searchTag,
      selection: TextSelection.collapsed(offset: filter.searchTag.length),
    );

    final filteredItems = _filterItems(items, overrideQuery: filter.searchTag);
    if (!mounted) return;

    if (_selectedTab == 0) {
      await Navigator.of(context).pushNamed(
        AppRoutes.mosquesAndEvents,
        arguments: filteredItems,
      );
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRoutes.nearbyEvents,
      arguments: EventSearchListingRouteArgs(
        initialEvents: filteredItems,
        selectedCategory: filter.searchTag,
        initialType: filter.eventType ?? 'All types',
      ),
    );
  }

  void _openNearbyMap() {
    Navigator.of(context).pushNamed(AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final mosqueState = ref.watch(mosqueProvider);

    if (authState.hasValue && authState.valueOrNull == null) {
      _redirectToLogin();
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: LoadingState(label: 'Redirecting...'),
      );
    }

    if (authState.isLoading || !_requestedLoad) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: LoadingState(label: 'Loading nearby mosques...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar:
          const MainBottomNavBar(activeTab: MainAppTab.discover),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _MosqueSearchTopNav(
              location: _location,
              controller: _searchController,
              placeholder: _searchPlaceholder,
            ),
            _SearchTabBar(
              selectedTab: _selectedTab,
              onTabSelected: _selectTab,
            ),
            Expanded(
              child: mosqueState.when(
                loading: () =>
                    const LoadingState(label: 'Loading nearby mosques...'),
                error: (error, _) => ErrorState(
                  message: ApiErrorMapper.toUserMessage(error),
                  onRetry: _bootstrap,
                ),
                data: (items) {
                  final filteredItems = _filterItems(items);
                  if (filteredItems.isEmpty) {
                    return EmptyState(
                      title: _selectedTab == 0
                          ? 'No mosques match this search.'
                          : 'No events match this search.',
                      subtitle: _selectedTab == 0
                          ? 'Try a different search or explore another nearby filter.'
                          : 'Try a broader event term or switch back to mosques.',
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NearbyBanner(
                          label: _bannerLabel,
                          count: filteredItems.length,
                          onTap: _openNearbyMap,
                        ),
                        const SizedBox(height: 20),
                        const _SectionHeader(title: 'FILTER BY'),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _filtersForTab
                              .map(
                                (filter) => _FilterCard(
                                  filter: filter,
                                  onTap: () => _handleFilterTap(filter, items),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MosqueSearchTopNav extends StatelessWidget {
  const _MosqueSearchTopNav({
    required this.location,
    required this.controller,
    required this.placeholder,
  });

  final String location;
  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.accent,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: controller,
                  cursorColor: AppColors.primaryText,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primaryText,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: placeholder,
                    hintStyle: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: AppColors.mutedText,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.mutedText,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
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
}

class _SearchTabBar extends StatelessWidget {
  const _SearchTabBar({
    required this.selectedTab,
    required this.onTabSelected,
  });

  final int selectedTab;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: _SearchTab(
              label: 'Mosques',
              selected: selectedTab == 0,
              onTap: () => onTabSelected(0),
            ),
          ),
          Expanded(
            child: _SearchTab(
              label: 'Events',
              selected: selectedTab == 1,
              onTap: () => onTabSelected(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTab extends StatelessWidget {
  const _SearchTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                ),
              ),
            ),
            if (selected)
              Positioned(
                left: 28,
                bottom: 0,
                child: Container(
                  width: 139,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NearbyBanner extends StatelessWidget {
  const _NearbyBanner({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment(-0.57, 1.0),
            end: Alignment(0.57, -1.0),
            colors: [
              Color(0xFF4C5E5D),
              Color(0xFFB1C9BE),
            ], // Figma gradient — no token
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$label ($count)',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const _LocationBannerIcon(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationBannerIcon extends StatelessWidget {
  const _LocationBannerIcon();

  static const _assetPath = 'assets/illustrations/location_icon.svg';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FutureBuilder<String>(
        future: rootBundle.loadString(_assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return SvgPicture.string(
              snapshot.data!,
              width: 56,
              height: 56,
            );
          }

          return const Icon(
            Icons.location_searching_rounded,
            size: 40,
            color: AppColors.white,
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Proza Libre',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.8,
        color: AppColors.primaryText,
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.filter,
    required this.onTap,
  });

  final _SearchFilter filter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 175,
      height: 120,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: _FilterIllustration(
                        assetPath: filter.assetPath,
                        fallbackIcon: filter.fallbackIcon,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    filter.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
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

class _FilterIllustration extends StatelessWidget {
  const _FilterIllustration({
    required this.assetPath,
    required this.fallbackIcon,
  });

  final String assetPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return Icon(
          fallbackIcon,
          size: 40,
          color: AppColors.accent,
        );
      },
    );
  }
}

class _SearchFilter {
  const _SearchFilter({
    required this.label,
    required this.searchTag,
    required this.assetPath,
    required this.fallbackIcon,
    this.eventType,
  });

  final String label;
  final String searchTag;
  final String assetPath;
  final IconData fallbackIcon;
  final String? eventType;
}
