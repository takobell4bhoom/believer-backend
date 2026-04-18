class SuperAdminCustomer {
  const SuperAdminCustomer({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  factory SuperAdminCustomer.fromJson(Map<String, dynamic> json) {
    return SuperAdminCustomer(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'community',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  SuperAdminCustomer copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    bool clearCreatedAt = false,
  }) {
    return SuperAdminCustomer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: clearCreatedAt ? null : createdAt ?? this.createdAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }
}

class SuperAdminCustomerPage {
  const SuperAdminCustomerPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<SuperAdminCustomer> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory SuperAdminCustomerPage.fromResponse(Map<String, dynamic> response) {
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final meta = (response['meta'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pagination = (meta['pagination'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final items = data['items'];

    return SuperAdminCustomerPage(
      items: items is List
          ? items
              .map(
                (item) => SuperAdminCustomer.fromJson(
                  (item as Map).cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
          : const <SuperAdminCustomer>[],
      page: pagination['page'] as int? ?? 1,
      limit: pagination['limit'] as int? ?? 20,
      total: pagination['total'] as int? ?? 0,
      totalPages: pagination['totalPages'] as int? ?? 0,
    );
  }
}
