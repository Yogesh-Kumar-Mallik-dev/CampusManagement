import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'circular_theme_reveal.dart';

/// Ultra-smooth animated theme toggle button.
///
/// Features:
/// 1. Rotating and scaling sun/moon icon transition.
/// 2. Telegram-style circular reveal expanding from button coordinates.
/// 3. Synchronized with [AppTheme.themeModeNotifier].
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
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
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
          onPressed: () async {
            final box = context.findRenderObject() as RenderBox?;
            final Offset center;
            if (box != null && box.hasSize) {
              center = box.localToGlobal(box.size.center(Offset.zero));
            } else {
              center = Offset(MediaQuery.of(context).size.width - 40, 40);
            }

            final reveal = CircularThemeReveal.of(context);
            if (reveal != null) {
              await reveal.startTransition(
                center: center,
                isNextDark: !isDark,
                onThemeChange: () {
                  AppTheme.toggleTheme();
                },
              );
            } else {
              AppTheme.toggleTheme();
            }
          },
        );
      },
    );
  }
}
