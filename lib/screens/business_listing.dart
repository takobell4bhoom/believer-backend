import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_provider.dart';
import '../models/service.dart';
import '../navigation/app_routes.dart';
import '../screens/business_leave_review.dart';
import '../screens/business_review_screen.dart';
import '../services/outbound_action_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/common/async_states.dart';
import '../widgets/common/screen_header.dart';

class BusinessListingRouteArgs {
  const BusinessListingRouteArgs({
    this.service,
  });

  final Service? service;
}

class BusinessListing extends ConsumerStatefulWidget {
  const BusinessListing({
    super.key,
    this.args = const BusinessListingRouteArgs(),
    this.outboundActionService = const OutboundActionService(),
  });

  final BusinessListingRouteArgs args;
  final OutboundActionService outboundActionService;

  @override
  ConsumerState<BusinessListing> createState() => _BusinessListingState();
}

class _BusinessListingState extends ConsumerState<BusinessListing> {
  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showResult(Future<OutboundActionResult> future) async {
    final result = await future;
    if (!mounted) return;
    _showFeedback(result.message);
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.args.service;
    if (service == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F6F2),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ScreenHeader(
                  title: 'Business Details',
                  bottomSpacing: 12,
                ),
              ),
              const Expanded(
                child: Center(
                  child: EmptyState(
                    title: 'Business details unavailable',
                    subtitle:
                        'Open a business from Services to view the latest listing details.',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final business = _BusinessListingData.fromService(service);
    final opensWebsite = business.websiteUrl?.trim().isNotEmpty == true;
    final authSession = ref.watch(authProvider).valueOrNull;
    final canLeaveReview = authSession != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F2),
      bottomNavigationBar: _BusinessActionBar(
        onCallTap: () => _showResult(
          widget.outboundActionService.launchPhone(
            business.phoneNumber,
            successMessage: 'Opening business phone number...',
            fallbackMessage:
                'Could not open the phone app. Business number copied to clipboard.',
            unavailableMessage:
                'This business has not published a phone number yet.',
          ),
        ),
        onWhatsappTap: () => _showResult(
          widget.outboundActionService.launchWhatsApp(
            business.whatsappNumber ?? business.phoneNumber,
            message: 'Salam, I found your listing on Believers Lens.',
            successMessage: 'Opening WhatsApp...',
            fallbackMessage:
                'Could not open WhatsApp. Business contact copied to clipboard.',
            unavailableMessage:
                'This business has not published a WhatsApp contact yet.',
          ),
        ),
        onDirectionsTap: () => _showResult(
          widget.outboundActionService.launchDirections(
            address: business.fullAddress,
            successMessage: 'Opening business directions...',
            fallbackMessage:
                'Could not open maps. Business address copied to clipboard.',
            unavailableMessage:
                'This business does not have a mappable address yet.',
          ),
        ),
        primaryLabel: opensWebsite ? 'Website' : 'Share',
        onPrimaryTap: () => _showResult(
          opensWebsite
              ? widget.outboundActionService.launchExternalLink(
                  business.websiteUrl,
                  type: 'website',
                  successMessage: 'Opening website...',
                  fallbackMessage:
                      'Could not open the website. Link copied to clipboard.',
                  unavailableMessage:
                      'This business has not published a website yet.',
                )
              : widget.outboundActionService.shareText(
                  business.shareText,
                  subject: business.name,
                  successMessage: 'Share options opened for this business.',
                  fallbackMessage:
                      'Could not open share options. Business details copied to clipboard.',
                ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ScreenHeader(
                title: 'Business Details',
                bottomSpacing: 12,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BusinessHeroCard(
                          business: business,
                          onShareTap: () => _showResult(
                            widget.outboundActionService.shareText(
                              business.shareText,
                              subject: business.name,
                              successMessage:
                                  'Share options opened for this business.',
                              fallbackMessage:
                                  'Could not open share options. Business details copied to clipboard.',
                            ),
                          ),
                          onOpenHoursTap: () => _showFeedback(
                            'Open hours: ${business.hoursLabel}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${business.savedCount} users have saved this business',
                                style: const TextStyle(
                                  fontFamily: AppTypography.figtreeFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF667066),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF0A52A),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              business.listingRating,
                              style: const TextStyle(
                                fontFamily: AppTypography.figtreeFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7A7867),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final tag in business.tags)
                              _BusinessTagChip(tag),
                            const _BusinessVerifiedChip(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          business.description,
                          style: const TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 10.4,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF5E655F),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _BusinessBodySection(
                          title: 'Services We Offer:',
                          lines: business.servicesOffered,
                        ),
                        const SizedBox(height: 14),
                        _BusinessBodySection(
                          title: 'Specialties:',
                          lines: business.specialties,
                        ),
                        const SizedBox(height: 14),
                        if (business.connectLinks.isNotEmpty) ...[
                          const _BusinessSectionHeading('CONNECT'),
                          const SizedBox(height: 8),
                          for (final link in business.connectLinks) ...[
                            _BusinessLinkButton(
                              icon: link.icon,
                              label: link.label,
                              onTap: () => _showResult(
                                widget.outboundActionService.launchExternalLink(
                                  link.value,
                                  type: link.type,
                                  successMessage: link.successMessage,
                                  fallbackMessage: link.fallbackMessage,
                                  unavailableMessage: link.unavailableMessage,
                                ),
                              ),
                            ),
                            if (link != business.connectLinks.last)
                              const SizedBox(height: 7),
                          ],
                          const SizedBox(height: 16),
                        ],
                        const _BusinessSectionHeading('REVIEWS'),
                        const SizedBox(height: 8),
                        if (business.reviewCount > 0) ...[
                          Row(
                            children: [
                              const Text(
                                '★★★★☆',
                                style: TextStyle(
                                  fontFamily: AppTypography.figtreeFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF0A52A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                business.reviewSummary,
                                style: const TextStyle(
                                  fontFamily: AppTypography.figtreeFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5F665F),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.reviews,
                                  arguments: BusinessReviewScreenRouteArgs(
                                    businessListingId: service.id,
                                    businessName: business.name,
                                  ),
                                );
                              },
                              child: Text(
                                business.reviewCount > 0
                                    ? 'Read all reviews'
                                    : 'Check reviews',
                              ),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.leaveReview,
                                  arguments: BusinessLeaveReviewRouteArgs(
                                    businessListingId: service.id,
                                    businessName: business.name,
                                  ),
                                );
                              },
                              child: Text(
                                canLeaveReview
                                    ? 'Leave review'
                                    : 'Login to leave review',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 84),
                          child: Text(
                            business.reviewAvailabilityMessage,
                            style: const TextStyle(
                              fontFamily: AppTypography.figtreeFamily,
                              fontSize: 9.8,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF636962),
                            ),
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

class _BusinessHeroCard extends StatelessWidget {
  const _BusinessHeroCard({
    required this.business,
    required this.onShareTap,
    required this.onOpenHoursTap,
  });

  final _BusinessListingData business;
  final VoidCallback onShareTap;
  final VoidCallback onOpenHoursTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1EC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(
                    business.logoTileBackgroundColor ?? 0xFFF0DDCB,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: business.logoBytes != null
                      ? Image.memory(
                          business.logoBytes!,
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: _BusinessBrandMark(),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF364039),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 10,
                          color: Color(0xFF677168),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            business.addressLine1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.figtreeFamily,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF677168),
                            ),
                          ),
                        ),
                        Text(
                          business.distanceLabel,
                          style: const TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF677168),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 13),
                      child: Text(
                        business.addressLine2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.figtreeFamily,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF677168),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  onPressed: onShareTap,
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.share_rounded,
                    size: 18,
                    color: Color(0xFF4F5F51),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: onOpenHoursTap,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4E5A4F),
                  backgroundColor: const Color(0xFFF5F4EE),
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Hours',
                  style: TextStyle(
                    fontFamily: AppTypography.figtreeFamily,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4E5A4F),
                  ),
                ),
              ),
              const Text(
                '|',
                style: TextStyle(
                  fontFamily: AppTypography.figtreeFamily,
                  fontSize: 10,
                  color: Color(0xFF656B63),
                ),
              ),
              Text(
                business.hoursLabel,
                style: const TextStyle(
                  fontFamily: AppTypography.figtreeFamily,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE18B2D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusinessBrandMark extends StatelessWidget {
  const _BusinessBrandMark();

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
                width: 22,
                height: 22,
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
              size: 19,
              color: Color(0xFF7C6A63),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'BARAKAH',
          style: TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 4.8,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: Color(0xFF8B7C74),
          ),
        ),
      ],
    );
  }
}

class _BusinessTagChip extends StatelessWidget {
  const _BusinessTagChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD0DDD1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: 9.4,
          fontWeight: FontWeight.w600,
          color: Color(0xFF59625A),
        ),
      ),
    );
  }
}

class _BusinessVerifiedChip extends StatelessWidget {
  const _BusinessVerifiedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFD0DDD1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: 12,
            color: Color(0xFF4F6355),
          ),
          SizedBox(width: 4),
          Text(
            'Live listing',
            style: TextStyle(
              fontFamily: AppTypography.figtreeFamily,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF59625A),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessBodySection extends StatelessWidget {
  const _BusinessBodySection({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 10.7,
            fontWeight: FontWeight.w700,
            color: Color(0xFF505650),
          ),
        ),
        const SizedBox(height: 6),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: const TextStyle(
                fontFamily: AppTypography.figtreeFamily,
                fontSize: 9.7,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: Color(0xFF636962),
              ),
            ),
          ),
      ],
    );
  }
}

class _BusinessSectionHeading extends StatelessWidget {
  const _BusinessSectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: Color(0xFF565D57),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 1,
          color: const Color(0xFFDADDD7),
        ),
      ],
    );
  }
}

class _BusinessLinkButton extends StatelessWidget {
  const _BusinessLinkButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE0E3DE),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4F5E52),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 10, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5D685E),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF5D685E),
                    ),
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

class _BusinessActionBar extends StatelessWidget {
  const _BusinessActionBar({
    required this.onCallTap,
    required this.onWhatsappTap,
    required this.onDirectionsTap,
    required this.primaryLabel,
    required this.onPrimaryTap,
  });

  final VoidCallback onCallTap;
  final VoidCallback onWhatsappTap;
  final VoidCallback onDirectionsTap;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F4),
          border: Border(top: BorderSide(color: Color(0xFFD7DBD6))),
        ),
        child: Row(
          children: [
            _BusinessCircleActionButton(
              icon: Icons.call_outlined,
              onTap: onCallTap,
            ),
            const SizedBox(width: 6),
            _BusinessCircleActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: onWhatsappTap,
            ),
            const SizedBox(width: 6),
            _BusinessCircleActionButton(
              icon: Icons.navigation_outlined,
              onTap: onDirectionsTap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onPrimaryTap,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF516D53),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.north_east_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontFamily: AppTypography.figtreeFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessCircleActionButton extends StatelessWidget {
  const _BusinessCircleActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F2ED),
      shape: const CircleBorder(
        side: BorderSide(color: Color(0xFF8C978D)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF4F6550),
          ),
        ),
      ),
    );
  }
}

class _BusinessListingData {
  const _BusinessListingData({
    required this.name,
    required this.addressLine1,
    required this.addressLine2,
    required this.fullAddress,
    required this.distanceLabel,
    required this.description,
    required this.tags,
    required this.savedCount,
    required this.listingRating,
    required this.reviewSummary,
    required this.reviewCount,
    required this.reviewAvailabilityMessage,
    required this.hoursLabel,
    required this.phoneNumber,
    required this.whatsappNumber,
    required this.websiteUrl,
    required this.logoBytes,
    required this.logoTileBackgroundColor,
    required this.servicesOffered,
    required this.specialties,
    required this.connectLinks,
  });

  final String name;
  final String addressLine1;
  final String addressLine2;
  final String fullAddress;
  final String distanceLabel;
  final String description;
  final List<String> tags;
  final int savedCount;
  final String listingRating;
  final String reviewSummary;
  final int reviewCount;
  final String reviewAvailabilityMessage;
  final String hoursLabel;
  final String? phoneNumber;
  final String? whatsappNumber;
  final String? websiteUrl;
  final Uint8List? logoBytes;
  final int? logoTileBackgroundColor;
  final List<String> servicesOffered;
  final List<String> specialties;
  final List<_BusinessConnectLink> connectLinks;

  factory _BusinessListingData.fromService(Service service) {
    final addressLine1 = service.addressLine1.trim().isNotEmpty
        ? service.addressLine1.trim()
        : service.location;
    final addressLine2 = service.addressLine2.trim().isNotEmpty
        ? service.addressLine2.trim()
        : service.location;

    return _BusinessListingData(
      name: service.name,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      fullAddress: [addressLine1, addressLine2]
          .where((part) => part.trim().isNotEmpty)
          .join(', '),
      distanceLabel: _distanceLabelForLocation(service.location),
      description: _textOrFallback(
        service.description,
        'This business has not published a description yet.',
      ),
      tags: service.tags.isNotEmpty
          ? service.tags
          : <String>[
              if (service.category.trim().isNotEmpty) service.category,
            ],
      savedCount: service.savedCount,
      listingRating: service.rating.toStringAsFixed(1),
      reviewSummary:
          '${service.rating.toStringAsFixed(1)} (${service.reviewCount} reviews)',
      reviewCount: service.reviewCount,
      reviewAvailabilityMessage: service.reviewCount > 0
          ? 'This listing currently includes the published rating summary only.'
          : 'This business has not published community reviews yet.',
      hoursLabel: service.hoursLabel,
      phoneNumber: service.phoneNumber,
      whatsappNumber: service.whatsappNumber,
      websiteUrl: service.websiteUrl,
      logoBytes: service.logoBytes,
      logoTileBackgroundColor: service.logoTileBackgroundColor,
      servicesOffered: service.servicesOffered.isNotEmpty
          ? service.servicesOffered
          : const <String>[
              'This business has not published a service list yet.'
            ],
      specialties: service.specialties.isNotEmpty
          ? service.specialties
          : const <String>['This business has not published specialties yet.'],
      connectLinks: <_BusinessConnectLink>[
        if (service.instagramHandle?.trim().isNotEmpty == true)
          _BusinessConnectLink(
            icon: Icons.camera_alt_rounded,
            label: service.instagramHandle!,
            value: service.instagramHandle!,
            type: 'instagram',
          ),
        if (service.facebookPage?.trim().isNotEmpty == true)
          _BusinessConnectLink(
            icon: Icons.facebook_rounded,
            label: service.facebookPage!,
            value: service.facebookPage!,
            type: 'facebook',
          ),
        if (service.websiteUrl?.trim().isNotEmpty == true)
          _BusinessConnectLink(
            icon: Icons.language_rounded,
            label: service.websiteUrl!,
            value: service.websiteUrl!,
            type: 'website',
          ),
      ],
    );
  }

  String get shareText => '$name\n$fullAddress\n$hoursLabel';

  static String _distanceLabelForLocation(String location) {
    final normalized = location.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'location unavailable') {
      return 'Location unavailable';
    }
    if (normalized.contains('koramangala')) return '0.8 mi away';
    if (normalized.contains('indiranagar')) return '1.2 mi away';
    if (normalized.contains('frazer')) return '2.4 mi away';
    if (normalized.contains('shivajinagar')) return '1.7 mi away';
    return 'Nearby';
  }

  static String _textOrFallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

class _BusinessConnectLink {
  const _BusinessConnectLink({
    required this.icon,
    required this.label,
    required this.value,
    required this.type,
  });

  final IconData icon;
  final String label;
  final String value;
  final String type;

  String get successMessage {
    switch (type) {
      case 'instagram':
        return 'Opening Instagram...';
      case 'facebook':
        return 'Opening Facebook...';
      case 'website':
        return 'Opening website...';
      default:
        return 'Opening link...';
    }
  }

  String get fallbackMessage {
    switch (type) {
      case 'instagram':
        return 'Could not open Instagram. Link copied to clipboard.';
      case 'facebook':
        return 'Could not open Facebook. Link copied to clipboard.';
      case 'website':
        return 'Could not open the website. Link copied to clipboard.';
      default:
        return 'Could not open the link. Details copied to clipboard.';
    }
  }

  String get unavailableMessage {
    switch (type) {
      case 'instagram':
        return 'Instagram link not available yet.';
      case 'facebook':
        return 'Facebook link not available yet.';
      case 'website':
        return 'Website link not available yet.';
      default:
        return 'Link not available yet.';
    }
  }
}
