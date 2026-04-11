import 'package:flutter/material.dart';

import '../core/api_error_mapper.dart';
import '../models/review.dart';
import '../services/mosque_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/common/async_states.dart';
import '../widgets/common/screen_header.dart';

class ReviewScreenRouteArgs {
  const ReviewScreenRouteArgs({
    required this.mosqueId,
    required this.mosqueName,
    this.initialReviews = const <Review>[],
  });

  final String mosqueId;
  final String mosqueName;
  final List<Review> initialReviews;
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.reviews,
    this.mosqueId,
    this.mosqueName,
    this.mosqueService,
  });

  final List<Review> reviews;
  final String? mosqueId;
  final String? mosqueName;
  final MosqueService? mosqueService;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final MosqueService _mosqueService;

  late List<Review> _reviews;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mosqueService = widget.mosqueService ?? MosqueService();
    _reviews = widget.reviews;

    if (widget.mosqueId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadReviews();
        }
      });
    }
  }

  Future<void> _loadReviews() async {
    final mosqueId = widget.mosqueId;
    if (mosqueId == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final feed = await _mosqueService.getMosqueReviews(mosqueId);
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
              if (widget.mosqueName != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.mosqueName!,
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
        onRetry: widget.mosqueId == null ? null : _loadReviews,
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
