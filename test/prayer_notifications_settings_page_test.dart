import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/screens/prayer_notifications_settings_page.dart';

void main() {
  testWidgets('prayer settings renders in compact viewport without overflow',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 620);

    await tester.pumpWidget(
      const MaterialApp(home: PrayerNotificationsSettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prayer Notifications & Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('asar mode changes persist across page reload', (tester) async {
    SharedPreferences.setMockInitialValues({
      'prayer_settings.asar_time_mode': 'early',
      'prayer_settings.show_suhoor_iftar': true,
    });

    await tester.pumpWidget(
      const MaterialApp(home: PrayerNotificationsSettingsPage()),
    );
    await tester.pumpAndSettle();

    final asarLink = find.byKey(const Key('asar-time-link'));
    expect(asarLink, findsOneWidget);
    await tester.ensureVisible(asarLink);
    await tester.tap(asarLink);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('asar-option-late')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('prayer_settings.asar_time_mode'), 'late');

    await tester.pumpWidget(
      const MaterialApp(home: PrayerNotificationsSettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(prefs.getString('prayer_settings.asar_time_mode'), 'late');
  });

  testWidgets('show on homepage toggle persists across page reload',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'prayer_settings.asar_time_mode': 'late',
      'prayer_settings.show_suhoor_iftar': false,
    });

    await tester.pumpWidget(
      const MaterialApp(home: PrayerNotificationsSettingsPage()),
    );
    await tester.pumpAndSettle();

    final showHomeToggle = find.byKey(const Key('show-home-toggle'));
    await tester.ensureVisible(showHomeToggle);
    await tester.tap(showHomeToggle);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('prayer_settings.show_suhoor_iftar'), isTrue);

    await tester.pumpWidget(
      const MaterialApp(home: PrayerNotificationsSettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(prefs.getBool('prayer_settings.show_suhoor_iftar'), isTrue);
  });
}
