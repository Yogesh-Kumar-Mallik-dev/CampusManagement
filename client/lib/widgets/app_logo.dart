import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Institutional AppLogo component for CampusOS.
/// Renders `logo.svg` adapted dynamically for both Light and Dark modes.
class AppLogo extends StatelessWidget {
  final double size;
  final bool withFrame;
  final BorderRadius? borderRadius;

  const AppLogo({
    super.key,
    this.size = 28,
    this.withFrame = true,
    this.borderRadius,
  });

  // Invert RGB channels while preserving alpha transparency for dark mode
  static const List<double> _darkModeInvertMatrix = <double>[
    -1,  0,  0, 0, 255, // Red
     0, -1,  0, 0, 255, // Green
     0,  0, -1, 0, 255, // Blue
     0,  0,  0, 1,   0, // Alpha
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(6);

    Widget svgImage = SvgPicture.asset(
      'assets/images/logo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    // In dark mode, invert dark contours so strokes are luminous white (#FFFFFF)
    if (isDark) {
      svgImage = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_darkModeInvertMatrix),
        child: svgImage,
      );
    }

    if (!withFrame) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: svgImage),
      );
    }

    return AnimatedContainer(
      duration: AppTheme.themeAnimationDuration,
      curve: AppTheme.themeAnimationCurve,
      width: size + 6,
      height: size + 6,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: radius,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Center(child: svgImage),
    );
  }
}
