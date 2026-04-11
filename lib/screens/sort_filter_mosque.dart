import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SortFilterMosque extends StatelessWidget {
  const SortFilterMosque({
    super.key,
    this.initialFilters,
  });

  final Map<String, dynamic>? initialFilters;

  @override
  Widget build(BuildContext context) {
    return _SortFilterMosqueBody(initialFilters: initialFilters);
  }
}

class _SortFilterMosqueBody extends StatefulWidget {
  const _SortFilterMosqueBody({
    this.initialFilters,
  });

  final Map<String, dynamic>? initialFilters;

  @override
  State<_SortFilterMosqueBody> createState() => _SortFilterMosqueBodyState();
}

class _SortFilterMosqueBodyState extends State<_SortFilterMosqueBody> {
  static const _defaultSortBy = 'Nearest Mosque';
  static const _defaultRadius = 3;
  static const _defaultSect = 'Any';
  static const _defaultAsrTime = 'Any';
  static const _defaultReviewRating = 'Any';
  static const _defaultTiming = 'All mosques';
  static const _sortOptions = <String>[
    'Nearest Mosque',
    'Earlier Dhuhr',
  ];
  static const _distanceOptions = <int>[3, 5, 10, 25];
  static const _sectOptions = <String>['Any', 'Sunni', 'Shia'];
  static const _asarOptions = <String>[
    'Any',
    'Asr listed',
    '5:00 PM or later',
  ];
  static const _reviewOptions = <String>['Any', '4.0+', '3.0+'];
  static const _timingOptions = <String>[
    'All mosques',
    'Prayer times listed',
  ];
  static const _facilityOptions = <String>[
    'Women Prayer Area',
    'Wheelchair Access',
    'Parking',
    'Wudu',
    'Washroom',
  ];
  static const _classOptions = <String>[
    'Classes listed',
    'Qur\'an in title',
    'Halaqa in title',
  ];
  static const _eventOptions = <String>[
    'Events listed',
    'Family in title',
    'Youth in title',
  ];

  late String _sortBy;
  late int _radius;
  late String _sect;
  late String _asarTime;
  late String _reviewRating;
  late String _timing;
  late Set<String> _facilities;
  late Set<String> _classes;
  late Set<String> _events;
  bool _rememberFilters = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFilters;
    _sortBy = initial?['sortBy'] as String? ?? _defaultSortBy;
    final radius = initial?['radius'];
    _radius = radius is int ? radius : _defaultRadius;
    _sect = initial?['sect'] as String? ?? _defaultSect;
    _asarTime = initial?['asarTime'] as String? ?? _defaultAsrTime;
    _reviewRating = initial?['reviewRating'] as String? ?? _defaultReviewRating;
    _timing = initial?['timing'] as String? ?? _defaultTiming;
    _facilities = _toStringSet(initial?['facilities']);
    _classes = _toStringSet(initial?['classes']);
    _events = _toStringSet(initial?['events']);
  }

  Set<String> _toStringSet(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toSet();
    }
    return <String>{};
  }

  void _clearFilters() {
    setState(() {
      _sortBy = _defaultSortBy;
      _radius = _defaultRadius;
      _sect = _defaultSect;
      _asarTime = _defaultAsrTime;
      _reviewRating = _defaultReviewRating;
      _timing = _defaultTiming;
      _facilities = <String>{};
      _classes = <String>{};
      _events = <String>{};
    });
  }

  void _toggleSelection(Set<String> values, String item) {
    setState(() {
      if (values.contains(item)) {
        values.remove(item);
      } else {
        values.add(item);
      }
    });
  }

  void _applyFilters() {
    Navigator.of(context).pop(<String, dynamic>{
      'sortBy': _sortBy,
      'radius': _radius,
      'sect': _sect,
      'asarTime': _asarTime,
      'reviewRating': _reviewRating,
      'timing': _timing,
      'facilities': _facilities.toList(growable: false),
      'classes': _classes.toList(growable: false),
      'events': _events.toList(growable: false),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(
                          onBack: () => Navigator.of(context).pop(),
                          onClear: _clearFilters,
                          rememberFilters: _rememberFilters,
                          onRememberChanged: (value) {
                            setState(() => _rememberFilters = value);
                          },
                        ),
                        const SizedBox(height: 18),
                        _SectionBlock(
                          title: 'SORT BY',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in _sortOptions)
                                _ChoiceChipCard(
                                  label: option,
                                  isSelected: _sortBy == option,
                                  useRadio: true,
                                  onTap: () => setState(() => _sortBy = option),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionBlock(
                          title: 'DISTANCE',
                          child: _DistanceSection(
                            radius: _radius,
                            options: _distanceOptions,
                            onChanged: (value) =>
                                setState(() => _radius = value),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionBlock(
                          title: 'SECT',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in _sectOptions)
                                _ChoiceChipCard(
                                  label: option,
                                  isSelected: _sect == option,
                                  useRadio: true,
                                  onTap: () => setState(() => _sect = option),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionBlock(
                          title: 'ASR TIME',
                          child: Column(
                            children: [
                              for (final option in _asarOptions) ...[
                                _SingleRowOption(
                                  label: option,
                                  isSelected: _asarTime == option,
                                  onTap: () =>
                                      setState(() => _asarTime = option),
                                ),
                                if (option != _asarOptions.last)
                                  const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionBlock(
                          title: 'REVIEWS',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in _reviewOptions)
                                _ChoiceChipCard(
                                  label: option,
                                  isSelected: _reviewRating == option,
                                  useRadio: true,
                                  icon: option == 'Any' ? null : Icons.star,
                                  onTap: () =>
                                      setState(() => _reviewRating = option),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionBlock(
                          title: 'TIMINGS',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in _timingOptions)
                                _ChoiceChipCard(
                                  label: option,
                                  isSelected: _timing == option,
                                  useRadio: true,
                                  onTap: () => setState(() => _timing = option),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionBlock(
                          title: 'FACILITIES',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in _facilityOptions)
                                _GridOptionCard(
                                  label: option,
                                  isSelected: _facilities.contains(option),
                                  onTap: () =>
                                      _toggleSelection(_facilities, option),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionBlock(
                          title: 'MOSQUE CLASSES & HALAQAS',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in _classOptions)
                                _GridOptionCard(
                                  label: option,
                                  isSelected: _classes.contains(option),
                                  onTap: () =>
                                      _toggleSelection(_classes, option),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionBlock(
                          title: 'MOSQUE EVENTS',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in _eventOptions)
                                _GridOptionCard(
                                  label: option,
                                  isSelected: _events.contains(option),
                                  onTap: () =>
                                      _toggleSelection(_events, option),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _BottomActions(
              onClose: () => Navigator.of(context).pop(),
              onApply: _applyFilters,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onClear,
    required this.rememberFilters,
    required this.onRememberChanged,
  });

  final VoidCallback onBack;
  final VoidCallback onClear;
  final bool rememberFilters;
  final ValueChanged<bool> onRememberChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.primaryText,
              ),
            ),
            const Expanded(
              child: Text(
                'Sort & Filter',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondaryText,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              ),
              child: const Text(
                'Clear filters',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Checkbox(
              value: rememberFilters,
              onChanged: (value) => onRememberChanged(value ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              activeColor: AppColors.accent,
              side: const BorderSide(color: AppColors.lineStrong),
            ),
            const SizedBox(width: 2),
            const Text(
              'Remember my filters',
              style: TextStyle(
                fontFamily: 'Figtree',
                color: AppColors.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DistanceSection extends StatelessWidget {
  const _DistanceSection({
    required this.radius,
    required this.options,
    required this.onChanged,
  });

  final int radius;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final min = options.reduce((a, b) => a < b ? a : b).toDouble();
    final max = options.reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set radius',
          style: TextStyle(
            fontFamily: 'Figtree',
            color: AppColors.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: AppColors.secondaryText,
            inactiveTrackColor: AppColors.lineStrong,
            thumbColor: AppColors.primaryText,
            overlayColor: AppColors.accent.withValues(alpha: 0.10),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: radius.toDouble(),
            min: min,
            max: max,
            divisions: options.length - 1,
            onChanged: (value) {
              final nearest = options.reduce(
                (best, option) => (option - value).abs() < (best - value).abs()
                    ? option
                    : best,
              );
              onChanged(nearest);
            },
          ),
        ),
        Center(
          child: Text(
            '$radius miles',
            style: const TextStyle(
              fontFamily: 'Figtree',
              color: AppColors.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Figtree',
                color: AppColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.8,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Divider(
                color: AppColors.lineStrong,
                thickness: 1,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _SingleRowOption extends StatelessWidget {
  const _SingleRowOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE4EEE9) : const Color(0xFFE6EAE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.lineStrong,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            _RadioDot(selected: isSelected),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  color: AppColors.primaryText,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChipCard extends StatelessWidget {
  const _ChoiceChipCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.useRadio = false,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool useRadio;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE4EEE9) : const Color(0xFFE6EAE7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.lineStrong,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (useRadio) ...[
              _RadioDot(selected: isSelected),
              const SizedBox(width: 8),
            ],
            if (icon != null) ...[
              Icon(icon, size: 12, color: const Color(0xFFD69F58)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Figtree',
                color: AppColors.primaryText,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridOptionCard extends StatelessWidget {
  const _GridOptionCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  IconData? _iconFor(String value) {
    switch (value) {
      case 'Women Prayer Area':
        return Icons.accessibility_new_rounded;
      case 'Wheelchair Access':
        return Icons.accessible_rounded;
      case 'Parking':
        return Icons.local_parking_outlined;
      case 'Wudu':
        return Icons.water_drop_outlined;
      case 'Washroom':
        return Icons.wc_outlined;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(label);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: label.length > 18 ? 104 : 80,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE4EEE9) : const Color(0xFFE6EAE7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.primaryText),
              const SizedBox(height: 6),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Figtree',
                color: AppColors.primaryText,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryText : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? AppColors.primaryText : AppColors.secondaryText,
          width: 1.2,
        ),
      ),
      child: selected
          ? const Center(
              child: Icon(
                Icons.circle,
                size: 6,
                color: AppColors.white,
              ),
            )
          : null,
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.onClose,
    required this.onApply,
  });

  final VoidCallback onClose;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7F4),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 18),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryText,
                    backgroundColor: AppColors.white,
                    side: const BorderSide(color: AppColors.lineStrong),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSoft,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      fontFamily: 'Figtree',
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
  }
}
