import 'package:flutter/material.dart';

/// Institutional AppLogo component.
/// Renders the logo in ultra-high definition using Flutter's GPU-accelerated
/// bicubic texture pipeline (`FilterQuality.high`), eliminating the software
/// downsampling blur caused by SVG raster wrappers.
class AppLogo extends StatelessWidget {
  final double? height;
  final double? width;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.height = 42,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}
