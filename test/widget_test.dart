import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:believer/data/auth_provider.dart';
import 'package:believer/main.dart';
import 'package:believer/navigation/app_startup.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/screens/home_page_1.dart';
import 'package:believer/screens/onboarding_screen.dart';
import 'package:believer/screens/profile_settings_screen.dart';
import 'package:believer/services/auth_service.dart';
import 'package:believer/services/onboarding_preferences_service.dart';

void main() {
  testWidgets('app boots into onboarding on first launch',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final container = _createContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(BelieversLensApp(container: container));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Log In'), findsNothing);
  });

  testWidgets('app boots into login after onboarding is completed',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.completed': true,
    });

    final container = _createContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(BelieversLensApp(container: container));
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsWidgets);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('app boots into home for signed-out guest return',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.completed': true,
      'onboarding.continue_as_guest': true,
    });

    final container = _createContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(BelieversLensApp(container: container));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage1), findsOneWidget);
    expect(find.text('PRAYER TIME'), findsOneWidget);
  });

  testWidgets('app boots into home when an authenticated session exists',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.completed': true,
      'auth.user.id': 'user-1',
      'auth.user.name': 'Amina',
      'auth.user.email': 'amina@example.com',
      'auth.user.role': 'community',
    });

    final container = _createContainer(
      tokens: const AuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(BelieversLensApp(container: container));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage1), findsOneWidget);
    expect(find.text('DISCOVER MOSQUES NEAR YOU'), findsOneWidget);
  });

  testWidgets('signed-out logout return boots into onboarding',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.completed': true,
      'onboarding.show_on_signed_out_entry': true,
    });

    final container = _createContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(BelieversLensApp(container: container));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('logout routes authenticated users back to onboarding',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.completed': true,
      'auth.user.id': 'user-1',
      'auth.user.name': 'Amina',
      'auth.user.email': 'amina@example.com',
      'auth.user.role': 'community',
    });

    final container = _createContainer(
      tokens: const AuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          routes: {
            AppRoutes.onboarding: (_) =>
                const Scaffold(body: Text('Onboarding stub')),
            AppRoutes.profileSettings: (_) =>
                ProfileSettingsScreen(authService: _FakeAuthService()),
          },
          home: const HomePage1(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    final logoutFinder = find.text('Log Out');
    await tester.ensureVisible(logoutFinder);
    await tester.tap(logoutFinder);
    await tester.pumpAndSettle();

    expect(find.text('Onboarding stub'), findsOneWidget);
  });

  test('startup policy keeps guest and signed-out routing coherent', () {
    _expectRoute(
      AppStartupPolicy.resolveRoute(
        isAuthenticated: false,
        onboardingState: const OnboardingPreferencesState(
          onboardingCompleted: true,
          continueAsGuest: true,
          showOnboardingOnSignedOutEntry: false,
        ),
      ),
      AppRoutes.home,
    );

    _expectRoute(
      AppStartupPolicy.resolveRoute(
        isAuthenticated: false,
        onboardingState: const OnboardingPreferencesState(
          onboardingCompleted: true,
          continueAsGuest: false,
          showOnboardingOnSignedOutEntry: false,
        ),
      ),
      AppRoutes.login,
    );

    _expectRoute(
      AppStartupPolicy.resolveRoute(
        isAuthenticated: false,
        onboardingState: const OnboardingPreferencesState(
          onboardingCompleted: true,
          continueAsGuest: false,
          showOnboardingOnSignedOutEntry: true,
        ),
      ),
      AppRoutes.onboarding,
    );
  });
}

class _FakeAuthService extends AuthService {
  @override
  Future<void> logout() async {
    await OnboardingPreferencesService().markLogoutReturnPreferred();
  }
}

void _expectRoute(
  String actualRoute,
  String expectedRoute,
) {
  expect(actualRoute, expectedRoute);
}

ProviderContainer _createContainer({
  AuthTokens? tokens,
}) {
  return ProviderContainer(
    overrides: [
      authTokenStoreProvider.overrideWithValue(
        _FakeAuthTokenStore(tokens: tokens),
      ),
    ],
  );
}

class _FakeAuthTokenStore implements AuthTokenStore {
  _FakeAuthTokenStore({
    AuthTokens? tokens,
  }) : _tokens = tokens;

  AuthTokens? _tokens;

  @override
  Future<void> clearTokens() async {
    _tokens = null;
  }

  @override
  Future<AuthTokens?> readTokens() async => _tokens;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _tokens = AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}
