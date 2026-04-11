import 'package:flutter/material.dart';

import 'app_top_nav_bar.dart';

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.bottomSpacing = 18,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return AppTopNavBar(
      title: title,
      onLeadingTap: onBack,
      trailing: trailing,
      bottom: SizedBox(height: bottomSpacing),
      bottomSpacing: 0,
    );
  }
}
