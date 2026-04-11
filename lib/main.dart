import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_provider_container.dart';
import 'data/auth_provider.dart';
import 'navigation/app_router.dart';
import 'navigation/app_routes.dart';
import 'navigation/app_startup.dart';
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
  });

  final ProviderContainer? container;

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container ?? appProviderContainer,
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final onboardingState = ref.watch(onboardingCompletionProvider);
    final explicitRoute = AppStartupPolicy.resolveExplicitEntryRoute();
    String? initialRoute;

    if (explicitRoute != null) {
      initialRoute = explicitRoute;
    } else if (authState.isLoading || onboardingState.isLoading) {
      initialRoute = null;
    } else if (authState.hasError || onboardingState.hasError) {
      initialRoute = AppRoutes.login;
    } else {
      final session = authState.valueOrNull;
      final startupState = onboardingState.valueOrNull ??
          const OnboardingPreferencesState(
            onboardingCompleted: false,
            continueAsGuest: false,
            showOnboardingOnSignedOutEntry: false,
          );
      initialRoute = AppStartupPolicy.resolveRoute(
        isAuthenticated: session != null,
        onboardingState: startupState,
      );
    }

    return MaterialApp(
      key: ValueKey(initialRoute ?? 'auth-loading'),
      title: 'Believers Lens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: initialRoute == null ? const _AuthLoadingScreen() : null,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

final onboardingCompletionProvider =
    FutureProvider<OnboardingPreferencesState>((ref) async {
  return OnboardingPreferencesService().loadState();
});

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
