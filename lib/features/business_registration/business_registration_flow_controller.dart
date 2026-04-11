import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_provider.dart';
import '../../services/api_client.dart';
import '../../screens/business_registration_basic/business_registration_basic_models.dart';
import '../../screens/business_registration_contact/business_registration_contact_model.dart';
import 'business_registration_models.dart';
import 'business_registration_service.dart';

final businessRegistrationServiceProvider =
    Provider<BusinessRegistrationService>((ref) {
  return const BusinessRegistrationService();
});

final businessRegistrationFlowControllerProvider = AsyncNotifierProvider<
    BusinessRegistrationFlowController,
    BusinessRegistrationFlowState>(BusinessRegistrationFlowController.new);

class BusinessRegistrationFlowController
    extends AsyncNotifier<BusinessRegistrationFlowState> {
  String? get _userId => ref.read(authUserProvider)?.id;
  String? get _accessToken => ref.read(authAccessTokenProvider);

  BusinessRegistrationService get _service =>
      ref.read(businessRegistrationServiceProvider);

  @override
  Future<BusinessRegistrationFlowState> build() async {
    final user = ref.watch(authUserProvider);
    final accessToken = ref.watch(authAccessTokenProvider);
    if (user == null || accessToken == null || accessToken.isEmpty) {
      return const BusinessRegistrationFlowState();
    }

    final draft = await _service.fetchLatestListingStatus(
      bearerToken: accessToken,
    );
    return BusinessRegistrationFlowState(
      draft: draft ?? const BusinessRegistrationDraft(),
    );
  }

  BusinessRegistrationFlowState get _currentState =>
      state.valueOrNull ?? const BusinessRegistrationFlowState();

  void stageBasicDraft(BusinessRegistrationBasicDraft draft) {
    final current = _currentState;
    state = AsyncData(
      current.copyWith(
        draft: current.draft.copyWith(basicDetails: draft),
      ),
    );
  }

  void stageContactDraft(BusinessRegistrationContactDraft draft) {
    final current = _currentState;
    state = AsyncData(
      current.copyWith(
        draft: current.draft.copyWith(contactDetails: draft),
      ),
    );
  }

  Future<void> saveBasicDraft(BusinessRegistrationBasicDraft draft) async {
    await _saveDraftToBackend(
      _currentState.draft.copyWith(
        basicDetails: draft,
        lastUpdatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> saveContactDraft(BusinessRegistrationContactDraft draft) async {
    await _saveDraftToBackend(
      _currentState.draft.copyWith(
        contactDetails: draft,
        lastUpdatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> submitForReview(BusinessRegistrationContactDraft draft) async {
    final current = _currentState;
    final nextDraft = current.draft.copyWith(
      contactDetails: draft,
      status: BusinessRegistrationSubmissionStatus.underReview,
      submittedAt: DateTime.now(),
      clearPublishedAt: true,
      clearReviewedAt: true,
      clearRejectionReason: true,
      lastUpdatedAt: DateTime.now(),
    );

    state = AsyncData(
      current.copyWith(
        draft: nextDraft,
        isSubmitting: true,
      ),
    );

    try {
      final savedDraft = await _submitDraftToBackend(nextDraft);
      state = AsyncData(
        current.copyWith(
          draft: savedDraft,
          isSubmitting: false,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncData(
        current.copyWith(
          draft: nextDraft,
          isSubmitting: false,
        ),
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> resumeEditing() async {
    final current = _currentState;
    state = AsyncData(
      current.copyWith(
        draft: current.draft.copyWith(
          status: BusinessRegistrationSubmissionStatus.draft,
          clearSubmittedAt: true,
          clearPublishedAt: true,
          clearReviewedAt: true,
          clearRejectionReason: true,
          lastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> refreshListingStatus() async {
    final token = _accessToken;
    if (token == null || token.isEmpty || _userId == null) {
      state = const AsyncData(BusinessRegistrationFlowState());
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final draft = await _service.fetchLatestListingStatus(
        bearerToken: token,
      );
      return BusinessRegistrationFlowState(
        draft: draft ?? const BusinessRegistrationDraft(),
      );
    });
  }

  Future<void> _saveDraftToBackend(BusinessRegistrationDraft draft) async {
    final current = _currentState;

    state = AsyncData(
      current.copyWith(
        draft: draft,
        isSavingDraft: true,
      ),
    );

    try {
      final savedDraft = await _persistDraftToBackend(draft);
      state = AsyncData(
        current.copyWith(
          draft: savedDraft,
          isSavingDraft: false,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncData(
        current.copyWith(
          draft: draft,
          isSavingDraft: false,
        ),
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<BusinessRegistrationDraft> _persistDraftToBackend(
    BusinessRegistrationDraft draft,
  ) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in first.', statusCode: 401);
    }

    return _service.saveDraft(
      draft: draft,
      bearerToken: token,
    );
  }

  Future<BusinessRegistrationDraft> _submitDraftToBackend(
    BusinessRegistrationDraft draft,
  ) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in first.', statusCode: 401);
    }

    return _service.submitForReview(
      draft: draft,
      bearerToken: token,
    );
  }
}
