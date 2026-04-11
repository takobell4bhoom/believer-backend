import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_provider.dart';
import '../data/mosque_provider.dart';
import '../models/mosque_model.dart';
import '../navigation/app_startup.dart';
import '../navigation/app_routes.dart';
import '../screens/event_search_listing.dart';
import '../screens/location_setup_screen.dart';
import '../services/location_preferences_service.dart';
import '../widgets/common/main_bottom_nav_bar.dart';

class EventsSearch extends ConsumerStatefulWidget {
  const EventsSearch({super.key});

  @override
  ConsumerState<EventsSearch> createState() => _EventsSearchState();
}

class _EventsSearchState extends ConsumerState<EventsSearch> {
  final LocationPreferencesService _locationPreferencesService =
      LocationPreferencesService();
  final TextEditingController _searchController = TextEditingController();

  String _location = 'Location unavailable';
  SavedUserLocation? _savedLocation;
  bool _requestedLoad = false;
  bool _redirectingToLogin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadLocation();
    await _loadNearbyData();
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
      // Screen keeps its structure even if the async fetch fails.
    }
  }

  void _redirectToLogin() {
    if (_redirectingToLogin || !mounted) return;
    _redirectingToLogin = true;
    scheduleUnauthenticatedRedirect(context);
  }

  Future<void> _openLocation() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.locationSetup,
      arguments: const LocationSetupFlowArgs(nextRoute: AppRoutes.map),
    );
    if (!mounted) {
      return;
    }
    await _bootstrap();
  }

  void _openMenu() {
    Navigator.of(context).pushNamed(AppRoutes.profileSettings);
  }

  List<_EventCategoryTileData> _filterTiles(
      List<_EventCategoryTileData> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where((item) => item.title.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _openEventListing({
    required List<MosqueModel> mosques,
    String? selectedCategory,
    String initialType = 'All types',
  }) {
    Navigator.of(context).pushNamed(
      AppRoutes.nearbyEvents,
      arguments: EventSearchListingRouteArgs(
        initialEvents: mosques,
        selectedCategory: selectedCategory,
        initialType: initialType,
        initialSearchQuery: _searchController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final mosqueState = ref.watch(mosqueProvider);

    if (authState.hasValue && authState.valueOrNull == null) {
      _redirectToLogin();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authState.isLoading || !_requestedLoad) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mosques = mosqueState.valueOrNull ?? const <MosqueModel>[];
    final charityTiles = _filterTiles(_charityTiles);
    final celebrationTiles = _filterTiles(_celebrationTiles);
    final knowledgeTiles = _filterTiles(_knowledgeTiles);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F0),
      bottomNavigationBar:
          const MainBottomNavBar(activeTab: MainAppTab.discover),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              location: _location,
              onLocationTap: _openLocation,
              onMenuTap: _openMenu,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SearchField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        _TabStrip(
                          onMosquesTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.mosqueSearch),
                        ),
                        const SizedBox(height: 18),
                        _NearbyBanner(
                          onTap: () => _openEventListing(mosques: mosques),
                        ),
                        const SizedBox(height: 18),
                        const _SectionTitle(title: 'CHARITY'),
                        const SizedBox(height: 10),
                        _TileScroller(
                          tiles: charityTiles,
                          onTap: (tile) => _openEventListing(
                            mosques: mosques,
                            selectedCategory: tile.searchCategory,
                            initialType: 'Charity',
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _SectionTitle(title: 'CELEBRATIONS'),
                        const SizedBox(height: 10),
                        _TileScroller(
                          tiles: celebrationTiles,
                          onTap: (tile) => _openEventListing(
                            mosques: mosques,
                            selectedCategory: tile.searchCategory,
                            initialType: 'Celebration',
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _SectionTitle(title: 'ISLAMIC KNOWLEDGE'),
                        const SizedBox(height: 10),
                        _TileScroller(
                          tiles: knowledgeTiles,
                          onTap: (tile) => _openEventListing(
                            mosques: mosques,
                            selectedCategory: tile.searchCategory,
                            initialType: 'Islamic Knowledge',
                          ),
                        ),
                        const SizedBox(height: 72),
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.location,
    required this.onLocationTap,
    required this.onMenuTap,
  });

  final String location;
  final VoidCallback onLocationTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: onLocationTap,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF667567),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                shape: const RoundedRectangleBorder(),
              ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

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
    required this.onTap,
  });

  final List<_EventCategoryTileData> tiles;
  final ValueChanged<_EventCategoryTileData> onTap;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return Container(
        height: 116,
        decoration: BoxDecoration(
          color: const Color(0xFFD5DED6),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          'No categories match this search.',
          style: TextStyle(
            fontFamily: 'Figtree',
            fontSize: 10.6,
            fontWeight: FontWeight.w600,
            color: Color(0xFF59635C),
          ),
        ),
      );
    }

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tile = tiles[index];
          return _CategoryTile(
            tile: tile,
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
    required this.onTap,
  });

  final _EventCategoryTileData tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFA7B9AF),
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
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 11,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF253029),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: tile.artwork,
                ),
              ],
            ),
          ),
        ),
      ),
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
  final Widget artwork;
}

const _charityTiles = <_EventCategoryTileData>[
  _EventCategoryTileData(
    title: 'Zakat &\nsadaqah',
    searchCategory: 'Zakat & sadaqah',
    artwork: _BagHandArtwork(),
  ),
  _EventCategoryTileData(
    title: 'Foodbank &\ncommunity\nmeals',
    searchCategory: 'Foodbank & community meals',
    artwork: _FoodBagArtwork(),
  ),
  _EventCategoryTileData(
    title: 'Fundraisers for\nmosque\nsupport',
    searchCategory: 'Fundraisers for mosque support',
    artwork: _FundraiserArtwork(),
  ),
];

const _celebrationTiles = <_EventCategoryTileData>[
  _EventCategoryTileData(
    title: 'Iftar\ngatherings',
    searchCategory: 'Iftar gatherings',
    artwork: _PeopleMealArtwork(),
  ),
  _EventCategoryTileData(
    title: 'Suhoor\nnights',
    searchCategory: 'Suhoor nights',
    artwork: _SuhoorArtwork(),
  ),
  _EventCategoryTileData(
    title: 'Eid\ncelebrations',
    searchCategory: 'Eid celebrations',
    artwork: _MoonStarsArtwork(),
  ),
];

const _knowledgeTiles = <_EventCategoryTileData>[
  _EventCategoryTileData(
    title: 'Islamic history &\nlegacy',
    searchCategory: 'Islamic history & legacy',
    artwork: _KaabaArtwork(),
  ),
  _EventCategoryTileData(
    title: 'Qur’anic\nstudies',
    searchCategory: 'Qur’anic studies',
    artwork: _QuranArtwork(),
  ),
  _EventCategoryTileData(
    title: 'Spiritual\nreflections',
    searchCategory: 'Spiritual reflections',
    artwork: _MinbarArtwork(),
  ),
];

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
              decoration: BoxDecoration(
                color: const Color(0xFF607266),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 3,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(
                width: 34,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1EC),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            left: 32,
            bottom: 8,
            child: Container(
              width: 16,
              height: 16,
              color: const Color(0xFFF0F1EC),
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
            left: 10,
            bottom: 2,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 34,
                height: 40,
                color: const Color(0xFF65766B),
              ),
            ),
          ),
          Positioned(
            left: 19,
            top: 7,
            child: Container(
              width: 18,
              height: 12,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(width: 4, color: Color(0xFF65766B)),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 8,
            child: Container(
              width: 8,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF4F6A57),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF4F6A57),
                borderRadius: BorderRadius.circular(10),
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
      width: 66,
      height: 58,
      child: Stack(
        children: [
          Positioned(
            right: 10,
            bottom: 4,
            child: Container(
              width: 38,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF5A6E60),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 10,
            child: Container(
              width: 26,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF6E8076),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 5,
            child: Container(
              width: 34,
              height: 6,
              color: const Color(0xFFF0F1EC),
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
      width: 66,
      height: 52,
      child: Stack(
        children: [
          const Positioned(
            left: 8,
            bottom: 0,
            child: _PersonArt(
              shirt: Color(0xFF44524A),
              head: Color(0xFFF3E1D7),
            ),
          ),
          const Positioned(
            left: 28,
            bottom: 0,
            child: _PersonArt(
              shirt: Color(0xFF6D8075),
              head: Color(0xFFF3E1D7),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 4,
            child: Container(
              width: 18,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF44524A),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonArt extends StatelessWidget {
  const _PersonArt({
    required this.shirt,
    required this.head,
  });

  final Color shirt;
  final Color head;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 40,
      child: Stack(
        children: [
          Positioned(
            left: 5,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: head,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 2,
            bottom: 0,
            child: Container(
              width: 18,
              height: 22,
              decoration: BoxDecoration(
                color: shirt,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuhoorArtwork extends StatelessWidget {
  const _SuhoorArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 54,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            bottom: 2,
            child: Container(
              width: 52,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF596A60),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 10,
            child: Container(
              width: 16,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1EC),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 9,
            child: _CupArtwork(),
          ),
          Positioned(
            left: 22,
            top: 4,
            child: _CupArtwork(),
          ),
          Positioned(
            right: 4,
            top: 0,
            child: Container(
              width: 14,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF4D5D52),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CupArtwork extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1EC),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _MoonStarsArtwork extends StatelessWidget {
  const _MoonStarsArtwork();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 62,
      height: 50,
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 8,
            child: Icon(
              Icons.mode_night_outlined,
              size: 28,
              color: Color(0xFF4C5F53),
            ),
          ),
          Positioned(
            left: 18,
            top: 14,
            child: Icon(
              Icons.star,
              size: 12,
              color: Color(0xFFF0F1EC),
            ),
          ),
          Positioned(
            left: 30,
            bottom: 10,
            child: Icon(
              Icons.star,
              size: 10,
              color: Color(0xFFF0F1EC),
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
      width: 62,
      height: 50,
      child: Stack(
        children: [
          Positioned(
            right: 10,
            bottom: 6,
            child: Container(
              width: 30,
              height: 24,
              color: const Color(0xFF4F6154),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 28,
            child: Container(
              width: 30,
              height: 4,
              color: const Color(0xFFF0F1EC),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 0,
            child: Container(
              width: 24,
              height: 4,
              color: const Color(0xFFF0F1EC),
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
      width: 64,
      height: 54,
      child: Stack(
        children: [
          Positioned(
            right: 12,
            bottom: 8,
            child: Container(
              width: 28,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF55695A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Positioned(
            right: 21,
            bottom: 23,
            child: Icon(
              Icons.nightlight_round,
              size: 14,
              color: Color(0xFFF0F1EC),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 3,
            child: Container(
              width: 34,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1EC),
                borderRadius: BorderRadius.circular(4),
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
      width: 62,
      height: 54,
      child: Stack(
        children: [
          Positioned(
            right: 12,
            bottom: 5,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF52665A),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: 20,
            child: Container(
              width: 12,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF6F8176),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Positioned(
            right: 26,
            top: 2,
            child: Container(
              width: 4,
              height: 18,
              color: const Color(0xFF52665A),
            ),
          ),
        ],
      ),
    );
  }
}
