import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OnboardingScreen1 extends StatelessWidget {
  const OnboardingScreen1({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final imageWidth = width > 600 ? 640.0 : width - 24;

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            width: imageWidth,
            height: imageWidth * 0.56,
            child: const _IllustrationCard(),
          ),
          const SizedBox(height: 28),
          const Text(
            'Discover nearby mosques, check Iqamah\ntimings, explore events, and connect with\nthriving mosque communities',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 1.45,
              color: AppColors.primaryText,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard();

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surface, AppColors.lineStrong],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 38,
              top: 38,
              child: Container(
                width: 94,
                height: 94,
                decoration: const BoxDecoration(
                  color: AppColors.disabled,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const Positioned(
              right: 220,
              top: 44,
              child: Icon(Icons.star, color: AppColors.secondaryText, size: 54),
            ),
            Positioned(
              left: -40,
              right: -40,
              bottom: 108,
              child: Container(
                height: 118,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(180),
                ),
              ),
            ),
            Positioned(
              left: -20,
              right: -28,
              bottom: 62,
              child: Container(
                height: 106,
                decoration: BoxDecoration(
                  color: AppColors.disabled,
                  borderRadius: BorderRadius.circular(160),
                ),
              ),
            ),
            Positioned(
              left: -20,
              right: -20,
              bottom: -34,
              child: Container(
                height: 136,
                decoration: BoxDecoration(
                  color: AppColors.mutedText,
                  borderRadius: BorderRadius.circular(140),
                ),
              ),
            ),
            Positioned(
              right: 84,
              bottom: 80,
              child: Container(
                width: 22,
                height: 160,
                color: AppColors.primaryText,
              ),
            ),
            Positioned(
              right: 70,
              bottom: 230,
              child: CustomPaint(
                size: const Size(50, 88),
                painter: _TrianglePainter(),
              ),
            ),
            Positioned(
              left: 120,
              bottom: 0,
              child: SizedBox(
                width: 230,
                height: 220,
                child: CustomPaint(painter: _PersonPainter()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primaryText;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PersonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.secondaryText;

    final body = Path()
      ..moveTo(size.width * 0.24, size.height)
      ..lineTo(size.width * 0.14, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.26, size.height * 0.72,
          size.width * 0.34, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.44, size.height * 0.52,
          size.width * 0.46, size.height * 0.44)
      ..quadraticBezierTo(size.width * 0.58, size.height * 0.18,
          size.width * 0.8, size.height * 0.18)
      ..quadraticBezierTo(
          size.width * 0.95, size.height * 0.16, size.width, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.94, size.height * 0.56,
          size.width * 0.84, size.height * 0.64)
      ..lineTo(size.width * 0.9, size.height)
      ..close();

    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
