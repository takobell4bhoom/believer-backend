class PrayerTimeMethodOption {
  const PrayerTimeMethodOption({
    required this.id,
    required this.label,
  });

  final int id;
  final String label;

  @override
  String toString() => label;
}

const prayerTimeMethodOptions = <PrayerTimeMethodOption>[
  PrayerTimeMethodOption(
    id: 1,
    label: 'Karachi',
  ),
  PrayerTimeMethodOption(
    id: 2,
    label: 'ISNA',
  ),
  PrayerTimeMethodOption(
    id: 3,
    label: 'Muslim World League',
  ),
  PrayerTimeMethodOption(
    id: 4,
    label: 'Umm Al-Qura',
  ),
  PrayerTimeMethodOption(
    id: 5,
    label: 'Egyptian General Authority',
  ),
  PrayerTimeMethodOption(
    id: 8,
    label: 'Gulf Region',
  ),
  PrayerTimeMethodOption(
    id: 9,
    label: 'Kuwait',
  ),
  PrayerTimeMethodOption(
    id: 10,
    label: 'Qatar',
  ),
  PrayerTimeMethodOption(
    id: 11,
    label: 'Singapore',
  ),
  PrayerTimeMethodOption(
    id: 12,
    label: 'Turkey',
  ),
  PrayerTimeMethodOption(
    id: 15,
    label: 'Moonsighting Committee',
  ),
  PrayerTimeMethodOption(
    id: 16,
    label: 'Dubai',
  ),
  PrayerTimeMethodOption(
    id: 17,
    label: 'JAKIM',
  ),
  PrayerTimeMethodOption(
    id: 20,
    label: 'KEMENAG',
  ),
  PrayerTimeMethodOption(
    id: 21,
    label: 'Morocco',
  ),
  PrayerTimeMethodOption(
    id: 22,
    label: 'Portugal',
  ),
  PrayerTimeMethodOption(
    id: 23,
    label: 'Jordan',
  ),
];

const prayerSchoolOptions = <String>[
  'standard',
  'hanafi',
];

const prayerOffsetOrder = <String>[
  'fajr',
  'sunrise',
  'dhuhr',
  'asr',
  'maghrib',
  'isha',
];

String prayerOffsetLabel(String prayer) {
  return switch (prayer) {
    'fajr' => 'Fajr',
    'sunrise' => 'Sunrise',
    'dhuhr' => 'Dhuhr',
    'asr' => 'Asr',
    'maghrib' => 'Maghrib',
    'isha' => 'Isha',
    _ => prayer,
  };
}

String prayerSchoolLabel(String value) {
  return value == 'hanafi' ? 'Hanafi' : 'Standard';
}
