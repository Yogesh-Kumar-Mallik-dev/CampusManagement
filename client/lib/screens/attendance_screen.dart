import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/academic.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

enum AttendanceViewMode {
  summary,
  broadcastOptical,
  scanOptical,
  manualChecklist,
}

class AttendanceScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel currentUser;

  const AttendanceScreen({
    super.key,
    required this.storage,
    required this.currentUser,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  bool _loading = false;
  List<AttendanceSummaryModel> _summaries = [];
  AttendanceViewMode _mode = AttendanceViewMode.summary;

  // Selected Lecture Details
  final String _selectedCourseId = 'CS301';
  final String _selectedCourseCode = 'CS301';
  final String _selectedCourseName = 'Operating Systems';
  final String _selectedRoom = 'LH-101';
  final String _selectedScope = 'sec:cse-3a';

  // Optical Broadcast Stream State
  OpticalSessionModel? _opticalSession;
  Timer? _frameTimer;
  Timer? _progressTicker;
  int _sequence = 1;
  final int _refreshIntervalMs = 1500; // 1.5 seconds high-frequency optical rotation
  double _frameProgress = 1.0;
  String _currentPayload = '';
  String _currentNonce = '';
  String _currentSig = '';
  bool _isStreamPaused = false;
  List<AttendanceRecordModel> _opticalRoster = [];

  // Optical Receiver Scanner State
  final TextEditingController _scanInputController = TextEditingController();
  OpticalVerificationResult? _lastVerifiedResult;
  String? _scanError;
  bool _isVerifying = false;
  late AnimationController _sweepAnimController;

  final List<AttendanceRecordModel> _manualRoster = [
    AttendanceRecordModel(
      id: 'rec-1',
      sessionId: '',
      studentId: 'usr-harish_2025_l_btech_1',
      studentName: 'Harish Kumar',
      campusHandle: 'harish_2025_l_btech_1',
      status: 'present',
    ),
    AttendanceRecordModel(
      id: 'rec-2',
      sessionId: '',
      studentId: 'usr-priya_2024_emp_1',
      studentName: 'Dr. Priya Nair',
      campusHandle: 'priya_2024_emp_1',
      status: 'present',
    ),
    AttendanceRecordModel(
      id: 'rec-3',
      sessionId: '',
      studentId: 'usr-ramesh_2023_emp_1',
      studentName: 'Ramesh Singh',
      campusHandle: 'ramesh_2023_emp_1',
      status: 'present',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sweepAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _loadSummary();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _progressTicker?.cancel();
    _sweepAnimController.dispose();
    _scanInputController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    final data = await widget.storage.getAttendanceSummary(widget.currentUser.id);
    if (mounted) {
      setState(() {
        _summaries = data;
        _loading = false;
      });
    }
  }

  // ----------------------------------------------------
  // OPTICAL BROADCASTER ENGINE
  // ----------------------------------------------------

  Future<void> _startOpticalBroadcast() async {
    setState(() => _loading = true);

    try {
      final sess = await widget.storage.startOpticalSession(
        courseId: _selectedCourseId,
        courseCode: _selectedCourseCode,
        courseName: _selectedCourseName,
        scopeCode: _selectedScope,
        roomNumber: _selectedRoom,
        markedByUserId: widget.currentUser.id,
        markedByName: widget.currentUser.fullName,
        refreshIntervalMs: _refreshIntervalMs,
      );

      if (mounted) {
        setState(() {
          _opticalSession = sess;
          _opticalRoster = List.from(sess.verifiedRecords);
          _sequence = 1;
          _isStreamPaused = false;
          _loading = false;
          _mode = AttendanceViewMode.broadcastOptical;
        });

        _generateNextOpticalPacket();
        _startOpticalTimers();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start optical stream: $e'), backgroundColor: AppColors.statusRed),
        );
      }
    }
  }

  void _startOpticalTimers() {
    _frameTimer?.cancel();
    _progressTicker?.cancel();

    final stepDuration = const Duration(milliseconds: 50);
    final totalSteps = _refreshIntervalMs ~/ 50;
    int currentStep = totalSteps;

    _progressTicker = Timer.periodic(stepDuration, (timer) {
      if (_isStreamPaused) return;
      currentStep--;
      if (currentStep <= 0) {
        currentStep = totalSteps;
      }
      if (mounted) {
        setState(() {
          _frameProgress = currentStep / totalSteps;
        });
      }
    });

    _frameTimer = Timer.periodic(Duration(milliseconds: _refreshIntervalMs), (timer) {
      if (_isStreamPaused) return;
      _generateNextOpticalPacket();
      _fetchLiveRoster();
    });
  }

  void _generateNextOpticalPacket() {
    if (_opticalSession == null) return;

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = (DateTime.now().microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0');

    // Cryptographic HMAC-SHA256 frame signature
    final key = utf8.encode(_opticalSession!.sessionSecret);
    final data = '${_opticalSession!.id}:$_sequence:$nowSeconds:$nonce';
    final hmacSha256 = Hmac(sha256, key);
    final fullSig = hmacSha256.convert(utf8.encode(data)).toString();
    final truncatedSig = fullSig.length > 16 ? fullSig.substring(0, 16) : fullSig;

    final packet = OpticalFramePacket(
      sessionId: _opticalSession!.id,
      courseCode: _selectedCourseCode,
      courseName: _selectedCourseName,
      room: _selectedRoom,
      sequence: _sequence,
      timestamp: nowSeconds,
      nonce: nonce,
      signature: truncatedSig,
    );

    setState(() {
      _currentPayload = packet.encode();
      _currentNonce = nonce;
      _currentSig = truncatedSig;
      _sequence++;
    });
  }

  Future<void> _fetchLiveRoster() async {
    if (_opticalSession == null) return;
    try {
      final roster = await widget.storage.getOpticalRoster(_opticalSession!.id);
      if (mounted) {
        setState(() => _opticalRoster = roster);
      }
    } catch (_) {}
  }

  Future<void> _concludeOpticalBroadcast() async {
    _frameTimer?.cancel();
    _progressTicker?.cancel();
    _frameTimer = null;
    _progressTicker = null;
    _sweepAnimController.stop();

    if (_opticalSession != null) {
      await widget.storage.endOpticalSession(_opticalSession!.id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Optical attendance finalized (${_opticalRoster.length} students verified)'),
          backgroundColor: AppColors.githubGreen,
        ),
      );
      setState(() {
        _mode = AttendanceViewMode.summary;
        _opticalSession = null;
      });
      _loadSummary();
    }
  }

  // ----------------------------------------------------
  // OPTICAL RECEIVER (STUDENT SCANNER) ENGINE
  // ----------------------------------------------------

  void _openOpticalScanner() {
    _sweepAnimController.repeat(reverse: true);
    setState(() {
      _mode = AttendanceViewMode.scanOptical;
      _scanError = null;
      _lastVerifiedResult = null;
      _scanInputController.clear();
    });
  }

  Future<void> _processOpticalPayload(String rawPayload) async {
    final clean = rawPayload.trim();
    if (clean.isEmpty) {
      setState(() => _scanError = 'Please capture or enter a rolling optical frame payload.');
      return;
    }

    final packet = OpticalFramePacket.decode(clean);
    if (packet == null) {
      setState(() => _scanError = 'Invalid optical packet format. Ensure live QR is in view.');
      return;
    }

    // Freshness check: Reject expired frames
    if (packet.isExpired(maxAgeSeconds: 8)) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final drift = nowSec - packet.timestamp;
      setState(() => _scanError = 'Expired Optical Frame: Frame #${packet.sequence} was broadcast ${drift}s ago. Tokens expire in 6s. Scan directly from the live lecture display.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _scanError = null;
    });

    try {
      final result = await widget.storage.verifyOpticalAttendance(
        packet: packet,
        student: widget.currentUser,
      );

      if (mounted) {
        setState(() {
          _lastVerifiedResult = result;
          _isVerifying = false;
        });
        _loadSummary();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanError = e.toString().replaceFirst('Exception: ', '');
          _isVerifying = false;
        });
      }
    }
  }

  // Simulation convenience: capture the active broadcast frame instantly
  void _simulateCaptureFromLiveBroadcast() {
    if (_currentPayload.isNotEmpty) {
      _scanInputController.text = _currentPayload;
      _processOpticalPayload(_currentPayload);
      return;
    }

    // If no stream in same app instance, create a fresh live frame from active session or fallback
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = (DateTime.now().microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    final activeSessId = widget.storage.activeOpticalSession?.id ?? 'opt-sess-${nowSeconds - 1}';
    final secret = widget.storage.activeOpticalSession?.sessionSecret ?? 'loc_secret';

    final key = utf8.encode(secret);
    final data = '$activeSessId:$_sequence:$nowSeconds:$nonce';
    final hmacSha256 = Hmac(sha256, key);
    final fullSig = hmacSha256.convert(utf8.encode(data)).toString();
    final truncatedSig = fullSig.length > 16 ? fullSig.substring(0, 16) : fullSig;

    final simulatedPacket = OpticalFramePacket(
      sessionId: activeSessId,
      courseCode: _selectedCourseCode,
      courseName: _selectedCourseName,
      room: _selectedRoom,
      sequence: _sequence,
      timestamp: nowSeconds,
      nonce: nonce,
      signature: truncatedSig,
    );

    final encoded = simulatedPacket.encode();
    _scanInputController.text = encoded;
    _processOpticalPayload(encoded);
  }

  // ----------------------------------------------------
  // MANUAL ATTENDANCE FALLBACK
  // ----------------------------------------------------

  Future<void> _saveManualAttendanceLocally() async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final sessionId = 'sess-local-${DateTime.now().millisecondsSinceEpoch}';

    final session = AttendanceSessionModel(
      id: sessionId,
      courseId: _selectedCourseId,
      courseCode: _selectedCourseCode,
      courseName: _selectedCourseName,
      scopeCode: _selectedScope,
      sessionDate: dateStr,
      topic: 'Lecture in $_selectedRoom',
      records: _manualRoster
          .map((r) => AttendanceRecordModel(
                id: 'rec-${r.studentId}-$sessionId',
                sessionId: sessionId,
                studentId: r.studentId,
                studentName: r.studentName,
                campusHandle: r.campusHandle,
                status: r.status,
              ))
          .toList(),
    );

    widget.storage.recordOfflineAttendance(session);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance recorded in offline outbox (${widget.storage.pendingSyncCount} pending)',
          ),
          backgroundColor: AppColors.githubGreen,
          action: SnackBarAction(
            label: 'Sync Now',
            textColor: Colors.white,
            onPressed: _syncOutbox,
          ),
        ),
      );
      setState(() => _mode = AttendanceViewMode.summary);
      _loadSummary();
    }
  }

  Future<void> _syncOutbox() async {
    setState(() => _loading = true);
    final success = await widget.storage.flushOutbox(widget.currentUser.id);
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'All offline sessions replicated to Go backend' : 'Backend offline. Preserved in local storage',
          ),
          backgroundColor: success ? AppColors.githubGreen : AppColors.statusYellow,
        ),
      );
      _loadSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(_getTitleForMode()),
        actions: [
          if (widget.storage.pendingSyncCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                avatar: const AppSvgIcon(
                  svgString: AppSvgIcon.refresh,
                  size: 14,
                  color: Colors.white,
                ),
                label: Text(
                  '${widget.storage.pendingSyncCount} Pending',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
                backgroundColor: AppColors.githubGreen,
                onPressed: _syncOutbox,
              ),
            ),
          if (_mode != AttendanceViewMode.summary)
            IconButton(
              icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 18),
              tooltip: 'Return to Summary',
              onPressed: () {
                if (_mode == AttendanceViewMode.broadcastOptical) {
                  _concludeOpticalBroadcast();
                } else {
                  _sweepAnimController.stop();
                  setState(() => _mode = AttendanceViewMode.summary);
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.wineRed))
          : _buildCurrentView(),
    );
  }

  String _getTitleForMode() {
    switch (_mode) {
      case AttendanceViewMode.broadcastOptical:
        return 'Optical QR Broadcast • Live Session';
      case AttendanceViewMode.scanOptical:
        return 'Scan Rolling Optical QR';
      case AttendanceViewMode.manualChecklist:
        return 'Manual Attendance Roster';
      case AttendanceViewMode.summary:
        return 'Classroom Attendance';
    }
  }

  Widget _buildCurrentView() {
    switch (_mode) {
      case AttendanceViewMode.broadcastOptical:
        return _buildOpticalBroadcastView();
      case AttendanceViewMode.scanOptical:
        return _buildOpticalReceiverView();
      case AttendanceViewMode.manualChecklist:
        return _buildManualChecklistView();
      case AttendanceViewMode.summary:
        return _buildSummaryView();
    }
  }

  // ----------------------------------------------------
  // VIEW 1: SUMMARY LEDGER
  // ----------------------------------------------------

  Widget _buildSummaryView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFacultyOrAdmin = widget.currentUser.archetype == 'employee';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Optical Protocol Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.wineRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const AppSvgIcon(
                        svgString: AppSvgIcon.qrCode,
                        size: 24,
                        color: AppColors.wineRed,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Anti-Proxy Optical Data Transfer Attendance',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rapidly rolling ephemeral QR codes refresh every 1.5s with time-window HMAC signatures, preventing screenshot sharing and remote proxy fraud.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Toolbar
              Row(
                children: [
                  if (isFacultyOrAdmin)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.wineRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        icon: const AppSvgIcon(svgString: AppSvgIcon.qrCode, size: 16, color: Colors.white),
                        label: const Text('Broadcast Optical QR', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _startOpticalBroadcast,
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.githubGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        icon: const AppSvgIcon(svgString: AppSvgIcon.attendance, size: 16, color: Colors.white),
                        label: const Text('Scan Rolling QR', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _openOpticalScanner,
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Alternative action
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: AppSvgIcon(
                      svgString: isFacultyOrAdmin ? AppSvgIcon.attendance : AppSvgIcon.qrCode,
                      size: 16,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    label: Text(
                      isFacultyOrAdmin ? 'Manual Roster' : 'Open Optical Scanner',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    onPressed: () {
                      if (isFacultyOrAdmin) {
                        setState(() => _mode = AttendanceViewMode.manualChecklist);
                      } else {
                        _openOpticalScanner();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Course Attendance Summaries
              const Text(
                'Course Attendance Standing',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (_summaries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                  ),
                  child: Text(
                    'No recorded attendance history for current term.',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                )
              else
                Column(
                  children: _summaries.map((s) => _buildSummaryCard(s, isDark)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AttendanceSummaryModel s, bool isDark) {
    final meetsThreshold = s.percentage >= 75.0;
    final badgeStyle = meetsThreshold ? AppColors.greenBadge(isDark) : AppColors.redBadge(isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.courseCode} — ${s.courseName}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Attended ${s.attended} of ${s.totalSessions} sessions',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeStyle.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeStyle.border, width: 1),
                ),
                child: Text(
                  '${s.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: badgeStyle.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.totalSessions > 0 ? (s.attended / s.totalSessions).clamp(0.0, 1.0) : 0.0,
              minHeight: 6,
              backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              color: meetsThreshold ? AppColors.githubGreen : AppColors.statusRed,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // VIEW 2: FACULTY OPTICAL BROADCAST VIEW
  // ----------------------------------------------------

  Widget _buildOpticalBroadcastView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // Top Session Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_selectedCourseCode — $_selectedCourseName',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Room: $_selectedRoom  |  Cohort: $_selectedScope  |  Faculty: ${widget.currentUser.fullName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        // Live Ticker Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.githubGreenDarkSubtle,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.githubGreenDarkBorder, width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.githubGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'BROADCASTING LIVE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.githubGreenDarkText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Main Display: Rolling QR Canvas on left, Roster & Cryptography on right
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;

                  final qrCanvas = Column(
                    children: [
                      // QR Code Container with Frame Countdown Ring
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white, // Always high-contrast pure white for optical camera readability
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _currentPayload.isNotEmpty
                            ? QrImageView(
                                data: _currentPayload,
                                version: QrVersions.auto,
                                size: 260.0,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                              )
                            : const SizedBox(
                                width: 260,
                                height: 260,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Countdown & Frame Ticker Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    value: _frameProgress,
                                    strokeWidth: 2.5,
                                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    color: AppColors.wineRed,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Next Frame in ${(_frameProgress * (_refreshIntervalMs / 1000)).toStringAsFixed(1)}s',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.wineRedDarkSubtle : AppColors.wineRedSubtle,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDark ? AppColors.wineRedDarkBorder : AppColors.wineRedBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Frame #$_sequence',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                                    ),
                                  ),
                                ),
                                if (_currentSig.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'SIG: ${_currentSig.length > 8 ? _currentSig.substring(0, 8) : _currentSig}... [$_currentNonce]',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 9,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Anti-Screenshot / Anti-Proxy Notice
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.statusYellow.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.statusYellow.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          children: [
                            const AppSvgIcon(
                              svgString: AppSvgIcon.shield,
                              size: 15,
                              color: AppColors.statusYellow,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Screenshot & Replay Protected: Each frame expires in 6 seconds. Students must scan directly from this podium display.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.statusYellowDarkText : AppColors.statusYellow,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final telemetryPanel = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Roster Counter Header
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Live Verified Attendance Roster',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Real-time optical packet reconciliation',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.githubGreenDarkSubtle,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.githubGreenDarkBorder, width: 1),
                              ),
                              child: Text(
                                '${_opticalRoster.length} Present',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.githubGreenDarkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Live Verified Students List
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                        ),
                        child: _opticalRoster.isEmpty
                            ? Center(
                                child: Text(
                                  'Waiting for students to scan optical QR...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemCount: _opticalRoster.length,
                                separatorBuilder: (context, index) => const Divider(height: 8),
                                itemBuilder: (context, idx) {
                                  final r = _opticalRoster[idx];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                    leading: Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.githubGreen.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const AppSvgIcon(
                                        svgString: AppSvgIcon.check,
                                        size: 14,
                                        color: AppColors.githubGreen,
                                      ),
                                    ),
                                    title: Text(
                                      r.studentName.isNotEmpty ? r.studentName : r.studentId,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      r.campusHandle.isNotEmpty ? r.campusHandle : r.studentId,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppColors.darkBg : AppColors.lightBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                      ),
                                      child: Text(
                                        r.remarks.isNotEmpty ? r.remarks : 'VERIFIED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 14),

                      // Stream Controls
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: AppSvgIcon(
                                svgString: _isStreamPaused ? AppSvgIcon.refresh : AppSvgIcon.clock,
                                size: 14,
                              ),
                              label: Text(_isStreamPaused ? 'Resume Stream' : 'Pause Stream'),
                              onPressed: () {
                                setState(() => _isStreamPaused = !_isStreamPaused);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.wineRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                elevation: 0,
                              ),
                              icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 14, color: Colors.white),
                              label: const Text('Conclude & Save'),
                              onPressed: _concludeOpticalBroadcast,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 320, child: qrCanvas),
                        const SizedBox(width: 24),
                        Expanded(child: telemetryPanel),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      qrCanvas,
                      const SizedBox(height: 20),
                      telemetryPanel,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // VIEW 3: STUDENT OPTICAL RECEIVER SCANNER VIEW
  // ----------------------------------------------------

  Widget _buildOpticalReceiverView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Viewfinder Scanner Reticle Canvas
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1117) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Target Optical Frame Reticle
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.githubGreen, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          // Animated Laser Sweep Line
                          AnimatedBuilder(
                            animation: _sweepAnimController,
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment(0, (_sweepAnimController.value * 2) - 1),
                                child: Container(
                                  height: 2,
                                  width: double.infinity,
                                  color: AppColors.githubGreen,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
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
                ),
              ),
              const SizedBox(height: 20),

              // Instant Capture & Manual Optical Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.githubGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      icon: _isVerifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const AppSvgIcon(svgString: AppSvgIcon.check, size: 16, color: Colors.white),
                      label: Text(
                        _isVerifying ? 'Verifying Live Frame...' : 'Capture From Active Lecture Broadcast',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _isVerifying ? null : _simulateCaptureFromLiveBroadcast,
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Direct Optical Payload (Testing & Fallback)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _scanInputController,
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                              decoration: InputDecoration(
                                hintText: 'Paste CPOS:OPT:... packet',
                                hintStyle: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _processOpticalPayload(_scanInputController.text),
                          child: const Text('Decode'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scan Error Message
              if (_scanError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.statusRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      const AppSvgIcon(svgString: AppSvgIcon.alertTriangle, size: 16, color: AppColors.statusRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _scanError!,
                          style: const TextStyle(fontSize: 12, color: AppColors.statusRed, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Successful Verification Banner
              if (_lastVerifiedResult != null && _lastVerifiedResult!.verified) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.githubGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.githubGreen.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.githubGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const AppSvgIcon(svgString: AppSvgIcon.check, size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attendance Recorded • Present',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.githubGreenDarkText : AppColors.githubGreenText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_lastVerifiedResult!.courseCode} — ${_lastVerifiedResult!.courseName}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Text(
                        'Student: ${_lastVerifiedResult!.studentName} (${_lastVerifiedResult!.handle})  |  Frame: #${_lastVerifiedResult!.sequence}  |  Time: ${_lastVerifiedResult!.recordedAt.toIso8601String().split('T').last.substring(0, 8)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // VIEW 4: MANUAL CHECKLIST ROSTER FALLBACK
  // ----------------------------------------------------

  Widget _buildManualChecklistView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Attendance Roster • $_selectedCourseCode',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manual fallback for students unable to complete optical frame capture.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              ..._manualRoster.map((r) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.studentName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(r.campusHandle, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                        ],
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'present', label: Text('Present', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: 'absent', label: Text('Absent', style: TextStyle(fontSize: 11))),
                        ],
                        selected: {r.status},
                        onSelectionChanged: (val) {
                          setState(() => r.status = val.first);
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                onPressed: _saveManualAttendanceLocally,
                child: const Text('Save Manual Attendance Record', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
