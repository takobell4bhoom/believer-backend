import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../navigation/app_routes.dart';
import '../services/onboarding_preferences_service.dart';
import '../theme/app_colors.dart';
import 'location_setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.onLoginOrSignup,
    this.onExploreAsGuest,
    this.onboardingPreferencesService,
    this.splashDuration = const Duration(milliseconds: 1400),
  });

  final VoidCallback? onLoginOrSignup;
  final VoidCallback? onExploreAsGuest;
  final OnboardingPreferencesService? onboardingPreferencesService;
  final Duration splashDuration;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const double _designWidth = 384;
  static const double _designHeight = 768;

  Timer? _splashTimer;
  bool _showSplash = true;
  int _pageIndex = 0;
  late final OnboardingPreferencesService _onboardingPreferencesService;

  static const List<String> _pageAssets = <String>[
    'assets/images/onboarding/onboarding_1.png',
    'assets/images/onboarding/onboarding_2.png',
    'assets/images/onboarding/onboarding_3.png',
  ];

  @override
  void initState() {
    super.initState();
    _onboardingPreferencesService =
        widget.onboardingPreferencesService ?? OnboardingPreferencesService();
    _splashTimer = Timer(widget.splashDuration, _finishSplash);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  void _finishSplash() {
    if (!mounted || !_showSplash) {
      return;
    }
    setState(() => _showSplash = false);
  }

  void _goToNextPage() {
    if (_pageIndex >= _pageAssets.length - 1) {
      return;
    }
    setState(() => _pageIndex += 1);
  }

  Future<void> _openLoginOrSignup() async {
    await _onboardingPreferencesService.markAuthEntryPreferred();
    if (!mounted) {
      return;
    }

    if (widget.onLoginOrSignup != null) {
      widget.onLoginOrSignup!.call();
      return;
    }

    Navigator.of(context).pushNamed(AppRoutes.login);
  }

  Future<void> _exploreAsGuest() async {
    await _onboardingPreferencesService.markGuestReturnPreferred();
    if (!mounted) {
      return;
    }

    if (widget.onExploreAsGuest != null) {
      widget.onExploreAsGuest!.call();
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.locationSetup,
      arguments: const LocationSetupFlowArgs(
        nextRoute: AppRoutes.home,
        clearStackOnComplete: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final availableHeight = constraints.maxHeight;
            final frameScale = math.min(
              availableWidth / _designWidth,
              availableHeight / _designHeight,
            );
            final frameWidth = _designWidth * frameScale;
            final frameHeight = _designHeight * frameScale;

            return Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: _showSplash
                    ? _OnboardingFrame(
                        key: const ValueKey('splash-frame'),
                        width: frameWidth,
                        height: frameHeight,
                        imageAsset:
                            'assets/images/onboarding/splash_screen.png',
                      )
                    : _OnboardingFlowFrame(
                        key: ValueKey('onboarding-page-$_pageIndex'),
                        width: frameWidth,
                        height: frameHeight,
                        imageAsset: _pageAssets[_pageIndex],
                        pageIndex: _pageIndex,
                        onNext: _goToNextPage,
                        onLoginOrSignup: _openLoginOrSignup,
                        onExploreAsGuest: _exploreAsGuest,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingFrame extends StatelessWidget {
  const _OnboardingFrame({
    super.key,
    required this.width,
    required this.height,
    required this.imageAsset,
  });

  final double width;
  final double height;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        imageAsset,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _OnboardingFlowFrame extends StatelessWidget {
  const _OnboardingFlowFrame({
    super.key,
    required this.width,
    required this.height,
    required this.imageAsset,
    required this.pageIndex,
    required this.onNext,
    required this.onLoginOrSignup,
    required this.onExploreAsGuest,
  });

  final double width;
  final double height;
  final String imageAsset;
  final int pageIndex;
  final VoidCallback onNext;
  final VoidCallback onLoginOrSignup;
  final VoidCallback onExploreAsGuest;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              imageAsset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
          if (pageIndex < 2)
            _OverlayButtonRegion(
              key: Key('onboarding-next-$pageIndex'),
              semanticsLabel: 'Next',
              frameWidth: width,
              frameHeight: height,
              left: 34 / 384,
              top: 623 / 768,
              width: 316 / 384,
              height: 44 / 768,
              onTap: onNext,
            ),
          if (pageIndex == 2) ...[
            _OverlayButtonRegion(
              key: const Key('onboarding-login-signup'),
              semanticsLabel: 'Log In or Sign Up',
              frameWidth: width,
              frameHeight: height,
              left: 34 / 384,
              top: 623 / 768,
              width: 316 / 384,
              height: 44 / 768,
              onTap: onLoginOrSignup,
            ),
            _OverlayButtonRegion(
              key: const Key('onboarding-explore-guest'),
              semanticsLabel: 'Explore as Guest',
              frameWidth: width,
              frameHeight: height,
              left: 104 / 384,
              top: 685 / 768,
              width: 176 / 384,
              height: 34 / 768,
              onTap: onExploreAsGuest,
            ),
          ],
        ],
      ),
    );
  }
}

class _OverlayButtonRegion extends StatelessWidget {
  const _OverlayButtonRegion({
    super.key,
    required this.semanticsLabel,
    required this.frameWidth,
    required this.frameHeight,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String semanticsLabel;
  final double frameWidth;
  final double frameHeight;
  final double left;
  final double top;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: frameWidth * left,
      top: frameHeight * top,
      width: frameWidth * width,
      height: frameHeight * height,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.white.withValues(alpha: 0.08),
            highlightColor: Colors.transparent,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
