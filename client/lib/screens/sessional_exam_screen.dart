import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../di/service_locator.dart';
import '../facade/campus_facade.dart';
import '../models/complaint.dart';
import '../models/sessional.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import 'complaints_screen.dart';

class SessionalExamScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;
  final ICampusFacade? facade;

  const SessionalExamScreen({
    super.key,
    required this.storage,
    this.currentUser,
    this.facade,
  });

  @override
  State<SessionalExamScreen> createState() => _SessionalExamScreenState();
}

class _SessionalExamScreenState extends State<SessionalExamScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<InternalAssessmentModel> _records = [];
  List<SessionalScheduleModel> _schedules = [];
  List<DeskSeatingModel> _seating = [];
  AKTUInternalAwardListModel? _awardList;

  String _selectedSubjectCode = 'CS301';
  String _selectedScheduleExamType = 'All';
  final String _selectedHallNumber = 'LT-101';

  // In-memory edit buffers for faculty marks entry
  final Map<String, TextEditingController> _ct1Controllers = {};
  final Map<String, TextEditingController> _ct2Controllers = {};
  final Map<String, TextEditingController> _putControllers = {};
  final Map<String, TextEditingController> _taControllers = {};
  final Map<String, TextEditingController> _labContControllers = {};
  final Map<String, TextEditingController> _labVivaControllers = {};
  final Map<String, TextEditingController> _labAttControllers = {};

  ICampusFacade get _facade {
    if (widget.facade != null) return widget.facade!;
    if (CampusDI.instance.isRegistered<ICampusFacade>()) {
      return CampusDI.instance.get<ICampusFacade>();
    }
    return CampusFacade(storage: widget.storage, api: widget.storage.api);
  }

  bool get _isHOD {
    final u = widget.currentUser;
    if (u == null) return false;
    return u.isAdmin || u.isHOD;
  }

  String get _currentStudentId {
    if (widget.currentUser != null && widget.currentUser!.isStudent) {
      return widget.currentUser!.id;
    }
    return widget.storage.cachedUsers.where((u) => u.archetype == 'student').firstOrNull?.id ??
        widget.currentUser?.id ??
        '';
  }

  List<String> get _availableSubjectCodes {
    final codes = <String>{};
    for (final s in widget.storage.cachedSubjects) {
      if (s.code.trim().isNotEmpty) codes.add(s.code.trim());
    }
    for (final r in _records) {
      if (r.subjectCode.trim().isNotEmpty) codes.add(r.subjectCode.trim());
    }
    if (codes.isEmpty) {
      codes.addAll(['CS301', 'CS302', 'CS303', 'CS301L']);
    }
    return codes.toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _ct1Controllers.values) {
      c.dispose();
    }
    for (final c in _ct2Controllers.values) {
      c.dispose();
    }
    for (final c in _putControllers.values) {
      c.dispose();
    }
    for (final c in _taControllers.values) {
      c.dispose();
    }
    for (final c in _labContControllers.values) {
      c.dispose();
    }
    for (final c in _labVivaControllers.values) {
      c.dispose();
    }
    for (final c in _labAttControllers.values) {
      c.dispose();
    }
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recs = await _facade.getSessionalRecords(semester: 5);
      final scheds = await _facade.getSessionalSchedules(semester: 5);
      final seat = await _facade.getSeatingLayout(
        hallNumber: _selectedHallNumber,
        examType: 'CT-1',
      );

      AKTUInternalAwardListModel? award;
      try {
        award = await _facade.getAwardList(
          subjectCode: _selectedSubjectCode,
          semester: 5,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _records = recs;
          _schedules = scheds;
          _seating = seat;
          _awardList = award;
          _initControllers();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _initControllers() {
    for (final r in _records) {
      final key = '${r.subjectCode}-${r.universityRollNo}';
      _ct1Controllers[key] ??= TextEditingController(text: r.ct1Score.toString());
      _ct2Controllers[key] ??= TextEditingController(text: r.ct2Score.toString());
      _putControllers[key] ??= TextEditingController(text: r.putScore.toString());
      _taControllers[key] ??= TextEditingController(text: r.taScore.toString());
      _labContControllers[key] ??= TextEditingController(text: r.labContinuousScore.toString());
      _labVivaControllers[key] ??= TextEditingController(text: r.labVivaScore.toString());
      _labAttControllers[key] ??= TextEditingController(text: r.labAttendanceScore.toString());
    }
  }

  Future<void> _refreshAwardList() async {
    try {
      final award = await _facade.getAwardList(
        subjectCode: _selectedSubjectCode,
        semester: 5,
      );
      if (mounted) {
        setState(() {
          _awardList = award;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveMarksForRecord(InternalAssessmentModel record) async {
    final key = '${record.subjectCode}-${record.universityRollNo}';

    try {
      final ct1 = double.tryParse(_ct1Controllers[key]?.text.trim() ?? '') ?? record.ct1Score;
      final ct2 = double.tryParse(_ct2Controllers[key]?.text.trim() ?? '') ?? record.ct2Score;
      final put = double.tryParse(_putControllers[key]?.text.trim() ?? '') ?? record.putScore;
      final ta = double.tryParse(_taControllers[key]?.text.trim() ?? '') ?? record.taScore;
      final labCont = double.tryParse(_labContControllers[key]?.text.trim() ?? '') ?? record.labContinuousScore;
      final labViva = double.tryParse(_labVivaControllers[key]?.text.trim() ?? '') ?? record.labVivaScore;
      final labAtt = double.tryParse(_labAttControllers[key]?.text.trim() ?? '') ?? record.labAttendanceScore;

      final payload = <String, dynamic>{
        'record_id': record.id,
        'subject_code': record.subjectCode,
        'student_id': record.studentId,
        'entered_by': widget.currentUser?.campusHandle ?? 'faculty',
      };

      if (record.isPractical) {
        payload['lab_continuous_score'] = labCont;
        payload['lab_viva_score'] = labViva;
        payload['lab_attendance_score'] = labAtt;
      } else {
        payload['ct1_score'] = ct1;
        payload['ct2_score'] = ct2;
        payload['put_score'] = put;
        payload['ta_score'] = ta;
      }

      final updated = await _facade.updateSessionalMarks(payload);

      if (mounted) {
        final idx = _records.indexWhere((r) => r.id == updated.id);
        if (idx >= 0) {
          setState(() {
            _records[idx] = updated;
          });
        }
        await _refreshAwardList();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marks saved for ${record.studentName} (${record.subjectCode})'),
            backgroundColor: AppColors.wineRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving marks: $e'),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    }
  }

  Future<void> _freezeMarksForSubject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Freeze AKTU Internal Award List?'),
        content: Text(
          'Lock marks for $_selectedSubjectCode (Semester 5)? Once frozen, marks cannot be modified by faculty without explicit Exam Cell unlocking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.wineRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Freeze & Sign'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final award = await _facade.freezeSessionalMarks({
        'subject_code': _selectedSubjectCode,
        'semester': 5,
        'frozen_by': widget.currentUser?.campusHandle ?? 'dr_arun_kumar',
        'remarks': 'Approved and digitally signed for AKTU portal upload',
      });

      if (mounted) {
        setState(() {
          _awardList = award;
          for (int i = 0; i < _records.length; i++) {
            if (_records[i].subjectCode == _selectedSubjectCode) {
              _records[i] = _records[i].copyWith(
                isFrozen: true,
                status: 'frozen',
                frozenBy: award.frozenBy,
                frozenAt: award.frozenAt,
              );
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Award list for $_selectedSubjectCode frozen and digitally signed.'),
            backgroundColor: AppColors.wineRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error freezing marks: $e'),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    }
  }

  void _exportAKTUCsv() {
    if (_awardList == null) return;

    final csv = StringBuffer();
    csv.writeln('AKTU INTERNAL ASSESSMENT AWARD LIST');
    csv.writeln('Subject Code,${_awardList!.subjectCode}');
    csv.writeln('Subject Name,${_awardList!.subjectName}');
    csv.writeln('Semester,${_awardList!.semesterNumber}');
    csv.writeln('Session,${_awardList!.academicSession}');
    csv.writeln('Digital Signature,${_awardList!.digitalSignature ?? "UNFROZEN"}');
    csv.writeln('');
    csv.writeln('University Roll No,Student Name,CT1 (30),CT2 (30),PUT (100),Sessional (20),TA (10),Total Internal,Status');

    for (final r in _awardList!.records) {
      if (r.isPractical) {
        csv.writeln(
          '${r.universityRollNo},${r.studentName},-,${r.labContinuousScore},${r.labVivaScore},${r.labAttendanceScore},-,${r.totalInternalMarks},${r.totalInternalMarks >= 20.0 ? "PASS" : "FAIL"}',
        );
      } else {
        csv.writeln(
          '${r.universityRollNo},${r.studentName},${r.ct1Score},${r.ct2Score},${r.putScore},${r.calculatedSessional},${r.taScore},${r.totalInternalMarks},${r.totalInternalMarks >= 12.0 ? "PASS" : "FAIL"}',
        );
      }
    }

    final csvString = csv.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AKTU Award List CSV Export'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Formatted for Dr. A.P.J. Abdul Kalam Technical University portal bulk import:'),
              const SizedBox(height: 12),
              Container(
                height: 200,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csvString,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.wineRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvString));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('AKTU Award List CSV copied to clipboard.'),
                  backgroundColor: AppColors.wineRed,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy CSV'),
          ),
        ],
      ),
    );
  }

  void _openDisputeForRecord(InternalAssessmentModel record) {
    ComplaintsScreen.showRaiseDisputeDialog(
      context: context,
      storage: widget.storage,
      currentUser: widget.currentUser,
      initialTargetType: DisputeTargetType.result,
      initialTargetId: record.subjectCode,
      initialTitle: 'Sessional Mark Dispute for ${record.subjectCode} (${record.subjectName})',
      initialDescription:
          'Contesting evaluation or clerical tabulation for ${record.subjectCode}. Current total internal: ${record.totalInternalMarks}/${record.maxInternalMarks}.',
      initialRequestedResolution: 'Verification of answer script tabulation and clerical re-check',
      onSubmitted: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dispute raised for ${record.subjectCode}. Track under Complaints / Disputes.',
            ),
            backgroundColor: AppColors.wineRed,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'AKTU Sessional & Internal Assessment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
          labelColor: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          tabs: const [
            Tab(text: 'Student Scorecard'),
            Tab(text: 'Faculty Mark Entry'),
            Tab(text: 'Datesheet & Seating'),
            Tab(text: 'AKTU Award List & HOD'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Sessional Records',
            icon: const AppSvgIcon(svgString: AppSvgIcon.refresh, size: 18),
            onPressed: _loadAllData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.wineRed),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppSvgIcon(
                        svgString: AppSvgIcon.alertTriangle,
                        size: 32,
                        color: AppColors.statusRed,
                      ),
                      const SizedBox(height: 12),
                      Text('Error loading sessional data: $_errorMessage'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadAllData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStudentScorecardTab(isDark),
                    _buildFacultyMarkEntryTab(isDark),
                    _buildDatesheetAndSeatingTab(isDark),
                    _buildAKTUReportsAndHODTab(isDark),
                  ],
                ),
    );
  }

  // =========================================================================
  // TAB 1: STUDENT TRANSPARENCY SCORECARD
  // =========================================================================

  Widget _buildStudentScorecardTab(bool isDark) {
    final studentRecords = _records.where((r) {
      return r.studentId == _currentStudentId || r.universityRollNo == _currentStudentId;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStudentHeaderCard(isDark),
              const SizedBox(height: 16),
              if (studentRecords.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: const Center(
                    child: Text('No sessional assessment records found for this student.'),
                  ),
                )
              else
                ...studentRecords.map((rec) => _buildStudentRecordCard(rec, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeaderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.wineRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const AppSvgIcon(
                  svgString: AppSvgIcon.academicCap,
                  size: 20,
                  color: AppColors.wineRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.currentUser?.fullName.isNotEmpty == true
                          ? widget.currentUser!.fullName
                          : 'Student User',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'University Roll No: ${widget.currentUser?.universityRollNo?.isNotEmpty == true ? widget.currentUser!.universityRollNo : "Unassigned"}',
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
                  color: AppColors.wineRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'AKTU Affiliated',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.wineRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'As per AKTU guidelines, internal theory marks are derived from Class Tests (20 scaled) + Teacher Assessment (10). End-term theory exams are evaluated exclusively by the university.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRecordCard(InternalAssessmentModel record, bool isDark) {
    final isPass = record.totalInternalMarks >= (record.maxInternalMarks * 0.40);
    final statusBadge = record.isFrozen
        ? AppColors.greenBadge(isDark)
        : AppColors.yellowBadge(isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          record.subjectCode,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.wineRed,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: record.isPractical
                                ? AppColors.blueBadge(isDark).background
                                : AppColors.neutralBadge(isDark).background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            record.isPractical ? 'Practical Lab' : 'Theory Course',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: record.isPractical
                                  ? AppColors.blueBadge(isDark).text
                                  : AppColors.neutralBadge(isDark).text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.subjectName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBadge.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record.isFrozen ? 'Official Frozen' : 'Provisional Draft',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusBadge.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.isPractical) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildMarkPill('Continuous Lab', '${record.labContinuousScore} / 20', isDark),
                      _buildMarkPill('Internal Viva', '${record.labVivaScore} / 20', isDark),
                      _buildMarkPill('Lab Attendance', '${record.labAttendanceScore} / 10', isDark),
                      _buildMarkPill(
                        'Total Practical Internal',
                        '${record.totalInternalMarks} / 50',
                        isDark,
                        highlight: true,
                        isPass: isPass,
                      ),
                    ],
                  ),
                ] else ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildMarkPill('CT-1 Score', '${record.ct1Score} / 30', isDark),
                      _buildMarkPill('CT-2 Score', '${record.ct2Score} / 30', isDark),
                      _buildMarkPill('PUT Mock', '${record.putScore} / 100', isDark),
                      _buildMarkPill('Sessional Scaled', '${record.calculatedSessional} / 20', isDark),
                      _buildMarkPill('Teacher Assessment', '${record.taScore} / 10', isDark),
                      _buildMarkPill(
                        'Total Theory Internal',
                        '${record.totalInternalMarks} / 30',
                        isDark,
                        highlight: true,
                        isPass: isPass,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'AKTU Formula: ${record.formulaUsed}',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    key: Key('btn-dispute-sessional-${record.subjectCode}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _openDisputeForRecord(record),
                    icon: const Icon(Icons.gavel, size: 14),
                    label: const Text(
                      'Dispute Mark',
                      style: TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkPill(String label, String value, bool isDark, {bool highlight = false, bool isPass = true}) {
    Color bg = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04);
    Color fg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    if (highlight) {
      bg = isPass
          ? AppColors.greenBadge(isDark).background
          : AppColors.redBadge(isDark).background;
      fg = isPass
          ? AppColors.greenBadge(isDark).text
          : AppColors.redBadge(isDark).text;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: FACULTY MARK ENTRY PORTAL
  // =========================================================================

  Widget _buildFacultyMarkEntryTab(bool isDark) {
    final filtered = _records.where((r) => r.subjectCode == _selectedSubjectCode).toList();
    final isSubjectFrozen = filtered.isNotEmpty && filtered.first.isFrozen;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Select Course:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _availableSubjectCodes.map((code) {
                        final isSelected = _selectedSubjectCode == code;
                        return ChoiceChip(
                          label: Text(code),
                          selected: isSelected,
                          selectedColor: AppColors.wineRed.withValues(alpha: 0.18),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedSubjectCode = code;
                              });
                              _refreshAwardList();
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isSubjectFrozen)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.greenBadge(isDark).background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.greenBadge(isDark).text.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: AppColors.greenBadge(isDark).text),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Marks for $_selectedSubjectCode are locked and officially frozen by HOD. Edits are disabled.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.greenBadge(isDark).text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ...filtered.map((r) => _buildFacultyEntryCard(r, isDark, isSubjectFrozen)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyEntryCard(InternalAssessmentModel record, bool isDark, bool isFrozen) {
    final key = '${record.subjectCode}-${record.universityRollNo}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.studentName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Roll No: ${record.universityRollNo}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.wineRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Total Internal: ${record.totalInternalMarks} / ${record.maxInternalMarks.toInt()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (record.isPractical) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMarkInputField('Lab Cont (Max 20)', _labContControllers[key]!, isFrozen),
                _buildMarkInputField('Lab Viva (Max 20)', _labVivaControllers[key]!, isFrozen),
                _buildMarkInputField('Lab Att (Max 10)', _labAttControllers[key]!, isFrozen),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMarkInputField('CT-1 (Max 30)', _ct1Controllers[key]!, isFrozen),
                _buildMarkInputField('CT-2 (Max 30)', _ct2Controllers[key]!, isFrozen),
                _buildMarkInputField('PUT (Max 100)', _putControllers[key]!, isFrozen),
                _buildMarkInputField('TA (Max 10)', _taControllers[key]!, isFrozen),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (!isFrozen)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  key: Key('btn-save-marks-${record.subjectCode}-${record.universityRollNo}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.wineRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => _saveMarksForRecord(record),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Save Marks', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMarkInputField(String label, TextEditingController controller, bool isFrozen) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            enabled: !isFrozen,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: SESSIONAL DATESHEET & SEATING PLAN
  // =========================================================================

  Widget _buildDatesheetAndSeatingTab(bool isDark) {
    final filteredSchedules = _schedules.where((s) {
      if (_selectedScheduleExamType == 'All') return true;
      return s.examType == _selectedScheduleExamType;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Exam Filter:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    children: ['All', 'CT-1', 'CT-2', 'PUT'].map((exam) {
                      final isSelected = _selectedScheduleExamType == exam;
                      return ChoiceChip(
                        label: Text(exam),
                        selected: isSelected,
                        selectedColor: AppColors.wineRed.withValues(alpha: 0.18),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedScheduleExamType = exam;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Official Sessional Schedule', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...filteredSchedules.map((s) => _buildScheduleCard(s, isDark)),
              const SizedBox(height: 24),
              const Text('Interactive Hall Seating Layout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildSeatingGrid(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(SessionalScheduleModel schedule, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.wineRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  schedule.examType,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sem ${schedule.semesterNumber}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${schedule.subjectCode} - ${schedule.subjectName}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      schedule.examDate,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _buildIconDetail(Icons.access_time, schedule.timeSlot, isDark),
                    _buildIconDetail(Icons.meeting_room, 'Hall: ${schedule.hallNumber}', isDark),
                    _buildIconDetail(Icons.person_outline, 'Invigilator: ${schedule.invigilatorName}', isDark),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Roll Range: ${schedule.rollRange}',
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
    );
  }

  Widget _buildIconDetail(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSeatingGrid(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hall $_selectedHallNumber Desk Allocation',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.greenBadge(isDark).background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Verified Layout',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.greenBadge(isDark).text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _seating.map((desk) {
              return Container(
                width: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          desk.deskNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.wineRed),
                        ),
                        Text(
                          'Seat ${desk.seatIndex}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desk.studentName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      desk.studentRollNo,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 4: AKTU AWARD LIST & HOD SIGN-OFF
  // =========================================================================

  Widget _buildAKTUReportsAndHODTab(bool isDark) {
    final award = _awardList;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Course:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Wrap(
                        spacing: 8,
                        children: _availableSubjectCodes.map((c) {
                          final isSelected = _selectedSubjectCode == c;
                          return ChoiceChip(
                            label: Text(c),
                            selected: isSelected,
                            selectedColor: AppColors.wineRed.withValues(alpha: 0.18),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _selectedSubjectCode = c;
                                });
                                _refreshAwardList();
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('btn-export-aktu-csv'),
                        onPressed: _exportAKTUCsv,
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text('Export AKTU CSV', style: TextStyle(fontSize: 11)),
                      ),
                      if (_isHOD && (award == null || !award.isFrozen))
                        ElevatedButton.icon(
                          key: const Key('btn-freeze-aktu-award-list'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.wineRed,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _freezeMarksForSubject,
                          icon: const Icon(Icons.lock, size: 14),
                          label: const Text('Verify & Freeze (HOD)', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (award == null)
                const Center(child: Text('No award list compiled yet.'))
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildKpiCard('Class Average', '${award.averageMarks} / ${award.maxInternalMarks.toInt()}', isDark),
                    _buildKpiCard('Pass Percentage', '${award.passPercentage}%', isDark, isGood: award.passPercentage >= 75.0),
                    _buildKpiCard('Top Score', '${award.highestMarks}', isDark),
                    _buildKpiCard('Lowest Score', '${award.lowestMarks}', isDark),
                    _buildKpiCard('Deficit Danger (<40%)', '${award.deficitCount} students', isDark, isDanger: award.deficitCount > 0),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: award.isFrozen
                        ? AppColors.greenBadge(isDark).background
                        : AppColors.yellowBadge(isDark).background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: award.isFrozen
                          ? AppColors.greenBadge(isDark).text.withValues(alpha: 0.3)
                          : AppColors.yellowBadge(isDark).text.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            award.isFrozen ? Icons.verified : Icons.pending,
                            size: 16,
                            color: award.isFrozen
                                ? AppColors.greenBadge(isDark).text
                                : AppColors.yellowBadge(isDark).text,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            award.isFrozen
                                ? 'Digitally Signed & Frozen by HOD (${award.frozenBy ?? "HOD CSE"})'
                                : 'Pending HOD Audit & Sign-off',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: award.isFrozen
                                  ? AppColors.greenBadge(isDark).text
                                  : AppColors.yellowBadge(isDark).text,
                            ),
                          ),
                        ],
                      ),
                      if (award.isFrozen && award.digitalSignature != null) ...[
                        const SizedBox(height: 6),
                        SelectableText(
                          'SHA-256 Signature: ${award.digitalSignature}',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                      ),
                      columns: [
                        const DataColumn(label: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        if (!award.isPractical) ...[
                          const DataColumn(label: Text('CT1 (/30)', style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataColumn(label: Text('CT2 (/30)', style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataColumn(label: Text('Sessional (/20)', style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataColumn(label: Text('TA (/10)', style: TextStyle(fontWeight: FontWeight.bold))),
                        ] else ...[
                          const DataColumn(label: Text('Lab Cont (/20)', style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataColumn(label: Text('Lab Viva (/20)', style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataColumn(label: Text('Lab Att (/10)', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        const DataColumn(label: Text('Total Internal', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Result', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: award.records.map((r) {
                        final pass = r.totalInternalMarks >= (award.maxInternalMarks * 0.40);
                        return DataRow(
                          cells: [
                            DataCell(Text(r.universityRollNo, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(r.studentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            if (!award.isPractical) ...[
                              DataCell(Text('${r.ct1Score}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${r.ct2Score}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${r.calculatedSessional}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${r.taScore}', style: const TextStyle(fontSize: 12))),
                            ] else ...[
                              DataCell(Text('${r.labContinuousScore}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${r.labVivaScore}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${r.labAttendanceScore}', style: const TextStyle(fontSize: 12))),
                            ],
                            DataCell(
                              Text(
                                '${r.totalInternalMarks} / ${award.maxInternalMarks.toInt()}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: pass
                                      ? AppColors.greenBadge(isDark).background
                                      : AppColors.redBadge(isDark).background,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pass ? 'Pass' : 'Deficit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: pass
                                        ? AppColors.greenBadge(isDark).text
                                        : AppColors.redBadge(isDark).text,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, bool isDark, {bool isGood = false, bool isDanger = false}) {
    Color valColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    if (isGood) valColor = isDark ? AppColors.greenBadge(isDark).text : AppColors.githubGreen;
    if (isDanger) valColor = isDark ? AppColors.redBadge(isDark).text : AppColors.statusRed;

    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }
}
