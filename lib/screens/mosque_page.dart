import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_error_mapper.dart';
import '../data/auth_provider.dart';
import '../data/mosque_content_refresh_provider.dart';
import '../data/mosque_provider.dart';
import '../models/broadcast_message.dart';
import '../models/mosque_content.dart';
import '../models/mosque_model.dart';
import '../models/prayer_timings.dart';
import '../models/review.dart';
import '../navigation/mosque_detail_route_args.dart';
import '../navigation/app_startup.dart';
import '../navigation/app_routes.dart';
import '../services/api_client.dart';
import '../services/bookmark_service.dart';
import '../services/location_preferences_service.dart';
import '../services/mosque_service.dart';
import '../services/outbound_action_service.dart';
import '../theme/app_colors.dart';
import '../utils/mosque_prayer_summary.dart';
import '../widgets/common/async_states.dart';
import '../widgets/mosque_image_frame.dart';
import 'leave_review.dart';
import 'mosque_broadcast.dart';
import 'mosque_admin_edit_screen.dart';
import 'mosque_notification_settings.dart';
import 'review_screen.dart';

final _mosquePageLoadAttemptProvider =
    StateProvider.family<bool, String>((ref, mosqueId) => false);

final _resolvedMosqueProvider =
    FutureProvider.autoDispose.family<MosqueModel?, MosqueDetailRouteArgs>(
  (ref, args) async {
    final mosqueState = ref.watch(mosqueProvider);
    final currentMosques = mosqueState.valueOrNull ?? const <MosqueModel>[];
    final selected = _findMosqueById(currentMosques, args.mosqueId);

    if (selected != null) {
      return selected;
    }

    if (args.initialMosque != null) {
      return args.initialMosque;
    }

    if (mosqueState.hasError) {
      throw mosqueState.error!;
    }

    if (mosqueState.isLoading) {
      final loadedMosques = await ref.watch(mosqueProvider.future);
      return _findMosqueById(loadedMosques, args.mosqueId);
    }

    final hasAttempted =
        ref.read(_mosquePageLoadAttemptProvider(args.mosqueId));
    if (!hasAttempted) {
      ref.read(_mosquePageLoadAttemptProvider(args.mosqueId).notifier).state =
          true;
      final savedLocation =
          await LocationPreferencesService().loadSavedLocation();
      if (savedLocation?.hasCoordinates != true) {
        return null;
      }
      final loadedMosques = await ref.read(mosqueProvider.notifier).loadNearby(
            latitude: savedLocation!.latitude!,
            longitude: savedLocation.longitude!,
            radiusKm: 10,
          );
      return _findMosqueById(loadedMosques, args.mosqueId);
    }

    return null;
  },
);

class MosquePage extends ConsumerStatefulWidget {
  const MosquePage({
    super.key,
    required this.args,
    this.mosqueService,
    this.bookmarkService,
    this.outboundActionService = const OutboundActionService(),
  });

  final MosqueDetailRouteArgs args;
  final MosqueService? mosqueService;
  final BookmarkService? bookmarkService;
  final OutboundActionService outboundActionService;

  @override
  ConsumerState<MosquePage> createState() => _MosquePageState();
}

class _MosquePageState extends ConsumerState<MosquePage> {
  late final MosqueService _mosqueService;
  late final BookmarkService _bookmarkService;

  ReviewFeed? _reviewFeed;
  List<BroadcastMessage>? _broadcastMessages;
  MosqueContent? _mosqueContent;
  PrayerTimings? _prayerTimings;
  MosqueModel? _editedMosque;
  bool _isLoadingLiveContent = false;
  bool _bookmarkBusy = false;
  int _lastHandledContentRefreshTick = 0;

  @override
  void initState() {
    super.initState();
    _mosqueService = widget.mosqueService ?? MosqueService();
    _bookmarkService = widget.bookmarkService ?? BookmarkService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLiveContent();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MosquePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.args.mosqueId != widget.args.mosqueId) {
      _reviewFeed = null;
      _broadcastMessages = null;
      _mosqueContent = null;
      _prayerTimings = null;
      _editedMosque = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadLiveContent();
        }
      });
    }
  }

  Future<void> _loadLiveContent() async {
    if (_isLoadingLiveContent) {
      return;
    }

    try {
      _isLoadingLiveContent = true;
      ReviewFeed? nextReviewFeed = _reviewFeed;
      List<BroadcastMessage>? nextBroadcastMessages = _broadcastMessages;
      MosqueContent? nextMosqueContent = _mosqueContent;
      PrayerTimings? nextPrayerTimings = _prayerTimings;

      try {
        nextReviewFeed =
            await _mosqueService.getMosqueReviews(widget.args.mosqueId);
      } catch (_) {
        // Keep the existing fallback content on read failures.
      }

      try {
        nextBroadcastMessages = await _mosqueService.getMosqueBroadcastMessages(
          widget.args.mosqueId,
        );
      } catch (_) {
        // Keep the existing fallback content on read failures.
      }

      try {
        nextMosqueContent = await _mosqueService.getMosqueContent(
          widget.args.mosqueId,
        );
      } catch (_) {
        // Keep the existing fallback content on read failures.
      }

      try {
        nextPrayerTimings = await _mosqueService.getPrayerTimings(
          mosqueId: widget.args.mosqueId,
          date: _todayIsoDate(),
        );
      } catch (_) {
        // Keep the existing fallback content on read failures.
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _reviewFeed = nextReviewFeed;
        _broadcastMessages = nextBroadcastMessages;
        _mosqueContent = nextMosqueContent;
        _prayerTimings = nextPrayerTimings;
      });
    } finally {
      _isLoadingLiveContent = false;
    }
  }

  void _openBroadcastMessages(_MosquePageContent content) {
    Navigator.of(context).pushNamed(
      AppRoutes.mosqueBroadcast,
      arguments: MosqueBroadcastRouteArgs(
        mosqueId: content.mosqueId,
        mosqueName: content.mosqueName,
      ),
    );
  }

  String _todayIsoDate() {
    final now = DateTime.now();
    return _isoDate(now);
  }

  Future<List<_WeeklyIqamahDay>> _loadWeeklyIqamahTimings({
    required String mosqueId,
    PrayerTimings? todayPrayerTimings,
  }) async {
    final startDate = DateTime.now();
    final requests = List.generate(7, (index) async {
      final displayDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day + index,
      );
      final requestedDate = _isoDate(displayDate);

      PrayerTimings? timings;
      if (index == 0 &&
          todayPrayerTimings != null &&
          todayPrayerTimings.date == requestedDate) {
        timings = todayPrayerTimings;
      } else {
        try {
          timings = await _mosqueService.getPrayerTimings(
            mosqueId: mosqueId,
            date: requestedDate,
          );
        } catch (_) {
          timings = null;
        }
      }

      return _WeeklyIqamahDay.fromPrayerTimings(
        displayDate: displayDate,
        prayerTimings: timings,
      );
    });

    return Future.wait(requests);
  }

  Future<void> _openWeeklyIqamahTimings(_MosquePageContent content) async {
    final weeklyTimingsFuture = _loadWeeklyIqamahTimings(
      mosqueId: content.mosqueId,
      todayPrayerTimings: _prayerTimings,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _WeeklyIqamahSheet(
          mosqueName: content.mosqueName,
          weeklyTimingsFuture: weeklyTimingsFuture,
        );
      },
    );
  }

  Future<void> _openAdminEditor(MosqueModel mosque) async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.adminEditMosque,
      arguments: MosqueAdminEditRouteArgs(mosque: mosque),
    );

    if (!mounted || result is! MosqueAdminUpdateResult) {
      return;
    }

    setState(() {
      _editedMosque = result.mosque;
      _mosqueContent = result.content;
    });
  }

  Future<void> _showOutboundResult(
    Future<OutboundActionResult> future,
  ) async {
    final result = await future;
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _toggleBookmark(MosqueModel mosque) async {
    if (_bookmarkBusy) {
      return;
    }

    setState(() => _bookmarkBusy = true);

    try {
      final token = ref.read(authProvider).valueOrNull?.accessToken;
      if (mosque.isBookmarked) {
        await _bookmarkService.removeBookmark(
          mosque.id,
          bearerToken: token,
        );
      } else {
        await _bookmarkService.addBookmark(
          mosque.id,
          bearerToken: token,
        );
      }

      final updated = mosque.copyWith(isBookmarked: !mosque.isBookmarked);
      ref.read(mosqueProvider.notifier).setBookmarked(
            updated.id,
            updated.isBookmarked,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _editedMosque = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isBookmarked
                ? 'Added to bookmarks.'
                : 'Removed from bookmarks.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorMapper.toUserMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _bookmarkBusy = false);
      }
    }
  }

  Future<OutboundActionResult> _launchMosqueConnectLink(
    _SocialMediaLink link, {
    required String mosqueName,
  }) {
    final lowerType = link.type.toLowerCase();
    if (link.value.trim().isEmpty || lowerType == 'note') {
      return Future.value(
        const OutboundActionResult(
          message:
              'This mosque has not published outbound contact details yet.',
        ),
      );
    }

    if (lowerType.contains('phone')) {
      return widget.outboundActionService.launchPhone(
        link.value,
        successMessage: 'Opening mosque phone number...',
        fallbackMessage:
            'Could not open the phone app. Mosque number copied to clipboard.',
        unavailableMessage: '$mosqueName has not published a phone number yet.',
      );
    }

    if (lowerType.contains('email')) {
      return widget.outboundActionService.launchEmail(
        link.value,
        subject: 'Question about $mosqueName',
        successMessage: 'Opening mosque email...',
        fallbackMessage:
            'Could not open the email app. Mosque email copied to clipboard.',
        unavailableMessage: '$mosqueName has not published an email yet.',
      );
    }

    if (lowerType.contains('whatsapp')) {
      return widget.outboundActionService.launchWhatsApp(
        link.value,
        message: 'Salam, I found your mosque on Believers Lens.',
        successMessage: 'Opening WhatsApp...',
        fallbackMessage:
            'Could not open WhatsApp. Mosque contact copied to clipboard.',
        unavailableMessage:
            '$mosqueName has not published a WhatsApp contact yet.',
      );
    }

    final destinationLabel = switch (lowerType) {
      'instagram' => 'Instagram',
      'facebook' => 'Facebook',
      'youtube' => 'YouTube',
      'website' => 'website',
      _ => 'link',
    };

    return widget.outboundActionService.launchExternalLink(
      link.value,
      type: link.type,
      successMessage: 'Opening $destinationLabel...',
      fallbackMessage:
          'Could not open the $destinationLabel. Details copied to clipboard.',
      unavailableMessage: '$mosqueName has not published this link yet.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentRefreshTick = ref.watch(mosqueContentRefreshTickProvider);
    final authState = ref.watch(authProvider);

    if (contentRefreshTick != _lastHandledContentRefreshTick) {
      _lastHandledContentRefreshTick = contentRefreshTick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadLiveContent();
        }
      });
    }

    if (authState.hasValue && authState.valueOrNull == null) {
      _scheduleLoginRedirect(context);
      return const _MosquePageScaffold(
        title: 'Mosque Page',
        child: LoadingState(label: 'Redirecting...'),
      );
    }

    if (authState.isLoading) {
      return const _MosquePageScaffold(
        title: 'Mosque Page',
        child: LoadingState(label: 'Checking your session...'),
      );
    }

    final mosqueState = ref.watch(_resolvedMosqueProvider(widget.args));
    return mosqueState.when(
      loading: () => const _MosquePageScaffold(
        title: 'Mosque Page',
        child: LoadingState(label: 'Loading mosque details...'),
      ),
      error: (error, _) {
        if (_isUnauthorized(error)) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await ref.read(authProvider.notifier).clear();
          });
          return const _MosquePageScaffold(
            title: 'Mosque Page',
            child: LoadingState(label: 'Session expired. Redirecting...'),
          );
        }

        return _MosquePageScaffold(
          title: 'Mosque Page',
          child: ErrorState(
            message: ApiErrorMapper.toUserMessage(error),
            onRetry: () {
              ref
                  .read(
                    _mosquePageLoadAttemptProvider(widget.args.mosqueId)
                        .notifier,
                  )
                  .state = false;
              ref.invalidate(_resolvedMosqueProvider(widget.args));
            },
          ),
        );
      },
      data: (mosque) {
        final resolvedMosque =
            _editedMosque ?? mosque ?? widget.args.initialMosque;
        if (resolvedMosque == null) {
          return const _MosquePageScaffold(
            title: 'Mosque Page',
            child: EmptyState(
              title: 'Mosque page unavailable',
              subtitle:
                  'We could not load this mosque from the current nearby data or route context.',
            ),
          );
        }

        final isAuthenticated = authState.valueOrNull != null;
        final content = _MosquePageContent.fromMosque(
          resolvedMosque,
          reviewFeed: _reviewFeed,
          broadcastMessages: _broadcastMessages,
          mosqueContent: _mosqueContent,
          prayerTimings: _prayerTimings,
        );
        final shareText = _buildMosqueShareText(resolvedMosque, content);

        return _MosquePageScaffold(
          title: content.mosqueName,
          onShareTap: () => _showOutboundResult(
            widget.outboundActionService.shareText(
              shareText,
              subject: content.mosqueName,
              successMessage: 'Share options opened for this mosque.',
              fallbackMessage:
                  'Could not open share options. Mosque details copied to clipboard.',
            ),
          ),
          onBookmarkTap: () => _toggleBookmark(resolvedMosque),
          isBookmarked: resolvedMosque.isBookmarked,
          bookmarkBusy: _bookmarkBusy,
          onEditTap: resolvedMosque.canEdit
              ? () => _openAdminEditor(resolvedMosque)
              : null,
          bottomActionBar: _MosquePageActionBar(
            onCallTap: () => _showOutboundResult(
              widget.outboundActionService.launchPhone(
                resolvedMosque.contactPhone,
                successMessage: 'Opening mosque phone number...',
                fallbackMessage:
                    'Could not open the phone app. Mosque number copied to clipboard.',
                unavailableMessage:
                    'This mosque has not published a phone number yet.',
              ),
            ),
            onShareTap: () => _showOutboundResult(
              widget.outboundActionService.shareText(
                shareText,
                subject: content.mosqueName,
                successMessage: 'Share options opened for this mosque.',
                fallbackMessage:
                    'Could not open share options. Mosque details copied to clipboard.',
              ),
            ),
            onDirectionsTap: () => _showOutboundResult(
              widget.outboundActionService.launchDirections(
                address: content.address,
                latitude: resolvedMosque.latitude,
                longitude: resolvedMosque.longitude,
                successMessage: 'Opening mosque directions...',
                fallbackMessage:
                    'Could not open maps. Mosque address copied to clipboard.',
                unavailableMessage:
                    'This mosque does not have a mappable address yet.',
              ),
            ),
            onNotifyTap: () {
              Navigator.of(context).pushNamed(
                AppRoutes.mosqueNotificationSettings,
                arguments: MosqueNotificationSettingsRouteArgs(
                  mosqueId: content.mosqueId,
                  mosqueName: content.mosqueName,
                ),
              );
            },
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderSection(content: content),
                const SizedBox(height: 10),
                _GallerySection(images: content.images),
                const SizedBox(height: 12),
                _IqamahSection(
                  content: content,
                  onViewWeekTap: () => _openWeeklyIqamahTimings(content),
                ),
                const SizedBox(height: 12),
                const _SectionTitle(title: 'FACILITIES'),
                const SizedBox(height: 8),
                _PillWrap(
                  items: content.facilities
                      .map((label) => _PillData(label, _facilityIcon(label)))
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                const _SectionTitle(title: 'CONTACT'),
                const SizedBox(height: 8),
                _ImamsSection(imams: content.imams),
                if (content.aboutTitle.isNotEmpty ||
                    content.aboutBody.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionTitle(title: 'ABOUT'),
                  const SizedBox(height: 8),
                  _AboutSection(
                    title: content.aboutTitle,
                    body: content.aboutBody,
                  ),
                ],
                const SizedBox(height: 12),
                const _SectionTitle(title: 'EVENTS'),
                const SizedBox(height: 8),
                _PosterStrip(events: content.events),
                const SizedBox(height: 12),
                const _SectionTitle(title: 'CLASSES & HALAQAS'),
                const SizedBox(height: 8),
                _ClassStrip(classes: content.classes),
                const SizedBox(height: 12),
                const _SectionTitle(title: 'BROADCAST MESSAGES'),
                const SizedBox(height: 8),
                _BroadcastPreview(
                  messages: content.broadcastMessages,
                  onSeeAll: () => _openBroadcastMessages(content),
                ),
                const SizedBox(height: 12),
                const _SectionTitle(title: 'CONNECT'),
                const SizedBox(height: 8),
                _ConnectSection(
                  links: content.socialMediaLinks,
                  onLinkTap: (link) => _showOutboundResult(
                    _launchMosqueConnectLink(
                      link,
                      mosqueName: content.mosqueName,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ReviewsSection(
                  reviews: content.reviews,
                  ratingLabel: content.ratingLabel,
                  hasReviews: content.hasReviewSummary,
                  reviewActionLabel: isAuthenticated
                      ? (content.hasReviewSummary
                          ? 'Leave a review'
                          : 'Write the first review')
                      : 'Login to leave review',
                  onReadAll: () async {
                    await Navigator.of(context).pushNamed(
                      AppRoutes.reviews,
                      arguments: ReviewScreenRouteArgs(
                        mosqueId: content.mosqueId,
                        mosqueName: content.mosqueName,
                        initialReviews: content.reviews,
                      ),
                    );
                    if (mounted) {
                      _loadLiveContent();
                    }
                  },
                  onLeaveReview: () async {
                    await Navigator.of(context).pushNamed(
                      AppRoutes.leaveReview,
                      arguments: LeaveReviewRouteArgs(
                        mosqueId: content.mosqueId,
                        mosqueName: content.mosqueName,
                      ),
                    );
                    if (mounted) {
                      _loadLiveContent();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MosquePageScaffold extends StatelessWidget {
  const _MosquePageScaffold({
    required this.child,
    required this.title,
    this.onShareTap,
    this.onBookmarkTap,
    this.isBookmarked = false,
    this.bookmarkBusy = false,
    this.onEditTap,
    this.bottomActionBar,
  });

  final Widget child;
  final String title;
  final VoidCallback? onShareTap;
  final VoidCallback? onBookmarkTap;
  final bool isBookmarked;
  final bool bookmarkBusy;
  final VoidCallback? onEditTap;
  final Widget? bottomActionBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: _TopNav(
                title: title,
                onShareTap: onShareTap,
                onBookmarkTap: onBookmarkTap,
                isBookmarked: isBookmarked,
                bookmarkBusy: bookmarkBusy,
                onEditTap: onEditTap,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: child,
                  ),
                ),
              ),
            ),
            if (bottomActionBar != null)
              SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: bottomActionBar!,
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

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.title,
    this.onShareTap,
    this.onBookmarkTap,
    this.isBookmarked = false,
    this.bookmarkBusy = false,
    this.onEditTap,
  });

  final String title;
  final VoidCallback? onShareTap;
  final VoidCallback? onBookmarkTap;
  final bool isBookmarked;
  final bool bookmarkBusy;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            padding: EdgeInsets.zero,
            splashRadius: 18,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
          ),
          if (onEditTap != null)
            IconButton(
              onPressed: onEditTap,
              padding: EdgeInsets.zero,
              splashRadius: 18,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              icon: const Icon(
                Icons.edit_outlined,
                size: 17,
                color: AppColors.accentSoft,
              ),
            )
          else
            const SizedBox(width: 28),
          if (onBookmarkTap != null)
            IconButton(
              onPressed: bookmarkBusy ? null : onBookmarkTap,
              padding: EdgeInsets.zero,
              splashRadius: 18,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              icon: Icon(
                bookmarkBusy
                    ? Icons.hourglass_top
                    : isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                size: 18,
                color: AppColors.accentSoft,
              ),
            )
          else
            const SizedBox(width: 28),
          if (onShareTap != null)
            IconButton(
              onPressed: onShareTap,
              padding: EdgeInsets.zero,
              splashRadius: 18,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              icon: const Icon(
                Icons.share_outlined,
                size: 17,
                color: AppColors.accentSoft,
              ),
            )
          else
            const SizedBox(width: 28),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.content});

  final _MosquePageContent content;

  @override
  Widget build(BuildContext context) {
    final ratingText = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          content.distanceLabel,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 11,
            color: AppColors.secondaryText,
          ),
        ),
        if (content.hasCommunityRating) ...[
          const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
          Text(
            content.ratingChipLabel,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
        ] else
          const Text(
            'No reviews yet',
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 11,
              color: AppColors.secondaryText,
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content.mosqueName,
          style: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 330;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          content.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ratingText,
                ],
              );
            }

            return Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    content.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ratingText,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _SmallPill(
              label: content.sectLabel,
              icon: Icons.mosque_outlined,
            ),
            _SmallPill(
              label: content.asrLabel,
              icon: Icons.wb_twilight_outlined,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFD8A55D),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            content.openHoursLabel,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFBFD0C7),
        border: Border.all(color: AppColors.primaryText, width: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primaryText),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 10.5,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _GallerySection extends StatefulWidget {
  const _GallerySection({required this.images});

  final List<String> images;

  @override
  State<_GallerySection> createState() => _GallerySectionState();
}

class _GallerySectionState extends State<_GallerySection> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final images =
        widget.images.where((image) => image.trim().isNotEmpty).toList(
              growable: false,
            );

    if (images.length <= 1) {
      return _GalleryTile(
        key: const ValueKey('mosque-gallery-single'),
        imagePath: images.isNotEmpty ? images.first : '',
        aspectRatio: 16 / 9,
      );
    }

    return MosqueImageFrame(
      key: const ValueKey('mosque-gallery-slider'),
      aspectRatio: 16 / 9,
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              if (mounted) {
                setState(() => _currentPage = index);
              }
            },
            itemBuilder: (context, index) {
              return _GalleryTile(
                imagePath: images[index],
                aspectRatio: null,
              );
            },
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: _GalleryArrowButton(
              key: const ValueKey('mosque-gallery-prev'),
              icon: Icons.chevron_left_rounded,
              onPressed: _currentPage == 0
                  ? null
                  : () => _jumpToPage(_currentPage - 1),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: _GalleryArrowButton(
              key: const ValueKey('mosque-gallery-next'),
              icon: Icons.chevron_right_rounded,
              onPressed: _currentPage >= images.length - 1
                  ? null
                  : () => _jumpToPage(_currentPage + 1),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x8F102325),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_currentPage + 1} / ${images.length}',
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Row(
              children: List<Widget>.generate(images.length, (index) {
                final selected = index == _currentPage;
                return Container(
                  width: selected ? 16 : 6,
                  height: 6,
                  margin: EdgeInsets.only(
                      right: index == images.length - 1 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.white : const Color(0x99FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    super.key,
    required this.imagePath,
    this.aspectRatio,
  });

  final String imagePath;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    return MosqueImageFrame(
      aspectRatio: aspectRatio,
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildGalleryImage(imagePath),
        ],
      ),
    );
  }
}

class _GalleryArrowButton extends StatelessWidget {
  const _GalleryArrowButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: onPressed == null
            ? const Color(0x55102325)
            : const Color(0x8F102325),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              icon,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildGalleryImage(String imagePath) {
  if (imagePath.startsWith('http')) {
    return Image.network(
      imagePath,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.1),
      errorBuilder: (_, __, ___) => const _GalleryFallback(),
    );
  }

  if (imagePath.isNotEmpty) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.1),
      errorBuilder: (_, __, ___) => const _GalleryFallback(),
    );
  }

  return const _GalleryFallback();
}

class _GalleryFallback extends StatelessWidget {
  const _GalleryFallback();

  @override
  Widget build(BuildContext context) {
    return const MosqueImagePlaceholder(
      message: 'Mosque image unavailable',
      iconSize: 28,
    );
  }
}

class _IqamahSection extends StatelessWidget {
  const _IqamahSection({
    required this.content,
    required this.onViewWeekTap,
  });

  final _MosquePageContent content;
  final VoidCallback onViewWeekTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E9E4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final badge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5F6660),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  content.iqamahStatusBadge,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              );

              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IQAMAH',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 12,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    badge,
                  ],
                );
              }

              return Row(
                children: [
                  const Text(
                    'IQAMAH',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 12,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const Spacer(),
                  Flexible(child: badge),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              content.iqamahFocusTitle,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chevron_left,
                    size: 15,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    content.iqamahFocusSubtitle,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 9.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 15,
                    color: AppColors.secondaryText,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (var index = 0;
              index < content.iqamahTimings.length;
              index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    _prayerIcon(content.iqamahTimings[index].name),
                    size: 14,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      content.iqamahTimings[index].name,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  Text(
                    content.iqamahTimings[index].time,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 11,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (index < content.iqamahTimings.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFD0D5D0)),
          ],
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: onViewWeekTap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondaryText,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text(
                'View this week\'s iqamah timings',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyIqamahSheet extends StatelessWidget {
  const _WeeklyIqamahSheet({
    required this.mosqueName,
    required this.weeklyTimingsFuture,
  });

  final String mosqueName;
  final Future<List<_WeeklyIqamahDay>> weeklyTimingsFuture;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 80, 12, 12),
        child: Material(
          color: const Color(0xFFF5F3EE),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: FutureBuilder<List<_WeeklyIqamahDay>>(
              future: weeklyTimingsFuture,
              builder: (context, snapshot) {
                final days = snapshot.data ?? const <_WeeklyIqamahDay>[];

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.82,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'This week\'s iqamah timings',
                                  style: TextStyle(
                                    fontFamily: 'Figtree',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mosqueName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Figtree',
                                    fontSize: 11,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            splashRadius: 18,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Daily backend-owned mosque timings for the next 7 days.',
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState != ConnectionState.done &&
                          days.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (days.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Weekly iqamah timings are not available right now.',
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: days.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _WeeklyIqamahDayCard(day: days[index]);
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyIqamahDayCard extends StatelessWidget {
  const _WeeklyIqamahDayCard({required this.day});

  final _WeeklyIqamahDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E9E4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.dayLabel,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.dateLabel,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 10.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5F6660),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  day.statusLabel,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: day.timings
                .map(
                  (timing) => SizedBox(
                    width: 108,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _prayerIcon(timing.name.toLowerCase()),
                          size: 13,
                          color: AppColors.secondaryText,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${timing.name} ${timing.time}',
                            style: const TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 10.5,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          if (day.note != null) ...[
            const SizedBox(height: 8),
            Text(
              day.note!,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 10.5,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
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
            fontSize: 12,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFD4D8D4),
          ),
        ),
      ],
    );
  }
}

class _PillWrap extends StatelessWidget {
  const _PillWrap({required this.items});

  final List<_PillData> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFBFD0C7),
                border: Border.all(color: AppColors.primaryText, width: 0.8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 16, color: AppColors.primaryText),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 12,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ImamsSection extends StatelessWidget {
  const _ImamsSection({required this.imams});

  final List<_ImamProfile> imams;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: imams
          .map(
            (imam) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE2DE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _InitialsAvatar(name: imam.name),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          imam.name,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          imam.role,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 10,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.secondaryText,
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
          if (title.isNotEmpty && body.isNotEmpty) const SizedBox(height: 8),
          if (body.isNotEmpty)
            Text(
              body,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 13,
                height: 1.45,
                color: AppColors.secondaryText,
              ),
            ),
        ],
      ),
    );
  }
}

class _PosterStrip extends StatelessWidget {
  const _PosterStrip({required this.events});

  final List<_CommunityEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _SectionFallbackCard(
        message:
            'No event details have been published for this mosque yet. Listing summaries only show event titles when available.',
      );
    }

    return SizedBox(
      height: 156,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final event = events[index];
          return _PosterCard(
            title: event.title,
            badge: event.schedule,
            posterLabel: event.posterLabel,
            posterColors: event.posterColors,
            badgeColor: const Color(0xFFF3E1DE),
            badgeTextColor: AppColors.surfaceHighlight,
          );
        },
      ),
    );
  }
}

class _ClassStrip extends StatelessWidget {
  const _ClassStrip({required this.classes});

  final List<_ClassOffering> classes;

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const _SectionFallbackCard(
        message:
            'No class or halaqa details have been published for this mosque yet. Listing summaries only show class titles when available.',
      );
    }

    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: classes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final classItem = classes[index];
          return _PosterCard(
            title: classItem.title,
            badge: classItem.schedule,
            posterLabel: classItem.posterLabel,
            posterColors: classItem.posterColors,
            badgeColor: const Color(0xFFE6E1F4),
            badgeTextColor: const Color(0xFF56418C),
          );
        },
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.title,
    required this.badge,
    required this.posterLabel,
    required this.posterColors,
    required this.badgeColor,
    required this.badgeTextColor,
  });

  final String title;
  final String badge;
  final String posterLabel;
  final List<Color> posterColors;
  final Color badgeColor;
  final Color badgeTextColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      decoration: BoxDecoration(
        color: const Color(0xFFE7EBE8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 84,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: posterColors,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _PosterArtwork(label: posterLabel),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: badgeTextColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.primaryText,
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

class _BroadcastPreview extends StatelessWidget {
  const _BroadcastPreview({
    required this.messages,
    required this.onSeeAll,
  });

  final List<BroadcastMessage> messages;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDDE6DF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No recent broadcast messages have been published for this mosque yet.',
          style: TextStyle(
            fontFamily: 'Figtree',
            fontSize: 10.5,
            height: 1.35,
            color: AppColors.secondaryText,
          ),
        ),
      );
    }

    final preview = messages.first;
    final previewDate = preview.displayDate.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDDE6DF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (previewDate.isNotEmpty) ...[
            Text(
              previewDate,
              style: const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            preview.title,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            preview.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 10,
              height: 1.3,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEDE9),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD0D6D1)),
              ),
              child: Text(
                'See all ${messages.length} messages in last 60 days',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionFallbackCard extends StatelessWidget {
  const _SectionFallbackCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFDDE2DE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Figtree',
          fontSize: 10.5,
          height: 1.35,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}

class _ConnectSection extends StatelessWidget {
  const _ConnectSection({
    required this.links,
    required this.onLinkTap,
  });

  final List<_SocialMediaLink> links;
  final ValueChanged<_SocialMediaLink> onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: links
          .map(
            (link) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onLinkTap(link),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E7E4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7DDD8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        _socialIcon(link.type, link.label),
                        color: AppColors.secondaryText,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        link.label,
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 10.5,
                          color: AppColors.secondaryText,
                          decoration: link.value.trim().isEmpty
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviews,
    required this.ratingLabel,
    required this.hasReviews,
    required this.reviewActionLabel,
    required this.onReadAll,
    required this.onLeaveReview,
  });

  final List<Review> reviews;
  final String ratingLabel;
  final bool hasReviews;
  final String reviewActionLabel;
  final VoidCallback onReadAll;
  final VoidCallback onLeaveReview;

  @override
  Widget build(BuildContext context) {
    final preview = reviews.take(2).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'REVIEWS'),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final reviewCta = TextButton(
              onPressed: onLeaveReview,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondaryText,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              ),
              child: Text(
                reviewActionLabel,
                style: const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            );
            final ratingSummary = Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ratingLabel,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ],
            );

            if (constraints.maxWidth < 340) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ratingSummary,
                  const SizedBox(height: 2),
                  reviewCta,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: ratingSummary),
                reviewCta,
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFDDE2DE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (!hasReviews)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No community reviews have been published for this mosque yet.',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 10.5,
                      height: 1.35,
                      color: AppColors.secondaryText,
                    ),
                  ),
                )
              else ...[
                ...preview.map(
                  (review) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBFD0C7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                review.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (review.displayTimeAgo.isNotEmpty)
                              Text(
                                review.displayTimeAgo,
                                style: const TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 10,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          review.userName,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          review.comment,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 10,
                            height: 1.3,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        if (review != preview.last) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFD0D6D1)),
                        ],
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onReadAll,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentSoft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 4,
                      ),
                    ),
                    child: const Text(
                      'Read all reviews',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MosquePageActionBar extends StatelessWidget {
  const _MosquePageActionBar({
    required this.onCallTap,
    required this.onShareTap,
    required this.onDirectionsTap,
    required this.onNotifyTap,
  });

  final VoidCallback onCallTap;
  final VoidCallback onShareTap;
  final VoidCallback onDirectionsTap;
  final VoidCallback onNotifyTap;

  @override
  Widget build(BuildContext context) {
    final iconButtons = [
      _ActionIconButton(
        icon: Icons.call_outlined,
        onTap: onCallTap,
      ),
      _ActionIconButton(
        icon: Icons.share_outlined,
        onTap: onShareTap,
      ),
      _ActionIconButton(
        icon: Icons.near_me_outlined,
        onTap: onDirectionsTap,
      ),
    ];

    final notificationButton = SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onNotifyTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentSoft,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.notifications_active_outlined, size: 18),
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Enable Notifications',
            style: TextStyle(
              fontFamily: 'Figtree',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          if (compact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final button in iconButtons) button,
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: notificationButton),
              ],
            );
          }

          return Row(
            children: [
              for (var index = 0; index < iconButtons.length; index++) ...[
                iconButtons[index],
                if (index < iconButtons.length - 1) const SizedBox(width: 8),
              ],
              const SizedBox(width: 10),
              Expanded(child: notificationButton),
            ],
          );
        },
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentSoft,
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.accentSoft, width: 1.5),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Icon(icon, size: 18),
    );
  }
}

class _MosquePageContent {
  const _MosquePageContent({
    required this.mosqueId,
    required this.mosqueName,
    required this.address,
    required this.images,
    required this.facilities,
    required this.iqamahTimings,
    required this.imams,
    required this.events,
    required this.classes,
    required this.broadcastMessages,
    required this.socialMediaLinks,
    required this.reviews,
    required this.aboutTitle,
    required this.aboutBody,
    required this.distanceLabel,
    required this.ratingLabel,
    required this.ratingChipLabel,
    required this.hasCommunityRating,
    required this.hasReviewSummary,
    required this.sectLabel,
    required this.asrLabel,
    required this.openHoursLabel,
    required this.todayLabel,
    required this.verificationLabel,
    required this.iqamahFocusTitle,
    required this.iqamahFocusSubtitle,
    required this.iqamahStatusBadge,
  });

  final String mosqueId;
  final String mosqueName;
  final String address;
  final List<String> images;
  final List<String> facilities;
  final List<_IqamahTiming> iqamahTimings;
  final List<_ImamProfile> imams;
  final List<_CommunityEvent> events;
  final List<_ClassOffering> classes;
  final List<BroadcastMessage> broadcastMessages;
  final List<_SocialMediaLink> socialMediaLinks;
  final List<Review> reviews;
  final String aboutTitle;
  final String aboutBody;
  final String distanceLabel;
  final String ratingLabel;
  final String ratingChipLabel;
  final bool hasCommunityRating;
  final bool hasReviewSummary;
  final String sectLabel;
  final String asrLabel;
  final String openHoursLabel;
  final String todayLabel;
  final String verificationLabel;
  final String iqamahFocusTitle;
  final String iqamahFocusSubtitle;
  final String iqamahStatusBadge;

  factory _MosquePageContent.fromMosque(
    MosqueModel mosque, {
    ReviewFeed? reviewFeed,
    List<BroadcastMessage>? broadcastMessages,
    MosqueContent? mosqueContent,
    PrayerTimings? prayerTimings,
  }) {
    final resolvedReviews = reviewFeed?.items ?? const <Review>[];
    final resolvedRatingLabel = reviewFeed?.ratingLabel;
    final resolvedRatingChipLabel = reviewFeed?.ratingChipLabel;
    final resolvedBroadcastMessages =
        broadcastMessages ?? const <BroadcastMessage>[];
    final liveEvents = _eventsFromMosqueContent(mosqueContent);
    final liveClasses = _classesFromMosqueContent(mosqueContent);
    final liveConnectLinks = _connectLinksFromMosqueContent(mosqueContent);
    final liveAbout = mosqueContent?.about;
    final liveIqamahTimings = _iqamahTimingsFromPrayerTimings(prayerTimings);
    final prayerHeaderLabel = _prayerHeaderLabel(prayerTimings);
    final readableFacilities = mosque.facilities.isEmpty
        ? const <String>['Facilities pending']
        : mosque.facilities
            .map((facility) => _toTitleCase(facility.replaceAll('_', ' ')))
            .toList(growable: false);
    final prayerSubtitleLabel = _prayerSubtitleLabel(prayerTimings, mosque);
    final prayerStatusBadge = _prayerStatusBadge(prayerTimings, mosque);
    final summaryPrayerLabel = _summaryPrayerLabel(prayerTimings, mosque);
    final hasReviewSummary =
        reviewFeed?.hasReviews ?? mosque.hasCommunityRating;
    final address = [
      mosque.addressLine.trim(),
      [mosque.city, mosque.state]
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(', '),
    ].where((part) => part.isNotEmpty).join(' • ');
    final images = mosque.imageUrls.isNotEmpty
        ? mosque.imageUrls
        : <String>[
            if (mosque.imageUrl.trim().isNotEmpty) mosque.imageUrl.trim(),
          ];

    return _MosquePageContent(
      mosqueId: mosque.id,
      mosqueName: mosque.name.trim().isEmpty ? 'Community Mosque' : mosque.name,
      address:
          address.isEmpty ? 'Address details will be updated soon.' : address,
      images: images.take(10).toList(growable: false),
      facilities: readableFacilities.take(4).toList(growable: false),
      iqamahTimings: liveIqamahTimings ?? _listingLevelPrayerRows(mosque),
      imams: _contactProfilesForMosque(mosque),
      events: liveEvents ??
          mosque.eventTags
              .take(3)
              .map(
                (event) => _CommunityEvent(
                  title: event,
                  schedule: 'Event title only',
                  posterLabel: 'EVENT',
                  posterColors: const [Color(0xFF607A73), Color(0xFF92A89A)],
                ),
              )
              .toList(growable: false),
      classes: liveClasses ??
          mosque.classTags
              .take(3)
              .map(
                (classTag) => _ClassOffering(
                  title: classTag,
                  schedule: 'Class title only',
                  posterLabel: 'CLASS',
                  posterColors: const [Color(0xFF69598B), Color(0xFF9380B8)],
                ),
              )
              .toList(growable: false),
      broadcastMessages: resolvedBroadcastMessages,
      socialMediaLinks: liveConnectLinks ??
          [
            if (mosque.contactPhone.trim().isNotEmpty)
              _SocialMediaLink(
                label: mosque.contactPhone.trim(),
                type: 'phone',
                value: mosque.contactPhone.trim(),
              ),
            if (mosque.contactEmail.trim().isNotEmpty)
              _SocialMediaLink(
                label: mosque.contactEmail.trim(),
                type: 'email',
                value: mosque.contactEmail.trim(),
              ),
            if (mosque.websiteUrl.trim().isNotEmpty)
              _SocialMediaLink(
                label: mosque.websiteUrl.trim(),
                type: 'website',
                value: mosque.websiteUrl.trim(),
              ),
            if (mosque.contactPhone.trim().isEmpty &&
                mosque.contactEmail.trim().isEmpty &&
                mosque.websiteUrl.trim().isEmpty) ...const [
              _SocialMediaLink(
                label: 'Contact details not published yet',
                type: 'note',
                value: '',
              ),
            ],
          ],
      reviews: resolvedReviews,
      aboutTitle: liveAbout?.title ?? '',
      aboutBody: liveAbout?.body ?? '',
      distanceLabel: '${mosque.distanceMiles.toStringAsFixed(1)} mi away',
      ratingLabel: resolvedRatingLabel ??
          (hasReviewSummary
              ? '${mosque.rating.toStringAsFixed(1)} from ${mosque.reviewCount} ${mosque.reviewCount == 1 ? 'review' : 'reviews'}'
              : 'No community reviews yet'),
      ratingChipLabel: resolvedRatingChipLabel ??
          (hasReviewSummary ? mosque.rating.toStringAsFixed(1) : 'New'),
      hasCommunityRating: hasReviewSummary,
      hasReviewSummary: hasReviewSummary,
      sectLabel: mosque.sect.trim().isEmpty ? 'Community' : mosque.sect,
      asrLabel: summaryPrayerLabel,
      openHoursLabel:
          mosque.isVerified ? 'Verified listing' : 'Community listed',
      todayLabel: prayerHeaderLabel,
      verificationLabel: mosque.isVerified
          ? 'Verified community listing'
          : 'Community listing',
      iqamahFocusTitle: prayerTimings?.isAvailable == true
          ? 'Prayer timings TODAY'
          : mosque.hasListedPrayerTimes
              ? 'Listed prayer times'
              : 'Prayer timings',
      iqamahFocusSubtitle: prayerSubtitleLabel,
      iqamahStatusBadge: prayerStatusBadge,
    );
  }
}

List<_IqamahTiming>? _iqamahTimingsFromPrayerTimings(
    PrayerTimings? prayerTimings) {
  if (prayerTimings == null) {
    return null;
  }

  if (!prayerTimings.isAvailable) {
    return const [
      _IqamahTiming(name: 'Fajr', time: '--'),
      _IqamahTiming(name: 'Dhuhr', time: '--'),
      _IqamahTiming(name: 'Asr', time: '--'),
      _IqamahTiming(name: 'Maghrib', time: '--'),
      _IqamahTiming(name: 'Isha', time: '--'),
    ];
  }

  return [
    _IqamahTiming(
      name: 'Fajr',
      time: prayerTimings.timeFor('fajr'),
    ),
    _IqamahTiming(
      name: 'Dhuhr',
      time: prayerTimings.timeFor('dhuhr'),
    ),
    _IqamahTiming(
      name: 'Asr',
      time: prayerTimings.timeFor('asr'),
    ),
    _IqamahTiming(
      name: 'Maghrib',
      time: prayerTimings.timeFor('maghrib'),
    ),
    _IqamahTiming(
      name: 'Isha',
      time: prayerTimings.timeFor('isha'),
    ),
  ];
}

String _prayerHeaderLabel(PrayerTimings? prayerTimings) {
  if (prayerTimings == null || prayerTimings.date.isEmpty) {
    return 'Prayer timings for today';
  }

  return 'Prayer timings for ${prayerTimings.date}';
}

String _prayerSubtitleLabel(
  PrayerTimings? prayerTimings,
  MosqueModel mosque,
) {
  if (prayerTimings == null) {
    return buildMosqueListingPrayerSubtitle(mosque);
  }

  final configuration = prayerTimings.configuration;
  if (!prayerTimings.isConfigured || configuration == null) {
    return 'Configure this mosque in admin to enable live prayer timings';
  }

  if (!prayerTimings.isAvailable) {
    return prayerTimings.unavailableReason ??
        'Live prayer timings are not available right now.';
  }

  final sourceLabel = switch (prayerTimings.source) {
    'cache' => 'cached backend read',
    'aladhan' => 'live AlAdhan read',
    _ => 'backend read',
  };
  return '${configuration.calculationMethodName} • ${configuration.schoolLabel} • $sourceLabel';
}

String _prayerStatusBadge(
  PrayerTimings? prayerTimings,
  MosqueModel mosque,
) {
  if (prayerTimings == null) {
    return buildMosqueListingPrayerStatus(mosque);
  }

  if (!prayerTimings.isConfigured) {
    return 'Prayer-time config needed';
  }

  if (!prayerTimings.isAvailable) {
    return 'Live timing read unavailable';
  }

  if (prayerTimings.nextPrayer.isNotEmpty &&
      prayerTimings.nextPrayerTime.isNotEmpty) {
    return 'Next: ${prayerTimings.nextPrayer} ${prayerTimings.nextPrayerTime}';
  }

  return 'Live timings ready';
}

String _summaryPrayerLabel(PrayerTimings? prayerTimings, MosqueModel mosque) {
  return buildMosquePrayerSummaryLabel(prayerTimings, mosque);
}

List<_IqamahTiming> _listingLevelPrayerRows(MosqueModel mosque) {
  return [
    const _IqamahTiming(name: 'Fajr', time: '--'),
    _IqamahTiming(
      name: 'Dhuhr',
      time: mosque.hasDhuhrTime ? mosque.duhrTime : '--',
    ),
    _IqamahTiming(
      name: 'Asr',
      time: mosque.hasAsrTime ? mosque.asarTime : '--',
    ),
    const _IqamahTiming(name: 'Maghrib', time: '--'),
    const _IqamahTiming(name: 'Isha', time: '--'),
  ];
}

List<_ImamProfile> _contactProfilesForMosque(MosqueModel mosque) {
  if (mosque.contactName.trim().isNotEmpty) {
    return [
      _ImamProfile(
        name: mosque.contactName.trim(),
        role: 'Mosque contact',
      ),
    ];
  }

  if (mosque.contactPhone.trim().isNotEmpty ||
      mosque.contactEmail.trim().isNotEmpty ||
      mosque.websiteUrl.trim().isNotEmpty) {
    return const [
      _ImamProfile(
        name: 'Published contact channels',
        role:
            'Use the Connect section below for current phone, email, or website details.',
      ),
    ];
  }

  return const [
    _ImamProfile(
      name: 'Contact details not published yet',
      role:
          'This mosque has not shared a primary contact on the current backend payload.',
    ),
  ];
}

String _isoDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _weeklyDayLabel(DateTime displayDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(displayDate.year, displayDate.month, displayDate.day);
  final dayOffset = target.difference(today).inDays;

  return switch (dayOffset) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => _weekdayLabel(displayDate.weekday),
  };
}

String _weeklyDateLabel(DateTime displayDate) {
  return '${_weekdayLabel(displayDate.weekday)}, ${displayDate.day.toString().padLeft(2, '0')} ${_monthLabel(displayDate.month)} ${displayDate.year}';
}

String _weekdayLabel(int weekday) {
  const weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  return weekdays[weekday - 1];
}

String _monthLabel(int month) {
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

  return months[month - 1];
}

class _IqamahTiming {
  const _IqamahTiming({
    required this.name,
    required this.time,
  });

  final String name;
  final String time;
}

class _WeeklyIqamahDay {
  const _WeeklyIqamahDay({
    required this.dayLabel,
    required this.dateLabel,
    required this.statusLabel,
    required this.timings,
    this.note,
  });

  factory _WeeklyIqamahDay.fromPrayerTimings({
    required DateTime displayDate,
    required PrayerTimings? prayerTimings,
  }) {
    if (prayerTimings == null) {
      return _WeeklyIqamahDay(
        dayLabel: _weeklyDayLabel(displayDate),
        dateLabel: _weeklyDateLabel(displayDate),
        statusLabel: 'Unavailable',
        timings: const [
          _IqamahTiming(name: 'Fajr', time: '--'),
          _IqamahTiming(name: 'Dhuhr', time: '--'),
          _IqamahTiming(name: 'Asr', time: '--'),
          _IqamahTiming(name: 'Maghrib', time: '--'),
          _IqamahTiming(name: 'Isha', time: '--'),
        ],
        note: 'Could not load backend timings for this day.',
      );
    }

    if (!prayerTimings.isConfigured) {
      return _WeeklyIqamahDay(
        dayLabel: _weeklyDayLabel(displayDate),
        dateLabel: _weeklyDateLabel(displayDate),
        statusLabel: 'Config needed',
        timings: const [
          _IqamahTiming(name: 'Fajr', time: '--'),
          _IqamahTiming(name: 'Dhuhr', time: '--'),
          _IqamahTiming(name: 'Asr', time: '--'),
          _IqamahTiming(name: 'Maghrib', time: '--'),
          _IqamahTiming(name: 'Isha', time: '--'),
        ],
        note: 'This mosque still needs prayer-time configuration.',
      );
    }

    if (!prayerTimings.isAvailable) {
      return _WeeklyIqamahDay(
        dayLabel: _weeklyDayLabel(displayDate),
        dateLabel: _weeklyDateLabel(displayDate),
        statusLabel: 'Unavailable',
        timings: const [
          _IqamahTiming(name: 'Fajr', time: '--'),
          _IqamahTiming(name: 'Dhuhr', time: '--'),
          _IqamahTiming(name: 'Asr', time: '--'),
          _IqamahTiming(name: 'Maghrib', time: '--'),
          _IqamahTiming(name: 'Isha', time: '--'),
        ],
        note: prayerTimings.unavailableReason ??
            'Backend timings are not available for this day.',
      );
    }

    final statusLabel = switch (prayerTimings.source) {
      'cache' => 'Cached backend',
      'aladhan' => 'Live backend',
      _ => 'Backend timings',
    };

    return _WeeklyIqamahDay(
      dayLabel: _weeklyDayLabel(displayDate),
      dateLabel: _weeklyDateLabel(displayDate),
      statusLabel: statusLabel,
      timings: [
        _IqamahTiming(name: 'Fajr', time: prayerTimings.timeFor('fajr')),
        _IqamahTiming(name: 'Dhuhr', time: prayerTimings.timeFor('dhuhr')),
        _IqamahTiming(name: 'Asr', time: prayerTimings.timeFor('asr')),
        _IqamahTiming(
          name: 'Maghrib',
          time: prayerTimings.timeFor('maghrib'),
        ),
        _IqamahTiming(name: 'Isha', time: prayerTimings.timeFor('isha')),
      ],
    );
  }

  final String dayLabel;
  final String dateLabel;
  final String statusLabel;
  final List<_IqamahTiming> timings;
  final String? note;
}

class _ImamProfile {
  const _ImamProfile({
    required this.name,
    required this.role,
  });

  final String name;
  final String role;
}

class _CommunityEvent {
  const _CommunityEvent({
    required this.title,
    required this.schedule,
    required this.posterLabel,
    required this.posterColors,
  });

  final String title;
  final String schedule;
  final String posterLabel;
  final List<Color> posterColors;
}

class _ClassOffering {
  const _ClassOffering({
    required this.title,
    required this.schedule,
    required this.posterLabel,
    required this.posterColors,
  });

  final String title;
  final String schedule;
  final String posterLabel;
  final List<Color> posterColors;
}

class _SocialMediaLink {
  const _SocialMediaLink({
    required this.label,
    required this.type,
    required this.value,
  });

  final String label;
  final String type;
  final String value;
}

class _PillData {
  const _PillData(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final initials = parts.take(2).map((part) => part[0]).join().toUpperCase();

    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5E6F65), Color(0xFF9FB0A6)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? 'IM' : initials,
        style: const TextStyle(
          fontFamily: 'Figtree',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _PosterArtwork extends StatelessWidget {
  const _PosterArtwork({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    switch (label.toUpperCase()) {
      case 'FAMILY':
        return const Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 10,
              left: 8,
              right: 8,
              child: Text(
                'family',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Proza Libre',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF8F3E9),
                ),
              ),
            ),
            Positioned(
              bottom: 14,
              left: 10,
              right: 10,
              child: Icon(
                Icons.groups_rounded,
                size: 28,
                color: Color(0xFFF6E8C6),
              ),
            ),
          ],
        );
      case 'IFTAR':
        return const Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 12,
              left: 8,
              right: 8,
              child: Text(
                'Iftar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Proza Libre',
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFD255),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 14,
              child: Icon(
                Icons.wb_twilight_rounded,
                size: 22,
                color: Color(0xFFF9F4E7),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 14,
              child: Icon(
                Icons.nightlight_round,
                size: 20,
                color: Color(0xFFF9F4E7),
              ),
            ),
          ],
        );
      case 'ISLAM':
        return const Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 14,
              left: 8,
              right: 8,
              child: Text(
                'ISLAM',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 15,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF9F4E7),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 10,
              right: 10,
              child: Icon(
                Icons.menu_book_rounded,
                size: 24,
                color: Color(0xFFF4D6EC),
              ),
            ),
          ],
        );
      case '40':
        return const Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Text(
                '40',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Proza Libre',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFE0C7),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 8,
              right: 8,
              child: Text(
                'HADITH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: Color(0xFFFFEAD6),
                ),
              ),
            ),
          ],
        );
      case 'LOVE':
        return const Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 12,
              left: 8,
              right: 8,
              child: Text(
                'LOVE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Proza Libre',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF8EAFD),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Icon(
                Icons.favorite_border_rounded,
                size: 24,
                color: Color(0xFFF8EAFD),
              ),
            ),
          ],
        );
      case 'QURAN':
        return const Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 12,
              left: 8,
              right: 8,
              child: Text(
                'Quran',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Proza Libre',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF0F7EA),
                ),
              ),
            ),
            Positioned(
              bottom: 13,
              left: 0,
              right: 0,
              child: Icon(
                Icons.auto_stories_outlined,
                size: 24,
                color: Color(0xFFEAF7E4),
              ),
            ),
          ],
        );
      default:
        return Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Proza Libre',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        );
    }
  }
}

MosqueModel? _findMosqueById(List<MosqueModel> mosques, String mosqueId) {
  for (final mosque in mosques) {
    if (mosque.id == mosqueId) {
      return mosque;
    }
  }
  return null;
}

bool _isUnauthorized(Object error) {
  return error is ApiException && error.statusCode == 401;
}

void _scheduleLoginRedirect(BuildContext context) {
  scheduleUnauthenticatedRedirect(context);
}

String _buildMosqueShareText(MosqueModel mosque, _MosquePageContent content) {
  final lines = <String>[
    content.mosqueName,
    if (content.address.trim().isNotEmpty) content.address.trim(),
    if (mosque.contactPhone.trim().isNotEmpty)
      'Call: ${mosque.contactPhone.trim()}',
    if (mosque.websiteUrl.trim().isNotEmpty)
      'Website: ${mosque.websiteUrl.trim()}',
  ];
  return lines.join('\n');
}

IconData _facilityIcon(String facility) {
  final normalized = facility.toLowerCase();
  if (normalized.contains('women')) return Icons.accessibility_new_rounded;
  if (normalized.contains('wheelchair')) return Icons.accessible_rounded;
  if (normalized.contains('parking')) return Icons.local_parking_outlined;
  if (normalized.contains('wudu')) return Icons.water_drop_outlined;
  if (normalized.contains('washroom')) return Icons.wc_outlined;
  return Icons.check_circle_outline_rounded;
}

IconData _prayerIcon(String prayer) {
  switch (prayer.toLowerCase()) {
    case 'fajr':
      return Icons.wb_twilight_outlined;
    case 'dhuhr':
    case 'zuhr':
      return Icons.wb_sunny_outlined;
    case 'asr':
      return Icons.brightness_5_outlined;
    case 'maghrib':
      return Icons.nights_stay_outlined;
    case 'isha':
      return Icons.dark_mode_outlined;
    case 'jumuah':
      return Icons.people_outline_rounded;
    default:
      return Icons.access_time_rounded;
  }
}

List<_CommunityEvent>? _eventsFromMosqueContent(MosqueContent? content) {
  final events = content?.events;
  if (events == null || events.isEmpty) {
    return null;
  }

  const palettes = <List<Color>>[
    [Color(0xFF6F736B), Color(0xFFB1B6A5)],
    [Color(0xFF1D60A5), Color(0xFF1A8D7A)],
    [Color(0xFF4B3F99), Color(0xFFCF5FA1)],
  ];

  return events.take(3).toList(growable: false).asMap().entries.map((entry) {
    final item = entry.value;
    return _CommunityEvent(
      title: item.title,
      schedule: item.schedule,
      posterLabel: item.posterLabel,
      posterColors: palettes[entry.key % palettes.length],
    );
  }).toList(growable: false);
}

List<_ClassOffering>? _classesFromMosqueContent(MosqueContent? content) {
  final classes = content?.classes;
  if (classes == null || classes.isEmpty) {
    return null;
  }

  const palettes = <List<Color>>[
    [Color(0xFF7B3E3D), Color(0xFFC17363)],
    [Color(0xFF4763C9), Color(0xFF8E9BFF)],
    [Color(0xFF2C845B), Color(0xFF7CC59A)],
  ];

  return classes.take(3).toList(growable: false).asMap().entries.map((entry) {
    final item = entry.value;
    return _ClassOffering(
      title: item.title,
      schedule: item.schedule,
      posterLabel: item.posterLabel,
      posterColors: palettes[entry.key % palettes.length],
    );
  }).toList(growable: false);
}

List<_SocialMediaLink>? _connectLinksFromMosqueContent(MosqueContent? content) {
  final links = content?.connect;
  if (links == null || links.isEmpty) {
    return null;
  }

  return links
      .take(4)
      .map(
        (link) => _SocialMediaLink(
          label: link.label,
          type: link.type,
          value: link.value,
        ),
      )
      .toList(growable: false);
}

IconData _socialIcon(String type, String label) {
  final lowerType = type.toLowerCase();
  final lower = label.toLowerCase();
  if (lowerType.contains('instagram')) return Icons.camera_alt_outlined;
  if (lowerType.contains('facebook')) return Icons.thumb_up_alt_outlined;
  if (lowerType.contains('youtube')) return Icons.play_circle_outline_rounded;
  if (lowerType.contains('phone')) return Icons.call_outlined;
  if (lowerType.contains('email')) return Icons.email_outlined;
  if (lowerType.contains('whatsapp')) return Icons.chat_outlined;
  if (lowerType.contains('telegram')) return Icons.send_outlined;
  if (lower.contains('instagram')) return Icons.camera_alt_outlined;
  if (lower.contains('facebook')) return Icons.thumb_up_alt_outlined;
  if (lower.contains('youtube')) return Icons.play_circle_outline_rounded;
  if (lower.contains('@')) return Icons.email_outlined;
  if (lower.contains('+')) return Icons.call_outlined;
  if (lower.contains('website') || lower.contains('.org')) {
    return Icons.language_outlined;
  }
  return Icons.link_outlined;
}

String _toTitleCase(String value) {
  final words = value
      .split(' ')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .toList(growable: false);
  return words.join(' ');
}
