import 'package:flutter/material.dart';
import '../models/academic.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';

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

  // Marking session state
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
            'Attendance saved locally! (${widget.storage.pendingSyncCount} pending sync)',
          ),
          backgroundColor: Colors.teal.shade700,
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
            success ? 'Synced all pending attendance to Go backend!' : 'Backend offline. Kept safe locally.',
          ),
          backgroundColor: success ? Colors.green.shade700 : Colors.amber.shade900,
        ),
      );
      _loadSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMarkingMode ? 'Take Attendance' : 'Attendance Overview'),
        actions: [
          if (widget.storage.pendingSyncCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                avatar: const Icon(Icons.cloud_upload, size: 18, color: Colors.white),
                label: Text(
                  '${widget.storage.pendingSyncCount} Pending',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.orange.shade800,
                onPressed: _syncOutbox,
              ),
            ),
          IconButton(
            icon: Icon(_isMarkingMode ? Icons.close : Icons.playlist_add_check),
            tooltip: _isMarkingMode ? 'Close' : 'Mark Attendance',
            onPressed: () {
              setState(() => _isMarkingMode = !_isMarkingMode);
            },
          ),
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Minimum 75% attendance is required to sit for end-semester examinations.',
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
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
                      Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No attendance records found yet.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Mark Class Attendance'),
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
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  s.courseCode,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${s.percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isLow ? Colors.red.shade900 : Colors.green.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(s.courseName, style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: s.totalSessions > 0 ? (s.attended / s.totalSessions) : 0,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                color: isLow ? Colors.red : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Attended ${s.attended} of ${s.totalSessions} sessions',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMarkingView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    '$_selectedCourseCode - $_selectedCourseName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Lecture Topic / Lab Module',
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
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPresent ? Colors.green.shade100 : Colors.red.shade100,
                  child: Icon(
                    isPresent ? Icons.check : Icons.close,
                    color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                title: Text(student.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(student.campusHandle),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'present', label: Text('Present')),
                    ButtonSegment(value: 'absent', label: Text('Absent')),
                  ],
                  selected: {student.status},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      student.status = newSelection.first;
                    });
                  },
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Locally (Offline-Safe)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
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
