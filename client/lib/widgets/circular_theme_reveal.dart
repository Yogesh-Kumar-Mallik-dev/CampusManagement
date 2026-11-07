import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// High-performance Telegram-style circular clip reveal theme transition.
///
/// Captures a zero-delay synchronous raster snapshot [toImageSync] of the
/// previous theme and animates an expanding circular clip of the new theme
/// from the exact touch/button coordinates across the entire viewport.
class CircularThemeReveal extends StatefulWidget {
  final Widget child;

  const CircularThemeReveal({super.key, required this.child});

  static CircularThemeRevealState? of(BuildContext context) {
    return context.findAncestorStateOfType<CircularThemeRevealState>();
  }

  @override
  State<CircularThemeReveal> createState() => CircularThemeRevealState();
}

class CircularThemeRevealState extends State<CircularThemeReveal>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  ui.Image? _oldImage;
  Offset _center = Offset.zero;
  bool _isNextDark = false;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _oldImage?.dispose();
    super.dispose();
  }

  /// Triggers the zero-lag circular reveal animation from [center].
  void revealTheme(Offset center, VoidCallback onThemeChange) {
    if (_controller.isAnimating) return;

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null && !boundary.debugNeedsPaint) {
        _oldImage = boundary.toImageSync();
        _center = center;
      }
    } catch (_) {
      _oldImage = null;
    }

    _isNextDark = AppTheme.themeModeNotifier.value != ThemeMode.dark;

    // Toggle theme immediately
    onThemeChange();

    if (_oldImage != null) {
      _controller.forward(from: 0.0).then((_) {
        _oldImage?.dispose();
        _oldImage = null;
        if (mounted) setState(() {});
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // If transitioning, display the static snapshot of the previous theme underneath
          if (_oldImage != null)
            Positioned.fill(
              child: RawImage(
                image: _oldImage,
                fit: BoxFit.cover,
              ),
            ),

          // If transitioning, clip the new theme in an expanding circular mask
          if (_oldImage != null)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final screenSize = MediaQuery.of(context).size;
                final maxRadius = math.sqrt(
                  math.pow(math.max(_center.dx, screenSize.width - _center.dx), 2) +
                      math.pow(math.max(_center.dy, screenSize.height - _center.dy), 2),
                );
                final currentRadius = _animation.value * maxRadius;
                final ringColor = _isNextDark
                    ? const Color(0xFFF0883E)
                    : AppColors.wineRed;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipPath(
                      clipper: _CircularRevealClipper(
                        center: _center,
                        radius: currentRadius,
                      ),
                      child: child,
                    ),
                    // Crisp glowing wavefront ring at leading edge of circular reveal
                    CustomPaint(
                      size: screenSize,
                      painter: _CircularEdgeRingPainter(
                        center: _center,
                        radius: currentRadius,
                        color: ringColor.withValues(
                          alpha: (1.0 - _animation.value).clamp(0.2, 0.8),
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: widget.child,
            )
          else
            widget.child,
        ],
      ),
    );
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _CircularRevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.center != center;
}

class _CircularEdgeRingPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;

  _CircularEdgeRingPainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_CircularEdgeRingPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}
