class MosqueEvent {
  final String id;
  final String mosqueId;
  final String title;
  final String description;
  final DateTime date;
  final String type;
  final String imageUrl;
  final bool isActive;

  const MosqueEvent({
    required this.id,
    required this.mosqueId,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    required this.imageUrl,
    required this.isActive,
  });

  factory MosqueEvent.fromJson(Map<String, dynamic> json) {
    return MosqueEvent(
      id: json['id'] as String? ?? '',
      mosqueId: json['mosqueId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      date: DateTime.parse(json['date'] as String? ?? ''),
      type: json['type'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'mosqueId': mosqueId,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'type': type,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }

  MosqueEvent copyWith({
    String? id,
    String? mosqueId,
    String? title,
    String? description,
    DateTime? date,
    String? type,
    String? imageUrl,
    bool? isActive,
  }) {
    return MosqueEvent(
      id: id ?? this.id,
      mosqueId: mosqueId ?? this.mosqueId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }
}
