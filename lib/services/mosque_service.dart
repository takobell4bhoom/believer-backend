import 'dart:typed_data';

import '../models/broadcast_message.dart';
import '../models/mosque_content.dart';
import '../models/mosque_model.dart';
import '../models/notification_enabled_mosque.dart';
import '../models/notification_setting.dart';
import '../models/prayer_timings.dart';
import '../models/review.dart';
import 'api_client.dart';

class MosqueApiGateway {
  const MosqueApiGateway();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    String? bearerToken,
  }) {
    return ApiClient.get(path, query: query, bearerToken: bearerToken);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) {
    return ApiClient.post(path, body: body, bearerToken: bearerToken);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) {
    return ApiClient.put(path, body: body, bearerToken: bearerToken);
  }

  Future<void> delete(
    String path, {
    String? bearerToken,
  }) {
    return ApiClient.delete(path, bearerToken: bearerToken);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fileField,
    required List<int> fileBytes,
    required String fileName,
    Map<String, String>? fields,
    String? bearerToken,
  }) {
    return ApiClient.postMultipart(
      path,
      fileField: fileField,
      fileBytes: fileBytes,
      fileName: fileName,
      fields: fields,
      bearerToken: bearerToken,
    );
  }
}

class MosqueImageUploadFile {
  const MosqueImageUploadFile({
    required this.fileName,
    required this.bytes,
    this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final String? contentType;
}

class MosqueUploadedImage {
  const MosqueUploadedImage({
    required this.imageUrl,
    required this.imagePath,
    required this.fileName,
  });

  final String imageUrl;
  final String imagePath;
  final String fileName;
}

class MosqueAdminUpdateResult {
  const MosqueAdminUpdateResult({
    required this.mosque,
    required this.content,
  });

  final MosqueModel mosque;
  final MosqueContent content;
}

class MosqueService {
  MosqueService({
    MosqueApiGateway? apiGateway,
  }) : _apiGateway = apiGateway ?? const MosqueApiGateway();

  final MosqueApiGateway _apiGateway;

  static const maxMosqueImages = 10;

  Future<MosqueModel> createMosque({
    required Map<String, dynamic> payload,
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in with an admin account.',
          statusCode: 401);
    }

    final response = await _apiGateway.post(
      '/api/v1/mosques',
      bearerToken: token,
      body: payload,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return fromApi(data);
  }

  Future<MosqueAdminUpdateResult> updateMosque({
    required String mosqueId,
    required Map<String, dynamic> payload,
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in with an admin account.',
          statusCode: 401);
    }

    final response = await _apiGateway.put(
      '/api/v1/mosques/$mosqueId',
      bearerToken: token,
      body: payload,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final mosque = fromApi(
        data['mosque'] as Map<String, dynamic>? ?? const <String, dynamic>{});
    final content = MosqueContent.fromJson(
      data['content'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

    return MosqueAdminUpdateResult(
      mosque: mosque,
      content: content,
    );
  }

  Future<MosqueUploadedImage> uploadMosqueImage({
    required MosqueImageUploadFile file,
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in with an admin account.',
          statusCode: 401);
    }

    if (!_isSupportedMosqueUpload(file)) {
      throw ApiException('Upload a JPG, PNG, or WebP image.');
    }

    final response = await _apiGateway.postMultipart(
      '/api/v1/mosques/upload-image',
      bearerToken: token,
      fileField: 'file',
      fileBytes: file.bytes,
      fileName: file.fileName,
      fields: {
        if (file.contentType != null && file.contentType!.trim().isNotEmpty)
          'contentType': file.contentType!.trim(),
      },
    );

    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final imageUrl = data['imageUrl'] as String? ?? '';
    final imagePath = data['imagePath'] as String? ?? '';
    final fileName = data['fileName'] as String? ?? file.fileName;

    if (imageUrl.isEmpty || imagePath.isEmpty) {
      throw ApiException('Image upload failed.');
    }

    return MosqueUploadedImage(
      imageUrl: imageUrl,
      imagePath: imagePath,
      fileName: fileName,
    );
  }

  Future<MosqueModel> getMosqueDetail(
    String mosqueId, {
    String? bearerToken,
  }) async {
    final response = await _apiGateway.get(
      '/api/v1/mosques/$mosqueId',
      bearerToken: bearerToken,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return fromApi(data);
  }

  Future<List<MosqueModel>> getOwnedMosques({
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException(
        'Please log in with an admin account.',
        statusCode: 401,
      );
    }

    final response = await _apiGateway.get(
      '/api/v1/mosques/mine',
      bearerToken: token,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawItems = data['items'] as List<dynamic>? ?? const <dynamic>[];

    return rawItems
        .whereType<Map>()
        .map(
          (item) => fromApi(
            Map<String, dynamic>.from(item.cast<Object?, Object?>()),
          ),
        )
        .toList(growable: false);
  }

  Future<void> submitReview({
    required String mosqueId,
    required int rating,
    required String comments,
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in to submit a review.', statusCode: 401);
    }

    final response = await _apiGateway.post(
      '/api/v1/mosques/review',
      bearerToken: token,
      body: {
        'mosqueId': mosqueId,
        'rating': rating,
        'comments': comments,
      },
    );

    final data = response['data'];
    if (data is Map<String, dynamic> &&
        data['id'] is String &&
        data['mosqueId'] == mosqueId) {
      return;
    }

    throw ApiException('Review submission failed.');
  }

  Future<ReviewFeed> getMosqueReviews(
    String mosqueId, {
    String? bearerToken,
  }) async {
    final response = await _apiGateway.get(
      '/api/v1/mosques/$mosqueId/reviews',
      bearerToken: bearerToken,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return ReviewFeed.fromJson(data);
  }

  Future<List<BroadcastMessage>> getMosqueBroadcastMessages(
    String mosqueId, {
    String? bearerToken,
  }) async {
    final response = await _apiGateway.get(
      '/api/v1/mosques/$mosqueId/broadcasts',
      bearerToken: bearerToken,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawItems = data['items'] as List<dynamic>? ?? const <dynamic>[];

    return rawItems
        .whereType<Map>()
        .map(
          (item) => BroadcastMessage.fromJson(
            Map<String, dynamic>.from(item.cast<Object?, Object?>()),
          ),
        )
        .toList(growable: false);
  }

  Future<BroadcastMessage> publishMosqueBroadcast({
    required String mosqueId,
    required String title,
    required String description,
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in with an admin account.',
          statusCode: 401);
    }

    final response = await _apiGateway.post(
      '/api/v1/mosques/$mosqueId/broadcasts',
      bearerToken: token,
      body: {
        'title': title.trim(),
        'message': description.trim(),
      },
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return BroadcastMessage.fromJson(data);
  }

  Future<void> deleteMosqueBroadcast({
    required String mosqueId,
    required String broadcastId,
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in with an admin account.',
          statusCode: 401);
    }

    await _apiGateway.delete(
      '/api/v1/mosques/$mosqueId/broadcasts/$broadcastId',
      bearerToken: token,
    );
  }

  Future<MosqueContent> getMosqueContent(
    String mosqueId, {
    String? bearerToken,
  }) async {
    final response = await _apiGateway.get(
      '/api/v1/mosques/$mosqueId/content',
      bearerToken: bearerToken,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return MosqueContent.fromJson(data);
  }

  Future<PrayerTimings> getPrayerTimings({
    required String mosqueId,
    required String date,
    String? bearerToken,
  }) async {
    final response = await _apiGateway.get(
      '/api/v1/mosques/$mosqueId/prayer-times',
      query: {
        'date': date,
      },
      bearerToken: bearerToken,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return PrayerTimings.fromJson(data);
  }

  Future<List<NotificationSetting>> getNotificationSettings({
    required String mosqueId,
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException(
        'Please log in to view notification settings.',
        statusCode: 401,
      );
    }

    final response = await _apiGateway.get(
      '/api/v1/notifications/settings',
      query: {'mosqueId': mosqueId},
      bearerToken: token,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawSettings = data['settings'] as List<dynamic>? ?? const <dynamic>[];

    return rawSettings
        .whereType<Map>()
        .map(
          (item) => NotificationSetting.fromJson(
            Map<String, dynamic>.from(item.cast<Object?, Object?>()),
          ),
        )
        .toList(growable: false);
  }

  Future<List<NotificationEnabledMosque>> getNotificationEnabledMosques({
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException(
        'Please log in to view your notification-enabled mosques.',
        statusCode: 401,
      );
    }

    final response = await _apiGateway.get(
      '/api/v1/notifications/mosques',
      bearerToken: token,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawItems = data['items'] as List<dynamic>? ?? const <dynamic>[];

    return rawItems
        .whereType<Map>()
        .map(
          (item) => NotificationEnabledMosque.fromJson(
            Map<String, dynamic>.from(item.cast<Object?, Object?>()),
          ),
        )
        .toList(growable: false);
  }

  Future<void> updateNotificationSettings({
    required String mosqueId,
    required List<NotificationSetting> settings,
    String? bearerToken,
  }) async {
    final token = bearerToken;
    if (token == null || token.isEmpty) {
      throw ApiException(
        'Please log in to update notification settings.',
        statusCode: 401,
      );
    }

    final response = await _apiGateway.put(
      '/api/v1/notifications/settings',
      bearerToken: token,
      body: {
        'mosqueId': mosqueId,
        'settings': settings.map((setting) => setting.toJson()).toList(),
      },
    );

    final data = response['data'];
    if (data is Map<String, dynamic> && data['success'] == true) {
      return;
    }

    throw ApiException('Notification settings update failed.');
  }
}

bool _isSupportedMosqueUpload(MosqueImageUploadFile file) {
  final contentType = file.contentType?.trim().toLowerCase() ?? '';
  if (contentType == 'image/jpeg' ||
      contentType == 'image/jpg' ||
      contentType == 'image/png' ||
      contentType == 'image/webp') {
    return true;
  }

  final fileName = file.fileName.trim().toLowerCase();
  return fileName.endsWith('.jpg') ||
      fileName.endsWith('.jpeg') ||
      fileName.endsWith('.png') ||
      fileName.endsWith('.webp');
}
