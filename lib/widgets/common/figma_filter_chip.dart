import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

class FigmaFilterChip extends StatelessWidget {
  const FigmaFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF3EEE6) : const Color(0xFFF7F6F2),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? const Color(0xFFC8C1B2) : const Color(0xFFD7D8D1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: selected
                ? AppTypography.filterChipSelected
                : AppTypography.filterChip,
          ),
        ),
      ),
    );
  }
}
