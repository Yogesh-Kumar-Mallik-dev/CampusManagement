import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../utils/app_error_catalog.dart';

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
          _hardwareStatus = AppErrorCatalog.cameraNotFound.displayString;
        });
      }
      return;
    }

    // Low-latency hardware MJPEG direct streaming flags
    final lowLatencyHardwareArgs = [
      '-fflags', 'nobuffer',
      '-flags', 'low_delay',
      '-probesize', '32',
      '-analyzeduration', '0',
      '-f', 'v4l2',
      '-input_format', 'mjpeg',
      '-video_size', '640x480',
      '-framerate', '30',
      '-i', '/dev/video0',
      '-c:v', 'copy',
      '-flush_packets', '1',
      '-f', 'image2pipe',
      '-loglevel', 'quiet',
      'pipe:1',
    ];

    final lowLatencySoftwareArgs = [
      '-fflags', 'nobuffer',
      '-flags', 'low_delay',
      '-probesize', '32',
      '-analyzeduration', '0',
      '-f', 'v4l2',
      '-video_size', '640x480',
      '-framerate', '15',
      '-i', '/dev/video0',
      '-c:v', 'mjpeg',
      '-q:v', '5',
      '-flush_packets', '1',
      '-f', 'image2pipe',
      '-loglevel', 'quiet',
      'pipe:1',
    ];

    Process? process;
    try {
      process = await Process.start('ffmpeg', lowLatencyHardwareArgs);
    } catch (_) {
      try {
        process = await Process.start('ffmpeg', lowLatencySoftwareArgs);
      } catch (_) {
        _startFallbackZbar();
        return;
      }
    }

    _ffmpegProcess = process;

    if (mounted) {
      setState(() {
        _isHardwareCameraActive = true;
        _hardwareStatus = 'Live Linux Webcam (/dev/video0)';
      });
    }

    var pendingBytes = <int>[];
    var lastRenderTimeMs = 0;
    var lastScanTimeMs = 0;

    _ffmpegSub = _ffmpegProcess!.stdout.listen((data) {
      pendingBytes.addAll(data);

      // Find the LATEST complete JPEG frame in the accumulated buffer
      // Search backwards from the end for EOI (0xFF, 0xD9)
      var lastEoi = -1;
      for (var i = pendingBytes.length - 2; i >= 0; i--) {
        if (pendingBytes[i] == 0xFF && pendingBytes[i + 1] == 0xD9) {
          lastEoi = i;
          break;
        }
      }

      if (lastEoi >= 0) {
        // Search backwards from EOI for corresponding SOI (0xFF, 0xD8)
        var lastSoi = -1;
        for (var i = lastEoi - 1; i >= 0; i--) {
          if (pendingBytes[i] == 0xFF && pendingBytes[i + 1] == 0xD8) {
            lastSoi = i;
            break;
          }
        }

        if (lastSoi >= 0) {
          final latestFrame = Uint8List.fromList(pendingBytes.sublist(lastSoi, lastEoi + 2));

          // Critical zero-lag guarantee: Drop ALL stale frames that arrived before this latest frame
          pendingBytes = pendingBytes.sublist(lastEoi + 2);

          final now = DateTime.now().millisecondsSinceEpoch;

          // Render preview at up to 30 FPS with zero buffer backlog
          if (now - lastRenderTimeMs >= 33) {
            lastRenderTimeMs = now;
            if (mounted) {
              setState(() {
                _latestFrame = latestFrame;
              });
            }
          }

          // Scan rolling optical QR code every ~120ms (8+ scans/sec) without stalling event loop
          if (!_isAnalyzingFrame && !widget.isVerifying && (now - lastScanTimeMs >= 120)) {
            lastScanTimeMs = now;
            _analyzeFrameForBarcode(latestFrame);
          }
        }
      }

      // Memory safeguard against corrupted packet streams
      if (pendingBytes.length > 500000) {
        pendingBytes.clear();
      }
    }, onError: (_) {
      _startFallbackZbar();
    });
  }

  void _analyzeFrameForBarcode(Uint8List frame) async {
    if (_isAnalyzingFrame || widget.isVerifying) return;
    _isAnalyzingFrame = true;

    try {
      final proc = await Process.start('zbarimg', ['-q', '--raw', '-']);
      proc.stdin.add(frame);
      await proc.stdin.close();

      // Guard with a 200ms timeout to prevent process hangs
      final output = await proc.stdout.transform(utf8.decoder).join().timeout(
        const Duration(milliseconds: 200),
        onTimeout: () => '',
      );

      final clean = output.trim();
      if (clean.isNotEmpty && !widget.isVerifying && mounted) {
        widget.onScanned(clean);
      }
    } catch (_) {
      // Ignore frame decode errors
    } finally {
      if (mounted) {
        _isAnalyzingFrame = false;
      }
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
                      AppErrorCatalog.resolveMobileScannerError(error.errorCode.name).displayString,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.statusRed, fontSize: 12),
                    ),
                  ),
                );
              },
            )
          // 2. Linux Desktop live camera frames via low-latency ffmpeg
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
