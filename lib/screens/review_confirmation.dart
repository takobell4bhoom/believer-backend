import 'package:flutter/material.dart';

import '../navigation/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class ReviewConfirmation extends StatelessWidget {
  const ReviewConfirmation({super.key});

  static const _surfaceRadius = Radius.circular(34);

  void _goHome(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final shellWidth = width > 480 ? 460.0 : width;
            final compact = width < 360;

            return Center(
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
                      compact ? 22 : 28,
                      compact ? 32 : 40,
                      compact ? 22 : 28,
                      24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 12),
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ConfirmationGraphic(compact: compact),
                                const SizedBox(height: 36),
                                Text(
                                  'Your review has been posted!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTypography.figtreeFamily,
                                    fontSize: compact ? 22 : 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryText,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('review-confirmation-home'),
                          onPressed: () => _goHome(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accentSoft,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Back to home',
                            style: TextStyle(
                              fontFamily: AppTypography.figtreeFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

class _ConfirmationGraphic extends StatelessWidget {
  const _ConfirmationGraphic({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 122.0 : 136.0;
    final circleSize = compact ? 84.0 : 96.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: compact ? 18 : 14,
            right: compact ? 16 : 12,
            child: const _CelebrationDots(
              dots: [
                _CelebrationDot(offset: Offset(0, 0), color: Color(0xFFC97C6A)),
                _CelebrationDot(offset: Offset(10, 6), color: AppColors.accent),
                _CelebrationDot(
                  offset: Offset(18, 14),
                  color: AppColors.lineStrong,
                  size: 3,
                ),
                _CelebrationDot(
                  offset: Offset(6, 20),
                  color: AppColors.accentSoft,
                ),
                _CelebrationDot(
                  offset: Offset(26, 19),
                  color: Color(0xFFC97C6A),
                  size: 5,
                ),
              ],
            ),
          ),
          Positioned(
            left: compact ? 10 : 4,
            bottom: compact ? 18 : 12,
            child: const _CelebrationDots(
              dots: [
                _CelebrationDot(offset: Offset(0, 0), color: Color(0xFFC97C6A)),
                _CelebrationDot(
                  offset: Offset(10, 10),
                  color: AppColors.accentSoft,
                  size: 3,
                ),
                _CelebrationDot(
                  offset: Offset(18, 18),
                  color: AppColors.accent,
                ),
                _CelebrationDot(
                  offset: Offset(28, 20),
                  color: AppColors.lineStrong,
                  size: 3,
                ),
                _CelebrationDot(
                  offset: Offset(16, 28),
                  color: Color(0xFFC97C6A),
                  size: 5,
                ),
              ],
            ),
          ),
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE4E0),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFBED1C9), width: 1.5),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 56,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationDots extends StatelessWidget {
  const _CelebrationDots({required this.dots});

  final List<_CelebrationDot> dots;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        children: [
          for (final dot in dots)
            Positioned(
              left: dot.offset.dx,
              top: dot.offset.dy,
              child: Container(
                width: dot.size,
                height: dot.size,
                decoration: BoxDecoration(
                  color: dot.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CelebrationDot {
  const _CelebrationDot({
    required this.offset,
    required this.color,
    this.size = 4,
  });

  final Offset offset;
  final Color color;
  final double size;
}
