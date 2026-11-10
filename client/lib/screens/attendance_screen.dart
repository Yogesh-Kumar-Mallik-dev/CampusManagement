import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/academic.dart';
import '../models/complaint.dart';
import '../models/user.dart';
import '../screens/complaints_screen.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_skeleton.dart';

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
  PageLoadState _loadState = PageLoadState.pending;
  String? _errorMessage;
  List<AttendanceSummaryModel> _summaries = [];
  AttendanceViewMode _mode = AttendanceViewMode.summary;

  // Student Attendance Analytics State
  String _courseFilter = 'all'; // 'all', 'at_risk', 'safe'
  String? _selectedHeatmapDayInfo;

  static final List<Map<String, dynamic>> _heatmapDays = [
    {'day': 1, 'date': 'Oct 01', 'status': 'full', 'desc': 'Oct 01 (Wed): Attended 4/4 sessions (100%) - CS301, CS302, CS304, CS303'},
    {'day': 2, 'date': 'Oct 02', 'status': 'full', 'desc': 'Oct 02 (Thu): Attended 4/4 sessions (100%) - Operating Systems Lab & Lecture'},
    {'day': 3, 'date': 'Oct 03', 'status': 'partial', 'desc': 'Oct 03 (Fri): Attended 3/4 sessions (75%) - Missed MA101 Discrete Math'},
    {'day': 4, 'date': 'Oct 06', 'status': 'full', 'desc': 'Oct 06 (Mon): Attended 4/4 sessions (100%) - Neural Networks Lab & Theory'},
    {'day': 5, 'date': 'Oct 07', 'status': 'full', 'desc': 'Oct 07 (Tue): Attended 4/4 sessions (100%) - DBMS Transactions & Concurrency'},
    {'day': 6, 'date': 'Oct 08', 'status': 'full', 'desc': 'Oct 08 (Wed): Attended 4/4 sessions (100%) - Full attendance verified'},
    {'day': 7, 'date': 'Oct 09', 'status': 'absent', 'desc': 'Oct 09 (Thu): Attended 0/4 sessions (0%) - Absence on Academic Leave'},
    {'day': 8, 'date': 'Oct 10', 'status': 'full', 'desc': 'Oct 10 (Fri): Attended 4/4 sessions (100%) - Algorithms Dynamic Programming'},
    {'day': 9, 'date': 'Oct 13', 'status': 'full', 'desc': 'Oct 13 (Mon): Attended 4/4 sessions (100%) - Operating Systems Virtual Memory'},
    {'day': 10, 'date': 'Oct 14', 'status': 'full', 'desc': 'Oct 14 (Tue): Attended 4/4 sessions (100%) - All lectures verified'},
    {'day': 11, 'date': 'Oct 15', 'status': 'full', 'desc': 'Oct 15 (Wed): Attended 4/4 sessions (100%) - Full attendance verified'},
    {'day': 12, 'date': 'Oct 16', 'status': 'partial', 'desc': 'Oct 16 (Thu): Attended 2/4 sessions (50%) - Lab Attended, Missed Theory'},
    {'day': 13, 'date': 'Oct 17', 'status': 'full', 'desc': 'Oct 17 (Fri): Attended 4/4 sessions (100%) - Discrete Math Graph Theory'},
    {'day': 14, 'date': 'Oct 20', 'status': 'full', 'desc': 'Oct 20 (Mon): Attended 4/4 sessions (100%) - Deep Learning Backprop'},
    {'day': 15, 'date': 'Oct 21', 'status': 'full', 'desc': 'Oct 21 (Tue): Attended 4/4 sessions (100%) - Full attendance verified'},
    {'day': 16, 'date': 'Oct 22', 'status': 'full', 'desc': 'Oct 22 (Wed): Attended 4/4 sessions (100%) - Full attendance verified'},
    {'day': 17, 'date': 'Oct 23', 'status': 'full', 'desc': 'Oct 23 (Thu): Attended 4/4 sessions (100%) - OS File Systems'},
    {'day': 18, 'date': 'Oct 24', 'status': 'absent', 'desc': 'Oct 24 (Fri): Attended 0/4 sessions (0%) - Personal Medical Leave'},
    {'day': 19, 'date': 'Oct 27', 'status': 'full', 'desc': 'Oct 27 (Mon): Attended 4/4 sessions (100%) - DBMS Indexing B+ Trees'},
    {'day': 20, 'date': 'Oct 28', 'status': 'full', 'desc': 'Oct 28 (Tue): Attended 4/4 sessions (100%) - Algorithms Greedy Heuristics'},
    {'day': 21, 'date': 'Oct 29', 'status': 'full', 'desc': 'Oct 29 (Wed): Attended 4/4 sessions (100%) - Full attendance verified'},
    {'day': 22, 'date': 'Oct 30', 'status': 'full', 'desc': 'Oct 30 (Thu): Attended 4/4 sessions (100%) - Deep Learning CNN Architectures'},
    {'day': 23, 'date': 'Oct 31', 'status': 'partial', 'desc': 'Oct 31 (Fri): Attended 3/4 sessions (75%) - Missed Algorithms Lab'},
    {'day': 24, 'date': 'Nov 03', 'status': 'full', 'desc': 'Nov 03 (Mon): Attended 4/4 sessions (100%) - Operating Systems Deadlocks'},
    {'day': 25, 'date': 'Nov 04', 'status': 'full', 'desc': 'Nov 04 (Tue): Attended 4/4 sessions (100%) - DBMS Normalization 3NF/BCNF'},
    {'day': 26, 'date': 'Nov 05', 'status': 'full', 'desc': 'Nov 05 (Wed): Attended 4/4 sessions (100%) - Continuous 12-day streak active'},
    {'day': 27, 'date': 'Nov 06', 'status': 'full', 'desc': 'Nov 06 (Thu): Attended 4/4 sessions (100%) - Full attendance verified'},
    {'day': 28, 'date': 'Nov 07', 'status': 'full', 'desc': 'Nov 07 (Fri): Attended 4/4 sessions (100%) - Discrete Math Combinatorics'},
    {'day': 29, 'date': 'Nov 10', 'status': 'full', 'desc': 'Nov 10 (Mon): Attended 4/4 sessions (100%) - Deep Learning Transformers'},
    {'day': 30, 'date': 'Nov 11', 'status': 'full', 'desc': 'Nov 11 (Tue): Attended 4/4 sessions (100%) - Today: All classes verified'},
  ];

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
  final ValueNotifier<double> _frameProgressNotifier = ValueNotifier<double>(1.0);
  String _currentPayload = '';
  String _currentNonce = '';
  String _currentSig = '';
  bool _isStreamPaused = false;
  List<AttendanceRecordModel> _opticalRoster = [];

  // Precomputed Summary Stats
  int _totalHeld = 0;
  int _totalAttended = 0;
  double _overallPct = 0.0;
  int _safeMargin = 0;
  int _recoveryReq = 0;
  List<AttendanceSummaryModel> _atRiskList = [];
  List<AttendanceSummaryModel> _safeList = [];

  void _recomputeSummaryStats() {
    final held = _summaries.fold<int>(0, (sum, item) => sum + item.totalSessions);
    final attended = _summaries.fold<int>(0, (sum, item) => sum + item.attended);
    final pct = held > 0 ? (attended / held) * 100.0 : 0.0;
    _totalHeld = held;
    _totalAttended = attended;
    _overallPct = pct;
    _atRiskList = _summaries.where((s) => s.percentage < 75.0).toList();
    _safeList = _summaries.where((s) => s.percentage >= 75.0).toList();
    _safeMargin = held > 0 && pct >= 75.0
        ? math.max(0, ((4 * attended - 3 * held) / 3).floor())
        : 0;
    _recoveryReq = held > 0 && pct < 75.0
        ? math.max(0, 3 * held - 4 * attended)
        : 0;
  }

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
    final cached = widget.storage.cachedSummaries;
    if (cached.isNotEmpty) {
      _summaries = List.from(cached);
      _recomputeSummaryStats();
      _loadState = PageLoadState.success;
    }
    _loadSummary();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _progressTicker?.cancel();
    _sweepAnimController.dispose();
    _frameProgressNotifier.dispose();
    _scanInputController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    if (_summaries.isEmpty) {
      setState(() {
        _loadState = PageLoadState.pending;
        _errorMessage = null;
      });
    }
    try {
      final data = await widget.storage.getAttendanceSummary(widget.currentUser.id);
      if (mounted) {
        setState(() {
          _summaries = data;
          _recomputeSummaryStats();
          _loadState = PageLoadState.success;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_summaries.isEmpty) {
            _loadState = PageLoadState.failed;
            _errorMessage = 'Failed to load attendance records. Check network.';
          }
        });
      }
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
      _frameProgressNotifier.value = currentStep / totalSteps;
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
          IconButton(
            key: const Key('btn-shortcut-attendance-complaint'),
            icon: const AppSvgIcon(
              svgString: AppSvgIcon.alertTriangle,
              size: 18,
              color: AppColors.statusRed,
            ),
            tooltip: 'Report Attendance Grievance',
            onPressed: () {
              ComplaintsScreen.showFileComplaintDialog(
                context: context,
                storage: widget.storage,
                currentUser: widget.currentUser,
                initialCategory: ComplaintCategory.student,
                initialTitle: 'Attendance Ledger Discrepancy',
              );
            },
          ),
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
      body: (_loading && _mode != AttendanceViewMode.summary)
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
    final isFacultyOrAdmin = widget.currentUser.canBroadcastAttendance(widget.currentUser.sectionScope) ||
        widget.currentUser.isAdmin ||
        widget.currentUser.isFaculty;

    if (!isFacultyOrAdmin) {
      return _buildStudentAttendanceDashboard(isDark);
    }

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

              if (_loadState == PageLoadState.pending)
                _buildSummarySkeletons(isDark)
              else if (_loadState == PageLoadState.failed)
                InlineStateError(
                  message: _errorMessage ?? 'Failed to load course attendance standing.',
                  onRetry: _loadSummary,
                )
              else if (_summaries.isEmpty)
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

  Widget _buildSummarySkeletons(bool isDark) {
    return Column(
      children: List.generate(3, (index) {
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
                children: const [
                  AppSkeleton(width: 180, height: 16, borderRadius: 4),
                  AppSkeleton(width: 50, height: 22, borderRadius: 4),
                ],
              ),
              const SizedBox(height: 8),
              const AppSkeleton(width: 120, height: 12, borderRadius: 4),
              const SizedBox(height: 12),
              const AppSkeleton.rect(height: 6, borderRadius: 3),
            ],
          ),
        );
      }),
    );
  }

  // ----------------------------------------------------
  // VIEW 1-B: STUDENT ATTENDANCE ANALYTICS DASHBOARD
  // ----------------------------------------------------

  Widget _buildStudentAttendanceDashboard(bool isDark) {
    final totalHeld = _totalHeld;
    final totalAttended = _totalAttended;
    final overallPct = _overallPct;
    final atRiskList = _atRiskList;
    final safeList = _safeList;
    final safeMargin = _safeMargin;
    final recoveryReq = _recoveryReq;

    List<AttendanceSummaryModel> displayedSummaries = _summaries;
    if (_courseFilter == 'at_risk') {
      displayedSummaries = atRiskList;
    } else if (_courseFilter == 'safe') {
      displayedSummaries = safeList;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Action & Status Bar (Always mounted)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 540;
                  final contentCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Student Attendance Analytics',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Statutory 75% regulatory compliance engine, safe bunk margins, and optical scanner.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  );

                  final scanBtn = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.githubGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    icon: const AppSvgIcon(svgString: AppSvgIcon.qrCode, size: 16, color: Colors.white),
                    label: const Text('Scan Rolling QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: _openOpticalScanner,
                  );

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                    ),
                    child: isNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.githubGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const AppSvgIcon(
                                      svgString: AppSvgIcon.attendance,
                                      size: 24,
                                      color: AppColors.githubGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(child: contentCol),
                                ],
                              ),
                              const SizedBox(height: 12),
                              scanBtn,
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.githubGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const AppSvgIcon(
                                  svgString: AppSvgIcon.attendance,
                                  size: 24,
                                  color: AppColors.githubGreen,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: contentCol),
                              const SizedBox(width: 12),
                              scanBtn,
                            ],
                          ),
                  );
                },
              ),
              const SizedBox(height: 18),

              if (_loadState == PageLoadState.pending)
                _buildStudentAttendanceSkeletons(isDark)
              else if (_loadState == PageLoadState.failed)
                InlineStateError(
                  message: _errorMessage ?? 'Failed to load student attendance analytics.',
                  onRetry: _loadSummary,
                )
              else ...[
                // 1. Overall Dual-Ring Radial Compliance Gauge
                _buildOverallAttendanceVisual(
                  isDark,
                  totalHeld,
                  totalAttended,
                  overallPct,
                  atRiskList.length,
                  safeMargin,
                  recoveryReq,
                ),
                const SizedBox(height: 18),

                // 2. 30-Day Classroom Activity Matrix
                _buildAttendanceHeatmap(isDark),
                const SizedBox(height: 18),

                // 3. Course-by-Course Comparative Benchmark Visual
                _buildCourseComparisonChart(isDark),
                const SizedBox(height: 18),

                // 4. Enrolled Course Standing & Margins
                _buildDetailedCourseList(
                  isDark,
                  displayedSummaries,
                  atRiskList.length,
                  safeList.length,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentAttendanceSkeletons(bool isDark) {
    return Column(
      children: [
        // Compliance Gauge Skeleton
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
          ),
          child: Row(
            children: [
              const AppSkeleton(width: 110, height: 110, borderRadius: 55),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppSkeleton(width: 180, height: 18, borderRadius: 4),
                    SizedBox(height: 10),
                    AppSkeleton(width: double.infinity, height: 12, borderRadius: 4),
                    SizedBox(height: 6),
                    AppSkeleton(width: 140, height: 12, borderRadius: 4),
                    SizedBox(height: 14),
                    AppSkeleton(width: 220, height: 26, borderRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // 30-Day Matrix Skeleton
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppSkeleton(width: 200, height: 16, borderRadius: 4),
              SizedBox(height: 16),
              AppSkeleton.rect(height: 60, borderRadius: 6),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Course Benchmark Skeleton
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppSkeleton(width: 160, height: 16, borderRadius: 4),
              SizedBox(height: 16),
              AppSkeleton.rect(height: 120, borderRadius: 6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverallAttendanceVisual(
    bool isDark,
    int totalHeld,
    int totalAttended,
    double overallPct,
    int atRiskCount,
    int safeMargin,
    int recoveryReq,
  ) {
    final meetsRegulatory = overallPct >= 75.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: AppSvgIcon(
                        svgString: meetsRegulatory ? AppSvgIcon.shield : AppSvgIcon.alertTriangle,
                        size: 16,
                        color: meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Statutory 75% Regulatory Compliance Gauge',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Dual-ring radial measurement against official university threshold',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  meetsRegulatory ? 'EXAM ELIGIBLE' : 'DEBARMENT SHORTFALL RISK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 580;

              final gaugeWidget = SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(150, 150),
                      painter: _AttendanceRadialPainter(
                        percentage: overallPct,
                        isDark: isDark,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${overallPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed,
                          ),
                        ),
                        Text(
                          'OVERALL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            meetsRegulatory ? '>= 75% PASS' : '< 75% RISK',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final metricsWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Regulatory Policy Rule Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSvgIcon(
                          svgString: meetsRegulatory ? AppSvgIcon.check : AppSvgIcon.alertTriangle,
                          size: 16,
                          color: meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meetsRegulatory
                                    ? 'Safe Bunk Margin: $safeMargin Class${safeMargin == 1 ? '' : 'es'}'
                                    : 'Recovery Needed: $recoveryReq Consecutive Class${recoveryReq == 1 ? '' : 'es'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: meetsRegulatory ? AppColors.githubGreen : AppColors.statusRed,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                meetsRegulatory
                                    ? 'You can safely miss up to $safeMargin more lecture${safeMargin == 1 ? '' : 's'} across enrolled courses while staying above the statutory 75% boundary.'
                                    : 'You are below statutory threshold. Attend the next $recoveryReq consecutive class${recoveryReq == 1 ? '' : 'es'} without absence to clear examination eligibility.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tally Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AGGREGATE ATTENDED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                              const SizedBox(height: 2),
                              Text('$totalAttended / $totalHeld', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SUBJECTS AT RISK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                              const SizedBox(height: 2),
                              Text('$atRiskCount of ${_summaries.length}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: atRiskCount > 0 ? AppColors.statusRed : AppColors.githubGreen)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    gaugeWidget,
                    const SizedBox(width: 20),
                    Expanded(child: metricsWidget),
                  ],
                );
              } else {
                return Column(
                  children: [
                    gaugeWidget,
                    const SizedBox(height: 16),
                    metricsWidget,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHeatmap(bool isDark) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 460;
              final streakBadge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.3), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSvgIcon(svgString: AppSvgIcon.flame, size: 12, color: AppColors.statusAmber),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '12-Day Active Streak',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusAmber,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );

              final titleSection = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.statusAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const AppSvgIcon(
                      svgString: AppSvgIcon.flame,
                      size: 16,
                      color: AppColors.statusAmber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '30-Day Classroom Activity Matrix',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Daily session participation and streak monitoring',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 8),
                    streakBadge,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleSection),
                  const SizedBox(width: 8),
                  streakBadge,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Heatmap Grid: 5 rows (Mon to Fri) x 6 columns (Weeks 1 to 6)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Labels (Mon to Fri)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(height: 24, child: Text('Mon', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
                      const SizedBox(height: 4),
                      SizedBox(height: 24, child: Text('Tue', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
                      const SizedBox(height: 4),
                      SizedBox(height: 24, child: Text('Wed', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
                      const SizedBox(height: 4),
                      SizedBox(height: 24, child: Text('Thu', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
                      const SizedBox(height: 4),
                      SizedBox(height: 24, child: Text('Fri', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
                    ],
                  ),
                ),

                // Matrix Weeks
                ...List.generate(6, (col) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      children: List.generate(5, (row) {
                        final index = col * 5 + row;
                        if (index >= _heatmapDays.length) {
                          return const SizedBox(width: 24, height: 28);
                        }
                        final day = _heatmapDays[index];
                        final status = day['status'] as String;
                        final color = _getHeatmapColor(status, isDark);
                        final isSelected = _selectedHeatmapDayInfo == day['desc'];

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedHeatmapDayInfo = day['desc'] as String;
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? Colors.black26 : Colors.white24),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Selected Day Feedback Pill or Default Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
            ),
            child: Row(
              children: [
                AppSvgIcon(
                  svgString: AppSvgIcon.calendar,
                  size: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedHeatmapDayInfo ?? 'Tap any heatmap day to inspect verified attendance logs.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
              const SizedBox(width: 6),
              _buildLegendSwatch(AppColors.statusRed),
              const SizedBox(width: 4),
              _buildLegendSwatch(const Color(0xFFD29922)),
              const SizedBox(width: 4),
              _buildLegendSwatch(AppColors.githubGreen),
              const SizedBox(width: 6),
              Text('More (100%)', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Color _getHeatmapColor(String status, bool isDark) {
    switch (status) {
      case 'full':
        return AppColors.githubGreen;
      case 'partial':
        return const Color(0xFFD29922);
      case 'absent':
        return AppColors.statusRed;
      default:
        return isDark ? const Color(0xFF21262D) : const Color(0xFFEAEEF2);
    }
  }

  Widget _buildLegendSwatch(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildCourseComparisonChart(bool isDark) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.githubBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const AppSvgIcon(
                        svgString: AppSvgIcon.chartBar,
                        size: 16,
                        color: AppColors.githubBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Course Benchmark vs. 75% Cutoff',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Mandatory statutory cutoff across enrolled subjects',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                ),
                child: Text(
                  'Cutoff: 75.0%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          ..._summaries.map((s) {
            final meets = s.percentage >= 75.0;
            final margin = meets
                ? math.max(0, ((4 * s.attended - 3 * s.totalSessions) / 3).floor())
                : 0;
            final recovery = !meets
                ? math.max(0, 3 * s.totalSessions - 4 * s.attended)
                : 0;

            return InkWell(
              onTap: () => _showCourseInspectorDialog(context, s, isDark),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${s.courseCode} ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: s.courseName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${s.attended}/${s.totalSessions} (${s.percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: meets ? AppColors.githubGreen : AppColors.statusRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final totalWidth = constraints.maxWidth;
                        final cutoffPosition = totalWidth * 0.75;
                        final barWidth = totalWidth * (s.percentage / 100.0).clamp(0.0, 1.0);

                        return SizedBox(
                          height: 14,
                          child: Stack(
                            children: [
                              // Background track
                              Container(
                                width: totalWidth,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF21262D) : const Color(0xFFEAEEF2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // Active bar
                              Container(
                                width: barWidth,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: meets ? AppColors.githubGreen : AppColors.statusRed,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // 75% Cutoff Indicator Line
                              Positioned(
                                left: cutoffPosition - 1,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 2,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meets
                          ? 'Safe Margin: Can miss $margin class${margin == 1 ? '' : 'es'}'
                          : 'Shortfall: Must attend next $recovery consecutive class${recovery == 1 ? '' : 'es'}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: meets ? AppColors.githubGreen : AppColors.statusRed,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ),
    );
  }

  Widget _buildDetailedCourseList(
    bool isDark,
    List<AttendanceSummaryModel> displayedSummaries,
    int atRiskCount,
    int safeCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            const Text(
              'Enrolled Course Standing & Margins',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            // Filter Segments
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              segments: [
                ButtonSegment(value: 'all', label: Text('All (${_summaries.length})')),
                ButtonSegment(value: 'at_risk', label: Text('At Risk ($atRiskCount)')),
                ButtonSegment(value: 'safe', label: Text('Safe ($safeCount)')),
              ],
              selected: {_courseFilter},
              onSelectionChanged: (val) {
                setState(() => _courseFilter = val.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (displayedSummaries.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
            ),
            child: Text(
              'No courses match the active filter criteria.',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
          )
        else
          Column(
            children: displayedSummaries.map((s) {
              final meets = s.percentage >= 75.0;
              final badgeStyle = meets ? AppColors.greenBadge(isDark) : AppColors.redBadge(isDark);
              final margin = meets
                  ? math.max(0, ((4 * s.attended - 3 * s.totalSessions) / 3).floor())
                  : 0;
              final recovery = !meets
                  ? math.max(0, 3 * s.totalSessions - 4 * s.attended)
                  : 0;

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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s.courseCode} — ${s.courseName}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Attended ${s.attended} of ${s.totalSessions} sessions (${s.totalSessions - s.attended} absent)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
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
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: s.totalSessions > 0 ? (s.attended / s.totalSessions).clamp(0.0, 1.0) : 0.0,
                        minHeight: 6,
                        backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        color: meets ? AppColors.githubGreen : AppColors.statusRed,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Margin Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (meets ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (meets ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppSvgIcon(
                                svgString: meets ? AppSvgIcon.check : AppSvgIcon.alertTriangle,
                                size: 12,
                                color: meets ? AppColors.githubGreen : AppColors.statusRed,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  meets
                                      ? 'Can miss $margin class${margin == 1 ? '' : 'es'}'
                                      : 'Must attend next $recovery class${recovery == 1 ? '' : 'es'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: meets ? AppColors.githubGreen : AppColors.statusRed,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Drilldown Action
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          icon: AppSvgIcon(
                            svgString: AppSvgIcon.academicCap,
                            size: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          label: const Text('Inspect Log', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _showCourseInspectorDialog(context, s, isDark),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showCourseInspectorDialog(BuildContext context, AttendanceSummaryModel s, bool isDark) {
    final meetsThreshold = s.percentage >= 75.0;
    final margin = meetsThreshold
        ? math.max(0, ((4 * s.attended - 3 * s.totalSessions) / 3).floor())
        : 0;
    final recovery = !meetsThreshold
        ? math.max(0, 3 * s.totalSessions - 4 * s.attended)
        : 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (meetsThreshold ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AppSvgIcon(
                svgString: meetsThreshold ? AppSvgIcon.check : AppSvgIcon.alertTriangle,
                size: 20,
                color: meetsThreshold ? AppColors.githubGreen : AppColors.statusRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.courseCode} — ${s.courseName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    'Course Attendance Inspector & Regulatory Standing',
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
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Stat Row
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('ATTENDANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                        const SizedBox(height: 4),
                        Text(
                          '${s.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: meetsThreshold ? AppColors.githubGreen : AppColors.statusRed,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 36, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    Column(
                      children: [
                        Text('SESSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                        const SizedBox(height: 4),
                        Text(
                          '${s.attended} / ${s.totalSessions}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 36, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    Column(
                      children: [
                        Text('MISSED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                        const SizedBox(height: 4),
                        Text(
                          '${s.totalSessions - s.attended}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.statusRed),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Statutory Policy Explanation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (meetsThreshold ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (meetsThreshold ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSvgIcon(
                      svgString: meetsThreshold ? AppSvgIcon.shield : AppSvgIcon.alertTriangle,
                      size: 16,
                      color: meetsThreshold ? AppColors.githubGreen : AppColors.statusRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        meetsThreshold
                            ? 'Statutory Buffer: You are currently compliant with institutional requirements (>=75%). You may miss up to $margin upcoming lecture${margin == 1 ? '' : 's'} while preserving semester exam clearance.'
                            : 'Debarment Warning: Your attendance has fallen below the mandatory 75% threshold. You must attend the next $recovery consecutive lecture${recovery == 1 ? '' : 's'} without absence to restore eligibility.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Recent Session Audit Log
              Text(
                'Recent Session Audit Log',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildLogItem('Session 32: Nov 05, 2026', 'Practical Lab Verification & Memory Paging', true, isDark),
                    _buildLogItem('Session 31: Nov 03, 2026', 'Virtual Memory & Page Replacement Algorithms', true, isDark),
                    _buildLogItem('Session 30: Oct 30, 2026', 'Concurrency, Mutexes & Semaphores', meetsThreshold, isDark),
                    _buildLogItem('Session 29: Oct 28, 2026', 'Process Synchronization & Race Conditions', true, isDark),
                    _buildLogItem('Session 28: Oct 24, 2026', 'CPU Scheduling: MLFQ & Real-Time Scheduling', meetsThreshold, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
      ),
    );
  }

  Widget _buildLogItem(String title, String subtitle, bool isPresent, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isPresent ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: (isPresent ? AppColors.githubGreen : AppColors.statusRed).withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              isPresent ? 'Present' : 'Absent',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isPresent ? AppColors.githubGreen : AppColors.statusRed,
              ),
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
                            ValueListenableBuilder<double>(
                              valueListenable: _frameProgressNotifier,
                              builder: (context, progress, _) {
                                return Row(
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 2.5,
                                        backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                        color: AppColors.wineRed,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Next Frame in ${(progress * (_refreshIntervalMs / 1000)).toStringAsFixed(1)}s',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                );
                              },
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
                          // Animated Laser Sweep Line (Isolated Repaint)
                          RepaintBoundary(
                            child: AnimatedBuilder(
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const AppSvgIcon(
                            svgString: AppSvgIcon.shield,
                            size: 14,
                            color: AppColors.wineRed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Anti-Proxy Protocol: Static screenshots and image uploads are strictly blocked. Optical frames expire in 6s and must be captured live from the classroom display.',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                                  color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
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

class _AttendanceRadialPainter extends CustomPainter {
  final double percentage;
  final bool isDark;

  const _AttendanceRadialPainter({
    required this.percentage,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 24) / 2;
    const strokeWidth = 14.0;

    // 1. Background Ring Track
    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF21262D) : const Color(0xFFE1E4E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Active Progress Arc
    final sweepAngle = (percentage / 100.0).clamp(0.0, 1.0) * 2 * math.pi;
    final isSafe = percentage >= 75.0;

    final progressPaint = Paint()
      ..color = isSafe ? AppColors.githubGreen : AppColors.statusRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Start at top (-pi / 2)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // 3. 75% Statutory Regulatory Benchmark Tick Marker
    // Starting at -pi/2, 75% is -pi/2 + 0.75 * 2*pi = pi (9 o'clock)
    const benchmarkAngle = -math.pi / 2 + (0.75 * 2 * math.pi);
    final innerTickRadius = radius - strokeWidth / 2 - 4;
    final outerTickRadius = radius + strokeWidth / 2 + 4;

    final tickPaint = Paint()
      ..color = isDark ? const Color(0xFFF0F6FC) : const Color(0xFF1F2328)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;

    final tickStart = Offset(
      center.dx + innerTickRadius * math.cos(benchmarkAngle),
      center.dy + innerTickRadius * math.sin(benchmarkAngle),
    );
    final tickEnd = Offset(
      center.dx + outerTickRadius * math.cos(benchmarkAngle),
      center.dy + outerTickRadius * math.sin(benchmarkAngle),
    );

    canvas.drawLine(tickStart, tickEnd, tickPaint);
  }

  @override
  bool shouldRepaint(covariant _AttendanceRadialPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.isDark != isDark;
  }
}
