import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Ultra-smooth 60/120fps animated theme toggle button with circular reveal.
///
/// Triggers global theme transition using [ThemeSwitcher] with an animated
/// rotating/scaling sun/moon transition and circular reveal clip.
class SmoothThemeToggle extends StatelessWidget {
  const SmoothThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher.withTheme(
      builder: (context, switcher, theme) {
        final isDark = theme.brightness == Brightness.dark;
        return IconButton(
          tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween<double>(begin: 0.75, end: 1.0).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              key: ValueKey<bool>(isDark),
              size: 20,
              color: isDark ? const Color(0xFFF0883E) : AppColors.wineRed,
            ),
          ),
          onPressed: () {
            final nextTheme = isDark ? AppTheme.lightTheme : AppTheme.darkTheme;
            AppTheme.themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            switcher.changeTheme(theme: nextTheme);
          },
        );
      },
    );
  }
}
