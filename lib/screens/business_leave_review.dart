import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_error_mapper.dart';
import '../data/auth_provider.dart';
import '../navigation/app_routes.dart';
import '../navigation/app_startup.dart';
import '../services/business_review_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class BusinessLeaveReview extends ConsumerStatefulWidget {
  const BusinessLeaveReview({
    super.key,
    this.businessListingId = 'business-listing-1',
    this.businessName = 'Community Business',
    this.reviewService,
  });

  final String businessListingId;
  final String businessName;
  final BusinessReviewService? reviewService;

  @override
  ConsumerState<BusinessLeaveReview> createState() =>
      _BusinessLeaveReviewState();
}

class BusinessLeaveReviewRouteArgs {
  const BusinessLeaveReviewRouteArgs({
    required this.businessListingId,
    required this.businessName,
  });

  final String businessListingId;
  final String businessName;
}

class _BusinessLeaveReviewState extends ConsumerState<BusinessLeaveReview> {
  static const _surfaceRadius = Radius.circular(34);

  final BusinessReviewService _fallbackReviewService = BusinessReviewService();
  final TextEditingController _commentsController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;
  bool _redirectingToLogin = false;
  String? _errorMessage;

  BusinessReviewService get _reviewService =>
      widget.reviewService ?? _fallbackReviewService;

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;

    if (_rating < 1 || _rating > 5) {
      setState(() {
        _errorMessage = 'Please select a star rating before submitting.';
      });
      return;
    }

    final auth = ref.read(authProvider).valueOrNull;
    final token = auth?.accessToken;
    if (token == null || token.isEmpty) {
      _redirectToLogin();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _reviewService.submitReview(
        businessListingId: widget.businessListingId,
        rating: _rating,
        comments: _commentsController.text.trim(),
        bearerToken: token,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.reviewConfirmation);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiErrorMapper.toUserMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _redirectToLogin() {
    if (_redirectingToLogin || !mounted) return;
    _redirectingToLogin = true;
    scheduleUnauthenticatedRedirect(context);
  }

  void _setRating(int rating) {
    if (_isSubmitting) return;
    setState(() {
      _rating = rating;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.hasValue && authState.valueOrNull == null) {
      _redirectToLogin();
      return const Scaffold(
        backgroundColor: Color(0xFFF2F4F2),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final shellWidth = width > 480 ? 460.0 : width;
            final titleStyle = TextStyle(
              fontFamily: AppTypography.figtreeFamily,
              fontSize: width < 360 ? 18 : 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
              height: 1.18,
            );
            final bodyStyle = TextStyle(
              fontFamily: AppTypography.figtreeFamily,
              fontSize: width < 360 ? 13 : 14,
              fontWeight: FontWeight.w400,
              color: AppColors.secondaryText,
              height: 1.25,
            );
            final actionGap =
                ((constraints.maxHeight - 560) * 0.2).clamp(20.0, 52.0);

            return SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                    maxWidth: shellWidth,
                  ),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.vertical(top: _surfaceRadius),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        width < 360 ? 18 : 26,
                        24,
                        width < 360 ? 18 : 26,
                        24,
                      ),
                      child: Column(
                        children: [
                          Text(
                            widget.businessName,
                            textAlign: TextAlign.center,
                            style: titleStyle,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Worked with this business?\n'
                            'Leave a quick rating to share your experience.',
                            textAlign: TextAlign.center,
                            style: bodyStyle.copyWith(
                              fontSize: width < 360 ? 13 : 15,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _BusinessReviewStarRow(
                            rating: _rating,
                            enabled: !_isSubmitting,
                            compact: width < 360,
                            onSelected: _setRating,
                          ),
                          const SizedBox(height: 28),
                          _BusinessReviewCommentField(
                            controller: _commentsController,
                            enabled: !_isSubmitting,
                            compact: width < 360,
                            onChanged: () {
                              if (_errorMessage == null) return;
                              setState(() => _errorMessage = null);
                            },
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            _BusinessReviewErrorBanner(message: _errorMessage!),
                          ],
                          SizedBox(height: actionGap),
                          _BusinessReviewActionRow(
                            compact: width < 350,
                            isSubmitting: _isSubmitting,
                            isReady: _rating > 0,
                            onCancel: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            onSubmit: _isSubmitting ? null : _submitReview,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BusinessReviewStarRow extends StatelessWidget {
  const _BusinessReviewStarRow({
    required this.rating,
    required this.enabled,
    required this.compact,
    required this.onSelected,
  });

  final int rating;
  final bool enabled;
  final bool compact;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: compact ? 10 : 18,
      runSpacing: 10,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        final selected = starNumber <= rating;
        return Semantics(
          button: true,
          label: 'Rate $starNumber star${starNumber == 1 ? '' : 's'}',
          child: InkWell(
            key: ValueKey('business-leave-review-star-$starNumber'),
            onTap: enabled ? () => onSelected(starNumber) : null,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                selected ? Icons.star_rounded : Icons.star_border_rounded,
                size: compact ? 38 : 46,
                color: selected ? const Color(0xFFF0A52A) : AppColors.line,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BusinessReviewCommentField extends StatelessWidget {
  const _BusinessReviewCommentField({
    required this.controller,
    required this.enabled,
    required this.compact,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool compact;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('business-leave-review-comments'),
      controller: controller,
      enabled: enabled,
      onChanged: (_) => onChanged(),
      minLines: compact ? 4 : 5,
      maxLines: compact ? 4 : 5,
      decoration: InputDecoration(
        hintText: 'Share a few details to help others know what to expect.',
        hintStyle: TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: compact ? 13 : 14,
          color: AppColors.secondaryText,
        ),
        filled: true,
        fillColor: const Color(0xFFF4F5F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 18,
          vertical: compact ? 16 : 18,
        ),
      ),
      style: TextStyle(
        fontFamily: AppTypography.figtreeFamily,
        fontSize: compact ? 13 : 14,
        color: AppColors.primaryText,
        height: 1.3,
      ),
    );
  }
}

class _BusinessReviewErrorBanner extends StatelessWidget {
  const _BusinessReviewErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.error,
          height: 1.3,
        ),
      ),
    );
  }
}

class _BusinessReviewActionRow extends StatelessWidget {
  const _BusinessReviewActionRow({
    required this.compact,
    required this.isSubmitting,
    required this.isReady,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool compact;
  final bool isSubmitting;
  final bool isReady;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final stackVertically = compact;

    final cancelButton = OutlinedButton(
      onPressed: onCancel,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
      ),
      child: const Text(
        'Maybe Later',
        style: TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText,
        ),
      ),
    );

    final submitButton = FilledButton(
      key: const ValueKey('business-leave-review-submit'),
      onPressed: onSubmit,
      style: FilledButton.styleFrom(
        backgroundColor: isReady ? const Color(0xFF516D53) : AppColors.line,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      ),
      child: isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Submit',
              style: TextStyle(
                fontFamily: AppTypography.figtreeFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    if (stackVertically) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: double.infinity, child: submitButton),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: cancelButton),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cancelButton),
        const SizedBox(width: 14),
        Expanded(child: submitButton),
      ],
    );
  }
}
