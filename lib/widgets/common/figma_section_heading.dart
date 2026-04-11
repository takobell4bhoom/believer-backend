import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

class FigmaSectionHeading extends StatelessWidget {
  const FigmaSectionHeading({
    super.key,
    required this.title,
    this.showDivider = false,
    this.style = AppTypography.homeSectionLabel,
    this.dividerColor = AppColors.lineStrong,
    this.dividerThickness = 1,
    this.gap = 8,
  });

  final String title;
  final bool showDivider;
  final TextStyle style;
  final Color dividerColor;
  final double dividerThickness;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!showDivider) {
      return Text(title, style: style);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Divider(
            color: dividerColor,
            thickness: dividerThickness,
            height: dividerThickness,
          ),
        ),
      ],
    );
  }
}
