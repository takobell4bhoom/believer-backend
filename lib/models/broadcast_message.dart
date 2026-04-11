class BroadcastMessage {
  final String? id;
  final String title;
  final String? date;
  final String description;
  final DateTime? publishedAt;

  const BroadcastMessage({
    this.id,
    required this.title,
    this.date,
    required this.description,
    this.publishedAt,
  });

  factory BroadcastMessage.fromJson(Map<String, dynamic> json) {
    final rawPublishedAt = json['publishedAt'] ?? json['published_at'];
    final publishedAt =
        rawPublishedAt is String && rawPublishedAt.trim().isNotEmpty
            ? DateTime.tryParse(rawPublishedAt)?.toLocal()
            : null;

    return BroadcastMessage(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      date: json['date'] as String?,
      description: json['description'] as String? ?? '',
      publishedAt: publishedAt,
    );
  }

  String get displayDate {
    final explicit = date?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final timestamp = publishedAt;
    if (timestamp == null) {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inDays == 0) {
      return 'Today';
    }
    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    const monthLabels = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = monthLabels[timestamp.month - 1];
    if (timestamp.year == now.year) {
      return '$month ${timestamp.day}';
    }
    return '$month ${timestamp.day}, ${timestamp.year}';
  }
}
