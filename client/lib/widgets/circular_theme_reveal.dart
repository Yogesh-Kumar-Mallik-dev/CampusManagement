import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Ultra-smooth Telegram-style circular theme reveal transition.
///
/// Captures a snapshot of the current theme, mounts it in an isolated overlay
/// layer, triggers the underlying theme change, and animates an expanding
/// circular cut-out using [BlendMode.dstOut] originating from the tap coordinates.
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
  final GlobalKey _repaintKey = GlobalKey();
  late final AnimationController _controller;
  late final Animation<double> _animation;

  ui.Image? _snapshot;
  Offset? _center;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  /// Initiates the circular theme reveal from [center].
  Future<void> startTransition({
    required Offset center,
    required bool isNextDark,
    required VoidCallback onThemeChange,
  }) async {
    if (_isAnimating) return;

    final captured = await _captureSnapshot();
    if (captured == null) {
      // Fallback: apply theme switch immediately if snapshot unavailable
      onThemeChange();
      return;
    }

    if (!mounted) {
      captured.dispose();
      return;
    }

    setState(() {
      _snapshot = captured;
      _center = center;
      _isAnimating = true;
    });

    // Wait until the overlay paints the captured snapshot
    await WidgetsBinding.instance.endOfFrame;

    // Change theme underneath while the old snapshot completely covers the screen
    onThemeChange();

    // Allow the new theme to lay out underneath the overlay
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    // Animate the expanding circular reveal from the tap coordinates
    await _controller.forward(from: 0.0);

    if (mounted) {
      setState(() {
        _isAnimating = false;
        _snapshot?.dispose();
        _snapshot = null;
        _center = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.reset();
        }
      });
    }
  }

  Future<ui.Image?> _captureSnapshot() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      if (boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
      }

      if (!mounted) return null;

      // Capture at 1.0 scale: instantaneous GPU copy with zero frame drops
      final image = await boundary.toImage(pixelRatio: 1.0);
      return image;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Underlying application
        RepaintBoundary(
          key: _repaintKey,
          child: widget.child,
        ),

        // Transition overlay with BlendMode.dstOut circular cutout
        if (_isAnimating && _snapshot != null && _center != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CircularRevealPainter(
                      image: _snapshot!,
                      center: _center!,
                      progress: _animation.value,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _CircularRevealPainter extends CustomPainter {
  final ui.Image image;
  final Offset center;
  final double progress;

  _CircularRevealPainter({
    required this.image,
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double maxRadius = _calculateMaxRadius(center, size);
    final double currentRadius = maxRadius * progress;

    final Rect fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Isolated offscreen compositing layer
    canvas.saveLayer(fullRect, Paint());

    // 1. Paint the previous theme snapshot across the entire viewport
    final Rect imageRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, imageRect, fullRect, Paint());

    // 2. Erase an expanding circular hole through the snapshot to reveal the new theme underneath
    final Paint clearPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, currentRadius, clearPaint);

    // Restore layer to screen canvas
    canvas.restore();
  }

  double _calculateMaxRadius(Offset center, Size size) {
    final double d1 = center.distance;
    final double d2 = (center - Offset(size.width, 0)).distance;
    final double d3 = (center - Offset(0, size.height)).distance;
    final double d4 = (center - Offset(size.width, size.height)).distance;
    return math.max(math.max(d1, d2), math.max(d3, d4));
  }

  @override
  bool shouldRepaint(_CircularRevealPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
