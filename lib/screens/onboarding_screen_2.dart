import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OnboardingScreen2 extends StatelessWidget {
  const OnboardingScreen2({super.key});

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
            'Follow your favourite mosques\nand stay updated with their latest\nannouncements',
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
            Positioned.fill(
                child: CustomPaint(painter: _AnnouncementScenePainter())),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = AppColors.primaryText;
    final medium = Paint()..color = AppColors.disabled;
    final light = Paint()..color = AppColors.lineStrong;

    final mosque = Path()
      ..moveTo(size.width * 0.28, size.height * 0.95)
      ..lineTo(size.width * 0.28, size.height * 0.43)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.22,
          size.width * 0.5, size.height * 0.14)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.22,
          size.width * 0.72, size.height * 0.43)
      ..lineTo(size.width * 0.72, size.height * 0.95)
      ..close();
    canvas.drawPath(mosque, medium);

    final moon = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(size.width * 0.52, size.height * 0.33),
          radius: size.width * 0.055));
    canvas.drawPath(moon, dark);
    final cutMoon = Paint()..color = AppColors.disabled;
    canvas.drawCircle(Offset(size.width * 0.545, size.height * 0.312),
        size.width * 0.05, cutMoon);

    canvas.drawCircle(Offset(size.width * 0.38, size.height * 0.36),
        size.width * 0.011, dark);
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.36),
        size.width * 0.011, dark);

    final leftBody = RRect.fromLTRBR(
      size.width * 0.3,
      size.height * 0.49,
      size.width * 0.45,
      size.height * 0.98,
      const Radius.circular(70),
    );
    canvas.drawRRect(leftBody, dark);
    canvas.drawCircle(Offset(size.width * 0.375, size.height * 0.58),
        size.width * 0.052, dark);

    final rightBody = RRect.fromLTRBR(
      size.width * 0.52,
      size.height * 0.52,
      size.width * 0.66,
      size.height * 0.98,
      const Radius.circular(70),
    );
    canvas.drawRRect(rightBody, dark);
    canvas.drawCircle(
        Offset(size.width * 0.59, size.height * 0.6), size.width * 0.052, dark);

    final arm = RRect.fromLTRBR(
      size.width * 0.64,
      size.height * 0.67,
      size.width * 0.75,
      size.height * 0.76,
      const Radius.circular(16),
    );
    canvas.drawRRect(arm, dark);

    final phone = RRect.fromLTRBR(
      size.width * 0.76,
      size.height * 0.61,
      size.width * 0.82,
      size.height * 0.78,
      const Radius.circular(8),
    );
    canvas.drawRRect(phone, dark);
    final screenCut = Paint()..color = AppColors.lineStrong;
    canvas.drawRRect(
      RRect.fromLTRBR(
        size.width * 0.775,
        size.height * 0.645,
        size.width * 0.806,
        size.height * 0.74,
        const Radius.circular(4),
      ),
      screenCut,
    );

    final megaphoneHorn = Path()
      ..moveTo(size.width * 0.14, size.height * 0.58)
      ..lineTo(size.width * 0.24, size.height * 0.51)
      ..lineTo(size.width * 0.24, size.height * 0.68)
      ..lineTo(size.width * 0.14, size.height * 0.62)
      ..close();
    canvas.drawPath(megaphoneHorn, dark);
    canvas.drawCircle(
        Offset(size.width * 0.12, size.height * 0.6), size.width * 0.05, dark);
    canvas.drawRRect(
      RRect.fromLTRBR(
        size.width * 0.23,
        size.height * 0.64,
        size.width * 0.29,
        size.height * 0.69,
        const Radius.circular(10),
      ),
      dark,
    );

    final frontShape = Path()
      ..moveTo(size.width * 0.12, size.height * 0.93)
      ..quadraticBezierTo(size.width * 0.38, size.height * 0.84,
          size.width * 0.5, size.height * 0.9)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.95,
          size.width * 0.9, size.height * 0.9)
      ..lineTo(size.width * 0.9, size.height)
      ..lineTo(size.width * 0.12, size.height)
      ..close();
    canvas.drawPath(frontShape, light);

    final sideLeaves = Path()
      ..moveTo(size.width * 0.11, size.height * 0.95)
      ..quadraticBezierTo(size.width * 0.07, size.height * 0.83,
          size.width * 0.14, size.height * 0.86)
      ..close();
    canvas.drawPath(sideLeaves, dark);
    final sideLeavesR = Path()
      ..moveTo(size.width * 0.79, size.height * 0.95)
      ..quadraticBezierTo(size.width * 0.86, size.height * 0.8,
          size.width * 0.82, size.height * 0.91)
      ..close();
    canvas.drawPath(sideLeavesR, dark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
