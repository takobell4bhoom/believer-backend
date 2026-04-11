class NotificationEnabledMosque {
  const NotificationEnabledMosque({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory NotificationEnabledMosque.fromJson(Map<String, dynamic> json) {
    return NotificationEnabledMosque(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Mosque',
    );
  }
}
