import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    this.bottomNavigation,
    this.topNavBar,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final Widget? bottomNavigation;
  final PreferredSizeWidget? topNavBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: topNavBar,
      bottomNavigationBar: bottomNavigation,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
