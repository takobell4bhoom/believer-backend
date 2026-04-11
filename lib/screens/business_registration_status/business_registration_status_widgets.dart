import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

const Color businessRegistrationStatusBackground = Color(0xFFF2F4F2);

class BusinessRegistrationTopBar extends StatelessWidget {
  const BusinessRegistrationTopBar({
    super.key,
    required this.title,
    this.onBackTap,
  });

  final String title;
  final VoidCallback? onBackTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBackTap != null)
            Positioned(
              left: 0,
              child: IconButton(
                onPressed: onBackTap,
                splashRadius: 22,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 34,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.figtreeFamily,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum BusinessRegistrationStepState { current, complete, upcoming }

class BusinessRegistrationProgressHeader extends StatelessWidget {
  const BusinessRegistrationProgressHeader({
    super.key,
    required this.basicDetailsState,
    required this.contactLocationState,
  });

  final BusinessRegistrationStepState basicDetailsState;
  final BusinessRegistrationStepState contactLocationState;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF8D948F), width: 1.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 18, 32, 20),
        child: Column(
          children: [
            Row(
              children: [
                _ProgressNode(state: basicDetailsState),
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _lineColor,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                _ProgressNode(state: contactLocationState),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Basic Details',
                    style: TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Contact & Location',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: AppTypography.figtreeFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
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

  Color get _lineColor {
    if (basicDetailsState == BusinessRegistrationStepState.complete &&
        contactLocationState == BusinessRegistrationStepState.complete) {
      return const Color(0xFF2E3832);
    }
    return const Color(0xFF5A665E);
  }
}

class _ProgressNode extends StatelessWidget {
  const _ProgressNode({required this.state});

  final BusinessRegistrationStepState state;

  @override
  Widget build(BuildContext context) {
    final bool isComplete = state == BusinessRegistrationStepState.complete;
    final bool isCurrent = state == BusinessRegistrationStepState.current;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isComplete ? const Color(0xFF2E3832) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF55635C),
          width: isCurrent ? 1.7 : 1.5,
        ),
      ),
      child: Center(
        child: isComplete
            ? const Icon(Icons.check_rounded, size: 22, color: AppColors.white)
            : Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color:
                      isCurrent ? const Color(0xFF2E3832) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}

class BusinessRegistrationPrimaryButton extends StatelessWidget {
  const BusinessRegistrationPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 66,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.accentSoft,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class BusinessRegistrationOutlineButton extends StatelessWidget {
  const BusinessRegistrationOutlineButton({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 66,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.accentSoft, width: 2),
          foregroundColor: AppColors.accentSoft,
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.figtreeFamily,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class BusinessRegistrationTextAction extends StatelessWidget {
  const BusinessRegistrationTextAction({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accentSoft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTypography.figtreeFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationThickness: 1.5,
        ),
      ),
    );
  }
}

class BusinessRegistrationIntroIllustration extends StatelessWidget {
  const BusinessRegistrationIntroIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: Transform.rotate(
              angle: -0.09,
              child: const _ListingCard(
                width: 178,
                height: 132,
                avatarAlignment: Alignment.topRight,
                includeBadge: false,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            bottom: 0,
            child: _ListingCard(
              width: 236,
              height: 150,
              avatarAlignment: Alignment.centerLeft,
              includeBadge: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.width,
    required this.height,
    required this.avatarAlignment,
    required this.includeBadge,
  });

  final double width;
  final double height;
  final Alignment avatarAlignment;
  final bool includeBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFCDD2CF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF496756), width: 3),
      ),
      child: Stack(
        children: [
          Align(
            alignment: avatarAlignment,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Container(
                width: width * 0.32,
                height: width * 0.32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF4D5F56),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.account_circle_rounded,
                    size: width * 0.2,
                    color: const Color(0xFF4D5F56),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: width * 0.44,
            top: height * 0.45,
            right: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardLine(width: width * 0.23),
                const SizedBox(height: 12),
                _CardLine(width: width * 0.34),
              ],
            ),
          ),
          if (includeBadge)
            Positioned(
              right: 20,
              bottom: 16,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF3F6B52),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 24,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFF4D5F56),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}

class BusinessRegistrationSuccessGraphic extends StatelessWidget {
  const BusinessRegistrationSuccessGraphic({
    super.key,
    this.celebratory = false,
  });

  final bool celebratory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 208,
      height: 208,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: celebratory ? 34 : 42,
            right: celebratory ? 26 : 32,
            child: _ConfettiCluster(
              rotation: -0.3,
              colors: celebratory
                  ? const [
                      Color(0xFF0E6D58),
                      Color(0xFFCC7E69),
                      Color(0xFFAFC8BE),
                    ]
                  : const [
                      Color(0xFF0E6D58),
                      Color(0xFFCC7E69),
                      Color(0xFFAFC8BE),
                    ],
            ),
          ),
          Positioned(
            left: celebratory ? 20 : 28,
            bottom: celebratory ? 34 : 40,
            child: _ConfettiCluster(
              rotation: 0.65,
              colors: celebratory
                  ? const [
                      Color(0xFF0E6D58),
                      Color(0xFFAFC8BE),
                      Color(0xFFCC7E69),
                    ]
                  : const [
                      Color(0xFF0E6D58),
                      Color(0xFFAFC8BE),
                      Color(0xFFCC7E69),
                    ],
            ),
          ),
          Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              color: const Color(0xFFDCE2DF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA9C0B6), width: 1.8),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 72,
              color: Color(0xFF52615B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiCluster extends StatelessWidget {
  const _ConfettiCluster({
    required this.rotation,
    required this.colors,
  });

  final double rotation;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          children: [
            for (final (index, offset) in _offsets.indexed)
              Positioned(
                left: offset.dx,
                top: offset.dy,
                child: _ConfettiDot(
                  width: index.isEven ? 6 : 4,
                  height: index.isEven ? 4 : 6,
                  color: colors[index % colors.length],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const List<Offset> _offsets = [
    Offset(0, 8),
    Offset(8, 18),
    Offset(16, 2),
    Offset(19, 24),
    Offset(28, 10),
    Offset(34, 20),
  ];
}

class _ConfettiDot extends StatelessWidget {
  const _ConfettiDot({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 8,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
