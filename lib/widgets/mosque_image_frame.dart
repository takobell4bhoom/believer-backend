import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MosqueImageFrame extends StatelessWidget {
  const MosqueImageFrame({
    super.key,
    required this.child,
    this.aspectRatio = 16 / 9,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.backgroundColor = AppColors.lineStrong,
  });

  final Widget child;
  final double? aspectRatio;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    Widget current = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox.expand(child: child),
      ),
    );

    if (aspectRatio != null) {
      current = AspectRatio(
        aspectRatio: aspectRatio!,
        child: current,
      );
    }

    if (width != null || height != null) {
      current = SizedBox(
        width: width,
        height: height,
        child: current,
      );
    }

    return current;
  }
}

class MosqueImagePlaceholder extends StatelessWidget {
  const MosqueImagePlaceholder({
    super.key,
    this.message,
    this.iconSize = 32,
  });

  final String? message;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8EB0CB), Color(0xFFDAC6A3)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mosque_outlined,
                size: iconSize,
                color: AppColors.white,
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
