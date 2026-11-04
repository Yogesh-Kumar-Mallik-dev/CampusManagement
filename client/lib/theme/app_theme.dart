import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Global Theme Controller for smooth 60fps/120fps animated transitions
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

  static void toggleTheme() {
    themeModeNotifier.value =
        themeModeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  // Smooth 60fps/120fps Theme Transition Constants
  static const Duration themeAnimationDuration = Duration(milliseconds: 300);
  static const Curve themeAnimationCurve = Curves.easeInOutCubic;

  // Enterprise Modern Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.wineRed,
        onPrimary: Colors.white,
        primaryContainer: AppColors.wineRedSubtle,
        onPrimaryContainer: AppColors.wineRedDark,
        secondary: AppColors.githubGreen,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.githubGreenSubtle,
        onSecondaryContainer: AppColors.githubGreenText,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.statusRed,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
          letterSpacing: -0.2,
        ),
        shape: Border(
          bottom: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.wineRed,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(inherit: false, fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.wineRed,
          side: const BorderSide(color: AppColors.wineRed, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(inherit: false, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedColor: AppColors.wineRedSubtle,
        elevation: 0,
        pressElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        labelStyle: const TextStyle(inherit: false, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.wineRed, width: 1),
        ),
        labelStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.lightBorder, width: 1),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedIconTheme: IconThemeData(color: AppColors.wineRed),
        unselectedIconTheme: IconThemeData(color: AppColors.lightTextMuted),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.wineRed,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.lightTextMuted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        indicatorColor: AppColors.wineRedSubtle,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.wineRed,
        unselectedItemColor: AppColors.lightTextMuted,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Enterprise Modern Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.wineRedLight,
        onPrimary: Colors.white,
        primaryContainer: AppColors.wineRedDark,
        onPrimaryContainer: Colors.white,
        secondary: AppColors.githubGreenHover,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFF1B4725),
        onSecondaryContainer: Colors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.statusRed,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.2,
        ),
        shape: Border(
          bottom: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.wineRed,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(inherit: false, fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.wineRedLight,
          side: const BorderSide(color: AppColors.wineRedDarkBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(inherit: false, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.wineRedDark,
        elevation: 0,
        pressElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        labelStyle: const TextStyle(inherit: false, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.wineRedDarkText, width: 1),
        ),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.darkBorder, width: 1),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedIconTheme: IconThemeData(color: AppColors.wineRedLight),
        unselectedIconTheme: IconThemeData(color: AppColors.darkTextMuted),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.wineRedLight,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.darkTextMuted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        indicatorColor: AppColors.wineRedDark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.wineRedLight,
        unselectedItemColor: AppColors.darkTextMuted,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
