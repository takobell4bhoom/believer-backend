import 'package:flutter/material.dart';

import 'common/app_shell.dart';

class ScaffoldLayout extends StatelessWidget {
  const ScaffoldLayout({
    super.key,
    required this.child,
    this.topNavBar,
    this.bottomNavBar,
    this.maxWidth,
    this.padding,
  });

  final Widget child;
  final PreferredSizeWidget? topNavBar;
  final Widget? bottomNavBar;
  final double? maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      topNavBar: topNavBar,
      bottomNavigation: bottomNavBar,
      maxWidth: maxWidth ?? 760,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12),
      child: child,
    );
  }
}
