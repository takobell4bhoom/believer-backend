import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'business_registration_status_widgets.dart';

class BusinessRegistrationLiveScreen extends StatelessWidget {
  const BusinessRegistrationLiveScreen({
    super.key,
    this.onBackTap,
    this.onPrimaryTap,
    this.onSecondaryTap,
    this.primaryLabel = 'Update Listing',
    this.secondaryLabel = 'Go to Home Page',
  });

  final VoidCallback? onBackTap;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;
  final String primaryLabel;
  final String secondaryLabel;

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
                    padding: const EdgeInsets.fromLTRB(18, 32, 18, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 152,
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.1),
                          const BusinessRegistrationSuccessGraphic(
                            celebratory: true,
                          ),
                          const SizedBox(height: 34),
                          const Text(
                            'Your business listing is live',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTypography.figtreeFamily,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: const Text(
                              'Customers can now discover your listing on BelieversLens. If you need to change published details, update the listing and resubmit it for moderation.',
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
                          BusinessRegistrationPrimaryButton(
                            label: primaryLabel,
                            onTap: onPrimaryTap,
                          ),
                          if (onSecondaryTap != null) ...[
                            const SizedBox(height: 14),
                            BusinessRegistrationTextAction(
                              label: secondaryLabel,
                              onTap: onSecondaryTap,
                            ),
                          ],
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
