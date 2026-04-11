class NotificationSetting {
  final String title;
  final String description;
  final bool isEnabled;

  const NotificationSetting({
    required this.title,
    required this.description,
    required this.isEnabled,
  });

  factory NotificationSetting.fromJson(Map<String, dynamic> json) {
    return NotificationSetting(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isEnabled: json['isEnabled'] as bool? ?? false,
    );
  }

  NotificationSetting copyWith({
    String? title,
    String? description,
    bool? isEnabled,
  }) {
    return NotificationSetting(
      title: title ?? this.title,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'isEnabled': isEnabled,
    };
  }
}
