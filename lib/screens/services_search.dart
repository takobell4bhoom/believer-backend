import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../data/auth_provider.dart';
import '../features/business_registration/business_registration_flow_controller.dart';
import '../features/business_registration/business_registration_models.dart';
import '../screens/business_registration_basic/business_registration_basic_taxonomy.dart';
import '../models/service.dart';
import '../navigation/app_routes.dart';
import '../screens/business_listing.dart';
import '../services/location_preferences_service.dart';
import '../services/services_search_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/common/async_states.dart';
import '../widgets/common/app_top_nav_bar.dart';
import '../widgets/common/main_bottom_nav_bar.dart';

class ServicesSearch extends StatelessWidget {
  const ServicesSearch({
    super.key,
    this.categoryName = 'Halal Food & Restaurants',
    this.servicesSearchService,
  });

  final String categoryName;
  final ServicesSearchService? servicesSearchService;

  @override
  Widget build(BuildContext context) {
    return _ServicesSearchBody(
      categoryName: categoryName,
      servicesSearchService: servicesSearchService ?? ServicesSearchService(),
    );
  }
}

class _ServicesSearchBody extends ConsumerStatefulWidget {
  const _ServicesSearchBody({
    required this.categoryName,
    required this.servicesSearchService,
  });

  final String categoryName;
  final ServicesSearchService servicesSearchService;

  @override
  ConsumerState<_ServicesSearchBody> createState() =>
      _ServicesSearchBodyState();
}

class _ServicesSearchBodyState extends ConsumerState<_ServicesSearchBody> {
  static final List<String> _serviceCategories =
      businessRegistrationBasicTaxonomy
          .map((group) => group.label)
          .toList(growable: false);
  static final Map<String, String> _serviceCategoryLookup = <String, String>{
    for (final group in businessRegistrationBasicTaxonomy)
      _normalizeCategoryKey(group.label): group.label,
    for (final group in businessRegistrationBasicTaxonomy)
      for (final item in group.items)
        _normalizeCategoryKey(item.label): group.label,
    _normalizeCategoryKey('Halal Food'): 'Halal Food & Restaurants',
    _normalizeCategoryKey('Islamic Books'): 'Islamic E-commerce & Retail',
  };

  static const _defaultSort = _ServiceFilterOption(
    label: 'New',
    sortKey: 'new',
  );
  static const _filters = <_ServiceFilterOption>[
    _ServiceFilterOption(
      label: 'Top Rated',
      backendFilters: <String>['Top Rated'],
      sortKey: 'top_rated',
    ),
    _ServiceFilterOption(label: 'Popular', sortKey: 'popular'),
    _defaultSort,
  ];

  _ServiceFilterOption _selectedFilter = _defaultSort;
  final LocationPreferencesService _locationPreferencesService =
      LocationPreferencesService();
  late String _selectedCategoryName;
  bool _isLoading = true;
  String? _errorMessage;
  String _locationLabel = 'Location unavailable';
  List<Service> _services = const <Service>[];
  List<Service> _allServices = const <Service>[];
  bool _isFilterPanelOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryName = _resolveInitialCategory(widget.categoryName);
    _loadLocation();
    _loadServices();
    Future<void>.microtask(() {
      ref
          .read(businessRegistrationFlowControllerProvider.notifier)
          .refreshListingStatus();
    });
  }

  @override
  void didUpdateWidget(covariant _ServicesSearchBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryName != widget.categoryName) {
      _selectedCategoryName = _resolveInitialCategory(widget.categoryName);
      _selectedFilter = _defaultSort;
      _loadServices();
    }
  }

  String _resolveInitialCategory(String categoryName) {
    return _serviceCategories.contains(categoryName)
        ? categoryName
        : _serviceCategories.first;
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final services = await widget.servicesSearchService.fetchServices(
        category: _selectedCategoryName,
        filters: _selectedFilter.backendFilters,
        sort: _selectedFilter.sortKey,
      );

      if (!mounted) return;
      setState(() {
        _services = services;
        if (_selectedFilter.isInclusiveDefault) {
          _allServices = services;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadLocation() async {
    try {
      final location = await _locationPreferencesService.loadCurrentLocation();
      if (!mounted) return;
      setState(() {
        _locationLabel = location == LocationPreferencesService.defaultLocation
            ? 'Location unavailable'
            : location;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationLabel = 'Location unavailable');
    }
  }

  Future<void> _openBusinessRegistrationEntry() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.businessRegistrationIntro,
      arguments: const BusinessRegistrationFlowRouteArgs(
        exitRouteName: AppRoutes.services,
      ),
    );
  }

  _BusinessRegistrationEntryState _buildBusinessRegistrationEntryState({
    required AuthSession? authSession,
    required AsyncValue<BusinessRegistrationFlowState> flowState,
  }) {
    if (authSession == null) {
      return const _BusinessRegistrationEntryState(
        title: 'Run a business like this?',
        subtitle:
            'Public services only show approved listings. Sign in to submit your business for review.',
        actionLabel: 'Sign in to register',
      );
    }

    return flowState.when(
      data: (value) {
        final draft = value.draft;
        switch (draft.status) {
          case BusinessRegistrationSubmissionStatus.live:
            if (_isLoading || _errorMessage != null) {
              return const _BusinessRegistrationEntryState(
                title: 'Your listing is live',
                subtitle:
                    'Checking where it appears in public services so this page stays honest.',
                actionLabel: 'View status',
              );
            }

            final liveCategory = _resolveCanonicalCategoryForPublicCategory(
              draft.publicCategory,
            );
            final appearsInCurrentCategory = draft.id != null &&
                _allServices.any((service) => service.id == draft.id);

            if (liveCategory == _selectedCategoryName &&
                appearsInCurrentCategory) {
              return _BusinessRegistrationEntryState(
                title: 'Your listing is live',
                subtitle:
                    'It is currently showing in $_selectedCategoryName. Open your listing status to confirm the published details are in good shape.',
                actionLabel: 'View status',
              );
            }

            if (liveCategory == _selectedCategoryName) {
              return _BusinessRegistrationEntryState(
                title: 'Your listing is live',
                subtitle:
                    'It is published in $_selectedCategoryName, but it is not appearing in the current public results yet. Open your listing status to review the published category details.',
                actionLabel: 'View status',
              );
            }

            if (liveCategory != null) {
              return _BusinessRegistrationEntryState(
                title: 'Your listing is live in $liveCategory',
                subtitle:
                    'You are currently browsing $_selectedCategoryName. Switch to $liveCategory to find your public listing on this screen.',
                actionLabel: 'View status',
              );
            }

            return const _BusinessRegistrationEntryState(
              title: 'Your listing is live',
              subtitle:
                  'Open your listing status to confirm the published category and details are in good shape.',
              actionLabel: 'View status',
            );
          case BusinessRegistrationSubmissionStatus.rejected:
            return const _BusinessRegistrationEntryState(
              title: 'Your listing needs changes',
              subtitle:
                  'Review the moderation feedback, update the details, and resubmit when ready.',
              actionLabel: 'Review updates',
            );
          case BusinessRegistrationSubmissionStatus.underReview:
            return const _BusinessRegistrationEntryState(
              title: 'Your listing is under review',
              subtitle:
                  'Check the latest status and stay ready to update details once it goes live.',
              actionLabel: 'View status',
            );
          case BusinessRegistrationSubmissionStatus.draft:
            if (draft.hasAnySavedInput) {
              return _BusinessRegistrationEntryState(
                title: 'Resume your listing draft',
                subtitle: draft.shouldResumeContactStep
                    ? 'You already finished the basics. Continue from contact and location.'
                    : 'Pick up where you left off and finish setting up your business.',
                actionLabel: 'Resume draft',
              );
            }
            return const _BusinessRegistrationEntryState(
              title: 'Own one of these services?',
              subtitle:
                  'Start a free listing without interrupting the public services experience.',
              actionLabel: 'Get started',
            );
        }
      },
      loading: () => const _BusinessRegistrationEntryState(
        title: 'Business tools for owners',
        subtitle: 'Checking whether you already have a draft or live listing.',
        actionLabel: 'Open listing tools',
      ),
      error: (_, __) => const _BusinessRegistrationEntryState(
        title: 'Business tools for owners',
        subtitle:
            'Start or resume your listing from here while public service discovery stays unchanged.',
        actionLabel: 'Open listing tools',
      ),
    );
  }

  static String _normalizeCategoryKey(String value) {
    return value.trim().toLowerCase();
  }

  String? _resolveCanonicalCategoryForPublicCategory(
    BusinessRegistrationPublicCategory? publicCategory,
  ) {
    final itemLabel = publicCategory?.itemLabel?.trim();
    final groupLabel = publicCategory?.groupLabel?.trim();

    if (itemLabel != null && itemLabel.isNotEmpty) {
      final itemCategory =
          _serviceCategoryLookup[_normalizeCategoryKey(itemLabel)];
      if (itemCategory != null) {
        return itemCategory;
      }
    }

    if (groupLabel != null && groupLabel.isNotEmpty) {
      return _serviceCategoryLookup[_normalizeCategoryKey(groupLabel)];
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final filterCount = _selectedFilter.isInclusiveDefault ? 0 : 1;
    final authSession = ref.watch(authProvider).valueOrNull;
    final businessRegistrationState =
        ref.watch(businessRegistrationFlowControllerProvider);
    final registrationEntryState = _buildBusinessRegistrationEntryState(
      authSession: authSession,
      flowState: businessRegistrationState,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      bottomNavigationBar:
          const MainBottomNavBar(activeTab: MainAppTab.services),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  AppTopNavBar(
                    title: _selectedCategoryName,
                    subtitle: _locationLabel,
                    trailing: _ServicesFilterToggleButton(
                      isOpen: _isFilterPanelOpen,
                      hasActiveFilter: filterCount > 0,
                      onTap: () {
                        setState(
                          () => _isFilterPanelOpen = !_isFilterPanelOpen,
                        );
                      },
                    ),
                    bottomSpacing: 12,
                    padding: EdgeInsets.zero,
                    bottom: Column(
                      children: [
                        const Divider(height: 1, color: Color(0xFFE2E2DE)),
                        if (_isFilterPanelOpen) ...[
                          const SizedBox(height: 16),
                          _ServicesFilterPanel(
                            categories: _serviceCategories,
                            selectedCategory: _selectedCategoryName,
                            onCategorySelected: (category) {
                              if (_selectedCategoryName == category) return;
                              setState(() {
                                _selectedCategoryName = category;
                                _selectedFilter = _defaultSort;
                              });
                              _loadServices();
                            },
                            filters: _filters,
                            selectedFilter: _selectedFilter,
                            onFilterSelected: (filter) {
                              setState(() {
                                _selectedFilter = _selectedFilter == filter
                                    ? _defaultSort
                                    : filter;
                              });
                              _loadServices();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BusinessRegistrationEntryCard(
                    title: registrationEntryState.title,
                    subtitle: registrationEntryState.subtitle,
                    actionLabel: registrationEntryState.actionLabel,
                    onTap: _openBusinessRegistrationEntry,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_services.length} Results',
                          style: const TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF455146),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          filterCount == 1
                              ? '1 Filter Applied'
                              : 'Sorted by New',
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF455146),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final selectedFilter = _selectedFilter;
    final showsFilteredEmptyState = !selectedFilter.isInclusiveDefault &&
        _allServices.isNotEmpty &&
        _services.isEmpty;

    if (_isLoading) {
      return _buildScrollableState(
        const LoadingState(label: 'Loading services...'),
      );
    }

    if (_errorMessage != null) {
      return _buildScrollableState(
        ErrorState(
          message: _errorMessage!,
          onRetry: _loadServices,
        ),
      );
    }

    if (_services.isEmpty) {
      return _buildScrollableState(
        EmptyState(
          title: showsFilteredEmptyState
              ? 'No live listings match ${selectedFilter.label} in $_selectedCategoryName.'
              : 'No approved listings are live in $_selectedCategoryName yet.',
          subtitle: showsFilteredEmptyState
              ? 'Clear the active filter to browse all approved live listings in this category.'
              : 'Try another category or check back later as more businesses complete review.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      itemCount: _services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _ServiceSearchCard(
          display: _ServiceCardDisplay.fromService(
            _services[index],
            index: index,
          ),
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.businessListing,
              arguments: BusinessListingRouteArgs(service: _services[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildScrollableState(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}

class _ServiceCategoryBar extends StatelessWidget {
  const _ServiceCategoryBar({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse categories',
          style: TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF455146),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in categories) ...[
                _ServicesFilterChip(
                  label: category,
                  selected: category == selectedCategory,
                  onTap: () => onSelected(category),
                ),
                if (category != categories.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BusinessRegistrationEntryState {
  const _BusinessRegistrationEntryState({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
}

class _ServicesFilterPanel extends StatelessWidget {
  const _ServicesFilterPanel({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final List<_ServiceFilterOption> filters;
  final _ServiceFilterOption selectedFilter;
  final ValueChanged<_ServiceFilterOption> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1EB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9D8D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ServiceCategoryBar(
            categories: categories,
            selectedCategory: selectedCategory,
            onSelected: onCategorySelected,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFD8D8D2)),
          const SizedBox(height: 14),
          _ServicesFilterBar(
            filters: filters,
            selectedFilter: selectedFilter,
            onSelected: onFilterSelected,
          ),
        ],
      ),
    );
  }
}

class _ServicesFilterBar extends StatelessWidget {
  const _ServicesFilterBar({
    required this.filters,
    required this.selectedFilter,
    required this.onSelected,
  });

  final List<_ServiceFilterOption> filters;
  final _ServiceFilterOption selectedFilter;
  final ValueChanged<_ServiceFilterOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sort & filter',
          style: TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF455146),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in filters)
              _ServicesFilterChip(
                label: filter.label,
                selected: filter == selectedFilter,
                onTap: () => onSelected(filter),
              ),
          ],
        ),
      ],
    );
  }
}

class _BusinessRegistrationEntryCard extends StatelessWidget {
  const _BusinessRegistrationEntryCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E2D2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD2C6AC)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F3E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    size: 20,
                    color: Color(0xFF5E5640),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: AppTypography.figtreeFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B3128),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: AppTypography.figtreeFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: Color(0xFF5B6253),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        actionLabel,
                        style: const TextStyle(
                          fontFamily: AppTypography.figtreeFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3C4537),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF5A624E),
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

class _ServicesFilterToggleButton extends StatelessWidget {
  const _ServicesFilterToggleButton({
    required this.isOpen,
    required this.hasActiveFilter,
    required this.onTap,
  });

  final bool isOpen;
  final bool hasActiveFilter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: isOpen ? const Color(0xFFE8ECE6) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const ValueKey('services-filter-toggle'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                isOpen ? Icons.close_rounded : Icons.tune_rounded,
                size: 24,
                color: const Color(0xFF58715D),
              ),
            ),
          ),
        ),
        if (hasActiveFilter)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFD37A66),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
      ],
    );
  }
}

class _ServicesFilterChip extends StatelessWidget {
  const _ServicesFilterChip({
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
      color: selected ? const Color(0xFFF2F1EC) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFA3AAA1)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.figtreeFamily,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF59645A),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceSearchCard extends StatelessWidget {
  const _ServiceSearchCard({
    required this.display,
    required this.onTap,
  });

  final _ServiceCardDisplay display;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width <= 360;

    return Material(
      color: const Color(0xFFE2E4E1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: isCompact ? 68 : 76,
                height: isCompact ? 68 : 76,
                decoration: BoxDecoration(
                  color: Color(
                    display.logoTileBackgroundColor ?? 0xFFF1C69D,
                  ),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: display.logoBytes != null
                      ? Image.memory(
                          display.logoBytes!,
                          fit: BoxFit.cover,
                        )
                      : const Center(child: _ServiceBrandMark()),
                ),
              ),
              SizedBox(width: isCompact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            display.name,
                            maxLines: isCompact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.figtreeFamily,
                              fontSize: isCompact ? 14 : 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF26312A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Color(0xFFF0A12A),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              display.rating,
                              style: const TextStyle(
                                fontFamily: AppTypography.figtreeFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF5D6D60),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF5D6D60),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 4 : 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 15,
                          color: Color(0xFF69746B),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            display.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.figtreeFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6A746B),
                            ),
                          ),
                        ),
                        if (display.distanceLabel != null) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.navigation_rounded,
                            size: 12,
                            color: Color(0xFF6A746B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            display.distanceLabel!,
                            style: const TextStyle(
                              fontFamily: AppTypography.figtreeFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6A746B),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: isCompact ? 6 : 10),
                    Text(
                      '${display.priceLabel}  •  ${display.deliveryLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: isCompact ? 11 : 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5D635E),
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

class _ServiceBrandMark extends StatelessWidget {
  const _ServiceBrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: 0.79,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF7C6A63),
                    width: 2,
                  ),
                ),
              ),
            ),
            const Icon(
              Icons.grid_3x3_rounded,
              size: 20,
              color: Color(0xFF7C6A63),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'BARAKAH',
          style: TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 4.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            color: Color(0xFF8D7D75),
          ),
        ),
      ],
    );
  }
}

class _ServiceFilterOption {
  const _ServiceFilterOption({
    required this.label,
    this.backendFilters = const <String>[],
    this.sortKey = 'new',
  });

  final String label;
  final List<String> backendFilters;
  final String sortKey;

  bool get isInclusiveDefault => sortKey == 'new' && backendFilters.isEmpty;
}

class _ServiceCardDisplay {
  const _ServiceCardDisplay({
    required this.name,
    required this.location,
    required this.distanceLabel,
    required this.priceLabel,
    required this.deliveryLabel,
    required this.rating,
    required this.logoBytes,
    required this.logoTileBackgroundColor,
  });

  final String name;
  final String location;
  final String? distanceLabel;
  final String priceLabel;
  final String deliveryLabel;
  final String rating;
  final Uint8List? logoBytes;
  final int? logoTileBackgroundColor;

  factory _ServiceCardDisplay.fromService(Service service,
      {required int index}) {
    final fallbackDistances = <String>[
      '0.2 mi away',
      '0.2 mi away',
      '0.2 mi away'
    ];

    return _ServiceCardDisplay(
      name: service.name,
      location: service.location,
      distanceLabel:
          service.location.trim().isEmpty ? null : fallbackDistances[index % 3],
      priceLabel: switch (service.priceRange.trim()) {
        '\$' => '\$15 - \$30/person',
        '\$\$' => '\$20 - \$40/person',
        '\$\$\$' => '\$35 - \$60/person',
        _ => service.priceRange,
      },
      deliveryLabel: _deliveryLabel(service.deliveryInfo),
      rating: service.rating.toStringAsFixed(1),
      logoBytes: service.logoBytes,
      logoTileBackgroundColor: service.logoTileBackgroundColor,
    );
  }

  static String _deliveryLabel(String source) {
    final normalized = source.trim().toLowerCase();
    if (normalized.contains('30-40')) {
      return '30-40 mins delivery';
    }
    if (normalized.contains('pickup and delivery')) {
      return 'Pickup & delivery';
    }
    if (normalized.contains('same day')) {
      return 'Same day delivery';
    }
    return source.trim().isEmpty
        ? 'Delivery details unavailable'
        : source.trim();
  }
}
