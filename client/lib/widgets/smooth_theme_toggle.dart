import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Ultra-smooth 60/120fps animated theme toggle button.
///
/// Triggers global [AppTheme.toggleTheme] with an animated rotating/scaling
/// sun/moon transition and hardware-accelerated color interpolation.
class SmoothThemeToggle extends StatelessWidget {
  const SmoothThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
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
          onPressed: () => AppTheme.toggleTheme(),
        );
      },
    );
  }
}
