import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_error_mapper.dart';
import '../data/auth_provider.dart';
import '../data/mosque_provider.dart';
import '../models/discovery_event.dart';
import '../models/mosque_content.dart';
import '../models/mosque_model.dart';
import '../navigation/app_startup.dart';
import '../navigation/app_routes.dart';
import '../screens/event_detail_screen.dart';
import '../services/location_preferences_service.dart';
import '../widgets/common/async_states.dart';
import '../widgets/common/main_bottom_nav_bar.dart';

class EventSearchListingRouteArgs {
  const EventSearchListingRouteArgs({
    this.initialEvents = const <MosqueModel>[],
    this.selectedCategory,
    this.initialType = 'All types',
    this.initialSearchQuery = '',
  });

  final List<MosqueModel> initialEvents;
  final String? selectedCategory;
  final String initialType;
  final String initialSearchQuery;
}

class EventSearchListing extends ConsumerStatefulWidget {
  const EventSearchListing({
    super.key,
    this.args = const EventSearchListingRouteArgs(),
  });

  final EventSearchListingRouteArgs args;

  @override
  ConsumerState<EventSearchListing> createState() => _EventSearchListingState();
}

class _EventSearchListingState extends ConsumerState<EventSearchListing> {
  static const _distanceOptions = <String>['Any distance', '5 mi', '10 mi'];
  static const _typeOptions = <String>[
    'All types',
    'Charity',
    'Celebration',
    'Islamic Knowledge',
  ];

  static const _sections = <_EventCategorySectionData>[
    _EventCategorySectionData(
      title: 'CHARITY',
      type: 'Charity',
      tiles: [
        _EventCategoryTileData(
          title: 'Zakat &\nsadaqah',
          searchCategory: 'Zakat & sadaqah',
          artwork: _EventTileArtwork.bagHand,
        ),
        _EventCategoryTileData(
          title: 'Foodbank &\ncommunity\nmeals',
          searchCategory: 'Foodbank & community meals',
          artwork: _EventTileArtwork.foodBag,
        ),
        _EventCategoryTileData(
          title: 'Fundraisers for\nmosque\nsupport',
          searchCategory: 'Fundraisers for mosque support',
          artwork: _EventTileArtwork.fundraiser,
        ),
      ],
    ),
    _EventCategorySectionData(
      title: 'CELEBRATIONS',
      type: 'Celebration',
      tiles: [
        _EventCategoryTileData(
          title: 'Iftar\ngatherings',
          searchCategory: 'Iftar gatherings',
          artwork: _EventTileArtwork.peopleMeal,
        ),
        _EventCategoryTileData(
          title: 'Suhoor\nnights',
          searchCategory: 'Suhoor nights',
          artwork: _EventTileArtwork.suhoor,
        ),
        _EventCategoryTileData(
          title: 'Eid\ncelebrations',
          searchCategory: 'Eid celebrations',
          artwork: _EventTileArtwork.moonStars,
        ),
      ],
    ),
    _EventCategorySectionData(
      title: 'ISLAMIC KNOWLEDGE',
      type: 'Islamic Knowledge',
      tiles: [
        _EventCategoryTileData(
          title: 'Islamic history &\nlegacy',
          searchCategory: 'Islamic history & legacy',
          artwork: _EventTileArtwork.kaaba,
        ),
        _EventCategoryTileData(
          title: 'Qur\'anic\nstudies',
          searchCategory: 'Qur\'anic studies',
          artwork: _EventTileArtwork.quran,
        ),
        _EventCategoryTileData(
          title: 'Spiritual\nreflections',
          searchCategory: 'Spiritual reflections',
          artwork: _EventTileArtwork.minbar,
        ),
      ],
    ),
  ];

  final LocationPreferencesService _locationPreferencesService =
      LocationPreferencesService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _location = 'Location unavailable';
  SavedUserLocation? _savedLocation;
  String _filterDistance = _distanceOptions.first;
  String _filterType = _typeOptions.first;
  String? _selectedCategory;
  bool _requestedLoad = false;
  bool _redirectingToLogin = false;

  @override
  void initState() {
    super.initState();
    _filterType = _typeOptions.contains(widget.args.initialType)
        ? widget.args.initialType
        : _typeOptions.first;
    _selectedCategory = widget.args.selectedCategory;
    _searchController.text = widget.args.initialSearchQuery.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadLocation();
    await _loadEvents();
  }

  Future<void> _loadLocation() async {
    try {
      final savedLocation =
          await _locationPreferencesService.loadSavedLocation();
      if (!mounted) return;
      setState(() {
        _savedLocation = savedLocation;
        _location = savedLocation?.label ?? 'Location unavailable';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _location = 'Location unavailable');
    }
  }

  Future<void> _loadEvents() async {
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
      // Error UI is handled via mosqueProvider.
    }
  }

  void _redirectToLogin() {
    if (_redirectingToLogin || !mounted) return;
    _redirectingToLogin = true;
    scheduleUnauthenticatedRedirect(context);
  }

  void _focusUpcomingResults() {
    if (!_scrollController.hasClients) return;
    final targetOffset = (_scrollController.offset + 320).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _selectTile(
      _EventCategorySectionData section, _EventCategoryTileData tile) {
    setState(() {
      _selectedCategory = tile.searchCategory;
      _filterType = section.type;
    });
    _focusUpcomingResults();
  }

  void _clearCategorySelection() {
    setState(() {
      _selectedCategory = null;
      _filterType = _typeOptions.first;
    });
    _focusUpcomingResults();
  }

  void _openMenu() {
    Navigator.of(context).pushNamed(AppRoutes.profileSettings);
  }

  List<_EventListingEntry> _buildPublishedEntries(List<MosqueModel> mosques) {
    final entries = <_EventListingEntry>[];

    for (final mosque in mosques) {
      for (final item in mosque.events) {
        entries.add(
          _EventListingEntry(
            mosque: mosque,
            program: item,
            isClass: false,
            details: DiscoveryEvent.fromMosqueProgram(mosque, item),
          ),
        );
      }

      for (final item in mosque.classes) {
        entries.add(
          _EventListingEntry(
            mosque: mosque,
            program: item,
            isClass: true,
            details: DiscoveryEvent.fromMosqueProgram(mosque, item),
          ),
        );
      }
    }

    entries.sort((a, b) {
      final distanceCompare =
          a.mosque.distanceMiles.compareTo(b.mosque.distanceMiles);
      if (distanceCompare != 0) {
        return distanceCompare;
      }

      return a.details.title.toLowerCase().compareTo(
            b.details.title.toLowerCase(),
          );
    });

    return entries;
  }

  List<_EventListingEntry> _applyFilters(List<_EventListingEntry> entries) {
    return entries.where((entry) {
      final matchesSearch = _matchesSearch(entry);
      final matchesDistance = switch (_filterDistance) {
        '5 mi' => entry.mosque.distanceMiles <= 5,
        '10 mi' => entry.mosque.distanceMiles <= 10,
        _ => true,
      };
      final matchesType = _matchesSelectedType(entry);
      final matchesCategory = _matchesSelectedCategory(entry);

      return matchesSearch && matchesDistance && matchesType && matchesCategory;
    }).toList(growable: false);
  }

  bool _matchesSearch(_EventListingEntry entry) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = _entryHaystack(entry);
    return haystack.contains(query);
  }

  bool _matchesSelectedType(_EventListingEntry entry) {
    if (_filterType == 'All types') return true;
    return _derivedTypeFor(entry) == _filterType;
  }

  bool _matchesSelectedCategory(_EventListingEntry entry) {
    final selectedCategory = _selectedCategory;
    if (selectedCategory == null || selectedCategory.isEmpty) {
      return true;
    }

    return _matchesCategoryKeyword(entry, selectedCategory);
  }

  bool _matchesAnyKeyword(_EventListingEntry entry, Iterable<String> keywords) {
    final haystack = _entryHaystack(entry);
    return keywords.any((keyword) => haystack.contains(keyword.toLowerCase()));
  }

  String? _derivedTypeFor(_EventListingEntry entry) {
    final haystack = [
      entry.program.title,
      entry.program.posterLabel,
      entry.program.schedule,
      entry.program.location,
      entry.program.description,
      entry.mosque.name,
      entry.mosque.city,
      entry.mosque.state,
    ].join(' ').toLowerCase();

    if (_containsAny(
      haystack,
      const ['zakat', 'sadaqah', 'food', 'donation', 'fund', 'volunteer'],
    )) {
      return 'Charity';
    }
    if (_containsAny(
      haystack,
      const ['iftar', 'suhoor', 'eid', 'family', 'community dinner', 'meetup'],
    )) {
      return 'Celebration';
    }
    if (_containsAny(
          haystack,
          const ['quran', 'tafsir', 'lecture', 'halaqa', 'seerah', 'history'],
        ) ||
        entry.isClass) {
      return 'Islamic Knowledge';
    }

    return null;
  }

  bool _containsAny(String haystack, Iterable<String> needles) {
    return needles.any(haystack.contains);
  }

  String _entryHaystack(_EventListingEntry entry) {
    return [
      entry.program.title,
      entry.program.posterLabel,
      entry.program.schedule,
      entry.program.location,
      entry.program.description,
      entry.mosque.name,
      entry.mosque.addressLine,
      entry.mosque.city,
      entry.mosque.state,
      entry.mosque.country,
      entry.mosque.sect,
    ].join(' ').toLowerCase();
  }

  List<_EventCategorySectionData> _visibleSections(
      List<_EventListingEntry> source) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _sections;

    return _sections
        .map((section) {
          final tiles = section.tiles.where((tile) {
            if (tile.title.toLowerCase().contains(query) ||
                tile.searchCategory.toLowerCase().contains(query)) {
              return true;
            }

            return source.any(
              (entry) =>
                  _matchesCategoryKeyword(entry, tile.searchCategory) &&
                  _matchesSearch(entry),
            );
          }).toList(growable: false);
          return section.copyWith(tiles: tiles);
        })
        .where((section) => section.tiles.isNotEmpty)
        .toList(growable: false);
  }

  bool _matchesCategoryKeyword(
    _EventListingEntry entry,
    String selectedCategory,
  ) {
    return switch (_normalize(selectedCategory)) {
      'zakat_sadaqah' => _matchesAnyKeyword(
          entry,
          const ['zakat', 'sadaqah', 'donation', 'charity', 'fund'],
        ),
      'foodbank_community_meals' => _matchesAnyKeyword(
          entry,
          const ['food', 'meal', 'dinner', 'iftar', 'pantry'],
        ),
      'fundraisers_for_mosque_support' => _matchesAnyKeyword(
          entry,
          const ['fundraiser', 'support', 'volunteer', 'drive', 'donation'],
        ),
      'iftar_gatherings' => _matchesAnyKeyword(
          entry,
          const ['iftar', 'community dinner', 'family night'],
        ),
      'suhoor_nights' => _matchesAnyKeyword(
          entry,
          const ['suhoor', 'qiyam', 'night', 'late'],
        ),
      'eid_celebrations' => _matchesAnyKeyword(
          entry,
          const ['eid', 'celebration', 'family', 'youth meetup'],
        ),
      'islamic_history_legacy' => _matchesAnyKeyword(
          entry,
          const ['history', 'legacy', 'seerah', 'heritage'],
        ),
      'quranic_studies' => _matchesAnyKeyword(
          entry,
          const ['quran', 'tafsir', 'tajweed', 'halaqa', 'study'],
        ),
      'spiritual_reflections' => _matchesAnyKeyword(
          entry,
          const ['reflection', 'lecture', 'halaqa', 'imam', 'sunnah'],
        ),
      _ => _matchesAnyKeyword(entry, [selectedCategory]),
    };
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final mosqueState = ref.watch(mosqueProvider);

    if (authState.hasValue && authState.valueOrNull == null) {
      _redirectToLogin();
      return const Scaffold(
        backgroundColor: Color(0xFFF3F2F0),
        body: LoadingState(label: 'Redirecting...'),
      );
    }

    if (authState.isLoading || !_requestedLoad) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F2F0),
        body: LoadingState(label: 'Loading event listings...'),
      );
    }

    return mosqueState.when(
      loading: () => _EventListingShell(
        location: _location,
        searchController: _searchController,
        selectedCategory: _selectedCategory,
        filterDistance: _filterDistance,
        filterType: _filterType,
        onSearchChanged: (_) => setState(() {}),
        onDistanceChanged: (value) {
          if (value == null) return;
          setState(() => _filterDistance = value);
        },
        onTypeChanged: (value) {
          if (value == null) return;
          setState(() => _filterType = value);
        },
        onClearCategory: _clearCategorySelection,
        onNearbyTap: _clearCategorySelection,
        onMosquesTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.mosqueSearch),
        onMenuTap: _openMenu,
        scrollController: _scrollController,
        sections: _visibleSections(const []),
        onTileTap: _selectTile,
        content: const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: LoadingState(label: 'Loading nearby events...'),
          ),
        ),
      ),
      error: (error, _) => _EventListingShell(
        location: _location,
        searchController: _searchController,
        selectedCategory: _selectedCategory,
        filterDistance: _filterDistance,
        filterType: _filterType,
        onSearchChanged: (_) => setState(() {}),
        onDistanceChanged: (value) {
          if (value == null) return;
          setState(() => _filterDistance = value);
        },
        onTypeChanged: (value) {
          if (value == null) return;
          setState(() => _filterType = value);
        },
        onClearCategory: _clearCategorySelection,
        onNearbyTap: _clearCategorySelection,
        onMosquesTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.mosqueSearch),
        onMenuTap: _openMenu,
        scrollController: _scrollController,
        sections: _visibleSections(const []),
        onTileTap: _selectTile,
        content: SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ErrorState(
              message: ApiErrorMapper.toUserMessage(error),
              onRetry: _bootstrap,
            ),
          ),
        ),
      ),
      data: (events) {
        final sourceMosques = widget.args.initialEvents.isNotEmpty
            ? widget.args.initialEvents
            : events;
        final publishedEntries = _buildPublishedEntries(sourceMosques);
        final filteredEntries = _applyFilters(publishedEntries);

        return _EventListingShell(
          location: _location,
          searchController: _searchController,
          selectedCategory: _selectedCategory,
          filterDistance: _filterDistance,
          filterType: _filterType,
          onSearchChanged: (_) => setState(() {}),
          onDistanceChanged: (value) {
            if (value == null) return;
            setState(() => _filterDistance = value);
          },
          onTypeChanged: (value) {
            if (value == null) return;
            setState(() => _filterType = value);
          },
          onClearCategory: _clearCategorySelection,
          onNearbyTap: _clearCategorySelection,
          onMosquesTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.mosqueSearch),
          onMenuTap: _openMenu,
          scrollController: _scrollController,
          sections: _visibleSections(publishedEntries),
          onTileTap: _selectTile,
          content: _buildResultsSliver(
            context,
            hasSavedLocation: _savedLocation?.hasCoordinates == true,
            publishedEntries: publishedEntries,
            filteredEntries: filteredEntries,
          ),
        );
      },
    );
  }

  Widget _buildResultsSliver(
    BuildContext context, {
    required bool hasSavedLocation,
    required List<_EventListingEntry> publishedEntries,
    required List<_EventListingEntry> filteredEntries,
  }) {
    final hasPublishedEntries = publishedEntries.isNotEmpty;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          const _EventSectionLabel(title: 'PUBLISHED NEAR YOU'),
          const SizedBox(height: 10),
          _ResultsSummaryCard(
            count: filteredEntries.length,
            selectedCategory: _selectedCategory,
            filterDistance: _filterDistance,
            filterType: _filterType,
          ),
          const SizedBox(height: 12),
          if (filteredEntries.isEmpty)
            _EmptyResultsCard(
              hasSavedLocation: hasSavedLocation,
              hasPublishedEntries: hasPublishedEntries,
              location: _location,
            )
          else
            Column(
              children: [
                for (var index = 0;
                    index < filteredEntries.length;
                    index++) ...[
                  _ListingEventCard(
                    details: filteredEntries[index].details,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.eventDetail,
                        arguments: EventDetailRouteArgs(
                          event: filteredEntries[index].mosque,
                          discoveryEvent: filteredEntries[index].details,
                        ),
                      );
                    },
                  ),
                  if (index != filteredEntries.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          const SizedBox(height: 84),
        ],
      ),
    );
  }
}

class _EventListingShell extends StatelessWidget {
  const _EventListingShell({
    required this.location,
    required this.searchController,
    required this.selectedCategory,
    required this.filterDistance,
    required this.filterType,
    required this.onSearchChanged,
    required this.onDistanceChanged,
    required this.onTypeChanged,
    required this.onClearCategory,
    required this.onNearbyTap,
    required this.onMosquesTap,
    required this.onMenuTap,
    required this.scrollController,
    required this.sections,
    required this.onTileTap,
    required this.content,
  });

  final String location;
  final TextEditingController searchController;
  final String? selectedCategory;
  final String filterDistance;
  final String filterType;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onDistanceChanged;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onClearCategory;
  final VoidCallback onNearbyTap;
  final VoidCallback onMosquesTap;
  final VoidCallback onMenuTap;
  final ScrollController scrollController;
  final List<_EventCategorySectionData> sections;
  final void Function(_EventCategorySectionData, _EventCategoryTileData)
      onTileTap;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F0),
      bottomNavigationBar:
          const MainBottomNavBar(activeTab: MainAppTab.discover),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _TopBar(
                  location: location,
                  onMenuTap: onMenuTap,
                ),
                Expanded(
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SearchField(
                                controller: searchController,
                                onChanged: onSearchChanged,
                              ),
                              const SizedBox(height: 8),
                              _TabStrip(onMosquesTap: onMosquesTap),
                              const SizedBox(height: 18),
                              _NearbyBanner(onTap: onNearbyTap),
                              const SizedBox(height: 12),
                              _FilterPillsRow(
                                filterDistance: filterDistance,
                                filterType: filterType,
                                onDistanceChanged: onDistanceChanged,
                                onTypeChanged: onTypeChanged,
                              ),
                              if (selectedCategory != null) ...[
                                const SizedBox(height: 10),
                                _SelectedCategoryChip(
                                  label: selectedCategory!,
                                  onClear: onClearCategory,
                                ),
                              ],
                              const SizedBox(height: 18),
                              for (final section in sections) ...[
                                _EventSectionLabel(title: section.title),
                                const SizedBox(height: 10),
                                _TileScroller(
                                  tiles: section.tiles,
                                  selectedCategory: selectedCategory,
                                  onTap: (tile) => onTileTap(section, tile),
                                ),
                                const SizedBox(height: 18),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: content,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.location,
    required this.onMenuTap,
  });

  final String location;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    size: 15,
                    color: Color(0xFF667567),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      location,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 10.6,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF667567),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF667567),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onMenuTap,
            splashRadius: 18,
            icon: const Icon(
              Icons.menu,
              size: 22,
              color: Color(0xFF3C4740),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
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
      decoration: InputDecoration(
        hintText: 'Search by city, area, street name',
        hintStyle: const TextStyle(
          fontFamily: 'Figtree',
          fontSize: 10.4,
          fontWeight: FontWeight.w500,
          color: Color(0xFF8B918C),
        ),
        prefixIcon: const Icon(
          Icons.search,
          size: 21,
          color: Color(0xFF67706B),
        ),
        filled: true,
        fillColor: const Color(0xFFD9DEDA),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(
        fontFamily: 'Figtree',
        fontSize: 10.6,
        fontWeight: FontWeight.w600,
        color: Color(0xFF4F5851),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.onMosquesTap});

  final VoidCallback onMosquesTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFD6D8D3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onMosquesTap,
              child: const Center(
                child: Text(
                  'Mosques',
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF636A64),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Events',
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A433D),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 128,
                  height: 3,
                  color: const Color(0xFF5C7565),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyBanner extends StatelessWidget {
  const _NearbyBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFA5B8AE),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          height: 72,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: _NearbyPinArt(),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'View published\nevents & classes',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 11.8,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF26312A),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Color(0xFF3A473E),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyPinArt extends StatelessWidget {
  const _NearbyPinArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFFE9EFEB),
            shape: BoxShape.circle,
          ),
        ),
        Positioned(
          bottom: 0,
          child: Transform.rotate(
            angle: 0.8,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFFE9EFEB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Color(0xFF74877A),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _FilterPillsRow extends StatelessWidget {
  const _FilterPillsRow({
    required this.filterDistance,
    required this.filterType,
    required this.onDistanceChanged,
    required this.onTypeChanged,
  });

  final String filterDistance;
  final String filterType;
  final ValueChanged<String?> onDistanceChanged;
  final ValueChanged<String?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _DropdownFilterPill(
          label: filterDistance,
          items: _EventSearchListingState._distanceOptions,
          onChanged: onDistanceChanged,
        ),
        _DropdownFilterPill(
          label: filterType,
          items: _EventSearchListingState._typeOptions,
          onChanged: onTypeChanged,
        ),
      ],
    );
  }
}

class _DropdownFilterPill extends StatelessWidget {
  const _DropdownFilterPill({
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD9DEDA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: label,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFF59655D),
          ),
          borderRadius: BorderRadius.circular(16),
          dropdownColor: const Color(0xFFF3F2F0),
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3A433D),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SelectedCategoryChip extends StatelessWidget {
  const _SelectedCategoryChip({
    required this.label,
    required this.onClear,
  });

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD4DED8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF435046),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(999),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: Color(0xFF435046),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSectionLabel extends StatelessWidget {
  const _EventSectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 11,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w700,
            color: Color(0xFF404842),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Divider(
            thickness: 1,
            height: 1,
            color: Color(0xFFD2D5D0),
          ),
        ),
      ],
    );
  }
}

class _TileScroller extends StatelessWidget {
  const _TileScroller({
    required this.tiles,
    required this.selectedCategory,
    required this.onTap,
  });

  final List<_EventCategoryTileData> tiles;
  final String? selectedCategory;
  final ValueChanged<_EventCategoryTileData> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tile = tiles[index];
          final selected = selectedCategory == tile.searchCategory;
          return _CategoryTile(
            tile: tile,
            selected: selected,
            onTap: () => onTap(tile),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.tile,
    required this.selected,
    required this.onTap,
  });

  final _EventCategoryTileData tile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF96AA9F) : const Color(0xFFA7B9AF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 134,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    tile.title,
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 11,
                      height: 1.18,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      color: const Color(0xFF253029),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: _TileArtwork(artwork: tile.artwork),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsSummaryCard extends StatelessWidget {
  const _ResultsSummaryCard({
    required this.count,
    required this.selectedCategory,
    required this.filterDistance,
    required this.filterType,
  });

  final int count;
  final String? selectedCategory;
  final String filterDistance;
  final String filterType;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (selectedCategory != null) selectedCategory!,
      if (filterType != 'All types') filterType,
      if (filterDistance != 'Any distance') filterDistance,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD9DEDA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count published items found',
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF253029),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitleParts.isEmpty
                ? 'Showing all nearby published events and classes.'
                : 'Filtered by ${subtitleParts.join(' • ')}.',
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 11,
              height: 1.3,
              color: Color(0xFF58645B),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResultsCard extends StatelessWidget {
  const _EmptyResultsCard({
    required this.hasSavedLocation,
    required this.hasPublishedEntries,
    required this.location,
  });

  final bool hasSavedLocation;
  final bool hasPublishedEntries;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD9DEDA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        !hasSavedLocation
            ? 'Save a location to load nearby mosques with published events and classes.'
            : hasPublishedEntries
                ? 'No published events or classes match this search yet. Try another category or widen the distance.'
                : 'No nearby mosques have published public event or class details for ${location.trim().isEmpty ? 'this saved location' : location} yet.',
        style: TextStyle(
          fontFamily: 'Figtree',
          fontSize: 11.4,
          height: 1.45,
          color: Color(0xFF4D5951),
        ),
      ),
    );
  }
}

class _ListingEventCard extends StatelessWidget {
  const _ListingEventCard({
    required this.details,
    required this.onTap,
  });

  final DiscoveryEvent details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFD9DEDA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 330;
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ListingPoster(details: details, stacked: true),
                    const SizedBox(height: 10),
                    _ListingEventCardBody(details: details),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ListingPoster(details: details),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ListingEventCardBody(details: details),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EventListingEntry {
  const _EventListingEntry({
    required this.mosque,
    required this.program,
    required this.isClass,
    required this.details,
  });

  final MosqueModel mosque;
  final MosqueProgramItem program;
  final bool isClass;
  final DiscoveryEvent details;
}

class _ListingPoster extends StatelessWidget {
  const _ListingPoster({
    required this.details,
    this.stacked = false,
  });

  final DiscoveryEvent details;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: stacked ? double.infinity : 108,
      height: stacked ? 108 : 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: details.posterColors,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  details.posterLabel,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Text(
                details.posterHeadline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: details.posterHeadlineFont,
                  fontSize:
                      details.posterHeadlineFont == 'Proza Libre' ? 18 : 15,
                  height: 1.08,
                  letterSpacing:
                      details.posterHeadlineFont == 'Proza Libre' ? 1.4 : 0.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingEventCardBody extends StatelessWidget {
  const _ListingEventCardBody({required this.details});

  final DiscoveryEvent details;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                details.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF26312A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Color(0xFF58655D),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFCF9850),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            details.dateLabel,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 10.4,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          details.locationLine,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 11,
            height: 1.25,
            color: Color(0xFF566159),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: details.tags
              .map((tag) => _CompactInfoChip(label: tag))
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _CompactInfoChip extends StatelessWidget {
  const _CompactInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFCBD8D1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Figtree',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4D5C52),
        ),
      ),
    );
  }
}

class _TileArtwork extends StatelessWidget {
  const _TileArtwork({required this.artwork});

  final _EventTileArtwork artwork;

  @override
  Widget build(BuildContext context) {
    return switch (artwork) {
      _EventTileArtwork.bagHand => const _BagHandArtwork(),
      _EventTileArtwork.foodBag => const _FoodBagArtwork(),
      _EventTileArtwork.fundraiser => const _FundraiserArtwork(),
      _EventTileArtwork.peopleMeal => const _PeopleMealArtwork(),
      _EventTileArtwork.suhoor => const _SuhoorArtwork(),
      _EventTileArtwork.moonStars => const _MoonStarsArtwork(),
      _EventTileArtwork.kaaba => const _KaabaArtwork(),
      _EventTileArtwork.quran => const _QuranArtwork(),
      _EventTileArtwork.minbar => const _MinbarArtwork(),
    };
  }
}

class _BagHandArtwork extends StatelessWidget {
  const _BagHandArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 52,
      child: Stack(
        children: [
          Positioned(
            right: 10,
            top: 6,
            child: Container(
              width: 30,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF607266),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 0,
            child: Container(
              width: 14,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF2EF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            left: 8,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: 40,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF2EF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodBagArtwork extends StatelessWidget {
  const _FoodBagArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 56,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 42,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFF657568),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(3),
                  bottomRight: Radius.circular(3),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 2,
            child: Container(
              width: 22,
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF4E5F53),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FundraiserArtwork extends StatelessWidget {
  const _FundraiserArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFF5B6D60),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              width: 26,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECE8),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleMealArtwork extends StatelessWidget {
  const _PeopleMealArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 52,
      child: Stack(
        children: [
          const Positioned(
            left: 4,
            bottom: 0,
            child: _SimplePerson(color: Color(0xFFE8ECE8)),
          ),
          const Positioned(
            right: 8,
            bottom: 0,
            child: _SimplePerson(color: Color(0xFF4E6054)),
          ),
          Positioned(
            left: 24,
            bottom: 6,
            child: Container(
              width: 20,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF36463E),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimplePerson extends StatelessWidget {
  const _SimplePerson({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 2),
        Container(
          width: 18,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

class _SuhoorArtwork extends StatelessWidget {
  const _SuhoorArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 48,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 62,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFF4E6054),
              borderRadius: BorderRadius.all(Radius.elliptical(31, 13)),
            ),
          ),
          const Positioned(
            top: 0,
            left: 14,
            child: _Dish(color: Color(0xFFE7ECE7)),
          ),
          const Positioned(
            top: 2,
            left: 28,
            child: _Dish(color: Color(0xFF6A7B70)),
          ),
          const Positioned(
            top: 6,
            right: 10,
            child: _Jug(color: Color(0xFF6C5D4D)),
          ),
        ],
      ),
    );
  }
}

class _Dish extends StatelessWidget {
  const _Dish({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Jug extends StatelessWidget {
  const _Jug({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _MoonStarsArtwork extends StatelessWidget {
  const _MoonStarsArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          Positioned(
            right: 10,
            top: 8,
            child: Icon(
              Icons.star_rounded,
              size: 12,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 6,
            child: Icon(
              Icons.brightness_2_rounded,
              size: 34,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _KaabaArtwork extends StatelessWidget {
  const _KaabaArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 52,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 38,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF4B5950),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(2),
                topRight: Radius.circular(2),
              ),
            ),
          ),
          Positioned(
            top: 6,
            child: Container(
              width: 38,
              height: 5,
              color: const Color(0xFFE9ECE8),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuranArtwork extends StatelessWidget {
  const _QuranArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 56,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 30,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF59695D),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Positioned(
            top: 10,
            child: Icon(
              Icons.brightness_2_outlined,
              size: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 34,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECE8),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinbarArtwork extends StatelessWidget {
  const _MinbarArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 56,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 32,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF4E6054),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(2),
                bottomRight: Radius.circular(2),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            child: Container(
              width: 20,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFE7ECE8),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCategorySectionData {
  const _EventCategorySectionData({
    required this.title,
    required this.type,
    required this.tiles,
  });

  final String title;
  final String type;
  final List<_EventCategoryTileData> tiles;

  _EventCategorySectionData copyWith({
    String? title,
    String? type,
    List<_EventCategoryTileData>? tiles,
  }) {
    return _EventCategorySectionData(
      title: title ?? this.title,
      type: type ?? this.type,
      tiles: tiles ?? this.tiles,
    );
  }
}

class _EventCategoryTileData {
  const _EventCategoryTileData({
    required this.title,
    required this.searchCategory,
    required this.artwork,
  });

  final String title;
  final String searchCategory;
  final _EventTileArtwork artwork;
}

enum _EventTileArtwork {
  bagHand,
  foodBag,
  fundraiser,
  peopleMeal,
  suhoor,
  moonStars,
  kaaba,
  quran,
  minbar,
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('&', '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
