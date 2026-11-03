import 'dart:async';
import '../models/academic.dart';
import 'api_service.dart';

class OfflineStorageService {
  final ApiService api;

  // In-memory local cache accessible on Web, Mobile, and Desktop
  final List<CourseModel> _cachedCourses = [];
  final List<TimetableSlotModel> _cachedTimetable = [];
  final List<NoticeModel> _cachedNotices = [];
  final List<AttendanceSummaryModel> _cachedSummaries = [];

  // Offline Outbox: Sessions recorded locally waiting to sync with Go backend
  final List<AttendanceSessionModel> _attendanceOutbox = [];

  bool isOnline = false;

  OfflineStorageService({required this.api});

  List<CourseModel> get cachedCourses => List.unmodifiable(_cachedCourses);
  List<TimetableSlotModel> get cachedTimetable =>
      List.unmodifiable(_cachedTimetable);
  List<NoticeModel> get cachedNotices => List.unmodifiable(_cachedNotices);
  List<AttendanceSummaryModel> get cachedSummaries =>
      List.unmodifiable(_cachedSummaries);
  List<AttendanceSessionModel> get attendanceOutbox =>
      List.unmodifiable(_attendanceOutbox);

  int get pendingSyncCount => _attendanceOutbox.length;

  // Check connectivity and sync outbox
  Future<void> refreshConnectivityAndSync(String userId) async {
    isOnline = await api.checkHealth();
    if (isOnline && _attendanceOutbox.isNotEmpty) {
      await flushOutbox(userId);
    }
  }

  // Record an attendance session offline (always succeeds instantly)
  void recordOfflineAttendance(AttendanceSessionModel session) {
    _attendanceOutbox.add(session);
  }

  // Push pending outbox to backend
  Future<bool> flushOutbox(String userId) async {
    if (_attendanceOutbox.isEmpty) return true;
    try {
      final success = await api.pushAttendanceBatch(userId, _attendanceOutbox);
      if (success) {
        _attendanceOutbox.clear();
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Load and cache fresh timetable from network (or keep cached if offline)
  Future<List<TimetableSlotModel>> getTimetable(String scope) async {
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final slots = await api.fetchTimetable(scope);
        _cachedTimetable
          ..clear()
          ..addAll(slots);
        return _cachedTimetable;
      } catch (_) {}
    }
    return _cachedTimetable;
  }

  // Load and cache notices
  Future<List<NoticeModel>> getNotices(List<String> scopes) async {
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final notices = await api.fetchNotices(scopes);
        _cachedNotices
          ..clear()
          ..addAll(notices);
        return _cachedNotices;
      } catch (_) {}
    }
    return _cachedNotices;
  }

  // Load and cache student attendance summary
  Future<List<AttendanceSummaryModel>> getAttendanceSummary(
      String studentId) async {
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final summaries = await api.fetchAttendanceSummary(studentId);
        _cachedSummaries
          ..clear()
          ..addAll(summaries);
        return _cachedSummaries;
      } catch (_) {}
    }
    return _cachedSummaries;
  }
}
