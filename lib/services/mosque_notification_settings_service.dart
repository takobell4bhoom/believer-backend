import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_setting.dart';

class MosqueNotificationSettingsService {
  static const _prefsPrefix = 'mosque.notification.';

  Future<List<NotificationSetting>> load({
    required String mosqueId,
    required List<NotificationSetting> defaults,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return defaults
        .map(
          (setting) => setting.copyWith(
            isEnabled: prefs.getBool(_prefsKey(mosqueId, setting.title)) ??
                setting.isEnabled,
          ),
        )
        .toList(growable: false);
  }

  Future<void> save({
    required String mosqueId,
    required List<NotificationSetting> settings,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final setting in settings) {
      await prefs.setBool(
          _prefsKey(mosqueId, setting.title), setting.isEnabled);
    }
  }

  String _prefsKey(String mosqueId, String title) {
    return '$_prefsPrefix$mosqueId.${title.toLowerCase().replaceAll(' ', '_')}';
  }
}
