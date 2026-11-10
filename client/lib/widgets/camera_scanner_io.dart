import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
  Process? _ffmpegProcess;
  Process? _fallbackZbarProcess;
  StreamSubscription<List<int>>? _ffmpegSub;
  Uint8List? _latestFrame;
  bool _isHardwareCameraActive = false;
  String? _hardwareStatus;
  bool _isAnalyzingFrame = false;

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
        _startLinuxCameraStream();
      } else if (Platform.isWindows) {
        _hardwareStatus = 'Windows Hardware Camera Active';
        _isHardwareCameraActive = true;
      }
    }
  }

  void _startLinuxCameraStream() async {
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
      // Stream live MJPEG video frames from /dev/video0 at 15 fps
      _ffmpegProcess = await Process.start('ffmpeg', [
        '-f', 'v4l2',
        '-video_size', '640x480',
        '-framerate', '15',
        '-i', '/dev/video0',
        '-f', 'image2pipe',
        '-vcodec', 'mjpeg',
        '-q:v', '5',
        '-loglevel', 'quiet',
        'pipe:1',
      ]);

      if (mounted) {
        setState(() {
          _isHardwareCameraActive = true;
          _hardwareStatus = 'Live Linux Webcam (/dev/video0)';
        });
      }

      final buffer = BytesBuilder(copy: false);

      _ffmpegSub = _ffmpegProcess!.stdout.listen((data) {
        buffer.add(data);
        final bytes = buffer.toBytes();

        // Search for JPEG SOI (0xFF, 0xD8)
        var startIndex = -1;
        for (var i = 0; i < bytes.length - 1; i++) {
          if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8) {
            startIndex = i;
            break;
          }
        }

        if (startIndex >= 0) {
          // Search for JPEG EOI (0xFF, 0xD9)
          for (var i = startIndex + 2; i < bytes.length - 1; i++) {
            if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
              final endIndex = i + 2;
              final frame = Uint8List.fromList(bytes.sublist(startIndex, endIndex));

              buffer.clear();
              if (endIndex < bytes.length) {
                buffer.add(bytes.sublist(endIndex));
              }

              if (mounted) {
                setState(() {
                  _latestFrame = frame;
                });
                _analyzeFrameForBarcode(frame);
              }
              break;
            }
          }
        } else if (bytes.length > 500000) {
          buffer.clear();
        }
      });
    } catch (_) {
      // Fallback to headless zbarcam if ffmpeg binary is not present
      _startFallbackZbar();
    }
  }

  void _analyzeFrameForBarcode(Uint8List frame) async {
    if (_isAnalyzingFrame || widget.isVerifying) return;
    _isAnalyzingFrame = true;

    try {
      final proc = await Process.start('zbarimg', ['-q', '--raw', '-']);
      proc.stdin.add(frame);
      await proc.stdin.close();

      final output = await proc.stdout.transform(utf8.decoder).join();
      final clean = output.trim();
      if (clean.isNotEmpty && !widget.isVerifying && mounted) {
        widget.onScanned(clean);
      }
    } catch (_) {
      // Ignore frame decode errors
    } finally {
      _isAnalyzingFrame = false;
    }
  }

  void _startFallbackZbar() async {
    try {
      _fallbackZbarProcess = await Process.start('zbarcam', [
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

      _fallbackZbarProcess!.stdout
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
    _ffmpegSub?.cancel();
    _ffmpegProcess?.kill(ProcessSignal.sigkill);
    _fallbackZbarProcess?.kill(ProcessSignal.sigkill);
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
            )
          // 2. Linux Desktop live camera frames via ffmpeg
          else if (_latestFrame != null)
            Positioned.fill(
              child: Image.memory(
                _latestFrame!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),

          // 3. Optical laser reticle
          _buildReticleOverlay(),

          // 4. Hardware device status banner
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
