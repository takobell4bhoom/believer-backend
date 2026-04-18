import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/profile_settings_screen.dart';
import 'package:believer/services/auth_service.dart';

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

class _AdminAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'admin-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 'admin-1',
        fullName: 'Admin Owner',
        email: 'admin@example.com',
        role: 'admin',
      ),
    );
  }
}

class _SuperAdminAuthNotifier extends AuthNotifier {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      accessToken: 'super-admin-token',
      refreshToken: 'refresh-token',
      user: AuthUser(
        id: 'super-admin-1',
        fullName: 'Super Admin',
        email: 'super-admin@example.com',
        role: 'super_admin',
      ),
    );
  }
}

class _FakeAuthService extends AuthService {
  bool logoutCalled = false;
  String? currentPassword;
  String? newPassword;
  Object? changePasswordError;

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
  }) async {
    return AuthUser(
      id: 'user-1',
      fullName: fullName,
      email: 'sidrah@hotmail.com',
      role: 'community',
    );
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    this.currentPassword = currentPassword;
    this.newPassword = newPassword;
    if (changePasswordError != null) {
      throw changePasswordError!;
    }
  }
}

void main() {
  testWidgets('regular user profile/settings variant matches the compact shell',
      (tester) async {
    final service = _FakeAuthService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_UserAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ProfileSettingsScreen(authService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Profile & Settings'), findsOneWidget);
    expect(find.text('Sidrah Saved'), findsOneWidget);
    expect(find.text('sidrah@hotmail.com'), findsOneWidget);
    expect(find.text('Mosque Updates'), findsOneWidget);
    expect(find.text('Push Notifications'), findsNothing);
    expect(find.text('Register as a Business'), findsOneWidget);
    expect(find.text('Rate Us'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-settings-admin-section')),
      findsNothing,
    );
  });

  testWidgets(
      'profile settings change password flow submits current and new password',
      (tester) async {
    final service = _FakeAuthService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_UserAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ProfileSettingsScreen(authService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('profile-settings-change-password')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('change-password-current')),
      'CurrentPass@123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('change-password-new')),
      'UpdatedPass@456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('change-password-confirm')),
      'UpdatedPass@456',
    );

    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(service.currentPassword, 'CurrentPass@123');
    expect(service.newPassword, 'UpdatedPass@456');
    expect(find.text('Password updated.'), findsOneWidget);
  });

  testWidgets('admin profile/settings variant shows owned mosque actions',
      (tester) async {
    final service = _FakeAuthService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_AdminAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.ownedMosques: (_) =>
                const Scaffold(body: Text('Owned mosques stub')),
            AppRoutes.adminAddMosque: (_) =>
                const Scaffold(body: Text('Add mosque stub')),
            AppRoutes.login: (_) => const Scaffold(body: Text('Login stub')),
          },
          home: ProfileSettingsScreen(authService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-settings-admin-section')),
      findsOneWidget,
    );
    expect(find.text('My Mosques'), findsOneWidget);
    expect(find.text('Manage Owned Mosques'), findsOneWidget);
    expect(find.text('Publish Events'), findsOneWidget);
    expect(find.text('Broadcast Messages'), findsOneWidget);
    expect(find.text('Add Mosque'), findsOneWidget);

    final myMosquesFinder = find.text('My Mosques');
    await tester.ensureVisible(myMosquesFinder);
    await tester.tap(myMosquesFinder);
    await tester.pumpAndSettle();

    expect(find.text('Owned mosques stub'), findsOneWidget);
  });

  testWidgets(
      'super admin sees the unified Admin Panel entry point from profile settings',
      (tester) async {
    final service = _FakeAuthService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_SuperAdminAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.superAdminPanel: (_) =>
                const Scaffold(body: Text('Admin panel stub')),
          },
          home: ProfileSettingsScreen(authService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-settings-super-admin-section')),
      findsOneWidget,
    );
    expect(find.text('Admin Panel'), findsOneWidget);

    await tester.ensureVisible(find.text('Admin Panel'));
    await tester.tap(find.text('Admin Panel'));
    await tester.pumpAndSettle();

    expect(find.text('Admin panel stub'), findsOneWidget);
  });

  testWidgets('settings info rows navigate to real routes', (tester) async {
    final service = _FakeAuthService();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_UserAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.notifications: (_) =>
                const Scaffold(body: Text('Notifications stub')),
            AppRoutes.settingsAbout: (_) =>
                const Scaffold(body: Text('About stub')),
            AppRoutes.settingsPrivacy: (_) =>
                const Scaffold(body: Text('Privacy stub')),
            AppRoutes.settingsRateUs: (_) =>
                const Scaffold(body: Text('Rate us feedback stub')),
            AppRoutes.settingsSuggestMosque: (_) =>
                const Scaffold(body: Text('Suggest mosque stub')),
            AppRoutes.settingsFaq: (_) =>
                const Scaffold(body: Text('FAQ stub')),
            AppRoutes.settingsSupport: (_) =>
                const Scaffold(body: Text('Support stub')),
            AppRoutes.settingsDeleteAccount: (_) =>
                const Scaffold(body: Text('Delete account stub')),
          },
          home: ProfileSettingsScreen(authService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text(
        'Start or resume your business listing draft.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Manage followed mosques and in-app updates from the Notifications tab.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Mosque Updates'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications stub'), findsOneWidget);
    Navigator.of(tester.element(find.text('Notifications stub'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('About'));
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('About stub'), findsOneWidget);
    Navigator.of(tester.element(find.text('About stub'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy stub'), findsOneWidget);
    Navigator.of(tester.element(find.text('Privacy stub'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rate Us'));
    await tester.pumpAndSettle();
    expect(find.text('Rate us feedback stub'), findsOneWidget);
    Navigator.of(tester.element(find.text('Rate us feedback stub'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Suggest a Mosque'));
    await tester.tap(find.text('Suggest a Mosque'));
    await tester.pumpAndSettle();
    expect(find.text('Suggest mosque stub'), findsOneWidget);
    Navigator.of(tester.element(find.text('Suggest mosque stub'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('FAQs'));
    await tester.tap(find.text('FAQs'));
    await tester.pumpAndSettle();
    expect(find.text('FAQ stub'), findsOneWidget);
    Navigator.of(tester.element(find.text('FAQ stub'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Support'));
    await tester.tap(find.text('Support'));
    await tester.pumpAndSettle();
    expect(find.text('Support stub'), findsOneWidget);
    Navigator.of(tester.element(find.text('Support stub'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete Account'));
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account stub'), findsOneWidget);
  });
}
