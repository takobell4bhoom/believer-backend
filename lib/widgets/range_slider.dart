import 'package:flutter/material.dart' as material;

import '../theme/app_colors.dart';

class RangeSlider extends material.StatelessWidget {
  const RangeSlider({
    super.key,
    required this.min,
    required this.max,
    required this.current,
    this.onChanged,
  });

  final int min;
  final int max;
  final int current;
  final material.ValueChanged<int>? onChanged;

  @override
  material.Widget build(material.BuildContext context) {
    return material.Column(
      crossAxisAlignment: material.CrossAxisAlignment.start,
      children: [
        material.Row(
          children: [
            material.Text(
              '$min mi',
              style: material.Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.secondaryText,
                  ),
            ),
            const material.Spacer(),
            material.Text(
              '$current mi',
              style: material.Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: material.FontWeight.w700,
                  ),
            ),
            const material.Spacer(),
            material.Text(
              '$max mi',
              style: material.Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.secondaryText,
                  ),
            ),
          ],
        ),
        material.SliderTheme(
          data: material.SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.line,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: material.Slider(
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            value: current.clamp(min, max).toDouble(),
            onChanged:
                onChanged == null ? null : (value) => onChanged!(value.round()),
          ),
        ),
      ],
    );
  }
}
