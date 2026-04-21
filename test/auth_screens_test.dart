import 'package:believer/core/api_error_mapper.dart';
import 'package:believer/navigation/app_router.dart';
import 'package:believer/navigation/app_routes.dart';
import 'package:believer/navigation/app_startup.dart';
import 'package:believer/screens/forgot_password_screen.dart';
import 'package:believer/screens/login_screen.dart';
import 'package:believer/screens/onboarding_screen.dart';
import 'package:believer/screens/reset_password_screen.dart';
import 'package:believer/screens/signup_screen.dart';
import 'package:believer/services/api_client.dart';
import 'package:believer/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'login screen shows explicit user and mosque-admin modes while keeping validation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.forgotPassword: (_) =>
                const Scaffold(body: Text('Forgot password stub')),
            AppRoutes.signup: (_) => const Scaffold(body: Text('Signup stub')),
          },
          home: const LoginScreen(),
        ),
      );

      final loginButtonFinder = find.widgetWithText(ElevatedButton, 'Log In');
      ElevatedButton loginButton() =>
          tester.widget<ElevatedButton>(loginButtonFinder);

      expect(find.text('Log In'), findsAtLeastNWidgets(1));
      expect(find.text('User Login'), findsOneWidget);
      expect(find.text('Mosque Admin Login'), findsOneWidget);
      expect(
          find.text('Use your email and password to sign in.'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(loginButton().onPressed, isNull);

      await tester.tap(find.text('Mosque Admin Login'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Mosque admins sign in with the same email and password they created during sign up.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot password stub'), findsOneWidget);

      Navigator.of(tester.element(find.text('Forgot password stub'))).pop();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.pump();
      loginButton().onPressed!();
      await tester.pump();

      expect(
        find.text('Enter a valid email address, like name@example.com.'),
        findsOneWidget,
      );
      expect(
        find.text('Password must be at least 8 characters long.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.pump();

      expect(loginButton().onPressed, isNotNull);

      final signUpLink = find.widgetWithText(TextButton, 'Sign Up');
      await tester.ensureVisible(signUpLink);
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();

      expect(find.text('Signup stub'), findsOneWidget);
    },
  );

  testWidgets(
    'login screen rewrites wrong-credential errors into plain language',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authService: _FakeAuthService(
              loginError: ApiException(
                'Invalid email or password',
                statusCode: 401,
                errorCode: 'INVALID_CREDENTIALS',
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.pump();
      final logInButton = find.widgetWithText(ElevatedButton, 'Log In');
      tester.widget<ElevatedButton>(logInButton).onPressed!();
      await tester.pump();

      expect(
        find.text(
          'Email or password is incorrect. Check your details and try again.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'login back button safely routes to onboarding',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.onboarding: (_) =>
                const Scaffold(body: Text('Onboarding stub')),
          },
          home: const LoginScreen(),
        ),
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Onboarding stub'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login back button safely routes to onboarding from a real named-route startup',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: AppRoutes.login,
          onGenerateRoute: (settings) {
            if (settings.name == '/') {
              return MaterialPageRoute<void>(
                builder: (_) => const SizedBox.shrink(),
                settings: settings,
              );
            }
            if (settings.name == AppRoutes.onboarding) {
              return MaterialPageRoute<void>(
                builder: (_) => const OnboardingScreen(
                  splashDuration: Duration(milliseconds: 10),
                ),
                settings: settings,
              );
            }
            return AppRouter.onGenerateRoute(settings);
          },
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('onboarding-page-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onboarding auth entry opens signup as a child flow and back returns to onboarding',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.onboarding) {
              return MaterialPageRoute<void>(
                builder: (_) => const OnboardingScreen(
                  splashDuration: Duration(milliseconds: 10),
                ),
                settings: settings,
              );
            }
            return AppRouter.onGenerateRoute(settings);
          },
          initialRoute: AppRoutes.onboarding,
        ),
      );

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding-next-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-next-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-login-signup')));
      await tester.pumpAndSettle();

      expect(find.text('Log In'), findsAtLeastNWidgets(1));

      await tester.tap(find.text('Mosque Admin Login'));
      await tester.pumpAndSettle();

      final signUpLink = find.widgetWithText(TextButton, 'Sign Up');
      await tester.ensureVisible(signUpLink);
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();

      expect(find.text('Sign Up'), findsOneWidget);
      expect(
        find.text('Create your mosque admin account with email and password.'),
        findsOneWidget,
      );
      expect(find.text('Mosque Admin Access Code'), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('onboarding-page-0')), findsOneWidget);
      expect(find.text('Sign Up'), findsNothing);
    },
  );

  testWidgets(
    'signup back button safely routes to onboarding when opened directly',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.onboarding: (_) =>
                const Scaffold(body: Text('Onboarding stub')),
          },
          home: const SignUpScreen(),
        ),
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Onboarding stub'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'forgot password screen validates input and shows the generic success state',
    (tester) async {
      final service = _FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.login: (_) => const Scaffold(body: Text('Login stub')),
          },
          home: ForgotPasswordScreen(authService: service),
        ),
      );

      await tester.enterText(find.byType(TextField), 'bad-email');
      await tester.pump();
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Send Reset Link'),
          )
          .onPressed!();
      await tester.pump();

      expect(
        find.text('Enter a valid email address, like name@example.com.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.pump();
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Send Reset Link'),
          )
          .onPressed!();
      await tester.pump();

      expect(service.passwordResetRequestEmail, 'user@example.com');
      expect(
        find.text(
          'If an account exists for this email, a one-time reset link is on the way.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'forgot password screen surfaces honest email-configuration failures',
    (tester) async {
      final service = _FakeAuthService()
        ..passwordResetRequestError = ApiException(
          'Password reset email is not configured for this environment',
          statusCode: 503,
          errorCode: 'EMAIL_NOT_CONFIGURED',
        );

      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(authService: service),
        ),
      );

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.pump();
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Send Reset Link'),
          )
          .onPressed!();
      await tester.pump();

      expect(
        find.text(
          'Password reset email is not available right now. Please try again later.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'valid reset links open the reset password screen through app routing',
    (tester) async {
      final initialRoute = AppStartupPolicy.resolveExplicitEntryRoute(
        currentUri: Uri.parse(
          'https://app.example.com/?token=valid-reset-token-123',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: initialRoute,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('Reset Password'), findsOneWidget);
    },
  );

  testWidgets(
    'reset password screen submits the token-backed password change',
    (tester) async {
      final service = _FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.login: (_) => const Scaffold(body: Text('Login stub')),
            AppRoutes.forgotPassword: (_) =>
                const Scaffold(body: Text('Forgot password stub')),
          },
          home: ResetPasswordScreen(
            authService: service,
            initialToken: 'valid-reset-token-12345678901234567890123456789012',
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField).at(0),
        'NewStrongPass@123',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'NewStrongPass@123',
      );
      await tester.pump();
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Update Password'),
          )
          .onPressed!();
      await tester.pump();

      expect(
        service.resetPasswordToken,
        'valid-reset-token-12345678901234567890123456789012',
      );
      expect(service.resetPasswordValue, 'NewStrongPass@123');
      expect(
        find.text(
          'Your password has been updated. Log in with your new password.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'reset password screen keeps the user on the reset flow when the token is missing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: AppRoutes.resetPassword,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('Reset Password'), findsOneWidget);
      expect(
        find.text(
          'This reset link is incomplete or no longer includes a token. Request a new password reset email to continue.',
        ),
        findsOneWidget,
      );
      expect(find.text('Update Password'), findsOneWidget);
    },
  );

  testWidgets(
    'reset password screen shows a plain-language expired-link error',
    (tester) async {
      final service = _FakeAuthService()
        ..resetPasswordError = ApiException(
          'Password reset token is invalid or expired',
          statusCode: 400,
          errorCode: 'INVALID_PASSWORD_RESET_TOKEN',
        );

      await tester.pumpWidget(
        MaterialApp(
          home: ResetPasswordScreen(
            authService: service,
            initialToken: 'valid-reset-token-12345678901234567890123456789012',
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField).at(0),
        'NewStrongPass@123',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'NewStrongPass@123',
      );
      await tester.pump();
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Update Password'),
          )
          .onPressed!();
      await tester.pump();

      expect(
        find.text(
          'This password reset link is invalid or has expired. Request a new one and try again.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'signup screen shows explicit user and mosque-admin sign-up modes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.login: (_) => const Scaffold(body: Text('Login stub')),
          },
          home: const SignUpScreen(),
        ),
      );

      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      for (final field in fields) {
        expect(field.controller?.text ?? '', isEmpty);
      }

      final signUpButtonFinder = find.widgetWithText(
        ElevatedButton,
        'Create Account',
      );
      ElevatedButton signUpButton() =>
          tester.widget<ElevatedButton>(signUpButtonFinder);

      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('User Sign Up'), findsOneWidget);
      expect(find.text('Mosque Admin Sign Up'), findsOneWidget);
      expect(find.text('Create your account with email and password.'),
          findsOneWidget);
      expect(
        find.text(ApiErrorMapper.passwordRequirementsText),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(signUpButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(0), 'Sidrah');
      await tester.enterText(
        find.byType(TextField).at(1),
        'sidrah@example.com',
      );
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.enterText(find.byType(TextField).at(3), 'password123');
      await tester.pump();

      expect(signUpButton().onPressed, isNotNull);

      final adminAccountTypeFinder =
          find.byKey(const ValueKey('signup-account-type-admin'));
      await tester.ensureVisible(adminAccountTypeFinder);
      await tester.tap(adminAccountTypeFinder);
      await tester.pumpAndSettle();

      expect(find.text('Mosque Admin Access Code'), findsNothing);
      expect(find.text('Mosque Admin Sign Up'), findsOneWidget);
      expect(
        find.text('Create your mosque admin account with email and password.'),
        findsOneWidget,
      );

      final logInLink = find.widgetWithText(TextButton, 'Log In');
      await tester.ensureVisible(logInLink);
      await tester.tap(logInLink);
      await tester.pumpAndSettle();

      expect(find.text('Login stub'), findsOneWidget);
    },
  );

  testWidgets(
    'signup screen shows friendlier validation and duplicate-email errors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpScreen(
            authService: _FakeAuthService(
              signupError: ApiException(
                'Email is already registered',
                statusCode: 409,
                errorCode: 'EMAIL_ALREADY_EXISTS',
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'Amina');
      await tester.enterText(find.byType(TextField).at(1), 'bad-email');
      await tester.enterText(find.byType(TextField).at(2), 'short');
      await tester.enterText(find.byType(TextField).at(3), 'different');
      final createAccountButton =
          find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.pump();
      tester.widget<ElevatedButton>(createAccountButton).onPressed!();
      await tester.pump();

      expect(
        find.text('Enter a valid email address, like name@example.com.'),
        findsOneWidget,
      );
      expect(
        find.text('Password must be at least 8 characters long.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Passwords do not match yet. Re-enter the same password to confirm.',
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).at(1), 'amina@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'StrongPass@123');
      await tester.enterText(find.byType(TextField).at(3), 'StrongPass@123');
      await tester.pump();
      tester.widget<ElevatedButton>(createAccountButton).onPressed!();
      await tester.pump();

      expect(
        find.text(
          'An account with this email already exists. Log in instead or use a different email.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'signup screen submits mosque-admin mode without requiring an extra access code field',
    (tester) async {
      final fakeAuthService = _FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: SignUpScreen(
            initialAccountType: SignupAccountType.admin,
            authService: fakeAuthService,
          ),
        ),
      );

      expect(find.text('Mosque Admin Access Code'), findsNothing);

      await tester.enterText(find.byType(TextField).at(0), 'Amina');
      await tester.enterText(find.byType(TextField).at(1), 'amina@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'StrongPass@123');
      await tester.enterText(find.byType(TextField).at(3), 'StrongPass@123');
      await tester.pump();
      final createAdminButton =
          find.widgetWithText(ElevatedButton, 'Create Account');
      tester.widget<ElevatedButton>(createAdminButton).onPressed!();
      await tester.pumpAndSettle();

      expect(fakeAuthService.signupAccountType, 'admin');
      expect(fakeAuthService.signupEmail, 'amina@example.com');
      expect(find.text('Mosque Admin Access Code'), findsNothing);
    },
  );
  testWidgets(
    'signup screen keeps actionable network troubleshooting copy',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpScreen(
            initialAccountType: SignupAccountType.admin,
            authService: _FakeAuthService(
              signupError: ApiException(
                'Cannot reach http://10.0.2.2:4000. Android emulator should use http://10.0.2.2:4000. For a physical device, set API_BASE_URL to your computer\'s LAN IP.',
                errorCode: 'NETWORK_ERROR',
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'Amina');
      await tester.enterText(find.byType(TextField).at(1), 'amina@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'StrongPass@123');
      await tester.enterText(find.byType(TextField).at(3), 'StrongPass@123');
      await tester.pump();

      final createAccountButton =
          find.widgetWithText(ElevatedButton, 'Create Account');
      tester.widget<ElevatedButton>(createAccountButton).onPressed!();
      await tester.pump();

      expect(
        find.text(
          'Cannot reach http://10.0.2.2:4000. Android emulator should use http://10.0.2.2:4000. For a physical device, set API_BASE_URL to your computer\'s LAN IP.',
        ),
        findsOneWidget,
      );
    },
  );
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    this.loginError,
    this.signupError,
  });

  final Object? loginError;
  final Object? signupError;
  Object? passwordResetRequestError;
  Object? resetPasswordError;
  String? signupFullName;
  String? signupEmail;
  String? signupPassword;
  String? signupAccountType;
  String? passwordResetRequestEmail;
  String? resetPasswordToken;
  String? resetPasswordValue;

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) {
      throw loginError!;
    }
  }

  @override
  Future<void> signup({
    required String fullName,
    required String email,
    required String password,
    String accountType = 'community',
  }) async {
    signupFullName = fullName;
    signupEmail = email;
    signupPassword = password;
    signupAccountType = accountType;
    if (signupError != null) {
      throw signupError!;
    }
  }

  @override
  Future<void> requestPasswordReset({
    required String email,
  }) async {
    passwordResetRequestEmail = email;
    if (passwordResetRequestError != null) {
      throw passwordResetRequestError!;
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    resetPasswordToken = token;
    resetPasswordValue = newPassword;
    if (resetPasswordError != null) {
      throw resetPasswordError!;
    }
  }
}
