import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'business_registration_status_widgets.dart';

class BusinessRegistrationRejectedScreen extends StatelessWidget {
  const BusinessRegistrationRejectedScreen({
    super.key,
    this.onBackTap,
    this.onPrimaryTap,
    this.rejectionReason,
  });

  final VoidCallback? onBackTap;
  final VoidCallback? onPrimaryTap;
  final String? rejectionReason;

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
                          const BusinessRegistrationSuccessGraphic(),
                          const SizedBox(height: 34),
                          const Text(
                            'Your business listing needs changes',
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
                            child: Text(
                              rejectionReason == null ||
                                      rejectionReason!.trim().isEmpty
                                  ? 'A super admin sent your listing back for updates. Review the details and resubmit when ready.'
                                  : rejectionReason!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
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
                            label: 'Update Listing',
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
