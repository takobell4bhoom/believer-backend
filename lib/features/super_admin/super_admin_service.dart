import '../../services/api_client.dart';
import '../business_moderation/business_moderation_service.dart';
import '../mosque_moderation/mosque_moderation_service.dart';
import 'super_admin_models.dart';

class SuperAdminService {
  const SuperAdminService({
    this.mosqueModerationService = const MosqueModerationService(),
    this.businessModerationService = const BusinessModerationService(),
  });

  final MosqueModerationService mosqueModerationService;
  final BusinessModerationService businessModerationService;

  Future<List<MosqueModerationItem>> fetchPendingMosques({
    required String bearerToken,
  }) {
    return mosqueModerationService.fetchPendingMosques(
      bearerToken: bearerToken,
    );
  }

  Future<MosqueModerationItem> approveMosque({
    required String mosqueId,
    required String bearerToken,
  }) {
    return mosqueModerationService.approveMosque(
      mosqueId: mosqueId,
      bearerToken: bearerToken,
    );
  }

  Future<MosqueModerationItem> rejectMosque({
    required String mosqueId,
    required String rejectionReason,
    required String bearerToken,
  }) {
    return mosqueModerationService.rejectMosque(
      mosqueId: mosqueId,
      rejectionReason: rejectionReason,
      bearerToken: bearerToken,
    );
  }

  Future<List<BusinessModerationListing>> fetchPendingBusinesses({
    required String bearerToken,
  }) {
    return businessModerationService.fetchPendingListings(
      bearerToken: bearerToken,
    );
  }

  Future<BusinessModerationListing> approveBusiness({
    required String listingId,
    required String bearerToken,
  }) {
    return businessModerationService.approveListing(
      listingId: listingId,
      bearerToken: bearerToken,
    );
  }

  Future<BusinessModerationListing> rejectBusiness({
    required String listingId,
    required String rejectionReason,
    required String bearerToken,
  }) {
    return businessModerationService.rejectListing(
      listingId: listingId,
      rejectionReason: rejectionReason,
      bearerToken: bearerToken,
    );
  }

  Future<SuperAdminCustomerPage> fetchCustomers({
    required String bearerToken,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final response = await ApiClient.get(
      '/api/v1/admin/users',
      bearerToken: bearerToken,
      query: query,
    );

    return SuperAdminCustomerPage.fromResponse(response);
  }

  Future<SuperAdminCustomer> deactivateUser({
    required String userId,
    required String bearerToken,
  }) async {
    final response = await ApiClient.post(
      '/api/v1/admin/users/$userId/deactivate',
      bearerToken: bearerToken,
    );
    return _parseUser(response);
  }

  Future<SuperAdminCustomer> reactivateUser({
    required String userId,
    required String bearerToken,
  }) async {
    final response = await ApiClient.post(
      '/api/v1/admin/users/$userId/reactivate',
      bearerToken: bearerToken,
    );
    return _parseUser(response);
  }

  Future<void> triggerPasswordReset({
    required String userId,
    required String bearerToken,
  }) async {
    await ApiClient.post(
      '/api/v1/admin/users/$userId/password-reset',
      bearerToken: bearerToken,
    );
  }

  SuperAdminCustomer _parseUser(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid admin user response.');
    }

    final user = data['user'];
    if (user is! Map) {
      throw ApiException('Invalid admin user response.');
    }

    return SuperAdminCustomer.fromJson(
      user.cast<String, dynamic>(),
    );
  }
}
