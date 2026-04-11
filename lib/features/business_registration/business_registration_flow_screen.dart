import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_provider.dart';
import '../../navigation/app_routes.dart';
import '../../navigation/app_startup.dart';
import '../../screens/business_registration_basic/business_registration_basic_models.dart';
import '../../screens/business_registration_basic/business_registration_basic_screen.dart';
import '../../screens/business_registration_contact/business_registration_contact_model.dart';
import '../../screens/business_registration_contact/business_registration_contact_screen.dart';
import '../../screens/business_registration_status/business_registration_intro_screen.dart';
import '../../screens/business_registration_status/business_registration_live_screen.dart';
import '../../screens/business_registration_status/business_registration_rejected_screen.dart';
import '../../screens/business_registration_status/business_registration_status_widgets.dart';
import '../../screens/business_registration_status/business_registration_under_review_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'business_registration_flow_controller.dart';
import 'business_registration_error_mapper.dart';
import 'business_registration_models.dart';

class BusinessRegistrationFlowScreen extends ConsumerStatefulWidget {
  const BusinessRegistrationFlowScreen({
    super.key,
    required this.step,
    this.routeArgs = const BusinessRegistrationFlowRouteArgs(),
  });

  final BusinessRegistrationFlowStep step;
  final BusinessRegistrationFlowRouteArgs routeArgs;

  @override
  ConsumerState<BusinessRegistrationFlowScreen> createState() =>
      _BusinessRegistrationFlowScreenState();
}

class _BusinessRegistrationFlowScreenState
    extends ConsumerState<BusinessRegistrationFlowScreen> {
  bool _redirectingToLogin = false;
  bool _requestedInitialRefresh = false;

  void _redirectToLogin() {
    if (_redirectingToLogin || !mounted) {
      return;
    }
    _redirectingToLogin = true;
    scheduleUnauthenticatedRedirect(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _goToRoute(String routeName) async {
    await Navigator.of(context).pushNamed(
      routeName,
      arguments: widget.routeArgs,
    );
  }

  Future<void> _beginLiveListingUpdate() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.businessRegistrationBasicDetails,
      arguments: widget.routeArgs,
    );
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (_) => false,
    );
  }

  void _leaveFlow() {
    final navigator = Navigator.of(context);
    final exitRouteName = widget.routeArgs.exitRouteName;
    var poppedToExitRoute = false;

    navigator.popUntil((route) {
      final routeName = route.settings.name;
      final shouldStop = exitRouteName != null
          ? routeName == exitRouteName
          : !AppRoutes.isBusinessRegistrationRoute(routeName);
      if (shouldStop) {
        poppedToExitRoute = true;
      }
      return shouldStop;
    });

    if (!mounted || poppedToExitRoute) {
      return;
    }

    navigator.pushNamedAndRemoveUntil(
      exitRouteName ?? AppRoutes.home,
      (_) => false,
    );
  }

  Future<void> _handleBasicNext(
    BusinessRegistrationBasicDraft draft,
  ) async {
    try {
      await ref
          .read(businessRegistrationFlowControllerProvider.notifier)
          .saveBasicDraft(draft);
      if (!mounted) {
        return;
      }
      await _goToRoute(AppRoutes.businessRegistrationContactLocation);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final presentation = mapBusinessRegistrationActionError(error);
      _showMessage(presentation.message);
    }
  }

  Future<void> _handleBasicSaveAndClose(
    BusinessRegistrationBasicDraft draft,
  ) async {
    try {
      await ref
          .read(businessRegistrationFlowControllerProvider.notifier)
          .saveBasicDraft(draft);
      if (!mounted) {
        return;
      }
      _showMessage('Business registration draft saved.');
      _leaveFlow();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final presentation = mapBusinessRegistrationActionError(error);
      _showMessage(presentation.message);
    }
  }

  Future<void> _handleContactSaveAndClose(
    BusinessRegistrationContactDraft draft,
  ) async {
    try {
      await ref
          .read(businessRegistrationFlowControllerProvider.notifier)
          .saveContactDraft(draft);
      if (!mounted) {
        return;
      }
      _showMessage('Business registration draft saved.');
      _leaveFlow();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final presentation = mapBusinessRegistrationActionError(error);
      _showMessage(presentation.message);
    }
  }

  Future<void> _handleContactSubmit(
    BusinessRegistrationContactDraft draft,
  ) async {
    try {
      await ref
          .read(businessRegistrationFlowControllerProvider.notifier)
          .submitForReview(draft);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.businessRegistrationUnderReview,
        (route) => !AppRoutes.isBusinessRegistrationRoute(route.settings.name),
        arguments: widget.routeArgs,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final presentation = mapBusinessRegistrationActionError(error);
      _showMessage(presentation.message);
      if (presentation.suggestedStep ==
          BusinessRegistrationFlowStep.basicDetails) {
        await Navigator.of(context).pushReplacementNamed(
          AppRoutes.businessRegistrationBasicDetails,
          arguments: widget.routeArgs,
        );
      }
    }
  }

  String _resolveIntroPrimaryRoute(BusinessRegistrationDraft draft) {
    switch (draft.status) {
      case BusinessRegistrationSubmissionStatus.underReview:
        return AppRoutes.businessRegistrationUnderReview;
      case BusinessRegistrationSubmissionStatus.live:
        return AppRoutes.businessRegistrationLive;
      case BusinessRegistrationSubmissionStatus.rejected:
        if (draft.shouldResumeContactStep) {
          return AppRoutes.businessRegistrationContactLocation;
        }
        return AppRoutes.businessRegistrationBasicDetails;
      case BusinessRegistrationSubmissionStatus.draft:
        if (draft.shouldResumeContactStep) {
          return AppRoutes.businessRegistrationContactLocation;
        }
        if (draft.basicDetails.isComplete) {
          return AppRoutes.businessRegistrationContactLocation;
        }
        if (draft.basicDetails.isDirty) {
          return AppRoutes.businessRegistrationBasicDetails;
        }
        return AppRoutes.businessRegistrationBasicDetails;
    }
  }

  Widget _buildResolvedStatusScreen(BusinessRegistrationDraft draft) {
    switch (draft.status) {
      case BusinessRegistrationSubmissionStatus.underReview:
        return BusinessRegistrationUnderReviewScreen(
          onBackTap: _goHome,
          onPrimaryTap: _goHome,
        );
      case BusinessRegistrationSubmissionStatus.live:
        return BusinessRegistrationLiveScreen(
          onBackTap: _goHome,
          onPrimaryTap: _beginLiveListingUpdate,
          onSecondaryTap: _goHome,
        );
      case BusinessRegistrationSubmissionStatus.rejected:
        return BusinessRegistrationRejectedScreen(
          onBackTap: _goHome,
          onPrimaryTap: () => _goToRoute(_resolveIntroPrimaryRoute(draft)),
          rejectionReason: draft.rejectionReason,
        );
      case BusinessRegistrationSubmissionStatus.draft:
        return BusinessRegistrationIntroScreen(
          onBackTap: _leaveFlow,
          onPrimaryTap: () => _goToRoute(_resolveIntroPrimaryRoute(draft)),
        );
    }
  }

  Widget _buildStep(BusinessRegistrationFlowState flowState) {
    final draft = flowState.draft;
    final status = draft.status;
    final isEditingStep =
        widget.step == BusinessRegistrationFlowStep.basicDetails ||
            widget.step == BusinessRegistrationFlowStep.contactAndLocation;

    if (status == BusinessRegistrationSubmissionStatus.underReview) {
      return _buildResolvedStatusScreen(draft);
    }

    if (status == BusinessRegistrationSubmissionStatus.rejected &&
        !isEditingStep) {
      return _buildResolvedStatusScreen(draft);
    }

    if (status == BusinessRegistrationSubmissionStatus.live && !isEditingStep) {
      return _buildResolvedStatusScreen(draft);
    }

    switch (widget.step) {
      case BusinessRegistrationFlowStep.intro:
        return _buildResolvedStatusScreen(draft);
      case BusinessRegistrationFlowStep.basicDetails:
        return BusinessRegistrationBasicScreen(
          initialDraft: draft.basicDetails,
          showSaveDraftAction:
              status != BusinessRegistrationSubmissionStatus.live,
          onBack: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).maybePop();
              return;
            }
            _leaveFlow();
          },
          onNext: _handleBasicNext,
          onSaveDraftAndClose: _handleBasicSaveAndClose,
        );
      case BusinessRegistrationFlowStep.contactAndLocation:
        return BusinessRegistrationContactScreen(
          initialValue: draft.contactDetails,
          isSubmitting: flowState.isSubmitting,
          isSavingDraft: flowState.isSavingDraft,
          showSaveDraftAction:
              status != BusinessRegistrationSubmissionStatus.live,
          submitButtonLabel: status == BusinessRegistrationSubmissionStatus.live
              ? 'Resubmit Listing'
              : 'Submit Listing',
          onChanged: ref
              .read(businessRegistrationFlowControllerProvider.notifier)
              .stageContactDraft,
          onBackPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).maybePop();
              return;
            }
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.businessRegistrationBasicDetails,
              arguments: widget.routeArgs,
            );
          },
          onSaveDraft: _handleContactSaveAndClose,
          onSubmit: _handleContactSubmit,
        );
      case BusinessRegistrationFlowStep.underReview:
        return _buildResolvedStatusScreen(draft);
      case BusinessRegistrationFlowStep.live:
        return _buildResolvedStatusScreen(draft);
    }
  }

  Widget _buildAsyncShell({
    required Widget child,
  }) {
    return Scaffold(
      backgroundColor: businessRegistrationStatusBackground,
      body: SafeArea(
        bottom: false,
        child: child,
      ),
    );
  }

  Widget _buildLoadingShell() {
    return _buildAsyncShell(
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorShell(Object error) {
    return _buildAsyncShell(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'We couldn\'t load your listing',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.figtreeFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                mapBusinessRegistrationLoadError(error),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTypography.figtreeFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF707671),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              BusinessRegistrationPrimaryButton(
                label: 'Try Again',
                onTap: () {
                  ref
                      .read(businessRegistrationFlowControllerProvider.notifier)
                      .refreshListingStatus();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.hasValue && authState.valueOrNull == null) {
      _redirectToLogin();
      return _buildLoadingShell();
    }

    if (authState.isLoading) {
      return _buildLoadingShell();
    }

    if (!_requestedInitialRefresh && authState.valueOrNull != null) {
      _requestedInitialRefresh = true;
      Future<void>.microtask(() {
        ref
            .read(businessRegistrationFlowControllerProvider.notifier)
            .refreshListingStatus();
      });
    }

    final flowState = ref.watch(businessRegistrationFlowControllerProvider);
    return flowState.when(
      data: _buildStep,
      loading: _buildLoadingShell,
      error: (error, _) => _buildErrorShell(error),
    );
  }
}
