import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'line_text_divider.dart';
import 'social_auth_button.dart';

class AuthFooter extends StatelessWidget {
  const AuthFooter({
    super.key,
    required this.dividerText,
    required this.promptText,
    required this.actionText,
    required this.onActionTap,
    this.showSocialAuthButtons = true,
    this.availabilityNote,
  });

  final String dividerText;
  final String promptText;
  final String actionText;
  final VoidCallback onActionTap;
  final bool showSocialAuthButtons;
  final String? availabilityNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LineTextDivider(text: dividerText),
        const SizedBox(height: 22),
        if (showSocialAuthButtons) ...[
          const SocialAuthButton.google(),
          const SizedBox(height: 12),
          const SocialAuthButton.apple(),
          const SizedBox(height: 18),
        ] else if (availabilityNote != null) ...[
          Text(
            availabilityNote!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w400,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 18),
        ],
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              Text(
                promptText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: AppColors.primaryText,
                ),
              ),
              TextButton(
                onPressed: onActionTap,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionText,
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.accentSoft,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
