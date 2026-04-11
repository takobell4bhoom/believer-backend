import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/settings_detail_screens.dart';
import 'package:believer/services/account_settings_service.dart';

class _UserAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'user-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 'user-1',
        fullName: 'Sidrah Saved',
        email: 'sidrah@hotmail.com',
        role: 'community',
      ),
    );
  }
}

class _FakeAccountSettingsService extends AccountSettingsService {
  bool deactivateCalled = false;
  String? confirmation;
  String? supportSubject;
  String? supportMessage;
  String? mosqueName;
  String? city;
  String? country;
  String? addressLine;
  String? notes;

  @override
  Future<void> deactivateAccount({
    required String confirmation,
  }) async {
    deactivateCalled = true;
    this.confirmation = confirmation;
  }

  @override
  Future<void> submitSupportRequest({
    required String subject,
    required String message,
  }) async {
    supportSubject = subject;
    supportMessage = message;
  }

  @override
  Future<void> submitMosqueSuggestion({
    required String mosqueName,
    required String city,
    required String country,
    String? addressLine,
    String? notes,
  }) async {
    this.mosqueName = mosqueName;
    this.city = city;
    this.country = country;
    this.addressLine = addressLine;
    this.notes = notes;
  }
}

void main() {
  testWidgets(
      'delete account requires DEACTIVATE and signs user out after confirmation',
      (tester) async {
    final service = _FakeAccountSettingsService();
    SharedPreferences.setMockInitialValues(
      const <String, Object>{
        'onboarding.completed': true,
        'onboarding.continue_as_guest': false,
        'onboarding.show_on_signed_out_entry': true,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.onboarding: (_) =>
              const Scaffold(body: Text('Onboarding stub')),
        },
        home: SettingsDeleteAccountScreen(accountSettingsService: service),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-delete-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Type DEACTIVATE to confirm.'), findsAtLeastNWidgets(1));
    expect(service.deactivateCalled, isFalse);

    await tester.enterText(
      find.byKey(const ValueKey('settings-delete-confirmation')),
      'DEACTIVATE',
    );
    await tester.tap(find.byKey(const ValueKey('settings-delete-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Deactivate account?'), findsOneWidget);

    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();

    expect(service.deactivateCalled, isTrue);
    expect(service.confirmation, 'DEACTIVATE');
    expect(find.text('Onboarding stub'), findsOneWidget);
  });

  testWidgets('support screen submits a real support request flow',
      (tester) async {
    final service = _FakeAccountSettingsService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_UserAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SettingsSupportScreen(accountSettingsService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('sidrah@hotmail.com'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('settings-support-subject')),
      'Need help',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-support-message')),
      'I need help updating a detail on my account.',
    );
    await tester.tap(find.byKey(const ValueKey('settings-support-submit')));
    await tester.pumpAndSettle();

    expect(service.supportSubject, 'Need help');
    expect(
      service.supportMessage,
      'I need help updating a detail on my account.',
    );
    expect(find.text('Support request sent.'), findsOneWidget);
  });

  testWidgets('rate us screen submits product feedback through support flow',
      (tester) async {
    final service = _FakeAccountSettingsService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_UserAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SettingsRateUsScreen(accountSettingsService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Rate Us'), findsOneWidget);
    expect(find.text('Share app feedback'), findsOneWidget);
    expect(
      find.textContaining('launch issues and product suggestions'),
      findsOneWidget,
    );
    expect(find.text('Send feedback'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('settings-support-message')),
      'The live business tools are easy to follow and the marketplace copy feels trustworthy.',
    );
    await tester.tap(find.byKey(const ValueKey('settings-support-submit')));
    await tester.pumpAndSettle();

    expect(service.supportSubject, 'Product feedback');
    expect(
      service.supportMessage,
      'The live business tools are easy to follow and the marketplace copy feels trustworthy.',
    );
    expect(find.text('Thanks for sharing your feedback.'), findsOneWidget);
  });

  testWidgets('suggest mosque screen submits a persisted suggestion flow',
      (tester) async {
    final service = _FakeAccountSettingsService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_UserAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SettingsSuggestMosqueScreen(accountSettingsService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('settings-suggest-mosque-name')),
      'Masjid Al Noor',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-suggest-city')),
      'Hyderabad',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-suggest-country')),
      'India',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-suggest-address')),
      '123 Market Road',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-suggest-notes')),
      'Women prayer space and parking available.',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-suggest-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('settings-suggest-submit')));
    await tester.pumpAndSettle();

    expect(service.mosqueName, 'Masjid Al Noor');
    expect(service.city, 'Hyderabad');
    expect(service.country, 'India');
    expect(service.addressLine, '123 Market Road');
    expect(service.notes, 'Women prayer space and parking available.');
    expect(find.text('Mosque suggestion sent.'), findsOneWidget);
  });
}
