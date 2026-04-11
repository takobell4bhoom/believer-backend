import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_provider.dart';
import '../models/broadcast_message.dart';
import '../models/discovery_event.dart';
import '../models/mosque_content.dart';
import '../models/mosque_model.dart';
import '../models/notification_enabled_mosque.dart';
import '../models/notification_setting.dart';
import '../navigation/app_routes.dart';
import '../services/location_preferences_service.dart';
import '../services/mosque_service.dart';
import '../screens/event_detail_screen.dart';
import '../screens/mosque_broadcast.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../screens/mosque_notification_settings.dart';
import '../widgets/common/async_states.dart';
import '../widgets/common/figma_section_heading.dart';
import '../widgets/common/main_bottom_nav_bar.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({
    super.key,
    this.mosqueService,
  });

  final MosqueService? mosqueService;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final LocationPreferencesService _locationPreferencesService =
      LocationPreferencesService();

  late final MosqueService _mosqueService;

  bool _showMyMosques = false;
  bool _requestedFeedLoad = false;
  bool _isFeedLoading = false;
  String _location = LocationPreferencesService.defaultLocation;
  String? _feedErrorMessage;
  String? _feedNoticeMessage;
  List<_NotificationSection> _notificationSections =
      const <_NotificationSection>[];
  List<_FollowedMosque> _followedMosques = const <_FollowedMosque>[];

  @override
  void initState() {
    super.initState();
    _mosqueService = widget.mosqueService ?? MosqueService();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final location = await _locationPreferencesService.loadCurrentLocation();
      if (!mounted) return;
      setState(() => _location = location);
    });
  }

  Future<void> _loadNotificationsFeed() async {
    final auth = ref.read(authProvider).valueOrNull;
    final token = auth?.accessToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _followedMosques = const <_FollowedMosque>[];
        _notificationSections = const <_NotificationSection>[];
        _isFeedLoading = false;
        _feedErrorMessage = null;
        _feedNoticeMessage = null;
      });
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isFeedLoading = true;
          _feedErrorMessage = null;
          _feedNoticeMessage = null;
        });
      }

      final mosques = await _mosqueService.getNotificationEnabledMosques(
        bearerToken: token,
      );
      final followedMosques = mosques
          .asMap()
          .entries
          .map(
            (entry) => _FollowedMosque.fromNotificationMosque(
              entry.value,
              index: entry.key,
            ),
          )
          .toList(growable: false);
      final feedResult = await _buildNotificationFeed(
        followedMosques,
        bearerToken: token,
      );

      if (!mounted) return;
      setState(() {
        _followedMosques = followedMosques;
        _notificationSections = feedResult.sections;
        _feedNoticeMessage = feedResult.noticeMessage;
        _feedErrorMessage = null;
        _isFeedLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _followedMosques = const <_FollowedMosque>[];
        _notificationSections = const <_NotificationSection>[];
        _feedErrorMessage =
            'We could not load your mosque updates right now. Please try again.';
        _feedNoticeMessage = null;
        _isFeedLoading = false;
      });
    }
  }

  void _showPlaceholder(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_NotificationFeedResult> _buildNotificationFeed(
    List<_FollowedMosque> mosques, {
    required String bearerToken,
  }) async {
    if (mosques.isEmpty) {
      return const _NotificationFeedResult(
        sections: <_NotificationSection>[],
      );
    }

    var failedMosqueCount = 0;
    final feedData = await Future.wait(
      mosques.map((mosque) async {
        try {
          final detailFuture = _mosqueService.getMosqueDetail(mosque.id);
          final contentFuture = _mosqueService.getMosqueContent(mosque.id);
          final broadcastsFuture =
              _mosqueService.getMosqueBroadcastMessages(mosque.id);
          final settingsFuture = _mosqueService.getNotificationSettings(
            mosqueId: mosque.id,
            bearerToken: bearerToken,
          );
          final results = await Future.wait<dynamic>([
            detailFuture,
            contentFuture,
            broadcastsFuture,
            settingsFuture,
          ]);
          final enabledSettingTitles = _enabledNotificationSettingTitles(
            results[3] as List<NotificationSetting>,
          );
          return _MosqueNotificationFeedData(
            mosque: mosque,
            detail: results[0] as MosqueModel,
            content: results[1] as MosqueContent,
            broadcasts: results[2] as List<BroadcastMessage>,
            showBroadcastMessages:
                enabledSettingTitles.contains(_broadcastMessagesSettingKey),
            showProgramUpdates:
                enabledSettingTitles.contains(_eventsAndClassesSettingKey),
          );
        } catch (_) {
          failedMosqueCount += 1;
          return null;
        }
      }),
    );

    final loadedData = feedData.whereType<_MosqueNotificationFeedData>().toList(
          growable: false,
        );
    final broadcastItems = <_NotificationItem>[];
    final programItems = <_NotificationItem>[];

    for (final data in loadedData) {
      if (data.showBroadcastMessages) {
        for (final message in data.broadcasts.take(3)) {
          broadcastItems.add(
            _NotificationItem.broadcast(
              mosqueId: data.mosque.id,
              mosqueName: data.mosque.name,
              messagePrefix: 'published a',
              messageHighlight: 'broadcast message',
              timeLabel: message.displayDate,
              cardTitle: _fallbackText(message.title, 'Broadcast update'),
              cardDescription: _fallbackText(
                message.description,
                'No broadcast body was published for this update.',
              ),
              palette: data.mosque.palette,
            ),
          );
        }
      }

      if (data.showProgramUpdates) {
        for (final event in data.content.events.take(2)) {
          programItems.add(
            _NotificationItem.program(
              mosqueId: data.mosque.id,
              mosqueName: data.mosque.name,
              mosqueDetail: data.detail,
              programItem: event,
              messagePrefix: 'published an',
              messageHighlight: 'event update',
              timeLabel: 'Event',
              cardBadge: _fallbackSchedule(event.schedule),
              cardTitle: _fallbackText(event.title, 'Event details'),
              cardSubtitle: _buildProgramSubtitle(
                location: event.location,
                fallbackLabel: 'Open event details',
              ),
              palette: data.mosque.palette,
            ),
          );
        }

        for (final item in data.content.classes.take(2)) {
          programItems.add(
            _NotificationItem.program(
              mosqueId: data.mosque.id,
              mosqueName: data.mosque.name,
              mosqueDetail: data.detail,
              programItem: item,
              messagePrefix: 'published a',
              messageHighlight: 'class or halaqa update',
              timeLabel: 'Class',
              cardBadge: _fallbackSchedule(item.schedule),
              cardTitle: _fallbackText(item.title, 'Class details'),
              cardSubtitle: _buildProgramSubtitle(
                location: item.location,
                fallbackLabel: 'Open class details',
              ),
              palette: data.mosque.palette,
            ),
          );
        }
      }
    }

    final sections = <_NotificationSection>[
      if (broadcastItems.isNotEmpty)
        _NotificationSection(
          title: 'BROADCAST MESSAGES',
          items: broadcastItems,
        ),
      if (programItems.isNotEmpty)
        _NotificationSection(
          title: 'EVENTS & CLASSES',
          items: programItems,
        ),
    ];

    return _NotificationFeedResult(
      sections: sections,
      noticeMessage: failedMosqueCount > 0
          ? 'Some mosque updates could not be loaded right now.'
          : null,
    );
  }

  void _openMosqueSettings(_FollowedMosque mosque) {
    Navigator.of(context).pushNamed(
      AppRoutes.mosqueNotificationSettings,
      arguments: MosqueNotificationSettingsRouteArgs(
        mosqueId: mosque.id,
        mosqueName: mosque.name,
      ),
    );
  }

  void _openNotificationItem(_NotificationItem item) {
    switch (item.type) {
      case _NotificationType.program:
        final mosqueDetail = item.mosqueDetail;
        final programItem = item.programItem;
        if (mosqueDetail == null || programItem == null) {
          _showPlaceholder('Event details are not available yet.');
          return;
        }
        Navigator.of(context).pushNamed(
          AppRoutes.eventDetail,
          arguments: EventDetailRouteArgs(
            event: mosqueDetail,
            discoveryEvent:
                DiscoveryEvent.fromMosqueProgram(mosqueDetail, programItem),
          ),
        );
        break;
      case _NotificationType.broadcast:
        Navigator.of(context).pushNamed(
          AppRoutes.mosqueBroadcast,
          arguments: MosqueBroadcastRouteArgs(
            mosqueId: item.mosqueId,
            mosqueName: item.mosqueName,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    if (!_requestedFeedLoad &&
        !authState.isLoading &&
        authState.valueOrNull != null) {
      _requestedFeedLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadNotificationsFeed();
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      bottomNavigationBar:
          const MainBottomNavBar(activeTab: MainAppTab.notifications),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _NotificationsTopShell(
              location: _location,
              showMyMosques: _showMyMosques,
              notificationBadge: _notificationSections.fold<int>(
                  0, (count, section) => count + section.items.length),
              onNotificationsTap: () => setState(() => _showMyMosques = false),
              onMyMosquesTap: () => setState(() => _showMyMosques = true),
              onMenuTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.profileSettings),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: _showMyMosques
                        ? _MyMosquesPanel(
                            isAuthenticated: authState.valueOrNull != null,
                            errorMessage: _feedErrorMessage,
                            mosques: _followedMosques,
                            onMosqueTap: _openMosqueSettings,
                          )
                        : _NotificationsFeedPanel(
                            isAuthenticated: authState.valueOrNull != null,
                            isLoading: _isFeedLoading,
                            errorMessage: _feedErrorMessage,
                            noticeMessage: _feedNoticeMessage,
                            sections: _notificationSections,
                            onRetry: _loadNotificationsFeed,
                            onItemTap: _openNotificationItem,
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

class _NotificationsTopShell extends StatelessWidget {
  const _NotificationsTopShell({
    required this.location,
    required this.showMyMosques,
    required this.notificationBadge,
    required this.onNotificationsTap,
    required this.onMyMosquesTap,
    required this.onMenuTap,
  });

  final String location;
  final bool showMyMosques;
  final int notificationBadge;
  final VoidCallback onNotificationsTap;
  final VoidCallback onMyMosquesTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_outlined,
                        size: 20,
                        color: AppColors.accentSoft,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.accentSoft,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accentSoft,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onMenuTap,
                        splashRadius: 20,
                        icon: const Icon(
                          Icons.menu,
                          size: 24,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderTab(
                          label: 'Notifications',
                          badge:
                              notificationBadge > 0 ? notificationBadge : null,
                          active: !showMyMosques,
                          onTap: onNotificationsTap,
                        ),
                      ),
                      Expanded(
                        child: _HeaderTab(
                          label: 'My Mosques',
                          active: showMyMosques,
                          onTap: onMyMosquesTap,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 3,
                          margin: EdgeInsets.only(
                            left: showMyMosques ? 0 : 28,
                            right: showMyMosques ? 28 : 0,
                          ),
                          color: !showMyMosques
                              ? AppColors.accentSoft
                              : Colors.transparent,
                        ),
                      ),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 3,
                          margin: EdgeInsets.only(
                            left: showMyMosques ? 28 : 0,
                            right: showMyMosques ? 0 : 28,
                          ),
                          color: showMyMosques
                              ? AppColors.accentSoft
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderTab extends StatelessWidget {
  const _HeaderTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool active;
  final int? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? AppColors.primaryText
                        : AppColors.secondaryText,
                    fontSize: 16,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 3),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsFeedPanel extends StatelessWidget {
  const _NotificationsFeedPanel({
    required this.isAuthenticated,
    required this.isLoading,
    required this.errorMessage,
    required this.noticeMessage,
    required this.sections,
    required this.onRetry,
    required this.onItemTap,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final String? noticeMessage;
  final List<_NotificationSection> sections;
  final VoidCallback onRetry;
  final ValueChanged<_NotificationItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      return const EmptyState(
        title: 'Log in to view mosque updates.',
        subtitle:
            'Follow mosques to see broadcast messages, events, and class updates in your in-app feed.',
      );
    }

    if (isLoading) {
      return const LoadingState(label: 'Loading mosque updates...');
    }

    if (errorMessage != null) {
      return ErrorState(
        message: errorMessage!,
        onRetry: onRetry,
      );
    }

    if (sections.isEmpty) {
      return const EmptyState(
        title: 'No mosque updates yet.',
        subtitle:
            'Broadcast messages, events, and classes from your followed mosques will appear here when they are published.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (noticeMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              noticeMessage!,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (var index = 0; index < sections.length; index++) ...[
          _NotificationSectionView(
            section: sections[index],
            onItemTap: onItemTap,
          ),
          if (index < sections.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _NotificationSectionView extends StatelessWidget {
  const _NotificationSectionView({
    required this.section,
    required this.onItemTap,
  });

  final _NotificationSection section;
  final ValueChanged<_NotificationItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FigmaSectionHeading(
          title: section.title,
          showDivider: true,
          style: AppTypography.figtreeSectionHeading,
          dividerColor: AppColors.lineStrong,
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < section.items.length; index++) ...[
          _NotificationCard(
            item: section.items[index],
            onTap: () => onItemTap(section.items[index]),
          ),
          if (index < section.items.length - 1) const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  final _NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          _NotificationHeader(item: item),
          const SizedBox(height: 4),
          if (item.type == _NotificationType.program) ...[
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: _EventCard(item: item),
            ),
          ] else if (item.type == _NotificationType.broadcast) ...[
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 310,
                child: _BroadcastCard(item: item),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CircleThumb(palette: item.palette),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.mosqueName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.accentSoft,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    height: 1.25,
                  ),
                  children: [
                    TextSpan(text: '${item.messagePrefix} '),
                    TextSpan(
                      text: item.messageHighlight,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (item.timeLabel.trim().isNotEmpty)
          Text(
            item.timeLabel,
            style: TextStyle(
              color: item.type == _NotificationType.program
                  ? AppColors.error
                  : AppColors.mutedText,
              fontSize: 12,
              fontWeight: item.type == _NotificationType.program
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _PosterThumb(
            palette: item.palette,
            height: 98,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((item.cardBadge ?? '').isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.cardBadge ?? '',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    item.cardTitle ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if ((item.cardSubtitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.cardSubtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.cardTitle ?? '',
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.cardDescription ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyMosquesPanel extends StatelessWidget {
  const _MyMosquesPanel({
    required this.isAuthenticated,
    required this.errorMessage,
    required this.mosques,
    required this.onMosqueTap,
  });

  final bool isAuthenticated;
  final String? errorMessage;
  final List<_FollowedMosque> mosques;
  final ValueChanged<_FollowedMosque> onMosqueTap;

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      return const EmptyState(
        title: 'Log in to manage followed mosques.',
        subtitle:
            'Mosques you follow and their in-app update preferences will appear here after you sign in.',
      );
    }

    if (errorMessage != null) {
      return ErrorState(message: errorMessage!);
    }

    if (mosques.isEmpty) {
      return const EmptyState(
        title: 'No followed mosques yet.',
        subtitle:
            'Follow a mosque from its page to manage which in-app updates you see here.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < mosques.length; index++) ...[
          _FollowedMosqueRow(
            mosque: mosques[index],
            onTap: () => onMosqueTap(mosques[index]),
          ),
          if (index < mosques.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppColors.lineStrong, height: 1),
            ),
        ],
      ],
    );
  }
}

class _FollowedMosqueRow extends StatelessWidget {
  const _FollowedMosqueRow({
    required this.mosque,
    required this.onTap,
  });

  final _FollowedMosque mosque;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleThumb(palette: mosque.palette),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            mosque.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.accentSoft,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentSoft,
            side: const BorderSide(color: AppColors.accentSoft, width: 1.5),
            minimumSize: const Size(60, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_active_outlined, size: 18),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleThumb extends StatelessWidget {
  const _CircleThumb({required this.palette});

  final _ThumbPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.colors,
        ),
      ),
      child: Icon(
        palette.icon,
        color: AppColors.white,
        size: 18,
      ),
    );
  }
}

class _PosterThumb extends StatelessWidget {
  const _PosterThumb({
    required this.palette,
    required this.height,
  });

  final _ThumbPalette palette;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.colors,
        ),
      ),
      child: Icon(
        palette.posterIcon,
        color: AppColors.white.withValues(alpha: 0.85),
        size: 30,
      ),
    );
  }
}

enum _NotificationType {
  program,
  broadcast,
}

class _NotificationSection {
  const _NotificationSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_NotificationItem> items;
}

class _NotificationItem {
  const _NotificationItem._({
    required this.type,
    required this.mosqueId,
    required this.mosqueName,
    required this.messagePrefix,
    required this.messageHighlight,
    required this.timeLabel,
    required this.palette,
    this.mosqueDetail,
    this.programItem,
    this.cardBadge,
    this.cardTitle,
    this.cardSubtitle,
    this.cardDescription,
  });

  const _NotificationItem.program({
    required String mosqueId,
    required String mosqueName,
    required MosqueModel mosqueDetail,
    required MosqueProgramItem programItem,
    required String messagePrefix,
    required String messageHighlight,
    required String timeLabel,
    required String cardBadge,
    required String cardTitle,
    required String cardSubtitle,
    required _ThumbPalette palette,
  }) : this._(
          type: _NotificationType.program,
          mosqueId: mosqueId,
          mosqueName: mosqueName,
          messagePrefix: messagePrefix,
          messageHighlight: messageHighlight,
          timeLabel: timeLabel,
          palette: palette,
          mosqueDetail: mosqueDetail,
          programItem: programItem,
          cardBadge: cardBadge,
          cardTitle: cardTitle,
          cardSubtitle: cardSubtitle,
        );

  const _NotificationItem.broadcast({
    required String mosqueId,
    required String mosqueName,
    required String messagePrefix,
    required String messageHighlight,
    required String timeLabel,
    required String cardTitle,
    required String cardDescription,
    required _ThumbPalette palette,
  }) : this._(
          type: _NotificationType.broadcast,
          mosqueId: mosqueId,
          mosqueName: mosqueName,
          messagePrefix: messagePrefix,
          messageHighlight: messageHighlight,
          timeLabel: timeLabel,
          palette: palette,
          cardTitle: cardTitle,
          cardDescription: cardDescription,
        );

  final _NotificationType type;
  final String mosqueId;
  final String mosqueName;
  final String messagePrefix;
  final String messageHighlight;
  final String timeLabel;
  final _ThumbPalette palette;
  final MosqueModel? mosqueDetail;
  final MosqueProgramItem? programItem;
  final String? cardBadge;
  final String? cardTitle;
  final String? cardSubtitle;
  final String? cardDescription;
}

class _MosqueNotificationFeedData {
  const _MosqueNotificationFeedData({
    required this.mosque,
    required this.detail,
    required this.content,
    required this.broadcasts,
    required this.showBroadcastMessages,
    required this.showProgramUpdates,
  });

  final _FollowedMosque mosque;
  final MosqueModel detail;
  final MosqueContent content;
  final List<BroadcastMessage> broadcasts;
  final bool showBroadcastMessages;
  final bool showProgramUpdates;
}

class _NotificationFeedResult {
  const _NotificationFeedResult({
    required this.sections,
    this.noticeMessage,
  });

  final List<_NotificationSection> sections;
  final String? noticeMessage;
}

String _fallbackText(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

const String _broadcastMessagesSettingKey = 'broadcast messages';
const String _eventsAndClassesSettingKey = 'events & class updates';

Set<String> _enabledNotificationSettingTitles(
  List<NotificationSetting> settings,
) {
  return settings
      .where((setting) => setting.isEnabled)
      .map((setting) => _normalizeNotificationSettingTitle(setting.title))
      .toSet();
}

String _normalizeNotificationSettingTitle(String title) {
  return title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _fallbackSchedule(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Schedule not published' : trimmed;
}

String _buildProgramSubtitle({
  required String location,
  required String fallbackLabel,
}) {
  final trimmedLocation = location.trim();
  return trimmedLocation.isEmpty ? fallbackLabel : trimmedLocation;
}

class _FollowedMosque {
  const _FollowedMosque({
    required this.id,
    required this.name,
    required this.palette,
  });

  factory _FollowedMosque.fromNotificationMosque(
    NotificationEnabledMosque mosque, {
    required int index,
  }) {
    const palettes = <_ThumbPalette>[
      _ThumbPalette.blue,
      _ThumbPalette.sand,
      _ThumbPalette.brown,
      _ThumbPalette.purple,
      _ThumbPalette.gold,
    ];

    return _FollowedMosque(
      id: mosque.id,
      name: mosque.name,
      palette: palettes[index % palettes.length],
    );
  }

  final String id;
  final String name;
  final _ThumbPalette palette;
}

enum _ThumbPalette {
  blue(
    [Color(0xFF8EB0CB), Color(0xFFDAC6A3)],
    Icons.mosque_outlined,
    Icons.event_note_rounded,
  ),
  sand(
    [Color(0xFFB89D73), Color(0xFFE6D8B6)],
    Icons.account_balance_outlined,
    Icons.schedule_rounded,
  ),
  brown(
    [Color(0xFF5A4B43), Color(0xFFA89277)],
    Icons.event_available_rounded,
    Icons.campaign_outlined,
  ),
  purple(
    [Color(0xFF2D265E), Color(0xFF7B55A8)],
    Icons.menu_book_outlined,
    Icons.auto_stories_outlined,
  ),
  gold(
    [Color(0xFF8C642A), Color(0xFFE3C17D)],
    Icons.book_outlined,
    Icons.school_outlined,
  );

  const _ThumbPalette(this.colors, this.icon, this.posterIcon);

  final List<Color> colors;
  final IconData icon;
  final IconData posterIcon;
}
