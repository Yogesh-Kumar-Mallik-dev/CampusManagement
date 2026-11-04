import 'package:flutter/material.dart';

/// Institutional AppLogo component.
/// Renders the authentic logo in ultra-high definition using Flutter's GPU-accelerated
/// bicubic texture pipeline (`FilterQuality.high`).
///
/// Seamlessly adapts to Light and Dark modes with clean alpha transparency,
/// preventing the logo from glowing like a harsh sticker in dark themes.
class AppLogo extends StatelessWidget {
  final double? height;
  final double? width;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.height = 40,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      isDark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}
