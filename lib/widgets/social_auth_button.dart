import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton.google({
    super.key,
    this.onPressed,
  }) : isApple = false;

  const SocialAuthButton.apple({
    super.key,
    this.onPressed,
  }) : isApple = true;

  final bool isApple;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isApple ? AppColors.black : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isApple
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 3,
                    offset: Offset(0, 0),
                  ),
                  BoxShadow(
                    color: Color(0x2B000000),
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isApple)
                  const Icon(Icons.apple, size: 24, color: AppColors.white)
                else
                  const _GoogleGlyph(),
                const SizedBox(width: 12),
                Text(
                  isApple ? 'Continue with Apple' : 'Continue with Google',
                  style: TextStyle(
                    color: isApple ? AppColors.white : AppColors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
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

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
