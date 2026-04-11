import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'business_registration_status_widgets.dart';

class BusinessRegistrationUnderReviewScreen extends StatelessWidget {
  const BusinessRegistrationUnderReviewScreen({
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
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: BusinessRegistrationTopBar(
                    title: 'Register Your Business',
                    onBackTap: onBackTap,
                  ),
                ),
                const BusinessRegistrationProgressHeader(
                  basicDetailsState: BusinessRegistrationStepState.complete,
                  contactLocationState: BusinessRegistrationStepState.complete,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 36, 18, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 152,
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.12),
                          const BusinessRegistrationSuccessGraphic(),
                          const SizedBox(height: 42),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: const Text(
                              'Your business listing is under review. Check back here for the latest status.',
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
                          const SizedBox(height: 34),
                          BusinessRegistrationOutlineButton(
                            label: 'Go to Home Page',
                            onTap: onPrimaryTap,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
