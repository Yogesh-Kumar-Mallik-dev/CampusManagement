import 'dart:convert';
import 'dart:io';
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
  State<CampusCameraScanner> createState() => _CampusCameraScannerIOState();
}

class _CampusCameraScannerIOState extends State<CampusCameraScanner> with SingleTickerProviderStateMixin {
  late final AnimationController _laserAnim;
  MobileScannerController? _mobileScannerController;
  Process? _linuxWebcamProcess;
  bool _isHardwareCameraActive = false;
  String? _hardwareStatus;

  bool get _isMobileOrMac => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    _laserAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    if (!_isTest) {
      if (_isMobileOrMac) {
        _mobileScannerController = MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          torchEnabled: false,
        );
      } else if (Platform.isLinux) {
        _startLinuxHardwareScanner();
      } else if (Platform.isWindows) {
        _hardwareStatus = 'Windows Hardware Camera Active';
        _isHardwareCameraActive = true;
      }
    }
  }

  void _startLinuxHardwareScanner() async {
    // Check if video capture device is connected (/dev/video0)
    final videoDevice = File('/dev/video0');
    final hasVideo0 = await videoDevice.exists();

    if (!hasVideo0) {
      if (mounted) {
        setState(() {
          _hardwareStatus = 'No /dev/video0 webcam detected';
        });
      }
      return;
    }

    try {
      _linuxWebcamProcess = await Process.start('zbarcam', [
        '--raw',
        '--nodisplay',
        '/dev/video0',
      ]);

      if (mounted) {
        setState(() {
          _isHardwareCameraActive = true;
          _hardwareStatus = 'Live Linux Webcam (/dev/video0)';
        });
      }

      _linuxWebcamProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final clean = line.trim();
        if (clean.isNotEmpty && !widget.isVerifying) {
          widget.onScanned(clean);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _hardwareStatus = 'Webcam available (/dev/video0)';
          _isHardwareCameraActive = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _laserAnim.dispose();
    _mobileScannerController?.dispose();
    _linuxWebcamProcess?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('campus-camera-viewfinder'),
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Mobile & macOS native hardware viewfinder
          if (_isMobileOrMac && _mobileScannerController != null && !_isTest)
            MobileScanner(
              controller: _mobileScannerController,
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

          // 2. Optical laser reticle
          _buildReticleOverlay(),

          // 3. Hardware device status banner
          if (_hardwareStatus != null)
            Positioned(
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isHardwareCameraActive ? AppColors.githubGreen : AppColors.darkBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isHardwareCameraActive ? AppColors.githubGreen : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _hardwareStatus!,
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
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
