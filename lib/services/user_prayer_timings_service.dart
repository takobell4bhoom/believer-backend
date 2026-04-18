import '../models/prayer_timings.dart';
import 'api_client.dart';

class UserPrayerTimingsApiGateway {
  const UserPrayerTimingsApiGateway();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) {
    return ApiClient.get(path, query: query);
  }
}

class UserPrayerTimingsService {
  UserPrayerTimingsService({
    UserPrayerTimingsApiGateway? apiGateway,
  }) : _apiGateway = apiGateway ?? const UserPrayerTimingsApiGateway();

  final UserPrayerTimingsApiGateway _apiGateway;

  Future<PrayerTimings> getDailyTimings({
    required String date,
    required double latitude,
    required double longitude,
    required String school,
    int? calculationMethodId,
  }) async {
    final query = <String, String>{
      'date': date,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'school': school,
    };
    if (calculationMethodId != null) {
      query['method'] = calculationMethodId.toString();
    }

    final response = await _apiGateway.get(
      '/api/v1/prayer-times/daily',
      query: query,
    );
    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return PrayerTimings.fromJson(data);
  }
}
