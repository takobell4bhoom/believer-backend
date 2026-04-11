class MosqueContent {
  const MosqueContent({
    required this.events,
    required this.classes,
    required this.connect,
    this.about,
  });

  final List<MosqueProgramItem> events;
  final List<MosqueProgramItem> classes;
  final List<MosqueConnectLink> connect;
  final MosqueAboutContent? about;

  factory MosqueContent.fromJson(Map<String, dynamic> json) {
    return MosqueContent(
      events: _readProgramItems(json['events']),
      classes: _readProgramItems(json['classes']),
      connect: _readConnectLinks(json['connect']),
      about: _readAbout(json['about']),
    );
  }

  bool get hasEvents => events.isNotEmpty;
  bool get hasClasses => classes.isNotEmpty;
  bool get hasConnect => connect.isNotEmpty;
  bool get hasAbout =>
      about != null &&
      (about!.title.trim().isNotEmpty || about!.body.trim().isNotEmpty);
}

class MosqueAboutContent {
  const MosqueAboutContent({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  factory MosqueAboutContent.fromJson(Map<String, dynamic> json) {
    return MosqueAboutContent(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
    };
  }
}

class MosqueProgramItem {
  const MosqueProgramItem({
    required this.id,
    required this.title,
    required this.schedule,
    required this.posterLabel,
    this.location = '',
    this.description = '',
  });

  final String id;
  final String title;
  final String schedule;
  final String posterLabel;
  final String location;
  final String description;

  factory MosqueProgramItem.fromJson(Map<String, dynamic> json) {
    return MosqueProgramItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      schedule: json['schedule'] as String? ?? '',
      posterLabel: json['posterLabel'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'schedule': schedule,
      'posterLabel': posterLabel,
      'location': location,
      'description': description,
    };
  }
}

class MosqueConnectLink {
  const MosqueConnectLink({
    required this.id,
    required this.type,
    required this.label,
    required this.value,
  });

  final String id;
  final String type;
  final String label;
  final String value;

  factory MosqueConnectLink.fromJson(Map<String, dynamic> json) {
    return MosqueConnectLink(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'other',
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }
}

List<MosqueProgramItem> _readProgramItems(dynamic value) {
  final rawItems = value as List<dynamic>? ?? const <dynamic>[];

  return rawItems
      .whereType<Map>()
      .map(
        (item) => MosqueProgramItem.fromJson(
          Map<String, dynamic>.from(item.cast<Object?, Object?>()),
        ),
      )
      .where((item) => item.title.trim().isNotEmpty)
      .toList(growable: false);
}

List<MosqueConnectLink> _readConnectLinks(dynamic value) {
  final rawItems = value as List<dynamic>? ?? const <dynamic>[];

  return rawItems
      .whereType<Map>()
      .map(
        (item) => MosqueConnectLink.fromJson(
          Map<String, dynamic>.from(item.cast<Object?, Object?>()),
        ),
      )
      .where(
        (item) => item.label.trim().isNotEmpty && item.value.trim().isNotEmpty,
      )
      .toList(growable: false);
}

MosqueAboutContent? _readAbout(dynamic value) {
  if (value is! Map) {
    return null;
  }

  final about = MosqueAboutContent.fromJson(
    Map<String, dynamic>.from(value.cast<Object?, Object?>()),
  );

  if (about.title.trim().isEmpty && about.body.trim().isEmpty) {
    return null;
  }

  return about;
}
