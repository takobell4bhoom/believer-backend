import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class FigmaSwitch extends StatelessWidget {
  const FigmaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.width = 48,
    this.height = 20,
    this.thumbSize = 20,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final double width;
  final double height;
  final double thumbSize;

  @override
  Widget build(BuildContext context) {
    var trackColor = value ? const Color(0xFFB1C9BE) : const Color(0xFFCBCDCC);
    var thumbColor = value ? AppColors.accentSoft : AppColors.disabled;

    if (!enabled || onChanged == null) {
      trackColor = trackColor.withValues(alpha: 0.65);
      thumbColor = thumbColor.withValues(alpha: 0.65);
    }

    return GestureDetector(
      onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(
              color: thumbColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
