import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_provider_container.dart';
import 'data/auth_provider.dart';
import 'navigation/app_router.dart';
import 'navigation/app_startup.dart';
import 'services/app_notification_service.dart';
import 'services/onboarding_preferences_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BelieversLensApp());
}

class BelieversLensApp extends StatelessWidget {
  const BelieversLensApp({
    super.key,
    this.container,
    this.enableNotificationBootstrap = true,
  });

  final ProviderContainer? container;
  final bool enableNotificationBootstrap;

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container ?? appProviderContainer,
      child: _AppRoot(
        enableNotificationBootstrap: enableNotificationBootstrap,
      ),
    );
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot({
    required this.enableNotificationBootstrap,
  });

  final bool enableNotificationBootstrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupState = ref.watch(appStartupBootstrapProvider);
    final authState = ref.watch(authProvider);
    final onboardingState = ref.watch(onboardingCompletionProvider);
    final explicitRoute = AppStartupPolicy.resolveExplicitEntryRoute();
    String? initialRoute;
    final debugStatus = 'startupLoading=${startupState.isLoading} '
        'startupError=${startupState.hasError} '
        'authLoading=${authState.isLoading} '
        'authError=${authState.hasError} '
        'onboardingLoading=${onboardingState.isLoading} '
        'onboardingError=${onboardingState.hasError}';

    if (explicitRoute != null) {
      initialRoute = explicitRoute;
    } else if (startupState.isLoading) {
      initialRoute = null;
    } else {
      final resolvedStartupState =
          startupState.valueOrNull ?? const AppStartupBootstrapState();
      initialRoute = AppStartupPolicy.resolveRoute(
        isAuthenticated: resolvedStartupState.session != null,
        onboardingState: resolvedStartupState.onboardingState,
      );
    }

    if (kDebugMode) {
      debugPrint('App startup state: $debugStatus initialRoute=$initialRoute');
    }

    final app = MaterialApp(
      key: ValueKey(initialRoute ?? 'auth-loading'),
      navigatorKey: initialRoute == null ? null : appNavigatorKey,
      title: 'Believers Lens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: initialRoute == null
          ? _AuthLoadingScreen(
              debugStatus: kDebugMode ? debugStatus : null,
            )
          : null,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );

    if (!enableNotificationBootstrap) {
      return app;
    }

    return AuthAwareNotificationBootstrap(
      child: app,
    );
  }
}

const _defaultOnboardingPreferencesState = OnboardingPreferencesState(
  onboardingCompleted: false,
  continueAsGuest: false,
  showOnboardingOnSignedOutEntry: false,
);

@immutable
class AppStartupBootstrapState {
  const AppStartupBootstrapState({
    this.session,
    this.onboardingState = _defaultOnboardingPreferencesState,
  });

  final AuthSession? session;
  final OnboardingPreferencesState onboardingState;
}

@immutable
class _StartupDependencyResult<T> {
  const _StartupDependencyResult({
    required this.value,
  });

  final T value;
}

final startupHydrationTimeoutProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 4);
});

final appStartupBootstrapProvider =
    FutureProvider<AppStartupBootstrapState>((ref) async {
  final timeout = ref.watch(startupHydrationTimeoutProvider);
  final authResult = _resolveStartupDependency<AuthSession?>(
    future: ref.watch(authProvider.future),
    timeout: timeout,
    fallback: null,
    label: 'auth',
  );
  final onboardingResult = _resolveStartupDependency<OnboardingPreferencesState>(
    future: ref.watch(onboardingCompletionProvider.future),
    timeout: timeout,
    fallback: _defaultOnboardingPreferencesState,
    label: 'onboarding',
  );

  return AppStartupBootstrapState(
    session: (await authResult).value,
    onboardingState: (await onboardingResult).value,
  );
});

Future<_StartupDependencyResult<T>> _resolveStartupDependency<T>({
  required Future<T> future,
  required Duration timeout,
  required T fallback,
  required String label,
}) async {
  try {
    return _StartupDependencyResult<T>(
      value: await future.timeout(timeout),
    );
  } on TimeoutException {
    debugPrint(
      'Startup $label hydration timed out after ${timeout.inMilliseconds}ms; '
      'continuing with fallback.',
    );
  } catch (error, stackTrace) {
    debugPrint(
      'Startup $label hydration failed; continuing with fallback. '
      'Error: $error',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  return _StartupDependencyResult<T>(value: fallback);
}

final onboardingCompletionProvider =
    FutureProvider<OnboardingPreferencesState>((ref) async {
  final loadState = OnboardingPreferencesService().loadState();

  if (shouldUseLocalWebStartupFallback()) {
    return loadState.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        debugPrint(
          'Onboarding bootstrap timed out on localhost web; using defaults.',
        );
        return _defaultOnboardingPreferencesState;
      },
    );
  }

  return loadState;
});

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen({
    this.debugStatus,
  });

  final String? debugStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (debugStatus != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  debugStatus!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
