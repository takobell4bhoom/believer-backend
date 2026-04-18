class PrayerTimeConfiguration {
  const PrayerTimeConfiguration({
    required this.enabled,
    required this.latitude,
    required this.longitude,
    required this.calculationMethodId,
    required this.calculationMethodName,
    required this.school,
    required this.schoolLabel,
    required this.adjustments,
  });

  final bool enabled;
  final double latitude;
  final double longitude;
  final int calculationMethodId;
  final String calculationMethodName;
  final String school;
  final String schoolLabel;
  final Map<String, int> adjustments;

  factory PrayerTimeConfiguration.fromJson(Map<String, dynamic> json) {
    final calculationMethod =
        json['calculationMethod'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
    final school =
        json['school'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final adjustments = json['adjustments'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    return PrayerTimeConfiguration(
      enabled: json['enabled'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      calculationMethodId: calculationMethod['id'] as int? ?? 0,
      calculationMethodName:
          calculationMethod['name'] as String? ?? 'Calculation Method',
      school: school['value'] as String? ?? 'standard',
      schoolLabel: school['label'] as String? ?? 'Standard',
      adjustments: <String, int>{
        for (final prayer in PrayerTimings.supportedPrayers)
          prayer: (adjustments[prayer] as num?)?.toInt() ?? 0,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'latitude': latitude,
      'longitude': longitude,
      'calculationMethod': <String, dynamic>{
        'id': calculationMethodId,
        'name': calculationMethodName,
      },
      'school': <String, dynamic>{
        'value': school,
        'label': schoolLabel,
      },
      'adjustments': adjustments,
    };
  }
}

class PrayerWindow {
  const PrayerWindow({
    required this.prayerKey,
    required this.startTime,
    required this.endTime,
    required this.progress,
  });

  final String prayerKey;
  final DateTime startTime;
  final DateTime? endTime;
  final double progress;
}

class PrayerTimings {
  static const supportedPrayers = <String>[
    'fajr',
    'sunrise',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  const PrayerTimings({
    required this.mosqueId,
    required this.date,
    this.dateLabel = '',
    required this.status,
    required this.isConfigured,
    required this.isAvailable,
    required this.source,
    required this.unavailableReason,
    required this.timezone,
    required this.configuration,
    required this.timings,
    required this.nextPrayer,
    required this.nextPrayerTime,
    required this.cachedAt,
  });

  final String mosqueId;
  final String date;
  final String dateLabel;
  final String status;
  final bool isConfigured;
  final bool isAvailable;
  final String source;
  final String? unavailableReason;
  final String? timezone;
  final PrayerTimeConfiguration? configuration;
  final Map<String, String> timings;
  final String nextPrayer;
  final String nextPrayerTime;
  final String? cachedAt;

  factory PrayerTimings.fromJson(Map<String, dynamic> json) {
    final rawTimings =
        json['timings'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return PrayerTimings(
      mosqueId: json['mosqueId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      status: json['status'] as String? ?? 'not_configured',
      isConfigured: json['isConfigured'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? false,
      source: json['source'] as String? ?? 'none',
      unavailableReason: json['unavailableReason'] as String?,
      timezone: json['timezone'] as String?,
      configuration: json['configuration'] is Map<String, dynamic>
          ? PrayerTimeConfiguration.fromJson(
              json['configuration'] as Map<String, dynamic>,
            )
          : null,
      timings: <String, String>{
        for (final prayer in supportedPrayers)
          prayer: rawTimings[prayer] as String? ?? '',
      },
      nextPrayer: json['nextPrayer'] as String? ?? '',
      nextPrayerTime: json['nextPrayerTime'] as String? ?? '',
      cachedAt: json['cachedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mosqueId': mosqueId,
      'date': date,
      'dateLabel': dateLabel,
      'status': status,
      'isConfigured': isConfigured,
      'isAvailable': isAvailable,
      'source': source,
      'unavailableReason': unavailableReason,
      'timezone': timezone,
      'configuration': configuration?.toJson(),
      'timings': timings,
      'nextPrayer': nextPrayer,
      'nextPrayerTime': nextPrayerTime,
      'cachedAt': cachedAt,
    };
  }

  String timeFor(String prayer) => timings[prayer] ?? '';

  DateTime? timeForPrayerOnDate(
    String prayer, {
    DateTime? baseDate,
  }) {
    final rawValue = timeFor(prayer).trim();
    if (rawValue.isEmpty || rawValue == '--') {
      return null;
    }

    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
    ).firstMatch(rawValue);
    if (match == null) {
      return null;
    }

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final meridiem = (match.group(3) ?? '').toUpperCase();
    final resolvedBaseDate = baseDate ?? DateTime.tryParse(date);

    if (hour == null ||
        minute == null ||
        hour < 1 ||
        hour > 12 ||
        minute < 0 ||
        minute > 59 ||
        resolvedBaseDate == null) {
      return null;
    }

    var normalizedHour = hour % 12;
    if (meridiem == 'PM') {
      normalizedHour += 12;
    }

    return DateTime(
      resolvedBaseDate.year,
      resolvedBaseDate.month,
      resolvedBaseDate.day,
      normalizedHour,
      minute,
    );
  }

  PrayerWindow? currentPrayerWindowAt(
    DateTime referenceTime, {
    List<String> prayerOrder = const <String>[
      'fajr',
      'dhuhr',
      'asr',
      'maghrib',
      'isha',
    ],
  }) {
    final baseDate = DateTime.tryParse(date);
    if (baseDate == null) {
      return null;
    }

    final resolvedReferenceTime = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      referenceTime.hour,
      referenceTime.minute,
      referenceTime.second,
      referenceTime.millisecond,
      referenceTime.microsecond,
    );

    final entries = <({String prayer, DateTime start})>[];
    for (final prayer in prayerOrder) {
      final start = timeForPrayerOnDate(
        prayer,
        baseDate: baseDate,
      );
      if (start != null) {
        entries.add((prayer: prayer, start: start));
      }
    }

    if (entries.isEmpty ||
        resolvedReferenceTime.isBefore(entries.first.start)) {
      return null;
    }

    for (var index = 0; index < entries.length; index++) {
      final current = entries[index];
      final next = index + 1 < entries.length ? entries[index + 1] : null;
      final isCurrentWindow = next == null
          ? !resolvedReferenceTime.isBefore(current.start)
          : !resolvedReferenceTime.isBefore(current.start) &&
              resolvedReferenceTime.isBefore(next.start);

      if (!isCurrentWindow) {
        continue;
      }

      final progress = next == null
          ? 1.0
          : ((resolvedReferenceTime.difference(current.start).inMilliseconds /
                      next.start.difference(current.start).inMilliseconds)
                  .clamp(0.0, 1.0))
              .toDouble();

      return PrayerWindow(
        prayerKey: current.prayer,
        startTime: current.start,
        endTime: next?.start,
        progress: progress,
      );
    }

    return null;
  }
}
