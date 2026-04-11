import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_error_mapper.dart';
import '../data/auth_provider.dart';
import '../navigation/app_startup.dart';
import '../navigation/app_routes.dart';
import '../services/mosque_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class LeaveReview extends ConsumerStatefulWidget {
  const LeaveReview({
    super.key,
    this.mosqueId = 'mosque-1',
    this.mosqueName = 'Downtown Community Mosque',
    this.mosqueService,
  });

  final String mosqueId;
  final String mosqueName;
  final MosqueService? mosqueService;

  @override
  ConsumerState<LeaveReview> createState() => _LeaveReviewState();
}

class LeaveReviewRouteArgs {
  const LeaveReviewRouteArgs({
    required this.mosqueId,
    required this.mosqueName,
  });

  final String mosqueId;
  final String mosqueName;
}

class _LeaveReviewState extends ConsumerState<LeaveReview> {
  static const _surfaceRadius = Radius.circular(34);

  final MosqueService _fallbackMosqueService = MosqueService();
  final TextEditingController _commentsController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;
  bool _redirectingToLogin = false;
  String? _errorMessage;

  MosqueService get _mosqueService =>
      widget.mosqueService ?? _fallbackMosqueService;

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
      await _mosqueService.submitReview(
        mosqueId: widget.mosqueId,
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
                            widget.mosqueName,
                            textAlign: TextAlign.center,
                            style: titleStyle,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Been to this mosque?\n'
                            'Leave a quick rating to share your experience.',
                            textAlign: TextAlign.center,
                            style: bodyStyle.copyWith(
                              fontSize: width < 360 ? 13 : 15,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _ReviewStarRow(
                            rating: _rating,
                            enabled: !_isSubmitting,
                            compact: width < 360,
                            onSelected: _setRating,
                          ),
                          const SizedBox(height: 28),
                          _ReviewCommentField(
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
                            _ReviewErrorBanner(message: _errorMessage!),
                          ],
                          SizedBox(height: actionGap),
                          _ReviewActionRow(
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

class _ReviewStarRow extends StatelessWidget {
  const _ReviewStarRow({
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
            key: ValueKey('leave-review-star-$starNumber'),
            onTap: enabled ? () => onSelected(starNumber) : null,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                selected ? Icons.star_rounded : Icons.star_outline_rounded,
                size: compact ? 44 : 48,
                color: selected ? AppColors.accent : AppColors.secondaryText,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ReviewCommentField extends StatelessWidget {
  const _ReviewCommentField({
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDCE1DE),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 20,
        vertical: compact ? 14 : 16,
      ),
      child: TextField(
        key: const ValueKey('leave-review-comments'),
        controller: controller,
        enabled: enabled,
        minLines: compact ? 7 : 8,
        maxLines: compact ? 7 : 8,
        maxLength: 250,
        onChanged: (_) => onChanged(),
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Share your thoughts about this mosque...',
          hintStyle: TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.secondaryText,
          ),
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.primaryText,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ReviewErrorBanner extends StatelessWidget {
  const _ReviewErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
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
          ),
        ],
      ),
    );
  }
}

class _ReviewActionRow extends StatelessWidget {
  const _ReviewActionRow({
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
    final cancelButton = SizedBox(
      height: 56,
      child: TextButton(
        key: const ValueKey('leave-review-cancel'),
        onPressed: onCancel,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.accentSoft,
          ),
        ),
      ),
    );

    final submitButton = SizedBox(
      height: 56,
      child: ElevatedButton(
        key: const ValueKey('leave-review-submit'),
        onPressed: onSubmit,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isReady ? AppColors.disabled : AppColors.disabled,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : const Text(
                'Submit',
                style: TextStyle(
                  fontFamily: AppTypography.figtreeFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          submitButton,
          const SizedBox(height: 10),
          cancelButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cancelButton),
        const SizedBox(width: 18),
        Expanded(child: submitButton),
      ],
    );
  }
}
