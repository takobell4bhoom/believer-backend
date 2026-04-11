import 'package:shared_preferences/shared_preferences.dart';

enum AsarTimeMode { early, late }
enum PrayerNotificationMode { silent, on, adhan }

class PrayerSettings {
  const PrayerSettings({
    required this.asarTimeMode,
    required this.showSuhoorIftarOnHome,
    required this.duhaReminder,
    required this.qiyamReminder,
    required this.prayerModes,
  });

  final AsarTimeMode asarTimeMode;
  final bool showSuhoorIftarOnHome;
  final bool duhaReminder;
  final bool qiyamReminder;
  final Map<String, PrayerNotificationMode> prayerModes;

  static const defaultPrayerModes = {
    'Fajar': PrayerNotificationMode.silent,
    'Duhr': PrayerNotificationMode.silent,
    'Asar': PrayerNotificationMode.silent,
    'Maghrib': PrayerNotificationMode.silent,
    'Isha': PrayerNotificationMode.silent,
  };

  factory PrayerSettings.defaults() {
    return const PrayerSettings(
      asarTimeMode: AsarTimeMode.late,
      showSuhoorIftarOnHome: false,
      duhaReminder: false,
      qiyamReminder: false,
      prayerModes: defaultPrayerModes,
    );
  }

  PrayerSettings copyWith({
    AsarTimeMode? asarTimeMode,
    bool? showSuhoorIftarOnHome,
    bool? duhaReminder,
    bool? qiyamReminder,
    Map<String, PrayerNotificationMode>? prayerModes,
  }) {
    return PrayerSettings(
      asarTimeMode: asarTimeMode ?? this.asarTimeMode,
      showSuhoorIftarOnHome: showSuhoorIftarOnHome ?? this.showSuhoorIftarOnHome,
      duhaReminder: duhaReminder ?? this.duhaReminder,
      qiyamReminder: qiyamReminder ?? this.qiyamReminder,
      prayerModes: prayerModes ?? this.prayerModes,
    );
  }
}

class PrayerSettingsService {
  static const _asarTimeModeKey = 'prayer_settings.asar_time_mode';
  static const _showSuhoorIftarKey = 'prayer_settings.show_suhoor_iftar';
  static const _duhaReminderKey = 'prayer_settings.duha_reminder';
  static const _qiyamReminderKey = 'prayer_settings.qiyam_reminder';
  static const _prayerModePrefix = 'prayer_settings.prayer_mode.';

  Future<PrayerSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = prefs.getString(_asarTimeModeKey) ?? AsarTimeMode.late.name;
    final prayerModes = <String, PrayerNotificationMode>{
      for (final prayer in PrayerSettings.defaultPrayerModes.keys)
        prayer: _decodeMode(
          prefs.getString('$_prayerModePrefix$prayer') ?? PrayerNotificationMode.silent.name,
        ),
    };

    return PrayerSettings(
      asarTimeMode: modeRaw == AsarTimeMode.early.name ? AsarTimeMode.early : AsarTimeMode.late,
      showSuhoorIftarOnHome: prefs.getBool(_showSuhoorIftarKey) ?? false,
      duhaReminder: prefs.getBool(_duhaReminderKey) ?? false,
      qiyamReminder: prefs.getBool(_qiyamReminderKey) ?? false,
      prayerModes: prayerModes,
    );
  }

  Future<void> save(PrayerSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_asarTimeModeKey, settings.asarTimeMode.name);
    await prefs.setBool(_showSuhoorIftarKey, settings.showSuhoorIftarOnHome);
    await prefs.setBool(_duhaReminderKey, settings.duhaReminder);
    await prefs.setBool(_qiyamReminderKey, settings.qiyamReminder);

    for (final entry in settings.prayerModes.entries) {
      await prefs.setString('$_prayerModePrefix${entry.key}', entry.value.name);
    }
  }

  PrayerNotificationMode _decodeMode(String raw) {
    switch (raw) {
      case 'on':
        return PrayerNotificationMode.on;
      case 'adhan':
        return PrayerNotificationMode.adhan;
      case 'silent':
      default:
        return PrayerNotificationMode.silent;
    }
  }
}
