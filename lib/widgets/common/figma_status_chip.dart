import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

class FigmaStatusChip extends StatelessWidget {
  const FigmaStatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.iconSize = 11,
    this.gap = 4,
    this.borderRadius = AppRadius.xs,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.textStyle = AppTypography.compactChip,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final double iconSize;
  final double gap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: foreground),
          SizedBox(width: gap),
          Text(
            label,
            style: textStyle.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
