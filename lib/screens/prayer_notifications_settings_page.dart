import 'dart:async';

import 'package:flutter/material.dart';

import '../models/prayer_timings.dart';
import '../services/location_preferences_service.dart';
import '../services/prayer_settings_service.dart';
import '../services/user_prayer_timings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/common/figma_section_heading.dart';
import '../widgets/common/figma_status_chip.dart';
import '../widgets/common/figma_switch.dart';

extension _AsarTimeModeLabel on AsarTimeMode {
  String get label {
    switch (this) {
      case AsarTimeMode.early:
        return 'Early Asar (Maliki, Shafi & Hanbali)';
      case AsarTimeMode.late:
        return 'Late Asar (Hanafi)';
    }
  }
}

class PrayerNotificationsSettingsPage extends StatefulWidget {
  const PrayerNotificationsSettingsPage({
    super.key,
    this.settingsService,
    this.locationPreferencesService,
    this.userPrayerTimingsService,
    this.now,
    this.liveRefreshInterval = const Duration(minutes: 1),
  });

  final PrayerSettingsService? settingsService;
  final LocationPreferencesService? locationPreferencesService;
  final UserPrayerTimingsService? userPrayerTimingsService;
  final DateTime Function()? now;
  final Duration liveRefreshInterval;

  @override
  State<PrayerNotificationsSettingsPage> createState() =>
      _PrayerNotificationsSettingsPageState();
}

class _PrayerNotificationsSettingsPageState
    extends State<PrayerNotificationsSettingsPage> {
  late final PrayerSettingsService _settingsService;
  late final LocationPreferencesService _locationPreferencesService;
  late final UserPrayerTimingsService _userPrayerTimingsService;

  PrayerSettings? _settings;
  SavedUserLocation? _savedLocation;
  PrayerTimings? _prayerTimings;
  String? _timingsMessage;
  bool _isPrayerTimingsLoading = true;
  Timer? _refreshTimer;
  DateTime _currentTime = DateTime.now();
  int _timingsRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _settingsService = widget.settingsService ?? PrayerSettingsService();
    _locationPreferencesService =
        widget.locationPreferencesService ?? LocationPreferencesService();
    _userPrayerTimingsService =
        widget.userPrayerTimingsService ?? UserPrayerTimingsService();
    _currentTime = _now();
    _initializePage();
    _refreshTimer = Timer.periodic(
      widget.liveRefreshInterval,
      (_) => _handleRefreshTick(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  String get _locationLabel =>
      _savedLocation?.label ?? LocationPreferencesService.defaultLocation;

  String get _requestedDate => _formatIsoDate(_currentTime);

  Future<void> _initializePage() async {
    final loadedSettings = await _settingsService.load();
    final savedLocation = await _locationPreferencesService.loadSavedLocation();
    if (!mounted) return;
    setState(() {
      _settings = loadedSettings;
      _savedLocation = savedLocation;
    });
    await _refreshPrayerTimings(
      settingsOverride: loadedSettings,
      locationOverride: savedLocation,
    );
  }

  Future<void> _updateSettings(PrayerSettings next) async {
    final previousAsarMode = _settings?.asarTimeMode;
    setState(() => _settings = next);
    await _settingsService.save(next);
    if (next.asarTimeMode != previousAsarMode) {
      await _refreshPrayerTimings(settingsOverride: next);
    }
  }

  void _showPlaceholder(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleRefreshTick() async {
    final nextNow = _now();
    final nextLocation = await _locationPreferencesService.loadSavedLocation();
    if (!mounted) return;

    final locationChanged = !_sameLocation(_savedLocation, nextLocation);
    final dateChanged = _formatIsoDate(_currentTime) != _formatIsoDate(nextNow);
    setState(() {
      _currentTime = nextNow;
      _savedLocation = nextLocation;
    });

    if (locationChanged || dateChanged) {
      await _refreshPrayerTimings(locationOverride: nextLocation);
    }
  }

  Future<void> _refreshPrayerTimings({
    PrayerSettings? settingsOverride,
    SavedUserLocation? locationOverride,
  }) async {
    final settings = settingsOverride ?? _settings;
    final location = locationOverride ?? _savedLocation;
    final requestVersion = ++_timingsRequestVersion;

    if (location == null || !location.hasCoordinates) {
      if (!mounted || requestVersion != _timingsRequestVersion) return;
      setState(() {
        _prayerTimings = null;
        _timingsMessage = null;
        _isPrayerTimingsLoading = false;
      });
      return;
    }

    if (settings == null) {
      return;
    }

    setState(() {
      _isPrayerTimingsLoading = true;
      _timingsMessage = null;
    });

    try {
      final timings = await _userPrayerTimingsService.getDailyTimings(
        date: _requestedDate,
        latitude: location.latitude!,
        longitude: location.longitude!,
        school:
            settings.asarTimeMode == AsarTimeMode.late ? 'hanafi' : 'standard',
      );
      if (!mounted || requestVersion != _timingsRequestVersion) return;
      setState(() {
        _prayerTimings = timings;
        _timingsMessage =
            timings.isAvailable ? null : timings.unavailableReason;
        _isPrayerTimingsLoading = false;
      });
    } catch (_) {
      if (!mounted || requestVersion != _timingsRequestVersion) return;
      setState(() {
        _prayerTimings = null;
        _timingsMessage =
            'Live prayer timings are temporarily unavailable. Please try again shortly.';
        _isPrayerTimingsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final overviewModel = _buildOverviewModel(
      prayerTimings: _prayerTimings,
      currentTime: _currentTime,
      isLoading: _isPrayerTimingsLoading,
      timingsMessage: _timingsMessage,
      hasSavedCoordinates: _savedLocation?.hasCoordinates ?? false,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _PrayerSettingsTopNav(
              location: _locationLabel,
              onBackTap: () => Navigator.of(context).maybePop(),
              onMenuTap: () =>
                  _showPlaceholder('Main menu actions will be added soon.'),
            ),
            Expanded(
              child: settings == null
                  ? const Center(child: CircularProgressIndicator())
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PrayerOverviewCard(
                                asarTimeMode: settings.asarTimeMode,
                                prayerModes: settings.prayerModes,
                                overview: overviewModel,
                                onAsarModeChanged: (mode) => _updateSettings(
                                  settings.copyWith(asarTimeMode: mode),
                                ),
                                onPrayerModeChanged: (prayer, mode) {
                                  final nextModes =
                                      Map<String, PrayerNotificationMode>.from(
                                    settings.prayerModes,
                                  );
                                  nextModes[prayer] = mode;
                                  _updateSettings(
                                    settings.copyWith(prayerModes: nextModes),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              _SuhoorIftarCard(
                                showOnHome: settings.showSuhoorIftarOnHome,
                                onShowOnHomeChanged: (value) => _updateSettings(
                                  settings.copyWith(
                                    showSuhoorIftarOnHome: value,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const FigmaSectionHeading(
                                title: 'VOLUNTARY PRAYERS',
                                showDivider: true,
                                style:
                                    AppTypography.figtreeSectionHeadingCompact,
                                dividerColor: AppColors.line,
                                gap: 10,
                              ),
                              const SizedBox(height: 8),
                              _VoluntaryPrayerPanel(
                                duhaReminder: settings.duhaReminder,
                                qiyamReminder: settings.qiyamReminder,
                                onDuhaReminderChanged: (value) =>
                                    _updateSettings(
                                  settings.copyWith(duhaReminder: value),
                                ),
                                onQiyamReminderChanged: (value) =>
                                    _updateSettings(
                                  settings.copyWith(qiyamReminder: value),
                                ),
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
}

class _PrayerOverviewData {
  const _PrayerOverviewData({
    required this.dateLabel,
    required this.currentPrayerLabel,
    required this.currentPrayerRange,
    required this.badgeLabel,
    required this.methodLabel,
    required this.activePrayerKey,
    required this.rowTimes,
  });

  final String dateLabel;
  final String currentPrayerLabel;
  final String currentPrayerRange;
  final String badgeLabel;
  final String methodLabel;
  final String? activePrayerKey;
  final Map<String, String> rowTimes;
}

const Map<String, String> _prayerLabels = <String, String>{
  'fajr': 'Fajar',
  'dhuhr': 'Duhr',
  'asr': 'Asar',
  'maghrib': 'Maghrib',
  'isha': 'Isha',
};

const List<String> _overviewPrayerOrder = <String>[
  'fajr',
  'dhuhr',
  'asr',
  'maghrib',
  'isha',
];

_PrayerOverviewData _buildOverviewModel({
  required PrayerTimings? prayerTimings,
  required DateTime currentTime,
  required bool isLoading,
  required String? timingsMessage,
  required bool hasSavedCoordinates,
}) {
  final rowTimes = <String, String>{
    for (final prayer in _overviewPrayerOrder)
      prayer: prayerTimings?.timeFor(prayer).trim().isNotEmpty == true
          ? prayerTimings!.timeFor(prayer)
          : '--',
  };
  final dateLabel = prayerTimings?.dateLabel.isNotEmpty == true
      ? prayerTimings!.dateLabel
      : _formatDisplayDate(prayerTimings?.date ?? _formatIsoDate(currentTime));

  if (isLoading) {
    return _PrayerOverviewData(
      dateLabel: dateLabel,
      currentPrayerLabel: 'Loading',
      currentPrayerRange: 'Fetching today\'s prayer timings',
      badgeLabel: 'Refreshing timings',
      methodLabel: '',
      activePrayerKey: null,
      rowTimes: rowTimes,
    );
  }

  if (!hasSavedCoordinates) {
    return _PrayerOverviewData(
      dateLabel: dateLabel,
      currentPrayerLabel: 'Location Needed',
      currentPrayerRange:
          'Save your location coordinates to load today\'s timings',
      badgeLabel: 'Settings stay active',
      methodLabel: '',
      activePrayerKey: null,
      rowTimes: rowTimes,
    );
  }

  if (prayerTimings == null || !prayerTimings.isAvailable) {
    return _PrayerOverviewData(
      dateLabel: dateLabel,
      currentPrayerLabel: 'Unavailable',
      currentPrayerRange: timingsMessage ??
          prayerTimings?.unavailableReason ??
          'Live prayer timings are temporarily unavailable',
      badgeLabel: 'Try again soon',
      methodLabel: '',
      activePrayerKey: null,
      rowTimes: rowTimes,
    );
  }

  final currentWindow = prayerTimings.currentPrayerWindowAt(currentTime);
  if (currentWindow != null) {
    final prayerLabel = _prayerDisplayLabel(currentWindow.prayerKey);
    final range = _buildPrayerRange(
      prayerTimings,
      currentWindow.prayerKey,
      currentWindow.endTime != null
          ? _nextPrayerKey(currentWindow.prayerKey)
          : null,
    );
    final badgeLabel = currentWindow.endTime != null
        ? 'Ends in ${_formatDuration(currentWindow.endTime!.difference(currentTime))}'
        : 'Last listed prayer today';
    return _PrayerOverviewData(
      dateLabel: dateLabel,
      currentPrayerLabel: prayerLabel,
      currentPrayerRange: range,
      badgeLabel: badgeLabel,
      methodLabel: _buildMethodLabel(prayerTimings),
      activePrayerKey: currentWindow.prayerKey,
      rowTimes: rowTimes,
    );
  }

  if (prayerTimings.nextPrayer.isNotEmpty &&
      prayerTimings.nextPrayerTime.isNotEmpty) {
    final nextPrayerKey = _prayerKeyForLabel(prayerTimings.nextPrayer);
    final nextPrayerTime = prayerTimings.nextPrayerTime;
    final nextDateTime = nextPrayerKey == null
        ? null
        : prayerTimings.timeForPrayerOnDate(nextPrayerKey);
    return _PrayerOverviewData(
      dateLabel: dateLabel,
      currentPrayerLabel: _normalizePrayerLabel(prayerTimings.nextPrayer),
      currentPrayerRange: '$nextPrayerTime starts next',
      badgeLabel: nextDateTime == null
          ? 'Starts soon'
          : 'Starts in ${_formatDuration(nextDateTime.difference(currentTime))}',
      methodLabel: _buildMethodLabel(prayerTimings),
      activePrayerKey: null,
      rowTimes: rowTimes,
    );
  }

  return _PrayerOverviewData(
    dateLabel: dateLabel,
    currentPrayerLabel: 'Prayer Times',
    currentPrayerRange: 'Final prayer listed below for today',
    badgeLabel: 'Live timings loaded',
    methodLabel: _buildMethodLabel(prayerTimings),
    activePrayerKey: null,
    rowTimes: rowTimes,
  );
}

String _formatIsoDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatDisplayDate(String isoDate) {
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) {
    return isoDate;
  }

  const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
  return '${weekdays[parsed.weekday - 1]} ${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]}';
}

String _buildMethodLabel(PrayerTimings? prayerTimings) {
  final methodName = prayerTimings?.configuration?.calculationMethodName.trim();
  if (methodName == null || methodName.isEmpty || prayerTimings?.isAvailable != true) {
    return '';
  }

  return 'Method: $methodName';
}

String _prayerDisplayLabel(String prayer) => _prayerLabels[prayer] ?? prayer;

String? _prayerKeyForLabel(String label) {
  for (final prayer in _overviewPrayerOrder) {
    if (_prayerDisplayLabel(prayer) == label ||
        _prayerDisplayLabel(prayer) == _normalizePrayerLabel(label)) {
      return prayer;
    }
  }
  return null;
}

String _normalizePrayerLabel(String label) {
  if (label == 'Dhuhr') {
    return 'Duhr';
  }
  if (label == 'Fajr') {
    return 'Fajar';
  }
  return label;
}

String? _nextPrayerKey(String prayer) {
  final currentIndex = _overviewPrayerOrder.indexOf(prayer);
  if (currentIndex < 0 || currentIndex >= _overviewPrayerOrder.length - 1) {
    return null;
  }
  return _overviewPrayerOrder[currentIndex + 1];
}

String _buildPrayerRange(
  PrayerTimings timings,
  String prayerKey,
  String? nextPrayerKey,
) {
  final start = timings.timeFor(prayerKey);
  final end = nextPrayerKey == null ? '' : timings.timeFor(nextPrayerKey);
  if (start.isEmpty) {
    return '--';
  }
  if (end.isEmpty) {
    return '$start onwards';
  }
  return '$start - $end';
}

String _formatDuration(Duration duration) {
  if (duration.isNegative || duration == Duration.zero) {
    return 'less than a minute';
  }

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) {
    return '$minutes min${minutes == 1 ? '' : 's'}';
  }
  if (minutes == 0) {
    return '$hours hr${hours == 1 ? '' : 's'}';
  }
  return '$hours hr${hours == 1 ? '' : 's'} $minutes min${minutes == 1 ? '' : 's'}';
}

bool _sameLocation(SavedUserLocation? left, SavedUserLocation? right) {
  return left?.label == right?.label &&
      left?.latitude == right?.latitude &&
      left?.longitude == right?.longitude;
}

class _PrayerSettingsTopNav extends StatelessWidget {
  const _PrayerSettingsTopNav({
    required this.location,
    required this.onBackTap,
    required this.onMenuTap,
  });

  final String location;
  final VoidCallback onBackTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F7F4),
        border: Border(
          bottom: BorderSide(color: Color(0xFFDBDED6)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 14,
                  color: Color(0xFF6B796F),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.accentSoft,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.accentSoft,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onMenuTap,
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                  icon: const Icon(
                    Icons.menu,
                    size: 22,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  onPressed: onBackTap,
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 24,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Prayer Notifications & Settings',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerOverviewCard extends StatelessWidget {
  const _PrayerOverviewCard({
    required this.overview,
    required this.asarTimeMode,
    required this.prayerModes,
    required this.onAsarModeChanged,
    required this.onPrayerModeChanged,
  });

  final _PrayerOverviewData overview;
  final AsarTimeMode asarTimeMode;
  final Map<String, PrayerNotificationMode> prayerModes;
  final ValueChanged<AsarTimeMode> onAsarModeChanged;
  final void Function(String prayer, PrayerNotificationMode mode)
      onPrayerModeChanged;

  Future<void> _openAsarTime(BuildContext context) async {
    final mode = await showModalBottomSheet<AsarTimeMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AsarTimePopup(initialMode: asarTimeMode),
    );
    if (mode != null) {
      onAsarModeChanged(mode);
    }
  }

  Future<void> _openPrayerTime(BuildContext context, String prayer) async {
    final selectedMode = prayerModes[prayer] ?? PrayerNotificationMode.silent;
    final result = await showModalBottomSheet<PrayerNotificationMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrayerTimePopup(
        initialPrayer: prayer,
        initialMode: selectedMode,
      ),
    );
    if (result != null) {
      onPrayerModeChanged(prayer, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFF93AA9D),
                  Color(0xFFDDE6D9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  top: 20,
                  child: Container(
                    width: 118,
                    height: 74,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 36,
                  child: Column(
                    children: List.generate(
                      3,
                      (index) => Container(
                        width: 56,
                        height: 8,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'TODAY',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.chevron_left,
                          size: 20,
                          color: AppColors.primaryText,
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              overview.dateLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.primaryText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'NOW',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      overview.currentPrayerLabel,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      overview.currentPrayerRange,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 9),
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: FigmaStatusChip(
                        icon: Icons.alarm,
                        label: overview.badgeLabel,
                        background: const Color(0xFFF3F4F1),
                        foreground: AppColors.primaryText,
                        iconSize: 14,
                        borderRadius: 6,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: AppTypography.figtreeFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              children: [
                _PrayerTimeRow(
                  prayer: 'Fajar',
                  time: overview.rowTimes['fajr'] ?? '--',
                  notificationMode:
                      prayerModes['Fajar'] ?? PrayerNotificationMode.silent,
                  isActive: overview.activePrayerKey == 'fajr',
                  onTap: () => _openPrayerTime(context, 'Fajar'),
                ),
                const SizedBox(height: 6),
                _PrayerTimeRow(
                  prayer: 'Duhr',
                  time: overview.rowTimes['dhuhr'] ?? '--',
                  isActive: overview.activePrayerKey == 'dhuhr',
                  notificationMode:
                      prayerModes['Duhr'] ?? PrayerNotificationMode.silent,
                  onTap: () => _openPrayerTime(context, 'Duhr'),
                ),
                const SizedBox(height: 6),
                _PrayerTimeRow(
                  prayer: 'Asar',
                  time: overview.rowTimes['asr'] ?? '--',
                  isActive: overview.activePrayerKey == 'asr',
                  notificationMode:
                      prayerModes['Asar'] ?? PrayerNotificationMode.silent,
                  onTap: () => _openPrayerTime(context, 'Asar'),
                ),
                const SizedBox(height: 6),
                _PrayerTimeRow(
                  prayer: 'Maghrib',
                  time: overview.rowTimes['maghrib'] ?? '--',
                  isActive: overview.activePrayerKey == 'maghrib',
                  notificationMode:
                      prayerModes['Maghrib'] ?? PrayerNotificationMode.silent,
                  onTap: () => _openPrayerTime(context, 'Maghrib'),
                ),
                const SizedBox(height: 6),
                _PrayerTimeRow(
                  prayer: 'Isha',
                  time: overview.rowTimes['isha'] ?? '--',
                  isActive: overview.activePrayerKey == 'isha',
                  notificationMode:
                      prayerModes['Isha'] ?? PrayerNotificationMode.silent,
                  onTap: () => _openPrayerTime(context, 'Isha'),
                ),
                const SizedBox(height: 10),
                InkWell(
                  key: const Key('asar-time-link'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openAsarTime(context),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentSoft,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.accentSoft,
                        ),
                        children: [
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.settings,
                                size: 14,
                                color: AppColors.accentSoft,
                              ),
                            ),
                          ),
                          TextSpan(text: 'Asar Time: ${asarTimeMode.label}'),
                        ],
                      ),
                    ),
                  ),
                ),
                if (overview.methodLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    overview.methodLabel,
                    key: const Key('prayer-method-label'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerTimeRow extends StatelessWidget {
  const _PrayerTimeRow({
    required this.prayer,
    required this.time,
    required this.notificationMode,
    required this.onTap,
    this.isActive = false,
  });

  final String prayer;
  final String time;
  final PrayerNotificationMode notificationMode;
  final VoidCallback onTap;
  final bool isActive;

  IconData _leadingIcon(String prayer) {
    switch (prayer) {
      case 'Fajar':
        return Icons.wb_sunny_outlined;
      case 'Maghrib':
        return Icons.wb_twilight_outlined;
      case 'Isha':
        return Icons.nights_stay_outlined;
      case 'Asar':
        return Icons.brightness_5_outlined;
      default:
        return Icons.wb_sunny_outlined;
    }
  }

  IconData _trailingIcon(PrayerNotificationMode mode) {
    switch (mode) {
      case PrayerNotificationMode.on:
        return Icons.notifications_active_outlined;
      case PrayerNotificationMode.adhan:
        return Icons.volume_up_outlined;
      case PrayerNotificationMode.silent:
        return Icons.notifications_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isActive ? AppColors.primaryText : AppColors.mutedText;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFBFD0C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              _leadingIcon(prayer),
              size: 18,
              color: textColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                prayer,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _trailingIcon(notificationMode),
              size: 16,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuhoorIftarCard extends StatelessWidget {
  const _SuhoorIftarCard({
    required this.showOnHome,
    required this.onShowOnHomeChanged,
  });

  final bool showOnHome;
  final ValueChanged<bool> onShowOnHomeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _CompactPrayerInfo(
                    icon: Icons.free_breakfast_outlined,
                    title: 'Suhoor',
                    time: '05:10 AM',
                  ),
                ),
                VerticalDivider(
                  width: 20,
                  thickness: 1,
                  color: AppColors.lineStrong,
                ),
                Expanded(
                  child: _CompactPrayerInfo(
                    icon: Icons.emoji_food_beverage_outlined,
                    title: 'Iftar',
                    time: '06:21 AM',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Show on homepage',
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              FigmaSwitch(
                key: const Key('show-home-toggle'),
                value: showOnHome,
                onChanged: onShowOnHomeChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactPrayerInfo extends StatelessWidget {
  const _CompactPrayerInfo({
    required this.icon,
    required this.title,
    required this.time,
  });

  final IconData icon;
  final String title;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: AppColors.secondaryText),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  time,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryText,
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

class _VoluntaryPrayerPanel extends StatelessWidget {
  const _VoluntaryPrayerPanel({
    required this.duhaReminder,
    required this.qiyamReminder,
    required this.onDuhaReminderChanged,
    required this.onQiyamReminderChanged,
  });

  final bool duhaReminder;
  final bool qiyamReminder;
  final ValueChanged<bool> onDuhaReminderChanged;
  final ValueChanged<bool> onQiyamReminderChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VoluntaryPrayerItem(
            title: 'Duha',
            description:
                'Performed after sunrise and before Duhr. It brings blessings, increases sustenance, and was highly encouraged by the Prophet (PBUH). It can be prayed in 2 to 12 rakahs.',
            timeLine: '06:58 AM & 12:30 PM',
            reminderValue: duhaReminder,
            onReminderChanged: onDuhaReminderChanged,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              thickness: 1,
              color: AppColors.lineStrong,
            ),
          ),
          _VoluntaryPrayerItem(
            title: 'Qiyam Al Layl',
            description:
                'Performed after Isha and before Fajr. It is a source of immense blessings, closeness to Allah, and spiritual elevation. The Prophet (PBUH) encouraged it, and it can be prayed in any number of rakahs, typically in pairs.',
            timeLine: '12:00 AM & 05:25 AM',
            reminderValue: qiyamReminder,
            onReminderChanged: onQiyamReminderChanged,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              thickness: 1,
              color: AppColors.lineStrong,
            ),
          ),
          const _VoluntaryPrayerItem(
            title: 'Tahiyat Al Wudu',
            description:
                'Performed after completing wudu. It brings spiritual purification, earns great rewards, and was encouraged by the Prophet (PBUH). It consists of two rakahs.',
          ),
        ],
      ),
    );
  }
}

class _VoluntaryPrayerItem extends StatelessWidget {
  const _VoluntaryPrayerItem({
    required this.title,
    required this.description,
    this.timeLine,
    this.reminderValue = false,
    this.onReminderChanged,
  });

  final String title;
  final String description;
  final String? timeLine;
  final bool reminderValue;
  final ValueChanged<bool>? onReminderChanged;

  @override
  Widget build(BuildContext context) {
    final hasReminder = timeLine != null && onReminderChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 12,
            height: 1.28,
            fontWeight: FontWeight.w400,
            color: AppColors.primaryText,
          ),
        ),
        if (timeLine != null) ...[
          const SizedBox(height: 14),
          Wrap(
            runSpacing: 10,
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 150,
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 12,
                      color: AppColors.primaryText,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Pray between\n',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(
                        text: timeLine,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasReminder)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Turn on reminder',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FigmaSwitch(
                      key: Key(
                          '${title.toLowerCase().replaceAll(' ', '-')}-toggle'),
                      value: reminderValue,
                      onChanged: onReminderChanged!,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AsarTimePopup extends StatelessWidget {
  const _AsarTimePopup({required this.initialMode});

  final AsarTimeMode initialMode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'SET ASAR TIME',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.8,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    'Shows Asar time and mosque suggestions\nbased on your selection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w300,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _AsarOptionTile(
                  key: const Key('asar-option-early'),
                  title: 'Early Asar (Maliki, Shafi & Hanbali)',
                  subtitle:
                      'Begins when the shadow of an object is equal to its length plus its original shadow (after Dhuhr).',
                  selected: initialMode == AsarTimeMode.early,
                  onTap: () => Navigator.of(context).pop(AsarTimeMode.early),
                ),
                const SizedBox(height: 10),
                _AsarOptionTile(
                  key: const Key('asar-option-late'),
                  title: 'Late Asar (Hanafi)',
                  subtitle:
                      'Begins when the shadow of an object is twice its length plus its original shadow.',
                  selected: initialMode == AsarTimeMode.late,
                  onTap: () => Navigator.of(context).pop(AsarTimeMode.late),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AsarOptionTile extends StatelessWidget {
  const _AsarOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final openParen = title.indexOf('(');
    final hasParenthetical = openParen > 0 && title.endsWith(')');
    final mainTitle =
        hasParenthetical ? title.substring(0, openParen).trimRight() : title;
    final parenthetical = hasParenthetical ? title.substring(openParen) : '';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accentSoft : Colors.transparent,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.accentSoft : Colors.transparent,
                border: Border.all(
                  color: AppColors.accentSoft,
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                      children: [
                        TextSpan(text: mainTitle),
                        if (hasParenthetical)
                          TextSpan(
                            text: ' $parenthetical',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w300,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerTimePopup extends StatefulWidget {
  const _PrayerTimePopup({
    required this.initialPrayer,
    required this.initialMode,
  });

  final String initialPrayer;
  final PrayerNotificationMode initialMode;

  @override
  State<_PrayerTimePopup> createState() => _PrayerTimePopupState();
}

class _PrayerTimePopupState extends State<_PrayerTimePopup> {
  static const _prayers = <String>[
    'Fajar',
    'Duhr',
    'Asar',
    'Maghrib',
    'Isha',
  ];

  late String _selectedPrayer;
  late PrayerNotificationMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedPrayer = widget.initialPrayer;
    _selectedMode = widget.initialMode;
  }

  IconData _prayerIcon(String prayer) {
    switch (prayer) {
      case 'Isha':
        return Icons.nights_stay_outlined;
      case 'Asar':
        return Icons.wb_twilight_outlined;
      default:
        return Icons.wb_sunny_outlined;
    }
  }

  void _selectMode(PrayerNotificationMode mode) {
    setState(() => _selectedMode = mode);
    Navigator.of(context).pop(mode);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'PRAYER TIME NOTIFICATIONS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.8,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: _prayers
                        .map(
                          (prayer) => Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  setState(() => _selectedPrayer = prayer),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _selectedPrayer == prayer
                                      ? AppColors.secondaryText
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      prayer,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _selectedPrayer == prayer
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: _selectedPrayer == prayer
                                            ? AppColors.white
                                            : AppColors.mutedText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Icon(
                                      _prayerIcon(prayer),
                                      size: 18,
                                      color: _selectedPrayer == prayer
                                          ? AppColors.white
                                          : AppColors.mutedText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _PrayerModeOptionTile(
                  title: 'Silent',
                  subtitle: 'No notification will be delivered',
                  icon: Icons.notifications_off_outlined,
                  active: _selectedMode == PrayerNotificationMode.silent,
                  onTap: () => _selectMode(PrayerNotificationMode.silent),
                ),
                const SizedBox(height: 10),
                _PrayerModeOptionTile(
                  title: 'On',
                  subtitle:
                      'Notification will play the default sound (Tap to hear)',
                  icon: Icons.notifications_active_outlined,
                  active: _selectedMode == PrayerNotificationMode.on,
                  onTap: () => _selectMode(PrayerNotificationMode.on),
                ),
                const SizedBox(height: 10),
                _PrayerModeOptionTile(
                  title: 'Adhan',
                  subtitle: 'Notification will play the Adhan (Tap to hear)',
                  icon: Icons.volume_up_outlined,
                  active: _selectedMode == PrayerNotificationMode.adhan,
                  onTap: () => _selectMode(PrayerNotificationMode.adhan),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrayerModeOptionTile extends StatelessWidget {
  const _PrayerModeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.accentSoft : Colors.transparent,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryText),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color:
                          active ? AppColors.accentSoft : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w300,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
