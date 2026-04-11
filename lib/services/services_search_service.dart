import '../models/service.dart';
import 'api_client.dart';

class ServicesSearchService {
  Future<List<Service>> fetchServices({
    required String category,
    required List<String> filters,
    String sort = 'new',
  }) async {
    final response = await ApiClient.get(
      '/api/v1/services',
      query: {
        'category': category,
        if (filters.isNotEmpty) 'filters': filters.join(','),
        'sort': sort,
      },
    );

    final data =
        response['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final items = data['services'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .whereType<Map<String, dynamic>>()
        .map(Service.fromApi)
        .toList(growable: false);
  }
}
