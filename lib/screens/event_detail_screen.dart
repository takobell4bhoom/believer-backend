import 'package:flutter/material.dart';

import '../models/discovery_event.dart';
import '../models/mosque_model.dart';
import '../navigation/app_routes.dart';
import '../navigation/mosque_detail_route_args.dart';
import '../services/outbound_action_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/figma_section_heading.dart';

class EventDetailRouteArgs {
  const EventDetailRouteArgs({
    required this.event,
    this.discoveryEvent,
  });

  final MosqueModel event;
  final DiscoveryEvent? discoveryEvent;
}

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    super.key,
    required this.args,
    this.outboundActionService = const OutboundActionService(),
  });

  final EventDetailRouteArgs args;
  final OutboundActionService outboundActionService;

  @override
  Widget build(BuildContext context) {
    final details = args.discoveryEvent;
    final primaryAction = _EventPrimaryAction.fromMosque(args.event);

    if (details == null) {
      final organizerName = args.event.name.trim().isEmpty
          ? 'Mosque organizer'
          : args.event.name.trim();

      return Scaffold(
        backgroundColor: const Color(0xFFF3F2F0),
        bottomNavigationBar: _BottomActionBar(
          priceLabel: '',
          primaryLabel: primaryAction.label,
          onPrimaryTap: () => _handlePrimaryAction(
            context,
            action: primaryAction,
            mosque: args.event,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Event details unavailable',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334039),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'This screen does not have a published mosque event or class to show yet. Open the organizer page for current schedules and contact details.',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 12.2,
                        height: 1.42,
                        color: Color(0xFF59655E),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const FigmaSectionHeading(
                      title: 'ORGANIZER',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 11.2,
                        letterSpacing: 3.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF49534C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _OrganizerCard(
                      organizer: DiscoveryEventOrganizer(
                        name: organizerName,
                        description:
                            'Public event details appear here only after the organizer publishes them.',
                      ),
                      actionLabel: primaryAction.organizerLabel,
                      onActionTap: () => _handlePrimaryAction(
                        context,
                        action: primaryAction,
                        mosque: args.event,
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F0),
      bottomNavigationBar: _BottomActionBar(
        priceLabel: details.priceLabel,
        primaryLabel: primaryAction.label,
        onPrimaryTap: () => _handlePrimaryAction(
          context,
          action: primaryAction,
          mosque: args.event,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 8),
                  _EventPosterCard(details: details),
                  const SizedBox(height: 10),
                  _TitleRow(
                    title: details.title,
                    onShare: () => _shareEvent(context, details),
                  ),
                  const SizedBox(height: 10),
                  _DateBadge(label: details.dateLabel),
                  const SizedBox(height: 8),
                  _LocationRow(
                    location: details.locationLine,
                    distance: details.distanceLabel,
                    onTap: () => _openDirections(context, args.event, details),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: details.tags
                        .map((tag) => _TagChip(label: tag))
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    details.description,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 12.2,
                      height: 1.42,
                      color: Color(0xFF59655E),
                    ),
                  ),
                  if (details.speakers.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const FigmaSectionHeading(
                      title: 'EVENT SPEAKERS',
                      style: TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 11.2,
                        letterSpacing: 3.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF49534C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: details.speakers
                          .map(
                            (speaker) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _SpeakerCard(speaker: speaker),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 4),
                  ] else
                    const SizedBox(height: 18),
                  const FigmaSectionHeading(
                    title: 'ORGANIZER',
                    style: TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 11.2,
                      letterSpacing: 3.2,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF49534C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _OrganizerCard(
                    organizer: details.organizer,
                    actionLabel: primaryAction.organizerLabel,
                    onActionTap: () => _handlePrimaryAction(
                      context,
                      action: primaryAction,
                      mosque: args.event,
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

  Future<void> _shareEvent(
    BuildContext context,
    DiscoveryEvent details,
  ) async {
    final result = await outboundActionService.shareText(
      details.shareText,
      subject: details.title,
      successMessage: 'Share options opened for this event.',
      fallbackMessage:
          'Could not open share options. Event details copied to clipboard.',
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _openDirections(
    BuildContext context,
    MosqueModel mosque,
    DiscoveryEvent details,
  ) async {
    final result = await outboundActionService.launchDirections(
      address: details.locationLine,
      latitude: mosque.latitude,
      longitude: mosque.longitude,
      successMessage: 'Opening event directions...',
      fallbackMessage:
          'Could not open maps. Event location copied to clipboard.',
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _handlePrimaryAction(
    BuildContext context, {
    required _EventPrimaryAction action,
    required MosqueModel mosque,
  }) async {
    switch (action.type) {
      case _EventPrimaryActionType.website:
        {
          final result = await outboundActionService.launchExternalLink(
            mosque.websiteUrl,
            type: 'website',
            successMessage: 'Opening organizer website...',
            fallbackMessage:
                'Could not open the organizer website. Link copied to clipboard.',
            unavailableMessage:
                'The organizer has not published a website for this event.',
          );
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(result.message)));
          return;
        }
      case _EventPrimaryActionType.email:
        {
          final result = await outboundActionService.launchEmail(
            mosque.contactEmail,
            subject: 'Question about ${mosque.name}',
            successMessage: 'Opening organizer email...',
            fallbackMessage:
                'Could not open the email app. Organizer email copied to clipboard.',
            unavailableMessage:
                'The organizer has not published an email for this event.',
          );
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(result.message)));
          return;
        }
      case _EventPrimaryActionType.phone:
        {
          final result = await outboundActionService.launchPhone(
            mosque.contactPhone,
            successMessage: 'Opening organizer phone number...',
            fallbackMessage:
                'Could not open the phone app. Organizer number copied to clipboard.',
            unavailableMessage:
                'The organizer has not published a phone number for this event.',
          );
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(result.message)));
          return;
        }
      case _EventPrimaryActionType.mosquePage:
        Navigator.of(context).pushNamed(
          AppRoutes.mosqueDetail,
          arguments: MosqueDetailRouteArgs.fromMosque(mosque),
        );
        return;
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            splashRadius: 18,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            icon: const Icon(
              Icons.arrow_back,
              size: 22,
              color: Color(0xFF29332D),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventPosterCard extends StatelessWidget {
  const _EventPosterCard({required this.details});

  final DiscoveryEvent details;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: double.infinity,
        height: 152,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: details.posterColors,
            ),
          ),
          child: switch (details.posterStyle) {
            DiscoveryEventPosterStyle.seerah => const _SeerahPosterArtwork(),
            DiscoveryEventPosterStyle.community =>
              const _CommunityPosterArtwork(),
            DiscoveryEventPosterStyle.generic => const _GenericPosterArtwork(),
          },
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.onShare,
  });

  final String title;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Figtree',
              fontSize: 16,
              height: 1.22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334039),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onShare,
          padding: EdgeInsets.zero,
          splashRadius: 18,
          constraints: const BoxConstraints.tightFor(width: 24, height: 24),
          icon: const Icon(
            Icons.share_outlined,
            size: 21,
            color: Color(0xFF4D614E),
          ),
        ),
      ],
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD19A52),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Figtree',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.location,
    required this.distance,
    required this.onTap,
  });

  final String location;
  final String distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 335;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Color(0xFF4E5E50),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4E5E50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.near_me_outlined,
                      size: 16,
                      color: Color(0xFF4E5E50),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9DEDA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    distance,
                    style: const TextStyle(
                      fontFamily: 'Figtree',
                      fontSize: 10.4,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5C675F),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFD1DED6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Figtree',
          fontSize: 10.4,
          fontWeight: FontWeight.w500,
          color: Color(0xFF4B5D4E),
        ),
      ),
    );
  }
}

class _SpeakerCard extends StatelessWidget {
  const _SpeakerCard({required this.speaker});

  final DiscoveryEventSpeaker speaker;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFD9DEDB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _AvatarBadge(
            initials: speaker.initials,
            palette: speaker.avatarColors,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  speaker.name,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3731),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  speaker.bio,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 10.8,
                    height: 1.3,
                    color: Color(0xFF67736A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  const _OrganizerCard({
    required this.organizer,
    required this.actionLabel,
    required this.onActionTap,
  });

  final DiscoveryEventOrganizer organizer;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFD9DEDB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/illustrations/business_logo.png',
              width: 34,
              height: 34,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.apartment_rounded,
                  color: AppColors.accent,
                  size: 24,
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organizer.name,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3731),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  organizer.description,
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 10.8,
                    height: 1.3,
                    color: Color(0xFF67736A),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onActionTap,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF556B57),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(Icons.north_east_rounded, size: 16),
                        Text(
                          actionLabel,
                          style: const TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 10.8,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.initials,
    required this.palette,
  });

  final String initials;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
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

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.priceLabel,
    required this.primaryLabel,
    required this.onPrimaryTap,
  });

  final String priceLabel;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 330;
            final hasPriceLabel = priceLabel.trim().isNotEmpty;
            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasPriceLabel)
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 10),
                      child: Text(
                        priceLabel,
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6D8F6E),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: onPrimaryTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF556B57),
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    primaryLabel,
                                    style: const TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.north_east_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                if (hasPriceLabel)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, right: 14),
                    child: Text(
                      priceLabel,
                      style: const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6D8F6E),
                      ),
                    ),
                  ),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: onPrimaryTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF556B57),
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    primaryLabel,
                                    style: const TextStyle(
                                      fontFamily: 'Figtree',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.north_east_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _EventPrimaryActionType { website, email, phone, mosquePage }

class _EventPrimaryAction {
  const _EventPrimaryAction({
    required this.type,
    required this.label,
    required this.organizerLabel,
  });

  final _EventPrimaryActionType type;
  final String label;
  final String organizerLabel;

  factory _EventPrimaryAction.fromMosque(MosqueModel mosque) {
    if (mosque.websiteUrl.trim().isNotEmpty) {
      return const _EventPrimaryAction(
        type: _EventPrimaryActionType.website,
        label: 'Visit Organizer Site',
        organizerLabel: 'Visit organizer site',
      );
    }

    if (mosque.contactEmail.trim().isNotEmpty) {
      return const _EventPrimaryAction(
        type: _EventPrimaryActionType.email,
        label: 'Email Organizer',
        organizerLabel: 'Email organizer',
      );
    }

    if (mosque.contactPhone.trim().isNotEmpty) {
      return const _EventPrimaryAction(
        type: _EventPrimaryActionType.phone,
        label: 'Call Organizer',
        organizerLabel: 'Call organizer',
      );
    }

    return const _EventPrimaryAction(
      type: _EventPrimaryActionType.mosquePage,
      label: 'Open Organizer Page',
      organizerLabel: 'Open organizer page',
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
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 16,
          child: Column(
            children: [
              Text(
                'SEERAH',
                style: TextStyle(
                  fontFamily: 'Proza Libre',
                  fontSize: 34,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF564225),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'TRAIL',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 16,
                  letterSpacing: 7,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF766046),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'LONDON - MAKKA - MADINA',
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 7,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B775B),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'PERFORM UMRAH WITH SCHOLARS AND LEARN ABOUT THE LIFE OF\nTHE PROPHET THROUGH IN MAKKA AND MADINA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 5.8,
                  height: 1.45,
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFAD9A7F),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFB09A79), width: 1.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 12,
                color: Color(0xFF9F8967),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommunityPosterArtwork extends StatelessWidget {
  const _CommunityPosterArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 16,
          top: 18,
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 16,
          child: Container(
            width: 90,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(40),
            ),
          ),
        ),
        const Positioned.fill(
          child: Center(
            child: Text(
              'COMMUNITY\nEVENT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Proza Libre',
                fontSize: 28,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenericPosterArtwork extends StatelessWidget {
  const _GenericPosterArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 24,
          top: 24,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        Positioned(
          right: 22,
          top: 34,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Positioned.fill(
          child: Center(
            child: Text(
              'BELIEVERS\nEVENT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 28,
                height: 1.0,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
