import 'api_client.dart';

class BookmarkService {
  String _tokenOrThrow(String? bearerToken) {
    if (bearerToken == null || bearerToken.isEmpty) {
      throw ApiException('You must be logged in to manage bookmarks.');
    }
    return bearerToken;
  }

  Future<void> addBookmark(
    String mosqueId, {
    String? bearerToken,
  }) async {
    await ApiClient.post(
      '/api/v1/bookmarks',
      body: {'mosqueId': mosqueId},
      bearerToken: _tokenOrThrow(bearerToken),
    );
  }

  Future<void> removeBookmark(
    String mosqueId, {
    String? bearerToken,
  }) async {
    await ApiClient.delete(
      '/api/v1/bookmarks/$mosqueId',
      bearerToken: _tokenOrThrow(bearerToken),
    );
  }
}
