import '../models/review.dart';
import 'api_client.dart';

class BusinessReviewService {
  Future<void> submitReview({
    required String businessListingId,
    required int rating,
    required String comments,
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in to submit a review.', statusCode: 401);
    }

    final response = await ApiClient.post(
      '/api/v1/business-listings/$businessListingId/reviews',
      bearerToken: token,
      body: {
        'rating': rating,
        'comments': comments,
      },
    );

    final data = response['data'];
    if (data is Map<String, dynamic> &&
        data['id'] is String &&
        data['businessListingId'] == businessListingId) {
      return;
    }

    throw ApiException('Review submission failed.');
  }

  Future<ReviewFeed> getBusinessReviews(
    String businessListingId, {
    String? bearerToken,
  }) async {
    final response = await ApiClient.get(
      '/api/v1/business-listings/$businessListingId/reviews',
      bearerToken: bearerToken,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return ReviewFeed.fromJson(data);
  }
}
