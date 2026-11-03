import 'package:flutter/material.dart';
import '../models/academic.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

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

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = false;
  List<AttendanceSummaryModel> _summaries = [];
  bool _isMarkingMode = false;

  final String _selectedCourseId = 'course-CS301';
  final String _selectedCourseCode = 'CS301';
  final String _selectedCourseName = 'Operating Systems';
  String _topic = 'Process Synchronization';

  final List<AttendanceRecordModel> _roster = [
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
      studentId: 'usr-rahul_2026_r_btech_1',
      studentName: 'Rahul Sharma',
      campusHandle: 'rahul_2026_r_btech_1',
      status: 'present',
    ),
    AttendanceRecordModel(
      id: 'rec-3',
      sessionId: '',
      studentId: 'usr-sneha_2025_r_btech_2',
      studentName: 'Sneha Patel',
      campusHandle: 'sneha_2025_r_btech_2',
      status: 'present',
    ),
    AttendanceRecordModel(
      id: 'rec-4',
      sessionId: '',
      studentId: 'usr-arjun_2025_l_btech_1',
      studentName: 'Arjun Das',
      campusHandle: 'arjun_2025_l_btech_1',
      status: 'present',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    final data = await widget.storage.getAttendanceSummary(widget.currentUser.id);
    setState(() {
      _summaries = data;
      _loading = false;
    });
  }

  Future<void> _saveAttendanceLocally() async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final sessionId = 'sess-local-${DateTime.now().millisecondsSinceEpoch}';

    final session = AttendanceSessionModel(
      id: sessionId,
      courseId: _selectedCourseId,
      courseCode: _selectedCourseCode,
      courseName: _selectedCourseName,
      scopeCode: 'sec:cse-3a',
      sessionDate: dateStr,
      topic: _topic,
      records: _roster
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
      setState(() => _isMarkingMode = false);
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
        title: Text(_isMarkingMode ? 'Take Class Attendance' : 'Attendance Ledger'),
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
          IconButton(
            icon: AppSvgIcon(
              svgString: _isMarkingMode ? AppSvgIcon.close : AppSvgIcon.attendance,
              size: 18,
            ),
            tooltip: _isMarkingMode ? 'Close' : 'Mark Attendance',
            onPressed: () {
              setState(() => _isMarkingMode = !_isMarkingMode);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isMarkingMode
              ? _buildMarkingView()
              : _buildSummaryView(),
    );
  }

  Widget _buildSummaryView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : AppColors.wineRedSubtle,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.wineRedBorder,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              const AppSvgIcon(
                svgString: AppSvgIcon.info,
                size: 16,
                color: AppColors.wineRed,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Statutory Requirement: Minimum 75% aggregate attendance is mandatory for semester exams.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.wineRedDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _summaries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppSvgIcon(
                        svgString: AppSvgIcon.attendance,
                        size: 48,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No attendance records found for this user',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 16, color: Colors.white),
                        label: const Text('Mark Class Attendance'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.wineRed),
                        onPressed: () => setState(() => _isMarkingMode = true),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _summaries.length,
                  itemBuilder: (context, i) {
                    final s = _summaries[i];
                    final isLow = s.percentage < 75.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                s.courseCode,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isLow
                                      ? AppColors.statusRedSubtle
                                      : AppColors.githubGreenSubtle,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isLow
                                        ? AppColors.statusRedBorder
                                        : AppColors.githubGreenBorder,
                                  ),
                                ),
                                child: Text(
                                  '${s.percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isLow ? AppColors.statusRed : AppColors.githubGreenText,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.courseName,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: s.totalSessions > 0 ? (s.attended / s.totalSessions) : 0,
                              minHeight: 6,
                              backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
                              color: isLow ? AppColors.statusRed : AppColors.githubGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Attended ${s.attended} of ${s.totalSessions} sessions',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMarkingView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppSvgIcon(svgString: AppSvgIcon.academicCap, size: 18, color: AppColors.wineRed),
                  const SizedBox(width: 8),
                  Text(
                    '$_selectedCourseCode - $_selectedCourseName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Session Topic / Lab Module',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: _topic),
                onChanged: (val) => _topic = val,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _roster.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final student = _roster[i];
              final isPresent = student.status == 'present';
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isPresent ? AppColors.githubGreenSubtle : AppColors.statusRedSubtle,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isPresent ? AppColors.githubGreenBorder : AppColors.statusRedBorder,
                        ),
                      ),
                      child: AppSvgIcon(
                        svgString: isPresent ? AppSvgIcon.check : AppSvgIcon.close,
                        size: 14,
                        color: isPresent ? AppColors.githubGreenText : AppColors.statusRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            student.campusHandle,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'present', label: Text('Present', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'absent', label: Text('Absent', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {student.status},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          student.status = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              icon: const AppSvgIcon(svgString: AppSvgIcon.save, size: 16, color: Colors.white),
              label: const Text('Save Locally (Offline-Safe)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wineRed,
                foregroundColor: Colors.white,
              ),
              onPressed: _saveAttendanceLocally,
            ),
          ),
        ),
      ],
    );
  }
}
