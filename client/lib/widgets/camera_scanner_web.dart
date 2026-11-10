import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

class CampusCameraScanner extends StatefulWidget {
  final void Function(String payload) onScanned;
  final bool isVerifying;

  const CampusCameraScanner({
    super.key,
    required this.onScanned,
    this.isVerifying = false,
  });

  @override
  State<CampusCameraScanner> createState() => _CampusCameraScannerWebState();
}

class _CampusCameraScannerWebState extends State<CampusCameraScanner> with SingleTickerProviderStateMixin {
  late final AnimationController _laserAnim;
  MobileScannerController? _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _laserAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _laserAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.4), width: 1),
        ),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSvgIcon(svgString: AppSvgIcon.alertTriangle, size: 28, color: AppColors.statusRed),
              const SizedBox(height: 10),
              Text(
                'Camera Access Blocked or Unsupported',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      key: const Key('campus-camera-viewfinder'),
      height: 280,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (widget.isVerifying) return;
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.trim().isNotEmpty) {
                  widget.onScanned(raw.trim());
                  break;
                }
              }
            },
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Camera unavailable: ${error.errorCode.name}',
                    style: const TextStyle(color: AppColors.statusRed, fontSize: 12),
                  ),
                ),
              );
            },
          ),
          _buildReticleOverlay(),
        ],
      ),
    );
  }

  Widget _buildReticleOverlay() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.githubGreen, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedBuilder(
            animation: _laserAnim,
            builder: (context, child) {
              return Align(
                alignment: Alignment(0, (_laserAnim.value * 2) - 1),
                child: Container(
                  height: 2,
                  width: double.infinity,
                  color: AppColors.githubGreen,
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvgIcon(svgString: AppSvgIcon.qrCode, size: 12, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'ALIGN RETICLE WITH CLASSROOM DISPLAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
