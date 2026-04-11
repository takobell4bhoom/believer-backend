import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'business_registration_status_widgets.dart';

class BusinessRegistrationIntroScreen extends StatelessWidget {
  const BusinessRegistrationIntroScreen({
    super.key,
    this.onBackTap,
    this.onPrimaryTap,
  });

  final VoidCallback? onBackTap;
  final VoidCallback? onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: businessRegistrationStatusBackground,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                  child: Column(
                    children: [
                      BusinessRegistrationTopBar(
                        title: 'Register Your Business',
                        onBackTap: onBackTap,
                      ),
                      SizedBox(height: constraints.maxHeight * 0.18),
                      const BusinessRegistrationIntroIllustration(),
                      const SizedBox(height: 48),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: const Text(
                          'Let others find and support your business by listing it on our platform. It’s quick, easy, and free',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTypography.figtreeFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: AppColors.primaryText,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 38),
                      SizedBox(height: constraints.maxHeight * 0.12),
                      BusinessRegistrationPrimaryButton(
                        label: 'Get Started',
                        onTap: onPrimaryTap,
                      ),
                    ],
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
