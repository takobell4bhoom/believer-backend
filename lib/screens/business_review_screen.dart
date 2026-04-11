import 'package:flutter/material.dart';

import '../core/api_error_mapper.dart';
import '../models/review.dart';
import '../services/business_review_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/common/async_states.dart';
import '../widgets/common/screen_header.dart';

class BusinessReviewScreenRouteArgs {
  const BusinessReviewScreenRouteArgs({
    required this.businessListingId,
    required this.businessName,
    this.initialReviews = const <Review>[],
  });

  final String businessListingId;
  final String businessName;
  final List<Review> initialReviews;
}

class BusinessReviewScreen extends StatefulWidget {
  const BusinessReviewScreen({
    super.key,
    required this.reviews,
    this.businessListingId,
    this.businessName,
    this.reviewService,
  });

  final List<Review> reviews;
  final String? businessListingId;
  final String? businessName;
  final BusinessReviewService? reviewService;

  @override
  State<BusinessReviewScreen> createState() => _BusinessReviewScreenState();
}

class _BusinessReviewScreenState extends State<BusinessReviewScreen> {
  late final BusinessReviewService _reviewService;

  late List<Review> _reviews;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _reviewService = widget.reviewService ?? BusinessReviewService();
    _reviews = widget.reviews;

    if (widget.businessListingId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadReviews();
        }
      });
    }
  }

  Future<void> _loadReviews() async {
    final businessListingId = widget.businessListingId;
    if (businessListingId == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final feed = await _reviewService.getBusinessReviews(businessListingId);
      if (!mounted) return;
      setState(() {
        _reviews = feed.items;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiErrorMapper.toUserMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              const ScreenHeader(title: 'Reviews'),
              if (widget.businessName != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.businessName!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _reviews.isEmpty) {
      return const LoadingState(label: 'Loading reviews...');
    }

    if (_errorMessage != null && _reviews.isEmpty) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: widget.businessListingId == null ? null : _loadReviews,
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Text(
          'No reviews yet.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.secondaryText,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ),
        ],
        Expanded(
          child: ListView.separated(
            itemCount: _reviews.length,
            separatorBuilder: (_, __) => const Divider(
              color: AppColors.line,
              height: AppSpacing.lg * 2,
            ),
            itemBuilder: (context, index) {
              final review = _reviews[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.userName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.primaryText,
                                  ),
                        ),
                      ),
                      Text(
                        '⭐ ${review.rating.toStringAsFixed(1)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppColors.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    review.comment,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.primaryText,
                        ),
                  ),
                  if (review.displayTimeAgo.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      review.displayTimeAgo,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
