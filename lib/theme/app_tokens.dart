import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 30;
}

class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;
  static const double figma12 = 12.0; // Figma Corner-12 token
}

class AppTypography {
  static const String figtreeFamily = 'Figtree';
  static const String prozaLibreFamily = 'Proza Libre';

  static const TextStyle homeSectionLabel = TextStyle(
    fontFamily: prozaLibreFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.8,
    color: AppColors.primaryText,
  );

  static const TextStyle figtreeSectionHeading = TextStyle(
    fontFamily: figtreeFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 4,
    color: AppColors.primaryText,
  );

  static const TextStyle figtreeSectionHeadingCompact = TextStyle(
    fontFamily: figtreeFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 4,
    color: AppColors.primaryText,
  );

  static const TextStyle filterChip = TextStyle(
    fontFamily: figtreeFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    color: Color(0xFF5E675E),
  );

  static const TextStyle filterChipSelected = TextStyle(
    fontFamily: figtreeFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFF5E675E),
  );

  static const TextStyle outlineAction = TextStyle(
    fontFamily: figtreeFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFF556056),
  );

  static const TextStyle compactChip = TextStyle(
    fontFamily: figtreeFamily,
    fontSize: 9,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  static const TextStyle actionButton = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
}
