class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? mosqueId;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.mosqueId,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      mosqueId: json['mosqueId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'mosqueId': mosqueId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    String? mosqueId,
    bool clearMosqueId = false,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      mosqueId: clearMosqueId ? null : mosqueId ?? this.mosqueId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
