import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

class AppTopNavBar extends StatelessWidget {
  const AppTopNavBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onLeadingTap,
    this.leadingIcon = Icons.arrow_back_rounded,
    this.trailing,
    this.showLeading = true,
    this.centerTitle = true,
    this.bottom,
    this.bottomSpacing = AppSpacing.md,
    this.padding = const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, 0),
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onLeadingTap;
  final IconData leadingIcon;
  final Widget? trailing;
  final bool showLeading;
  final bool centerTitle;
  final Widget? bottom;
  final double bottomSpacing;
  final EdgeInsetsGeometry padding;

  static const double _controlSize = 44;

  @override
  Widget build(BuildContext context) {
    final titleTheme = Theme.of(context).textTheme.headlineMedium;
    final subtitleTheme = Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              showLeading
                  ? IconButton(
                      onPressed: onLeadingTap ??
                          () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        leadingIcon,
                        size: 30,
                        color: AppColors.primaryText,
                      ),
                      splashRadius: 22,
                      constraints: const BoxConstraints.tightFor(
                        width: _controlSize,
                        height: _controlSize,
                      ),
                      padding: EdgeInsets.zero,
                    )
                  : const SizedBox(width: _controlSize, height: _controlSize),
              Expanded(
                child: Column(
                  crossAxisAlignment: centerTitle
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign:
                          centerTitle ? TextAlign.center : TextAlign.left,
                      style: titleTheme?.copyWith(
                        fontFamily: 'Figtree',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            centerTitle ? TextAlign.center : TextAlign.left,
                        style: subtitleTheme?.copyWith(
                          fontFamily: 'Figtree',
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: _controlSize,
                height: _controlSize,
                child: trailing ?? const SizedBox.shrink(),
              ),
            ],
          ),
          if (bottom != null) ...[
            SizedBox(height: bottomSpacing),
            bottom!,
          ],
        ],
      ),
    );
  }
}
