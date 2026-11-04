import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/academic.dart';
import '../models/user.dart';
import 'api_service.dart';

class OfflineStorageService {
  final ApiService api;

  // In-memory local cache accessible on Web, Mobile, and Desktop
  final List<CourseModel> _cachedCourses = [];
  final List<TimetableSlotModel> _cachedTimetable = [];
  final List<NoticeModel> _cachedNotices = [];
  final List<AttendanceSummaryModel> _cachedSummaries = [];
  final List<UserModel> _cachedUsers = [];

  // Optical Attendance active session & live verified roster
  OpticalSessionModel? _activeOpticalSession;
  final List<AttendanceRecordModel> _opticalRoster = [];

  OpticalSessionModel? get activeOpticalSession => _activeOpticalSession;
  List<AttendanceRecordModel> get opticalRoster => List.unmodifiable(_opticalRoster);

  // Offline Outbox: Sessions recorded locally waiting to sync with Go backend
  final List<AttendanceSessionModel> _attendanceOutbox = [];

  UserModel? _currentUser;
  bool isOnline = false;

  OfflineStorageService({required this.api});

  UserModel? get currentUser => _currentUser;

  Future<UserModel> authenticate(String identifier, String password) async {
    try {
      isOnline = await api.checkHealth();
      if (isOnline) {
        final user = await api.login(identifier, password);
        _currentUser = user;
        return user;
      }
    } catch (_) {}

    final clean = identifier.trim().toLowerCase();
    final user = getMockUserForHandle(clean);
    _currentUser = user;
    return user;
  }

  void logout() {
    _currentUser = null;
  }

  static UserModel getMockUserForHandle(String clean) {
    if (clean.contains('priya') || clean.contains('emp_1') || clean.contains('faculty')) {
      return UserModel(
        id: 'usr-priya_2024_emp_1',
        campusHandle: 'priya_2024_emp_1',
        firstName: 'Dr. Priya',
        lastName: 'Nair',
        email: 'priya_2024_emp_1@campus.edu',
        archetype: 'employee',
        activeScopes: ['global', 'dept:cse', 'sec:cse-3a', 'unit:student_affairs'],
      );
    } else if (clean.contains('ramesh') || clean.contains('security')) {
      return UserModel(
        id: 'usr-ramesh_2023_emp_1',
        campusHandle: 'ramesh_2023_emp_1',
        firstName: 'Ramesh',
        lastName: 'Singh',
        email: 'ramesh_2023_emp_1@campus.edu',
        archetype: 'employee',
        activeScopes: ['global', 'unit:security', 'facility:gate-1'],
      );
    }
    return UserModel(
      id: 'usr-harish_2025_l_btech_1',
      campusHandle: 'harish_2025_l_btech_1',
      firstName: 'Harish',
      lastName: 'Kumar',
      email: 'harish_2025_l_btech_1@campus.edu',
      archetype: 'student',
      activeScopes: ['global', 'sec:cse-3a', 'club:robotics'],
    );
  }

  List<CourseModel> get cachedCourses => List.unmodifiable(_cachedCourses);
  List<TimetableSlotModel> get cachedTimetable =>
      List.unmodifiable(_cachedTimetable);
  List<NoticeModel> get cachedNotices => List.unmodifiable(_cachedNotices);
  List<AttendanceSummaryModel> get cachedSummaries =>
      List.unmodifiable(_cachedSummaries);
  List<AttendanceSessionModel> get attendanceOutbox =>
      List.unmodifiable(_attendanceOutbox);
  List<UserModel> get cachedUsers => List.unmodifiable(_cachedUsers);

  void _seedDefaultUsersIfEmpty() {
    if (_cachedUsers.isNotEmpty) return;
    _cachedUsers.addAll([
      UserModel(
        id: 'usr-harish_2025_l_btech_1',
        campusHandle: 'harish_2025_l_btech_1',
        firstName: 'Harish',
        lastName: 'Kumar',
        email: 'harish_2025_l_btech_1@campus.edu',
        personalEmail: 'harish.kumar@example.com',
        phone: '+91 98765 43210',
        archetype: 'student',
        universityRollNo: '2025-CS-042',
        admissionApplicationNo: 'APP-2025-0819',
        universityRegNo: 'REG-2025-9921',
        status: 'active',
        activeScopes: ['global', 'sec:cse-3a', 'club:robotics'],
        studentProfile: {
          'admission_year': 2025,
          'entry_type': 'lateral',
          'program': 'btech',
          'current_semester': 3,
          'batch_year': 2029,
        },
      ),
      UserModel(
        id: 'usr-priya_2024_emp_1',
        campusHandle: 'priya_2024_emp_1',
        firstName: 'Dr. Priya',
        lastName: 'Nair',
        email: 'priya_2024_emp_1@campus.edu',
        personalEmail: 'p.nair@academic-research.org',
        phone: '+91 98111 22334',
        archetype: 'employee',
        universityRollNo: 'EMP-2024-0012',
        status: 'active',
        activeScopes: ['global', 'dept:cse', 'sec:cse-3a', 'unit:student_affairs'],
        employeeRecord: {
          'joining_date': '2024-01-15T00:00:00Z',
          'employee_code': 'FAC-CS-012',
          'employment_type': 'permanent',
          'is_academic': true,
          'is_administrative': true,
        },
        academicProfile: {
          'academic_rank': 'Professor',
          'cabin_location': 'LH-302, Academic Block B',
          'departments': ['dept:cse'],
        },
        administrativeProfile: {
          'primary_unit': 'unit:student_affairs',
          'designation': 'Dean of Student Affairs',
          'office_location': 'Administrative Complex Room 104',
        },
      ),
      UserModel(
        id: 'usr-ramesh_2023_emp_1',
        campusHandle: 'ramesh_2023_emp_1',
        firstName: 'Ramesh',
        lastName: 'Singh',
        email: 'ramesh_2023_emp_1@campus.edu',
        personalEmail: 'ramesh.singh@campus-ops.net',
        phone: '+91 97222 33445',
        archetype: 'employee',
        universityRollNo: 'EMP-2023-0089',
        status: 'active',
        activeScopes: ['global', 'unit:security', 'facility:gate-1'],
        employeeRecord: {
          'joining_date': '2023-06-01T00:00:00Z',
          'employee_code': 'ADM-SEC-089',
          'employment_type': 'permanent',
          'is_academic': false,
          'is_administrative': true,
        },
        administrativeProfile: {
          'primary_unit': 'unit:security',
          'designation': 'Chief Security Officer',
          'office_location': 'Main Gate Security HQ',
        },
      ),
      UserModel(
        id: 'usr-vikram_2021_r_btech_1',
        campusHandle: 'vikram_2021_r_btech_1',
        firstName: 'Vikram',
        lastName: 'Malhotra',
        email: 'vikram_2021_r_btech_1@campus.edu',
        personalEmail: 'vikram.malhotra@alumni.org',
        phone: '+91 99000 11223',
        archetype: 'student',
        universityRollNo: '2021-CS-001',
        admissionApplicationNo: 'APP-2021-0044',
        status: 'graduated',
        discontinuationReason: 'Graduated Class of 2025 (B.Tech CSE with First Class Honors)',
        discontinuedAt: '2025-06-30T10:00:00Z',
        discontinuedBy: 'usr-priya_2024_emp_1',
        activeScopes: [],
        studentProfile: {
          'admission_year': 2021,
          'entry_type': 'regular',
          'program': 'btech',
          'current_semester': 8,
          'batch_year': 2025,
        },
      ),
    ]);
  }

  Future<List<UserModel>> getUsers({
    String? archetype,
    String? status,
    String? search,
    bool forceRefresh = false,
  }) async {
    _seedDefaultUsersIfEmpty();
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final users = await api.fetchUsers(
          archetype: archetype,
          status: status,
          search: search,
        );
        _cachedUsers
          ..clear()
          ..addAll(users);
        return _cachedUsers;
      } catch (_) {}
    }

    // Offline filter
    return _cachedUsers.where((u) {
      if (archetype != null && archetype.isNotEmpty && archetype != 'all') {
        if (u.archetype != archetype) return false;
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        if (status == 'inactive') {
          if (u.isActive) return false;
        } else if (u.status.toLowerCase() != status.toLowerCase()) {
          return false;
        }
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        final match = u.fullName.toLowerCase().contains(q) ||
            u.campusHandle.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.universityRollNo?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  Future<UserModel> getUserProfile(String idOrHandle) async {
    _seedDefaultUsersIfEmpty();
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final profile = await api.fetchUserProfile(idOrHandle);
        final idx = _cachedUsers.indexWhere((u) => u.id == profile.id || u.campusHandle == profile.campusHandle);
        if (idx != -1) {
          _cachedUsers[idx] = profile;
        } else {
          _cachedUsers.add(profile);
        }
        return profile;
      } catch (_) {}
    }

    final cached = _cachedUsers.firstWhere(
      (u) => u.id == idOrHandle || u.campusHandle == idOrHandle,
      orElse: () => UserModel(
        id: idOrHandle,
        campusHandle: idOrHandle,
        firstName: 'Campus',
        lastName: 'Member',
        email: '$idOrHandle@campus.edu',
        archetype: 'student',
        status: 'active',
      ),
    );
    return cached;
  }

  Future<UserModel> createStudent(Map<String, dynamic> req) async {
    _seedDefaultUsersIfEmpty();
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final user = await api.createStudent(req);
        _cachedUsers.insert(0, user);
        return user;
      } catch (_) {}
    }

    // Offline optimistic creation
    final firstName = (req['first_name'] ?? 'student').toString().toLowerCase();
    final year = req['admission_year'] ?? 2025;
    final entry = (req['entry_type'] ?? 'regular').toString().toLowerCase().substring(0, 1);
    final prog = (req['program'] ?? 'btech').toString().toLowerCase();
    final handle = '${firstName}_${year}_${entry}_${prog}_${_cachedUsers.length + 1}';

    final newUser = UserModel(
      id: 'usr-$handle',
      campusHandle: handle,
      firstName: req['first_name'] ?? '',
      lastName: req['last_name'] ?? '',
      email: req['email'] ?? '$handle@campus.edu',
      personalEmail: req['personal_email'],
      phone: req['phone'],
      archetype: 'student',
      admissionApplicationNo: req['admission_application_no'],
      status: 'active',
      activeScopes: ['global', 'sec:cse-3a'],
      studentProfile: {
        'admission_year': year,
        'entry_type': req['entry_type'] ?? 'regular',
        'program': prog,
        'current_semester': 1,
        'batch_year': year + 4,
      },
    );
    _cachedUsers.insert(0, newUser);
    return newUser;
  }

  Future<UserModel> createEmployee(Map<String, dynamic> req) async {
    _seedDefaultUsersIfEmpty();
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final user = await api.createEmployee(req);
        _cachedUsers.insert(0, user);
        return user;
      } catch (_) {}
    }

    // Offline optimistic creation
    final firstName = (req['first_name'] ?? 'emp').toString().toLowerCase();
    final year = req['joining_year'] ?? 2025;
    final handle = '${firstName}_${year}_emp_${_cachedUsers.length + 1}';

    final newUser = UserModel(
      id: 'usr-$handle',
      campusHandle: handle,
      firstName: req['first_name'] ?? '',
      lastName: req['last_name'] ?? '',
      email: req['email'] ?? '$handle@campus.edu',
      personalEmail: req['personal_email'],
      phone: req['phone'],
      archetype: 'employee',
      status: 'active',
      activeScopes: ['global'],
      employeeRecord: {
        'joining_date': DateTime.now().toIso8601String(),
        'employment_type': req['employment_type'] ?? 'permanent',
        'is_academic': req['is_academic'] == true,
        'is_administrative': req['is_administrative'] == true,
      },
      academicProfile: req['is_academic'] == true
          ? {
              'academic_rank': req['academic_rank'] ?? 'Assistant Professor',
              'cabin_location': req['cabin_location'],
              'departments': req['department_affiliations'] ?? ['dept:cse'],
            }
          : null,
      administrativeProfile: req['is_administrative'] == true
          ? {
              'primary_unit': req['primary_unit'] ?? 'registrar',
              'designation': req['designation'] ?? 'Staff',
              'office_location': req['office_location'],
            }
          : null,
    );
    _cachedUsers.insert(0, newUser);
    return newUser;
  }

  Future<UserModel> discontinueUser({
    required String userId,
    required String status,
    required String reason,
    required String discontinuedBy,
  }) async {
    _seedDefaultUsersIfEmpty();
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final updated = await api.discontinueUser(
          userId: userId,
          status: status,
          reason: reason,
          discontinuedBy: discontinuedBy,
        );
        final idx = _cachedUsers.indexWhere((u) => u.id == userId);
        if (idx != -1) {
          _cachedUsers[idx] = updated;
        }
        return updated;
      } catch (_) {}
    }

    // Offline mutation
    final idx = _cachedUsers.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final u = _cachedUsers[idx];
      final updated = u.copyWith(
        status: status,
        discontinuationReason: reason,
        discontinuedAt: DateTime.now().toIso8601String(),
        discontinuedBy: discontinuedBy,
        activeScopes: [], // Revoked
      );
      _cachedUsers[idx] = updated;
      return updated;
    }
    throw Exception('User not found in cache');
  }

  Future<UserModel> reactivateUser(String userId) async {
    _seedDefaultUsersIfEmpty();
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final updated = await api.reactivateUser(userId);
        final idx = _cachedUsers.indexWhere((u) => u.id == userId);
        if (idx != -1) {
          _cachedUsers[idx] = updated;
        }
        return updated;
      } catch (_) {}
    }

    // Offline mutation
    final idx = _cachedUsers.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final u = _cachedUsers[idx];
      final updated = u.copyWith(
        status: 'active',
        discontinuationReason: '',
        discontinuedAt: null,
        activeScopes: ['global'],
      );
      _cachedUsers[idx] = updated;
      return updated;
    }
    throw Exception('User not found in cache');
  }

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

  // ----------------------------------------------------
  // OPTICAL DATA TRANSFER ATTENDANCE (RAPIDLY CHANGING QR)
  // ----------------------------------------------------

  Future<OpticalSessionModel> startOpticalSession({
    required String courseId,
    required String courseCode,
    required String courseName,
    required String scopeCode,
    required String roomNumber,
    required String markedByUserId,
    required String markedByName,
    int refreshIntervalMs = 1500,
  }) async {
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final sess = await api.startOpticalSession({
          'course_id': courseId,
          'course_code': courseCode,
          'course_name': courseName,
          'scope_code': scopeCode,
          'room_number': roomNumber,
          'marked_by_user_id': markedByUserId,
          'marked_by_name': markedByName,
          'refresh_interval_ms': refreshIntervalMs,
        });
        _activeOpticalSession = sess;
        _opticalRoster.clear();
        return sess;
      } catch (_) {}
    }

    // Local / Offline fallback session
    final now = DateTime.now();
    final localSecret = 'loc_secret_${now.millisecondsSinceEpoch}';
    final sessionId = 'opt-sess-${now.millisecondsSinceEpoch}';

    final session = OpticalSessionModel(
      id: sessionId,
      courseId: courseId,
      courseCode: courseCode,
      courseName: courseName,
      scopeCode: scopeCode,
      roomNumber: roomNumber,
      markedByUserId: markedByUserId,
      markedByName: markedByName,
      sessionSecret: localSecret,
      refreshIntervalMs: refreshIntervalMs,
      startedAt: now,
      expiresAt: now.add(const Duration(hours: 2)),
      isActive: true,
      verifiedRecords: [],
    );

    _activeOpticalSession = session;
    _opticalRoster.clear();
    return session;
  }

  Future<OpticalVerificationResult> verifyOpticalAttendance({
    required OpticalFramePacket packet,
    required UserModel student,
  }) async {
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final res = await api.verifyOpticalAttendance({
          'session_id': packet.sessionId,
          'student_id': student.id,
          'student_name': student.fullName,
          'campus_handle': student.campusHandle,
          'sequence': packet.sequence,
          'timestamp': packet.timestamp,
          'nonce': packet.nonce,
          'signature': packet.signature,
        });

        // Add to local optical roster cache
        final rec = AttendanceRecordModel(
          id: 'rec-${packet.sessionId}-${student.id}',
          sessionId: packet.sessionId,
          studentId: student.id,
          studentName: student.fullName,
          campusHandle: student.campusHandle,
          status: 'present',
        );
        if (!_opticalRoster.any((r) => r.studentId == student.id)) {
          _opticalRoster.insert(0, rec);
        }

        return res;
      } catch (e) {
        // Re-throw specific errors (e.g., expired or duplicate)
        rethrow;
      }
    }

    // Offline optical verification
    if (packet.isExpired(maxAgeSeconds: 8)) {
      throw Exception('Expired optical frame (#${packet.sequence}). Scan live broadcast.');
    }

    // If local active session matches secret, verify HMAC
    if (_activeOpticalSession != null && _activeOpticalSession!.id == packet.sessionId) {
      final key = utf8.encode(_activeOpticalSession!.sessionSecret);
      final bytes = utf8.encode('${packet.sessionId}:${packet.sequence}:${packet.timestamp}:${packet.nonce}');
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes).toString();
      final expectedSig = digest.length > 16 ? digest.substring(0, 16) : digest;

      if (packet.signature != expectedSig && !packet.signature.startsWith(expectedSig)) {
        throw Exception('Invalid optical packet cryptographic signature');
      }
    }

    if (_opticalRoster.any((r) => r.studentId == student.id)) {
      throw Exception('Attendance already verified for ${student.fullName} in this session');
    }

    final now = DateTime.now();
    final rec = AttendanceRecordModel(
      id: 'rec-${packet.sessionId}-${student.id}',
      sessionId: packet.sessionId,
      studentId: student.id,
      studentName: student.fullName,
      campusHandle: student.campusHandle,
      status: 'present',
    );
    _opticalRoster.insert(0, rec);

    // Queue session to attendance outbox for delta sync
    final localSession = AttendanceSessionModel(
      id: packet.sessionId,
      courseId: packet.courseCode,
      courseCode: packet.courseCode,
      courseName: packet.courseName,
      scopeCode: 'sec:cse-3a',
      sessionDate: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      topic: 'Lecture in ${packet.room} (Optical Stream)',
      records: List.from(_opticalRoster),
    );
    _attendanceOutbox.removeWhere((s) => s.id == packet.sessionId);
    _attendanceOutbox.add(localSession);

    return OpticalVerificationResult(
      verified: true,
      message: 'Verified via Optical Packet #${packet.sequence}',
      sessionId: packet.sessionId,
      courseCode: packet.courseCode,
      courseName: packet.courseName,
      studentName: student.fullName,
      handle: student.campusHandle,
      sequence: packet.sequence,
      recordedAt: now,
    );
  }

  Future<List<AttendanceRecordModel>> getOpticalRoster(String sessionId) async {
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        final list = await api.fetchOpticalSessionRoster(sessionId);
        _opticalRoster
          ..clear()
          ..addAll(list);
        return _opticalRoster;
      } catch (_) {}
    }
    return _opticalRoster;
  }

  Future<void> endOpticalSession(String sessionId) async {
    isOnline = await api.checkHealth();
    if (isOnline) {
      try {
        await api.endOpticalSession(sessionId);
      } catch (_) {}
    }
    _activeOpticalSession = null;
  }
}
