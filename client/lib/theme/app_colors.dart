import 'package:flutter/material.dart';

class BadgeStyle {
  final Color background;
  final Color border;
  final Color text;

  const BadgeStyle({
    required this.background,
    required this.border,
    required this.text,
  });
}

class AppColors {
  // Primary: Wine Red (Institutional Burgundy)
  static const Color wineRed = Color(0xFF7A1C30);
  static const Color wineRedDark = Color(0xFF581120);
  static const Color wineRedLight = Color(0xFF96243D);
  static const Color wineRedSubtle = Color(0xFFFDF2F4);
  static const Color wineRedBorder = Color(0xFFF1D1D8);

  // Dark mode specific wine red badge colors (high contrast & distinguishable)
  static const Color wineRedDarkSubtle = Color(0xFF38121A);
  static const Color wineRedDarkBorder = Color(0xFF5C1B28);
  static const Color wineRedDarkText = Color(0xFFFF94A6);

  // Accent: GitHub Green & Blue
  static const Color githubGreen = Color(0xFF238636);
  static const Color githubGreenHover = Color(0xFF2EA44F);
  static const Color githubGreenSubtle = Color(0xFFE6F7EC);
  static const Color githubGreenText = Color(0xFF1A7F37);
  static const Color githubGreenBorder = Color(0xFFBCE7C6);
  static const Color githubBlue = Color(0xFF0969DA);

  // Dark mode specific green badge colors
  static const Color githubGreenDarkSubtle = Color(0xFF112A1A);
  static const Color githubGreenDarkBorder = Color(0xFF1C4C2B);
  static const Color githubGreenDarkText = Color(0xFF4AC26B);

  // Enterprise Status Colors
  static const Color statusAmber = Color(0xFFD29922);
  static const Color statusYellow = Color(0xFF9A6700);
  static const Color statusYellowSubtle = Color(0xFFFFF8C5);
  static const Color statusYellowBorder = Color(0xFFF6E05E);

  // Dark mode specific yellow badge colors
  static const Color statusYellowDarkSubtle = Color(0xFF2B210A);
  static const Color statusYellowDarkBorder = Color(0xFF4E3A10);
  static const Color statusYellowDarkText = Color(0xFFE3B341);

  static const Color statusRed = Color(0xFFCF222E);
  static const Color statusRedSubtle = Color(0xFFFFEBE9);
  static const Color statusRedBorder = Color(0xFFFFC1C0);

  // Dark mode specific red badge colors
  static const Color statusRedDarkSubtle = Color(0xFF38181C);
  static const Color statusRedDarkBorder = Color(0xFF5E2228);
  static const Color statusRedDarkText = Color(0xFFFF8585);

  // Light Mode Neutrals (Clean ERP Surfaces)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightBackground = lightBg;
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHover = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderHover = Color(0xFFCBD5E1);
  static const Color lightBorderSubtle = Color(0xFFEDF2F7);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF64748B);

  // Dark Mode Neutrals (GitHub Dark Dimmed)
  static const Color darkBg = Color(0xFF0D1117);
  static const Color darkBackground = darkBg;
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceHover = Color(0xFF1C2128);
  static const Color darkBorder = Color(0xFF30363D);
  static const Color darkBorderHover = Color(0xFF444C56);
  static const Color darkTextPrimary = Color(0xFFF0F6FC);
  static const Color darkTextSecondary = Color(0xFF8B949E);
  static const Color darkTextMuted = Color(0xFF6E7681);

  // Reusable Contrast Badge Styles for Light & Dark Modes
  static BadgeStyle primaryBadge(bool isDark) => BadgeStyle(
        background: isDark ? wineRedDarkSubtle : wineRedSubtle,
        border: isDark ? wineRedDarkBorder : wineRedBorder,
        text: isDark ? wineRedDarkText : wineRed,
      );

  static BadgeStyle greenBadge(bool isDark) => BadgeStyle(
        background: isDark ? githubGreenDarkSubtle : githubGreenSubtle,
        border: isDark ? githubGreenDarkBorder : githubGreenBorder,
        text: isDark ? githubGreenDarkText : githubGreenText,
      );

  static BadgeStyle yellowBadge(bool isDark) => BadgeStyle(
        background: isDark ? statusYellowDarkSubtle : statusYellowSubtle,
        border: isDark ? statusYellowDarkBorder : statusYellowBorder,
        text: isDark ? statusYellowDarkText : statusYellow,
      );

  static BadgeStyle redBadge(bool isDark) => BadgeStyle(
        background: isDark ? statusRedDarkSubtle : statusRedSubtle,
        border: isDark ? statusRedDarkBorder : statusRedBorder,
        text: isDark ? statusRedDarkText : statusRed,
      );

  static BadgeStyle blueBadge(bool isDark) => BadgeStyle(
        background: isDark ? const Color(0xFF0D253F) : const Color(0xFFEFF6FF),
        border: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE),
        text: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
      );

  static BadgeStyle neutralBadge(bool isDark) => BadgeStyle(
        background: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
        border: isDark ? darkBorder : lightBorder,
        text: isDark ? darkTextSecondary : lightTextSecondary,
      );
}
