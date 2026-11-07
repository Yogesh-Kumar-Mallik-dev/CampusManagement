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
  final List<DepartmentModel> _cachedDepartments = [];
  final List<ProgramModel> _cachedPrograms = [];
  final List<SubjectModel> _cachedSubjects = [];
  final List<SemesterModel> _cachedSemesters = [];
  final List<SectionModel> _cachedSections = [];
  final Map<String, String> _studentSectionMap = {};
  final Map<String, String> _studentProgramMap = {};
  final Map<String, List<SectionSubjectAllocationModel>> _sectionAllocations = {};
  final Map<String, List<SyllabusVersionModel>> _cachedSyllabusVersions = {};
  final Map<String, List<LabBatchModel>> _cachedSectionBatches = {};
  final Map<String, List<FacultyAllocationModel>> _cachedSectionAllocations = {};
  final Map<String, String> _studentBatchMap = {};

  // Optical Attendance active session & live verified roster
  OpticalSessionModel? _activeOpticalSession;
  final List<AttendanceRecordModel> _opticalRoster = [];

  OpticalSessionModel? get activeOpticalSession => _activeOpticalSession;
  List<AttendanceRecordModel> get opticalRoster => List.unmodifiable(_opticalRoster);

  // Offline Outbox: Sessions recorded locally waiting to sync with Go backend
  final List<AttendanceSessionModel> _attendanceOutbox = [];

  UserModel? _currentUser;
  bool isOnline = false;
  DateTime? _lastHealthCheckTime;
  bool _isCheckingHealth = false;

  OfflineStorageService({required this.api}) {
    _lastHealthCheckTime = DateTime.now();
    _seedDefaultUsersIfEmpty();
    _seedDefaultAcademicHierarchyIfEmpty();
    _seedDefaultTimetableIfEmpty();
    _seedDefaultNoticesIfEmpty();
    if (_cachedSummaries.isEmpty) {
      _cachedSummaries.addAll(_getDefaultStudentSummaries());
    }
  }

  UserModel? get currentUser => _currentUser;

  Future<bool> checkConnectivity({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastHealthCheckTime != null &&
        now.difference(_lastHealthCheckTime!) < const Duration(seconds: 8)) {
      return isOnline;
    }
    if (_isCheckingHealth) {
      return isOnline;
    }
    _isCheckingHealth = true;
    try {
      isOnline = await api.checkHealth();
      _lastHealthCheckTime = DateTime.now();
    } catch (_) {
      isOnline = false;
    } finally {
      _isCheckingHealth = false;
    }
    return isOnline;
  }

  Future<UserModel> authenticate(String identifier, String password) async {
    try {
      await checkConnectivity(force: true);
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
  List<UserModel> get cachedUsers {
    _seedDefaultUsersIfEmpty();
    return List.unmodifiable(_cachedUsers);
  }
  List<DepartmentModel> get cachedDepartments {
    _seedDefaultAcademicHierarchyIfEmpty();
    return List.unmodifiable(_cachedDepartments);
  }
  List<ProgramModel> get cachedPrograms {
    _seedDefaultAcademicHierarchyIfEmpty();
    return List.unmodifiable(_cachedPrograms);
  }
  List<SubjectModel> get cachedSubjects {
    _seedDefaultAcademicHierarchyIfEmpty();
    return List.unmodifiable(_cachedSubjects);
  }
  List<SemesterModel> get cachedSemesters {
    _seedDefaultAcademicHierarchyIfEmpty();
    return List.unmodifiable(_cachedSemesters);
  }
  List<SectionModel> get cachedSections {
    _seedDefaultAcademicHierarchyIfEmpty();
    return List.unmodifiable(_cachedSections);
  }

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
      UserModel(
        id: 'usr-mukesh_2025_ext_1',
        campusHandle: 'mukesh_2025_ext_1',
        firstName: 'Mukesh',
        lastName: 'Verma',
        email: 'mukesh_2025_ext_1@campus.edu',
        personalEmail: 'mukesh.verma@sodexo-dining.com',
        phone: '+91 98333 44556',
        archetype: 'external',
        universityRollNo: 'GP-2025-0891',
        status: 'active',
        activeScopes: ['gate:main', 'building:canteen'],
        contractorProfile: {
          'onboarding_year': 2025,
          'vendor_organization': 'Sodexo Campus Dining',
          'service_type': 'canteen',
          'contract_expires_at': DateTime.now().add(const Duration(days: 300)).toIso8601String(),
          'gate_pass_id': 'GP-2025-0891',
          'supervisor_name': 'Anil Kapoor',
          'supervisor_phone': '+91 98222 11000',
          'permitted_scopes': ['gate:main', 'building:canteen'],
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
    await checkConnectivity();
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
    await checkConnectivity();
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
    await checkConnectivity();
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
    await checkConnectivity();
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

  Future<UserModel> createContractor(Map<String, dynamic> req) async {
    _seedDefaultUsersIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final user = await api.createContractor(req);
        _cachedUsers.insert(0, user);
        return user;
      } catch (_) {}
    }

    // Offline Contractor Creation
    final first = (req['first_name'] ?? 'external').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final year = req['onboarding_year'] ?? DateTime.now().year;
    final prefix = '${first}_${year}_ext';
    final count = _cachedUsers.where((u) => u.campusHandle.startsWith(prefix)).length + 1;
    final handle = '${prefix}_$count';
    final gatePass = req['gate_pass_id']?.toString().isNotEmpty == true
        ? req['gate_pass_id'].toString()
        : 'GP-$year-$handle';

    final newUser = UserModel(
      id: 'usr-$handle',
      campusHandle: handle,
      firstName: req['first_name'] ?? '',
      lastName: req['last_name'] ?? '',
      email: req['email'] ?? '$handle@campus.edu',
      personalEmail: req['personal_email'],
      phone: req['phone'],
      archetype: 'external',
      universityRollNo: gatePass,
      status: 'active',
      activeScopes: req['permitted_scopes'] is List ? List<String>.from(req['permitted_scopes']) : ['gate:main'],
      contractorProfile: {
        'onboarding_year': year,
        'vendor_organization': req['vendor_organization'] ?? 'Campus External Vendor',
        'service_type': req['service_type'] ?? 'canteen',
        'contract_expires_at': req['contract_expires_at'] ?? DateTime.now().add(const Duration(days: 365)).toIso8601String(),
        'gate_pass_id': gatePass,
        'supervisor_name': req['supervisor_name'],
        'supervisor_phone': req['supervisor_phone'],
        'permitted_scopes': req['permitted_scopes'] is List ? req['permitted_scopes'] : ['gate:main'],
      },
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
    await checkConnectivity();
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
    await checkConnectivity();
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
    await checkConnectivity(force: false);
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
    _seedDefaultTimetableIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final slots = await api.fetchTimetable(scope);
        if (slots.isNotEmpty) {
          _cachedTimetable
            ..clear()
            ..addAll(slots);
        }
        return _cachedTimetable;
      } catch (_) {}
    }
    return _cachedTimetable;
  }

  Future<TimetableSlotModel> saveTimetableSlot(TimetableSlotModel slot) async {
    _seedDefaultTimetableIfEmpty();
    final idx = _cachedTimetable.indexWhere((s) =>
        s.id == slot.id ||
        (s.dayOfWeek == slot.dayOfWeek && s.startTime == slot.startTime));
    if (idx >= 0) {
      _cachedTimetable[idx] = slot;
    } else {
      _cachedTimetable.add(slot);
    }
    await checkConnectivity();
    if (isOnline) {
      try {
        await api.saveTimetableSlot(slot);
      } catch (_) {}
    }
    return slot;
  }

  Future<bool> deleteTimetableSlot(String id) async {
    _seedDefaultTimetableIfEmpty();
    _cachedTimetable.removeWhere((s) => s.id == id);
    await checkConnectivity();
    if (isOnline) {
      try {
        await api.deleteTimetableSlot(id);
      } catch (_) {}
    }
    return true;
  }

  final Map<int, List<TimetableSlotModel>> _backupDaySchedules = {};

  /// Declares an entire academic day (all 8 one-hour blocks from 9 AM to 5 PM) as Off.
  Future<void> declareDayOff({
    required int dayOfWeek,
    required String reason,
    required String scopeCode,
  }) async {
    _seedDefaultTimetableIfEmpty();

    // 1. Backup current non-off slots for restoration
    final currentDaySlots = _cachedTimetable
        .where((s) => s.dayOfWeek == dayOfWeek)
        .map((s) => s.copyWith())
        .toList();
    if (currentDaySlots.any((s) => !s.isOff)) {
      _backupDaySchedules[dayOfWeek] = currentDaySlots;
    }

    // 2. Mark all 8 canonical blocks as declared off
    for (int i = 0; i < 8; i++) {
      final start = '${(9 + i).toString().padLeft(2, '0')}:00';
      final end = '${(10 + i).toString().padLeft(2, '0')}:00';
      final offSlot = TimetableSlotModel(
        id: 'slot-off-day-$dayOfWeek-$start',
        courseId: '',
        courseCode: 'OFF',
        courseName: reason.isNotEmpty ? reason : 'Declared Day Off',
        scopeCode: scopeCode,
        instructorName: '',
        dayOfWeek: dayOfWeek,
        startTime: start,
        endTime: end,
        roomNumber: '-',
        slotType: 'off',
      );
      await saveTimetableSlot(offSlot);
    }
  }

  /// Restores the academic schedule for a day that was previously declared Off.
  Future<void> restoreDaySchedule({
    required int dayOfWeek,
    required String scopeCode,
  }) async {
    _seedDefaultTimetableIfEmpty();
    final backup = _backupDaySchedules[dayOfWeek];
    if (backup != null && backup.isNotEmpty) {
      for (final slot in backup) {
        await saveTimetableSlot(slot);
      }
      _backupDaySchedules.remove(dayOfWeek);
    } else {
      // Re-seed default slots for this day from canonical defaults
      final defaults = _getDefaultDaySlots(dayOfWeek, scopeCode);
      for (final slot in defaults) {
        await saveTimetableSlot(slot);
      }
    }
  }

  List<TimetableSlotModel> _getDefaultDaySlots(int dayOfWeek, String scopeCode) {
    return _buildCanonicalDefaultSlots()
        .where((s) => s.dayOfWeek == dayOfWeek)
        .toList();
  }

  // Load and cache notices
  Future<List<NoticeModel>> getNotices(List<String> scopes) async {
    _seedDefaultNoticesIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final notices = await api.fetchNotices(scopes);
        if (notices.isNotEmpty) {
          _cachedNotices
            ..clear()
            ..addAll(notices);
        }
        return _cachedNotices;
      } catch (_) {}
    }
    return _cachedNotices;
  }

  void _seedDefaultTimetableIfEmpty() {
    if (_cachedTimetable.isNotEmpty) return;
    _cachedTimetable.addAll(_buildCanonicalDefaultSlots());
  }

  List<TimetableSlotModel> _buildCanonicalDefaultSlots() {
    return [
      // ==========================================
      // MONDAY (Day 1): 9:00 AM - 5:00 PM (8 Blocks)
      // ==========================================
      TimetableSlotModel(
        id: 'slot-mon-1',
        courseId: 'CS301',
        courseCode: 'CS301',
        courseName: 'Operating Systems',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. Priya Nair',
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '10:00',
        roomNumber: 'LHC-302',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-mon-2',
        courseId: 'CS302',
        courseCode: 'CS302',
        courseName: 'Database Management Systems',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Ramesh Singh',
        dayOfWeek: 1,
        startTime: '10:00',
        endTime: '11:00',
        roomNumber: 'LHC-204',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-mon-3',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Library & Open Research',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 1,
        startTime: '11:00',
        endTime: '12:00',
        roomNumber: 'Central Library',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-mon-4',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Midday Recess & Lunch',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 1,
        startTime: '12:00',
        endTime: '13:00',
        roomNumber: 'Campus Cafeteria',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-mon-5',
        courseId: 'CS304',
        courseCode: 'CS304',
        courseName: 'Deep Learning & Neural Networks Lab',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. Priya Nair',
        dayOfWeek: 1,
        startTime: '13:00',
        endTime: '14:00',
        roomNumber: 'CS-Lab-3',
        slotType: 'lab',
      ),
      TimetableSlotModel(
        id: 'slot-mon-6',
        courseId: 'CS304',
        courseCode: 'CS304',
        courseName: 'Deep Learning Practical Session',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. Priya Nair',
        dayOfWeek: 1,
        startTime: '14:00',
        endTime: '15:00',
        roomNumber: 'CS-Lab-3',
        slotType: 'lab',
      ),
      TimetableSlotModel(
        id: 'slot-mon-7',
        courseId: 'CS303',
        courseCode: 'CS303',
        courseName: 'Design & Analysis of Algorithms',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Alan Turing',
        dayOfWeek: 1,
        startTime: '15:00',
        endTime: '16:00',
        roomNumber: 'LHC-101',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-mon-8',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Evening Dismissal',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 1,
        startTime: '16:00',
        endTime: '17:00',
        roomNumber: '-',
        slotType: 'off',
      ),

      // ==========================================
      // TUESDAY (Day 2): 9:00 AM - 5:00 PM (8 Blocks)
      // ==========================================
      TimetableSlotModel(
        id: 'slot-tue-1',
        courseId: 'MA101',
        courseCode: 'MA101',
        courseName: 'Discrete Mathematics',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Gauss',
        dayOfWeek: 2,
        startTime: '09:00',
        endTime: '10:00',
        roomNumber: 'LHC-105',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-tue-2',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Faculty Consultation & Peer Study',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 2,
        startTime: '10:00',
        endTime: '11:00',
        roomNumber: 'Study Hall B',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-tue-3',
        courseId: 'CS301',
        courseCode: 'CS301',
        courseName: 'Operating Systems',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. Priya Nair',
        dayOfWeek: 2,
        startTime: '11:00',
        endTime: '12:00',
        roomNumber: 'LHC-302',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-tue-4',
        courseId: 'CS303',
        courseCode: 'CS303',
        courseName: 'Algorithms Tutorial & Problem Solving',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Alan Turing',
        dayOfWeek: 2,
        startTime: '12:00',
        endTime: '13:00',
        roomNumber: 'LHC-101',
        slotType: 'tutorial',
      ),
      TimetableSlotModel(
        id: 'slot-tue-5',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Midday Recess & Lunch',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 2,
        startTime: '13:00',
        endTime: '14:00',
        roomNumber: 'Campus Cafeteria',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-tue-6',
        courseId: 'CS302',
        courseCode: 'CS302',
        courseName: 'Database Systems Lab',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Ramesh Singh',
        dayOfWeek: 2,
        startTime: '14:00',
        endTime: '15:00',
        roomNumber: 'CS-Lab-2',
        slotType: 'lab',
      ),
      TimetableSlotModel(
        id: 'slot-tue-7',
        courseId: 'CS302',
        courseCode: 'CS302',
        courseName: 'Database Query Optimization Workshop',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Ramesh Singh',
        dayOfWeek: 2,
        startTime: '15:00',
        endTime: '16:00',
        roomNumber: 'CS-Lab-2',
        slotType: 'lab',
      ),
      TimetableSlotModel(
        id: 'slot-tue-8',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Campus Hours Concluded',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 2,
        startTime: '16:00',
        endTime: '17:00',
        roomNumber: '-',
        slotType: 'off',
      ),

      // ==========================================
      // WEDNESDAY (Day 3): 9:00 AM - 5:00 PM (8 Blocks)
      // ==========================================
      TimetableSlotModel(
        id: 'slot-wed-1',
        courseId: 'CS304',
        courseCode: 'CS304',
        courseName: 'Deep Learning & Neural Networks',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. Priya Nair',
        dayOfWeek: 3,
        startTime: '09:00',
        endTime: '10:00',
        roomNumber: 'LHC-302',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-wed-2',
        courseId: 'CS302',
        courseCode: 'CS302',
        courseName: 'Database Management Systems',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Ramesh Singh',
        dayOfWeek: 3,
        startTime: '10:00',
        endTime: '11:00',
        roomNumber: 'LHC-204',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-wed-3',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Open Innovation & Hackathon Prep',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 3,
        startTime: '11:00',
        endTime: '12:00',
        roomNumber: 'Innovation Hub',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-wed-4',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Midday Recess & Lunch',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 3,
        startTime: '12:00',
        endTime: '13:00',
        roomNumber: 'Campus Cafeteria',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-wed-5',
        courseId: 'CS301',
        courseCode: 'CS301',
        courseName: 'Operating Systems Kernel Lab',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. Priya Nair',
        dayOfWeek: 3,
        startTime: '13:00',
        endTime: '14:00',
        roomNumber: 'CS-Lab-1',
        slotType: 'lab',
      ),
      TimetableSlotModel(
        id: 'slot-wed-6',
        courseId: 'CS301',
        courseCode: 'CS301',
        courseName: 'OS Process Concurrency Lab',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. Priya Nair',
        dayOfWeek: 3,
        startTime: '14:00',
        endTime: '15:00',
        roomNumber: 'CS-Lab-1',
        slotType: 'lab',
      ),
      TimetableSlotModel(
        id: 'slot-wed-7',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Self-Study & Reading Hour',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 3,
        startTime: '15:00',
        endTime: '16:00',
        roomNumber: 'Central Library',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-wed-8',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Evening Dismissal',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 3,
        startTime: '16:00',
        endTime: '17:00',
        roomNumber: '-',
        slotType: 'off',
      ),

      // ==========================================
      // THURSDAY (Day 4): 9:00 AM - 5:00 PM (8 Blocks)
      // ==========================================
      TimetableSlotModel(
        id: 'slot-thu-1',
        courseId: 'CS303',
        courseCode: 'CS303',
        courseName: 'Design & Analysis of Algorithms',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Alan Turing',
        dayOfWeek: 4,
        startTime: '09:00',
        endTime: '10:00',
        roomNumber: 'LHC-101',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-thu-2',
        courseId: 'CS301',
        courseCode: 'CS301',
        courseName: 'Operating Systems',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. Priya Nair',
        dayOfWeek: 4,
        startTime: '10:00',
        endTime: '11:00',
        roomNumber: 'LHC-302',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-thu-3',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Faculty Office Hours & Doubts',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 4,
        startTime: '11:00',
        endTime: '12:00',
        roomNumber: 'Faculty Block B',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-thu-4',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Midday Recess & Lunch',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 4,
        startTime: '12:00',
        endTime: '13:00',
        roomNumber: 'Campus Cafeteria',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-thu-5',
        courseId: 'MA101',
        courseCode: 'MA101',
        courseName: 'Discrete Mathematics',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Gauss',
        dayOfWeek: 4,
        startTime: '13:00',
        endTime: '14:00',
        roomNumber: 'LHC-105',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-thu-6',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Competitive Programming Practice',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 4,
        startTime: '14:00',
        endTime: '15:00',
        roomNumber: 'Computing Center 1',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-thu-7',
        courseId: 'CS304',
        courseCode: 'CS304',
        courseName: 'Deep Learning & Neural Networks',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. Priya Nair',
        dayOfWeek: 4,
        startTime: '15:00',
        endTime: '16:00',
        roomNumber: 'LHC-302',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-thu-8',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Campus Hours Concluded',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 4,
        startTime: '16:00',
        endTime: '17:00',
        roomNumber: '-',
        slotType: 'off',
      ),

      // ==========================================
      // FRIDAY (Day 5): 9:00 AM - 5:00 PM (8 Blocks)
      // ==========================================
      TimetableSlotModel(
        id: 'slot-fri-1',
        courseId: 'CS302',
        courseCode: 'CS302',
        courseName: 'Database Management Systems',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Ramesh Singh',
        dayOfWeek: 5,
        startTime: '09:00',
        endTime: '10:00',
        roomNumber: 'LHC-204',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-fri-2',
        courseId: 'CS303',
        courseCode: 'CS303',
        courseName: 'Design & Analysis of Algorithms',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Alan Turing',
        dayOfWeek: 5,
        startTime: '10:00',
        endTime: '11:00',
        roomNumber: 'LHC-101',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-fri-3',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Student Research Colloquium',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 5,
        startTime: '11:00',
        endTime: '12:00',
        roomNumber: 'Seminar Hall 2',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-fri-4',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Midday Recess & Lunch',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 5,
        startTime: '12:00',
        endTime: '13:00',
        roomNumber: 'Campus Cafeteria',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-fri-5',
        courseId: 'CS303',
        courseCode: 'CS303',
        courseName: 'Algorithms Lab Benchmark Suite',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Alan Turing',
        dayOfWeek: 5,
        startTime: '13:00',
        endTime: '14:00',
        roomNumber: 'CS-Lab-1',
        slotType: 'lab',
      ),
      TimetableSlotModel(
        id: 'slot-fri-6',
        courseId: 'CS303',
        courseCode: 'CS303',
        courseName: 'Algorithms Performance Testing',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Prof. Alan Turing',
        dayOfWeek: 5,
        startTime: '14:00',
        endTime: '15:00',
        roomNumber: 'CS-Lab-1',
        slotType: 'lab',
      ),
      TimetableSlotModel(
        id: 'slot-fri-7',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Early Weekend Dismissal',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 5,
        startTime: '15:00',
        endTime: '16:00',
        roomNumber: '-',
        slotType: 'off',
      ),
      TimetableSlotModel(
        id: 'slot-fri-8',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Campus Closed',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 5,
        startTime: '16:00',
        endTime: '17:00',
        roomNumber: '-',
        slotType: 'off',
      ),

      // ==========================================
      // SATURDAY (Day 6): 9:00 AM - 5:00 PM (8 Blocks)
      // ==========================================
      TimetableSlotModel(
        id: 'slot-sat-1',
        courseId: 'SEM301',
        courseCode: 'SEM301',
        courseName: 'Industry Colloquium & Keynote',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Visiting Industry Lead',
        dayOfWeek: 6,
        startTime: '09:00',
        endTime: '10:00',
        roomNumber: 'Auditorium-1',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-sat-2',
        courseId: 'SEM301',
        courseCode: 'SEM301',
        courseName: 'Technical Panel & BoS Interaction',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Visiting Industry Lead',
        dayOfWeek: 6,
        startTime: '10:00',
        endTime: '11:00',
        roomNumber: 'Auditorium-1',
        slotType: 'lecture',
      ),
      TimetableSlotModel(
        id: 'slot-sat-3',
        courseId: '',
        courseCode: 'FREE',
        courseName: 'Campus Clubs & Robotics Workshop',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 6,
        startTime: '11:00',
        endTime: '12:00',
        roomNumber: 'Student Activity Center',
        slotType: 'free',
      ),
      TimetableSlotModel(
        id: 'slot-sat-4',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Saturday Half-Day Recess',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 6,
        startTime: '12:00',
        endTime: '13:00',
        roomNumber: '-',
        slotType: 'off',
      ),
      TimetableSlotModel(
        id: 'slot-sat-5',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Declared Off',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 6,
        startTime: '13:00',
        endTime: '14:00',
        roomNumber: '-',
        slotType: 'off',
      ),
      TimetableSlotModel(
        id: 'slot-sat-6',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Declared Off',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 6,
        startTime: '14:00',
        endTime: '15:00',
        roomNumber: '-',
        slotType: 'off',
      ),
      TimetableSlotModel(
        id: 'slot-sat-7',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Declared Off',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 6,
        startTime: '15:00',
        endTime: '16:00',
        roomNumber: '-',
        slotType: 'off',
      ),
      TimetableSlotModel(
        id: 'slot-sat-8',
        courseId: '',
        courseCode: 'OFF',
        courseName: 'Declared Off',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 6,
        startTime: '16:00',
        endTime: '17:00',
        roomNumber: '-',
        slotType: 'off',
      ),
    ];
  }

  void _seedDefaultNoticesIfEmpty() {
    if (_cachedNotices.isNotEmpty) return;
    _cachedNotices.addAll([
      NoticeModel(
        id: 'not-1',
        title: 'Mid-Term Examination Schedule Announced — Autumn 2026',
        content: 'The statutory mid-term examinations for B.Tech CSE, AI/ML, and Data Science will commence from November 15, 2026. Review your registered slot timings and room allocations.',
        category: 'exam',
        targetScopeCode: 'global',
        priority: 'urgent',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NoticeModel(
        id: 'not-2',
        title: 'Deep Learning GPU Server Cluster Scheduled Maintenance',
        content: 'High-performance computing nodes in Lab-3 will undergo NVIDIA driver updates and kernel patches this Saturday from 02:00 AM to 06:00 AM. Checkpoints should be saved prior.',
        category: 'academic',
        targetScopeCode: 'sec:cse-3a',
        priority: 'high',
        publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      NoticeModel(
        id: 'not-3',
        title: 'Campus Hostels Optical Fiber & Wi-Fi 6 Upgrade Complete',
        content: 'Network bandwidth across Block A and Block B has been enhanced to 10Gbps symmetric uplink. Connect to the CampusOS-Secure network using your canonical identity.',
        category: 'hostel',
        targetScopeCode: 'global',
        priority: 'normal',
        publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      NoticeModel(
        id: 'not-4',
        title: 'Annual Hackathon 2026: Team Registration Portal Open',
        content: 'Registrations are now open for the 48-hour Inter-Departmental Hackathon. Teams of up to 4 students across any accredited program may register before November 20.',
        category: 'general',
        targetScopeCode: 'global',
        priority: 'normal',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ]);
  }

  // Load and cache student attendance summary
  Future<List<AttendanceSummaryModel>> getAttendanceSummary(
      String studentId) async {
    await checkConnectivity();
    if (isOnline) {
      try {
        final summaries = await api.fetchAttendanceSummary(studentId);
        if (summaries.isNotEmpty) {
          _cachedSummaries
            ..clear()
            ..addAll(summaries);
          return _cachedSummaries;
        }
      } catch (_) {}
    }
    if (_cachedSummaries.isEmpty) {
      _cachedSummaries.addAll(_getDefaultStudentSummaries());
    }
    return _cachedSummaries;
  }

  static List<AttendanceSummaryModel> _getDefaultStudentSummaries() {
    return [
      AttendanceSummaryModel(
        courseId: 'CS301',
        courseCode: 'CS301',
        courseName: 'Operating Systems',
        totalSessions: 32,
        attended: 28,
        percentage: 87.5,
      ),
      AttendanceSummaryModel(
        courseId: 'CS302',
        courseCode: 'CS302',
        courseName: 'Database Management Systems',
        totalSessions: 30,
        attended: 24,
        percentage: 80.0,
      ),
      AttendanceSummaryModel(
        courseId: 'CS303',
        courseCode: 'CS303',
        courseName: 'Design & Analysis of Algorithms',
        totalSessions: 24,
        attended: 17,
        percentage: 70.8,
      ),
      AttendanceSummaryModel(
        courseId: 'CS304',
        courseCode: 'CS304',
        courseName: 'Deep Learning & Neural Networks',
        totalSessions: 30,
        attended: 29,
        percentage: 96.7,
      ),
      AttendanceSummaryModel(
        courseId: 'MA101',
        courseCode: 'MA101',
        courseName: 'Discrete Mathematics',
        totalSessions: 20,
        attended: 12,
        percentage: 60.0,
      ),
    ];
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
    await checkConnectivity();
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
    await checkConnectivity();
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
    await checkConnectivity();
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
    await checkConnectivity();
    if (isOnline) {
      try {
        await api.endOpticalSession(sessionId);
      } catch (_) {}
    }
    _activeOpticalSession = null;
  }

  // ----------------------------------------------------
  // DEPARTMENTS & ACADEMIC HIERARCHY
  // ----------------------------------------------------

  void _seedDefaultAcademicHierarchyIfEmpty() {
    if (_cachedDepartments.isNotEmpty) return;

    // Seed sample programs
    _cachedPrograms.addAll([
      ProgramModel(
        id: 'prog-btech-cse',
        code: 'BTECH-CSE',
        name: 'B.Tech in Computer Science & Engineering',
        degreeLevel: 'undergraduate',
        totalSemesters: 8,
      ),
      ProgramModel(
        id: 'prog-btech-aiml',
        code: 'BTECH-AIML',
        name: 'B.Tech in Artificial Intelligence & Machine Learning',
        degreeLevel: 'undergraduate',
        totalSemesters: 8,
      ),
      ProgramModel(
        id: 'prog-btech-ds',
        code: 'BTECH-DS',
        name: 'B.Tech in Data Science',
        degreeLevel: 'undergraduate',
        totalSemesters: 8,
      ),
      ProgramModel(
        id: 'prog-btech-ece',
        code: 'BTECH-ECE',
        name: 'B.Tech in Electronics & Communication',
        degreeLevel: 'undergraduate',
        totalSemesters: 8,
      ),
      ProgramModel(
        id: 'prog-btech-mech',
        code: 'BTECH-MECH',
        name: 'B.Tech in Mechanical Engineering',
        degreeLevel: 'undergraduate',
        totalSemesters: 8,
      ),
    ]);

    // Seed sample subjects
    final sylV1 = SyllabusVersionModel(
      id: 'syl-subj-bca-1',
      subjectId: 'subj-bca-102-202',
      revisionCode: 'Scheme-2021',
      effectiveFromYear: '2021-2022',
      effectiveToYear: '2024-2025',
      isActive: false,
      content: 'Unit 1: Computing Fundamentals & Architecture.\nUnit 2: C Programming Syntax & Control Flow.\nUnit 3: Pointers, Arrays & Memory Structures.',
      changeSummary: 'Initial BoS approved foundation syllabus',
      approvedBy: 'Academic Council & BoS',
    );
    final sylV2 = SyllabusVersionModel(
      id: 'syl-subj-bca-2',
      subjectId: 'subj-bca-102-202',
      revisionCode: 'Reg-2024',
      effectiveFromYear: '2024-2025',
      isActive: true,
      content: 'Unit 1: Modern Systems Architecture & Logic.\nUnit 2: Advanced C & Data Modeling.\nUnit 3: Dynamic Memory & POSIX I/O.\nUnit 4: Memory Safety & Rust Modern Systems Case Studies.',
      changeSummary: 'Added Unit 4 Memory Safety & Rust analysis per curriculum reform',
      approvedBy: 'BoS Curriculum Reform Committee',
    );

    _cachedSyllabusVersions['subj-bca-102-202'] = [sylV2, sylV1];

    _cachedSubjects.addAll([
      SubjectModel(id: 'subj-cs301', code: 'CS301', name: 'Operating Systems', credits: 4, departmentIds: ['dept-cse']),
      SubjectModel(id: 'subj-cs302', code: 'CS302', name: 'Database Management Systems', credits: 4, departmentIds: ['dept-cse']),
      SubjectModel(id: 'subj-cs303', code: 'CS303', name: 'Design & Analysis of Algorithms', credits: 4, departmentIds: ['dept-cse']),
      SubjectModel(id: 'subj-cs304', code: 'CS304', name: 'Deep Learning & Neural Networks', credits: 4, departmentIds: ['dept-cse']),
      SubjectModel(id: 'subj-ma101', code: 'MA101', name: 'Discrete Mathematics', credits: 3, departmentIds: ['dept-cse', 'dept-math', 'dept-ece']),
      SubjectModel(id: 'subj-ec201', code: 'EC201', name: 'Signals & Systems', credits: 4, departmentIds: ['dept-ece']),
      SubjectModel(
        id: 'subj-bca-102-202',
        code: 'BCA 102 / 202',
        oddSemCode: 'BCA-102',
        evenSemCode: 'BCA-202',
        name: 'Computer Fundamentals & Problem Solving with C',
        credits: 4,
        departmentIds: ['dept-cse'],
        activeSyllabus: sylV2,
      ),
    ]);

    // Seed sample program semesters
    _cachedSemesters.addAll([
      SemesterModel(
        id: 'sem-btech-cse-5-3a',
        programId: 'prog-btech-cse',
        programCode: 'BTECH-CSE',
        programName: 'B.Tech in Computer Science & Engineering',
        semesterNumber: 5,
        academicYear: '2025-2026',
        section: '3A',
        displayName: 'B.Tech CSE - Semester 5 (Sec 3A)',
        subjectIds: ['subj-cs301', 'subj-cs302', 'subj-cs303'],
        teacherIds: ['usr-priya_2024_emp_1'],
        studentCount: 1,
      ),
      SemesterModel(
        id: 'sem-btech-cse-3-2a',
        programId: 'prog-btech-cse',
        programCode: 'BTECH-CSE',
        programName: 'B.Tech in Computer Science & Engineering',
        semesterNumber: 3,
        academicYear: '2025-2026',
        section: '2A',
        displayName: 'B.Tech CSE - Semester 3 (Sec 2A)',
        subjectIds: ['subj-ma101'],
        teacherIds: ['usr-priya_2024_emp_1'],
        studentCount: 0,
      ),
      SemesterModel(
        id: 'sem-btech-ece-5-1a',
        programId: 'prog-btech-ece',
        programCode: 'BTECH-ECE',
        programName: 'B.Tech in Electronics & Communication',
        semesterNumber: 5,
        academicYear: '2025-2026',
        section: '1A',
        displayName: 'B.Tech ECE - Semester 5 (Sec 1A)',
        subjectIds: ['subj-ec201', 'subj-ma101'],
        teacherIds: ['usr-priya_2024_emp_1'],
        studentCount: 0,
      ),
    ]);

    // Seed default departments with M:N relations
    _cachedDepartments.addAll([
      DepartmentModel(
        id: 'dept-cse',
        code: 'CSE',
        name: 'Department of Computer Science & Engineering',
        description: 'Advancing computing frontiers through cutting-edge systems, AI, and cybersecurity research.',
        hodId: 'usr-priya_2024_emp_1',
        hodName: 'Dr. Priya Nair',
        subjectIds: ['subj-cs301', 'subj-cs302', 'subj-cs303', 'subj-ma101'],
        teacherIds: ['usr-priya_2024_emp_1'],
        semesterIds: ['sem-btech-cse-5-3a', 'sem-btech-cse-3-2a'],
        subjectCount: 4,
        teacherCount: 1,
        semesterCount: 2,
      ),
      DepartmentModel(
        id: 'dept-ece',
        code: 'ECE',
        name: 'Department of Electronics & Communication',
        description: 'Leading innovations in embedded robotics, VLSI architectures, and RF communication.',
        hodId: 'usr-priya_2024_emp_1',
        hodName: 'Dr. Priya Nair',
        subjectIds: ['subj-ec201', 'subj-ma101'],
        teacherIds: ['usr-priya_2024_emp_1'],
        semesterIds: ['sem-btech-ece-5-1a'],
        subjectCount: 2,
        teacherCount: 1,
        semesterCount: 1,
      ),
      DepartmentModel(
        id: 'dept-math',
        code: 'MATH',
        name: 'Department of Mathematics & Computing',
        description: 'Theoretical foundational sciences, numerical computing, and applied mathematical statistics.',
        subjectIds: ['subj-ma101'],
        teacherIds: ['usr-priya_2024_emp_1'],
        semesterIds: ['sem-btech-cse-3-2a'],
        subjectCount: 1,
        teacherCount: 1,
        semesterCount: 1,
      ),
    ]);

    // Seed Cross-Program Sections
    _cachedSections.addAll([
      SectionModel(
        id: 'sec-sem3-section-b',
        name: 'Section B',
        semesterNumber: 3,
        academicYear: '2025-2026',
        displayName: 'Semester 3 - Section B (BTECH-CSE, BTECH-AIML, BTECH-DS)',
        departmentId: 'dept-cse',
        programIds: ['prog-btech-cse', 'prog-btech-aiml', 'prog-btech-ds'],
        programNames: ['BTECH-CSE', 'BTECH-AIML', 'BTECH-DS'],
        subjectIds: ['subj-cs301', 'subj-cs302', 'subj-ma101'],
        teacherIds: ['usr-priya_2024_emp_1'],
        studentCount: 1,
      ),
      SectionModel(
        id: 'sec-sem5-section-a',
        name: 'Section A',
        semesterNumber: 5,
        academicYear: '2025-2026',
        displayName: 'Semester 5 - Section A (BTECH-CSE, BTECH-AIML)',
        departmentId: 'dept-cse',
        programIds: ['prog-btech-cse', 'prog-btech-aiml'],
        programNames: ['BTECH-CSE', 'BTECH-AIML'],
        subjectIds: ['subj-cs301', 'subj-cs302', 'subj-cs303', 'subj-cs304'],
        teacherIds: ['usr-priya_2024_emp_1'],
        studentCount: 1,
      ),
    ]);

    // Seed subject allocations (core shared vs program specialized)
    _sectionAllocations['sec-sem5-section-a'] = [
      SectionSubjectAllocationModel(
        subjectId: 'subj-cs301',
        subjectCode: 'CS301',
        subjectName: 'Operating Systems',
        credits: 4,
        programId: null, // Shared Core
      ),
      SectionSubjectAllocationModel(
        subjectId: 'subj-cs302',
        subjectCode: 'CS302',
        subjectName: 'Database Management Systems',
        credits: 4,
        programId: null, // Shared Core
      ),
      SectionSubjectAllocationModel(
        subjectId: 'subj-cs303',
        subjectCode: 'CS303',
        subjectName: 'Design & Analysis of Algorithms',
        credits: 4,
        programId: 'prog-btech-cse',
        programCode: 'BTECH-CSE',
        programName: 'B.Tech in Computer Science & Engineering',
      ),
      SectionSubjectAllocationModel(
        subjectId: 'subj-cs304',
        subjectCode: 'CS304',
        subjectName: 'Deep Learning & Neural Networks',
        credits: 4,
        programId: 'prog-btech-aiml',
        programCode: 'BTECH-AIML',
        programName: 'B.Tech in Artificial Intelligence & Machine Learning',
      ),
    ];

    // Seed student Harish section & program assignment
    _studentSectionMap['usr-harish_2025_l_btech_1'] = 'sec-sem5-section-a';
    _studentProgramMap['usr-harish_2025_l_btech_1'] = 'prog-btech-cse';

    // Seed Lab Batches for Section B
    _cachedSectionBatches['sec-sem3-section-b'] = [
      LabBatchModel(
        id: 'batch-sec-sem3-section-b-batch-b1',
        sectionId: 'sec-sem3-section-b',
        name: 'Batch B1',
        studentCount: 0,
      ),
      LabBatchModel(
        id: 'batch-sec-sem3-section-b-batch-b2',
        sectionId: 'sec-sem3-section-b',
        name: 'Batch B2',
        studentCount: 0,
      ),
    ];

    // Seed Faculty Allocations for Section A and Section B
    _cachedSectionAllocations['sec-sem5-section-a'] = [
      FacultyAllocationModel(
        id: 'alloc-sec-sem5-cs301-theory',
        sectionId: 'sec-sem5-section-a',
        sectionName: 'Section A',
        subjectId: 'subj-cs301',
        subjectCode: 'CS301',
        subjectName: 'Operating Systems',
        teacherId: 'usr-priya_2024_emp_1',
        teacherName: 'Dr. Priya Nair',
        componentType: 'theory',
        weeklyHours: 4,
      ),
      FacultyAllocationModel(
        id: 'alloc-sec-sem5-cs302-theory',
        sectionId: 'sec-sem5-section-a',
        sectionName: 'Section A',
        subjectId: 'subj-cs302',
        subjectCode: 'CS302',
        subjectName: 'Database Management Systems',
        teacherId: 'usr-priya_2024_emp_1',
        teacherName: 'Dr. Priya Nair',
        componentType: 'theory',
        weeklyHours: 3,
      ),
    ];

    _cachedSectionAllocations['sec-sem3-section-b'] = [
      FacultyAllocationModel(
        id: 'alloc-sec-sem3-bca-theory',
        sectionId: 'sec-sem3-section-b',
        sectionName: 'Section B',
        subjectId: 'subj-bca-102-202',
        subjectCode: 'BCA-102',
        subjectName: 'Computer Fundamentals & Problem Solving with C',
        teacherId: 'usr-priya_2024_emp_1',
        teacherName: 'Dr. Priya Nair',
        componentType: 'theory',
        weeklyHours: 4,
      ),
      FacultyAllocationModel(
        id: 'alloc-sec-sem3-bca-practical-b1',
        sectionId: 'sec-sem3-section-b',
        sectionName: 'Section B',
        subjectId: 'subj-bca-102-202',
        subjectCode: 'BCA-102',
        subjectName: 'Computer Fundamentals & Problem Solving with C',
        teacherId: 'usr-priya_2024_emp_1',
        teacherName: 'Dr. Priya Nair',
        componentType: 'practical',
        batchId: 'batch-sec-sem3-section-b-batch-b1',
        batchName: 'Batch B1',
        weeklyHours: 2,
      ),
    ];
  }

  Future<List<DepartmentModel>> getDepartments({bool forceRefresh = false}) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline && (forceRefresh || _cachedDepartments.isEmpty)) {
      try {
        final list = await api.fetchDepartments();
        _cachedDepartments
          ..clear()
          ..addAll(list);
        return List<DepartmentModel>.from(_cachedDepartments);
      } catch (_) {}
    }
    return List<DepartmentModel>.from(_cachedDepartments);
  }

  Future<DepartmentModel> addDepartment(Map<String, dynamic> payload) async {
    await checkConnectivity();
    if (isOnline) {
      try {
        final created = await api.createDepartment(payload);
        _cachedDepartments.removeWhere((d) => d.id == created.id);
        _cachedDepartments.insert(0, created);
        return created;
      } catch (_) {}
    }

    _seedDefaultAcademicHierarchyIfEmpty();
    final code = (payload['code'] ?? '').toString().toUpperCase().trim();
    final name = (payload['name'] ?? '').toString().trim();
    final deptId = 'dept-${code.toLowerCase()}';
    final subjectIds = (payload['subject_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final teacherIds = (payload['teacher_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final semesterIds = (payload['semester_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];

    String? hodName;
    final hodId = payload['hod_id'] as String?;
    if (hodId != null) {
      final user = _cachedUsers.cast<UserModel?>().firstWhere((u) => u?.id == hodId, orElse: () => null);
      if (user != null) hodName = user.fullName;
    }

    final newDept = DepartmentModel(
      id: deptId,
      code: code,
      name: name,
      description: payload['description'] ?? '',
      hodId: hodId,
      hodName: hodName,
      subjectIds: subjectIds,
      teacherIds: teacherIds,
      semesterIds: semesterIds,
      subjectCount: subjectIds.length,
      teacherCount: teacherIds.length,
      semesterCount: semesterIds.length,
    );

    _cachedDepartments.removeWhere((d) => d.id == newDept.id);
    _cachedDepartments.insert(0, newDept);
    return newDept;
  }

  Future<DepartmentDetailModel> getDepartmentDetail(String id) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.fetchDepartmentDetail(id);
      } catch (_) {}
    }

    final dept = _cachedDepartments.firstWhere(
      (d) => d.id == id,
      orElse: () => _cachedDepartments.first,
    );

    final subjects = _cachedSubjects.where((s) => dept.subjectIds.contains(s.id)).toList();
    final teachers = _cachedUsers.where((u) => dept.teacherIds.contains(u.id)).toList();
    final semesters = _cachedSemesters.where((sem) => dept.semesterIds.contains(sem.id)).toList();

    return DepartmentDetailModel(
      department: dept,
      subjects: subjects,
      teachers: teachers,
      semesters: semesters,
    );
  }

  Future<List<ProgramModel>> getPrograms() async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.fetchPrograms();
        _cachedPrograms
          ..clear()
          ..addAll(list);
        return _cachedPrograms;
      } catch (_) {}
    }
    return _cachedPrograms;
  }

  Future<List<SubjectModel>> getSubjects() async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.fetchSubjects();
        _cachedSubjects
          ..clear()
          ..addAll(list);
        return _cachedSubjects;
      } catch (_) {}
    }
    return _cachedSubjects;
  }

  Future<SubjectModel> createSubject(Map<String, dynamic> payload) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final created = await api.createSubject(payload);
        _cachedSubjects.add(created);
        if (created.activeSyllabus != null) {
          _cachedSyllabusVersions[created.id] = [created.activeSyllabus!];
        }
        return created;
      } catch (_) {}
    }

    final code = payload['code'] as String? ?? '';
    final oddCode = payload['odd_sem_code'] as String?;
    final evenCode = payload['even_sem_code'] as String?;
    final name = payload['name'] as String? ?? 'Subject';
    final credits = payload['credits'] as int? ?? 3;
    final resolvedCode = code.isNotEmpty
        ? code
        : (oddCode != null && evenCode != null
            ? '$oddCode / $evenCode'
            : (oddCode ?? evenCode ?? 'SUBJ'));

    final cleanKey = resolvedCode.toLowerCase().replaceAll(' ', '-').replaceAll('/', '-');
    final id = 'subj-$cleanKey';
    SyllabusVersionModel? syl;
    if (payload['active_syllabus'] != null) {
      syl = SyllabusVersionModel.fromJson(payload['active_syllabus']);
    }

    final sub = SubjectModel(
      id: id,
      code: resolvedCode,
      oddSemCode: oddCode,
      evenSemCode: evenCode,
      name: name,
      credits: credits,
      activeSyllabus: syl,
    );

    _cachedSubjects.add(sub);
    if (syl != null) {
      _cachedSyllabusVersions[id] = [syl];
    }
    return sub;
  }

  Future<List<SyllabusVersionModel>> getSubjectSyllabusAudit(String subjectId) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.fetchSyllabusAudit(subjectId);
        _cachedSyllabusVersions[subjectId] = list;
        return list;
      } catch (_) {}
    }
    return _cachedSyllabusVersions[subjectId] ?? [];
  }

  Future<SyllabusVersionModel> reviseSubjectSyllabus(Map<String, dynamic> payload) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final revised = await api.reviseSyllabus(payload);
        final list = _cachedSyllabusVersions[payload['subject_id']] ?? [];
        _cachedSyllabusVersions[payload['subject_id']] = [
          revised,
          ...list.map((v) => SyllabusVersionModel(
                id: v.id,
                subjectId: v.subjectId,
                revisionCode: v.revisionCode,
                effectiveFromYear: v.effectiveFromYear,
                effectiveToYear: v.isActive ? payload['effective_from_year'] ?? '2025-2026' : v.effectiveToYear,
                isActive: false,
                content: v.content,
                changeSummary: v.changeSummary,
                approvedBy: v.approvedBy,
                approvedAt: v.approvedAt,
                createdAt: v.createdAt,
              ))
        ];
        return revised;
      } catch (_) {}
    }

    final subjectId = payload['subject_id'] as String;
    final effFrom = payload['effective_from_year'] as String? ?? '2025-2026';
    final existing = _cachedSyllabusVersions[subjectId] ?? [];
    final updatedList = existing.map((v) {
      if (v.isActive) {
        return SyllabusVersionModel(
          id: v.id,
          subjectId: v.subjectId,
          revisionCode: v.revisionCode,
          effectiveFromYear: v.effectiveFromYear,
          effectiveToYear: effFrom,
          isActive: false,
          content: v.content,
          changeSummary: v.changeSummary,
          approvedBy: v.approvedBy,
          approvedAt: v.approvedAt,
          createdAt: v.createdAt,
        );
      }
      return v;
    }).toList();

    final newVer = SyllabusVersionModel(
      id: 'syl-$subjectId-${existing.length + 1}',
      subjectId: subjectId,
      revisionCode: payload['revision_code'] ?? 'Rev-New',
      effectiveFromYear: effFrom,
      isActive: true,
      content: payload['content'] ?? '',
      changeSummary: payload['change_summary'],
      approvedBy: payload['approved_by'],
      approvedAt: DateTime.now().toIso8601String(),
      createdAt: DateTime.now(),
    );

    _cachedSyllabusVersions[subjectId] = [newVer, ...updatedList];

    // Also update active syllabus on cached subject if found
    final subIdx = _cachedSubjects.indexWhere((s) => s.id == subjectId);
    if (subIdx != -1) {
      final s = _cachedSubjects[subIdx];
      _cachedSubjects[subIdx] = SubjectModel(
        id: s.id,
        code: s.code,
        oddSemCode: s.oddSemCode,
        evenSemCode: s.evenSemCode,
        name: s.name,
        credits: s.credits,
        departmentIds: s.departmentIds,
        activeSyllabus: newVer,
      );
    }

    return newVer;
  }

  Future<List<SemesterModel>> getSemesters() async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.fetchSemesters();
        _cachedSemesters
          ..clear()
          ..addAll(list);
        return _cachedSemesters;
      } catch (_) {}
    }
    return _cachedSemesters;
  }

  Future<SemesterDetailModel> getSemesterDetail(String id) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.fetchSemesterDetail(id);
      } catch (_) {}
    }

    final sem = _cachedSemesters.firstWhere(
      (s) => s.id == id,
      orElse: () => _cachedSemesters.first,
    );

    final subjects = _cachedSubjects.where((s) => sem.subjectIds.contains(s.id)).toList();
    final teachers = _cachedUsers.where((u) => sem.teacherIds.contains(u.id)).toList();
    // Students enrolled in this semester (Many-to-one relationship)
    final students = _cachedUsers.where((u) {
      if (u.archetype != 'student') return false;
      return sem.id == 'sem-btech-cse-5-3a'; // Student Harish enrolled here
    }).toList();

    return SemesterDetailModel(
      semester: sem,
      subjects: subjects,
      teachers: teachers,
      students: students,
    );
  }

  // ----------------------------------------------------
  // CROSS-PROGRAM SECTIONS
  // ----------------------------------------------------

  Future<List<SectionModel>> getSections({bool forceRefresh = false}) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline && (forceRefresh || _cachedSections.isEmpty)) {
      try {
        final list = await api.fetchSections();
        _cachedSections
          ..clear()
          ..addAll(list);
        return List<SectionModel>.from(_cachedSections);
      } catch (_) {}
    }
    return List<SectionModel>.from(_cachedSections);
  }

  Future<SectionModel> addSection(Map<String, dynamic> payload) async {
    await checkConnectivity();
    if (isOnline) {
      try {
        final created = await api.createSection(payload);
        _cachedSections.removeWhere((s) => s.id == created.id);
        _cachedSections.insert(0, created);
        return created;
      } catch (_) {}
    }

    _seedDefaultAcademicHierarchyIfEmpty();
    final name = (payload['name'] ?? '').toString().trim();
    final semNum = payload['semester_number'] is int ? payload['semester_number'] as int : 1;
    final year = (payload['academic_year'] ?? '2025-2026').toString();
    final secKey = name.toLowerCase().replaceAll(' ', '-');
    final secId = 'sec-sem$semNum-$secKey';

    final progIds = (payload['program_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final progNames = <String>[];
    for (final pid in progIds) {
      final p = _cachedPrograms.cast<ProgramModel?>().firstWhere((pr) => pr?.id == pid, orElse: () => null);
      if (p != null) progNames.add(p.code);
    }

    final subIds = (payload['subject_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final teacherIds = (payload['teacher_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];

    final newSec = SectionModel(
      id: secId,
      name: name,
      semesterNumber: semNum,
      academicYear: year,
      displayName: 'Semester $semNum - $name (${progNames.join(", ")})',
      departmentId: payload['department_id'],
      programIds: progIds,
      programNames: progNames,
      subjectIds: subIds,
      teacherIds: teacherIds,
      studentCount: 0,
    );

    _cachedSections.removeWhere((s) => s.id == newSec.id);
    _cachedSections.insert(0, newSec);
    return newSec;
  }

  Future<SectionDetailModel> getSectionDetail(String id) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.fetchSectionDetail(id);
      } catch (_) {}
    }

    final sec = _cachedSections.firstWhere(
      (s) => s.id == id,
      orElse: () => _cachedSections.first,
    );

    final programs = _cachedPrograms.where((p) => sec.programIds.contains(p.id)).toList();
    final subjects = _cachedSubjects.where((s) => sec.subjectIds.contains(s.id)).toList();
    final teachers = _cachedUsers.where((u) => sec.teacherIds.contains(u.id)).toList();

    // Allocations (fallback to default core allocations if none defined)
    var allocs = _sectionAllocations[sec.id];
    if (allocs == null || allocs.isEmpty) {
      allocs = subjects
          .map((sub) => SectionSubjectAllocationModel(
                subjectId: sub.id,
                subjectCode: sub.code,
                subjectName: sub.name,
                credits: sub.credits,
                programId: null, // Shared core
              ))
          .toList();
    }

    // Students enrolled in this section
    final enrolledStudents = _cachedUsers.where((u) {
      if (u.archetype != 'student') return false;
      return _studentSectionMap[u.id] == sec.id;
    }).toList();

    // Program breakdown
    final breakdown = <String, int>{};
    for (final st in enrolledStudents) {
      final pid = _studentProgramMap[st.id];
      final prog = _cachedPrograms.cast<ProgramModel?>().firstWhere((p) => p?.id == pid, orElse: () => null);
      final code = prog?.code ?? 'General';
      breakdown[code] = (breakdown[code] ?? 0) + 1;
    }

    return SectionDetailModel(
      section: sec,
      programs: programs,
      subjects: subjects,
      subjectAllocations: allocs,
      teachers: teachers,
      students: enrolledStudents,
      programBreakdown: breakdown,
      labBatches: _cachedSectionBatches[sec.id] ?? [],
      facultyAllocations: _cachedSectionAllocations[sec.id] ?? [],
    );
  }

  Future<void> assignStudentToSection({
    required String studentId,
    required String sectionId,
    required String programId,
  }) async {
    await checkConnectivity();
    if (isOnline) {
      try {
        await api.assignStudentToSection(
          studentId: studentId,
          sectionId: sectionId,
          programId: programId,
        );
      } catch (_) {}
    }
    _studentSectionMap[studentId] = sectionId;
    _studentProgramMap[studentId] = programId;
  }

  Future<void> transferStudentSection({
    required String studentId,
    required String targetSectionId,
  }) async {
    await checkConnectivity();
    if (isOnline) {
      try {
        await api.transferStudentSection(
          studentId: studentId,
          targetSectionId: targetSectionId,
        );
      } catch (_) {}
    }

    final oldSecId = _studentSectionMap[studentId];
    _studentSectionMap[studentId] = targetSectionId;

    if (oldSecId != null) {
      final oldIdx = _cachedSections.indexWhere((s) => s.id == oldSecId);
      if (oldIdx != -1) {
        final old = _cachedSections[oldIdx];
        _cachedSections[oldIdx] = SectionModel(
          id: old.id,
          name: old.name,
          semesterNumber: old.semesterNumber,
          academicYear: old.academicYear,
          displayName: old.displayName,
          departmentId: old.departmentId,
          programIds: old.programIds,
          programNames: old.programNames,
          subjectIds: old.subjectIds,
          teacherIds: old.teacherIds,
          studentCount: (old.studentCount > 0 ? old.studentCount - 1 : 0),
        );
      }
    }

    final targetIdx = _cachedSections.indexWhere((s) => s.id == targetSectionId);
    if (targetIdx != -1) {
      final tgt = _cachedSections[targetIdx];
      _cachedSections[targetIdx] = SectionModel(
        id: tgt.id,
        name: tgt.name,
        semesterNumber: tgt.semesterNumber,
        academicYear: tgt.academicYear,
        displayName: tgt.displayName,
        departmentId: tgt.departmentId,
        programIds: tgt.programIds,
        programNames: tgt.programNames,
        subjectIds: tgt.subjectIds,
        teacherIds: tgt.teacherIds,
        studentCount: tgt.studentCount + 1,
      );
    }
  }

  Future<int> mergeSectionCohorts({
    required String sourceSectionId,
    required String targetSectionId,
  }) async {
    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.mergeSectionCohorts(
          sourceSectionId: sourceSectionId,
          targetSectionId: targetSectionId,
        );
      } catch (_) {}
    }

    int migrated = 0;
    _studentSectionMap.forEach((stId, secId) {
      if (secId == sourceSectionId) {
        _studentSectionMap[stId] = targetSectionId;
        migrated++;
      }
    });

    final srcIdx = _cachedSections.indexWhere((s) => s.id == sourceSectionId);
    if (srcIdx != -1) {
      final src = _cachedSections[srcIdx];
      _cachedSections[srcIdx] = SectionModel(
        id: src.id,
        name: src.name,
        semesterNumber: src.semesterNumber,
        academicYear: src.academicYear,
        displayName: src.displayName,
        departmentId: src.departmentId,
        programIds: src.programIds,
        programNames: src.programNames,
        subjectIds: src.subjectIds,
        teacherIds: src.teacherIds,
        studentCount: 0,
      );
    }

    final tgtIdx = _cachedSections.indexWhere((s) => s.id == targetSectionId);
    if (tgtIdx != -1) {
      final tgt = _cachedSections[tgtIdx];
      _cachedSections[tgtIdx] = SectionModel(
        id: tgt.id,
        name: tgt.name,
        semesterNumber: tgt.semesterNumber,
        academicYear: tgt.academicYear,
        displayName: tgt.displayName,
        departmentId: tgt.departmentId,
        programIds: tgt.programIds,
        programNames: tgt.programNames,
        subjectIds: tgt.subjectIds,
        teacherIds: tgt.teacherIds,
        studentCount: tgt.studentCount + migrated,
      );
    }

    return migrated;
  }

  // ----------------------------------------------------
  // LAB BATCHES (PRACTICAL SUB-DIVISIONS)
  // ----------------------------------------------------

  Future<List<LabBatchModel>> getSectionBatches(String sectionId) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.fetchSectionBatches(sectionId);
        _cachedSectionBatches[sectionId] = list;
        return list;
      } catch (_) {}
    }
    return _cachedSectionBatches[sectionId] ?? [];
  }

  Future<LabBatchModel> createLabBatch(Map<String, dynamic> payload) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final created = await api.createLabBatch(payload);
        final list = _cachedSectionBatches[payload['section_id']] ?? [];
        list.removeWhere((b) => b.id == created.id);
        list.add(created);
        _cachedSectionBatches[payload['section_id']] = list;
        return created;
      } catch (_) {}
    }

    final secId = payload['section_id'] as String;
    final name = payload['name'] as String? ?? 'Lab Batch';
    final sids = (payload['student_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final id = 'batch-$secId-${name.toLowerCase().replaceAll(' ', '-')}';

    final batch = LabBatchModel(
      id: id,
      sectionId: secId,
      name: name,
      studentIds: sids,
      studentCount: sids.length,
    );

    for (final sid in sids) {
      _studentBatchMap[sid] = id;
    }

    final list = _cachedSectionBatches[secId] ?? [];
    list.removeWhere((b) => b.id == id);
    list.add(batch);
    _cachedSectionBatches[secId] = list;

    return batch;
  }

  Future<List<LabBatchModel>> autoPartitionBatches(Map<String, dynamic> payload) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.autoPartitionBatches(payload);
        _cachedSectionBatches[payload['section_id']] = list;
        return list;
      } catch (_) {}
    }

    final secId = payload['section_id'] as String;
    final batchCount = payload['batch_count'] as int? ?? 2;
    final prefix = payload['prefix'] as String? ?? 'Batch';

    // Fetch enrolled students
    final enrolledStudents = _cachedUsers
        .where((u) => u.archetype == 'student' && _studentSectionMap[u.id] == secId)
        .map((u) => u.id)
        .toList()
      ..sort();

    final List<LabBatchModel> created = [];
    final total = enrolledStudents.length;

    for (int i = 0; i < batchCount; i++) {
      final bNum = i + 1;
      final bName = '$prefix $bNum';
      final bId = 'batch-$secId-${bName.toLowerCase().replaceAll(' ', '-')}';

      final start = (i * total) ~/ batchCount;
      final end = ((i + 1) * total) ~/ batchCount;
      final assigned = (start < total) ? enrolledStudents.sublist(start, end > total ? total : end) : <String>[];

      for (final sid in assigned) {
        _studentBatchMap[sid] = bId;
      }

      created.add(LabBatchModel(
        id: bId,
        sectionId: secId,
        name: bName,
        studentIds: assigned,
        studentCount: assigned.length,
      ));
    }

    _cachedSectionBatches[secId] = created;
    return created;
  }

  Future<void> assignStudentBatch({required String batchId, required String studentId}) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        await api.assignStudentBatch(batchId: batchId, studentId: studentId);
      } catch (_) {}
    }

    // Update in local cache
    for (final secBatches in _cachedSectionBatches.values) {
      for (int i = 0; i < secBatches.length; i++) {
        final b = secBatches[i];
        if (b.studentIds.contains(studentId)) {
          final updatedSids = b.studentIds.where((id) => id != studentId).toList();
          secBatches[i] = LabBatchModel(
            id: b.id,
            sectionId: b.sectionId,
            name: b.name,
            studentIds: updatedSids,
            studentCount: updatedSids.length,
          );
        }
        if (b.id == batchId) {
          final updatedSids = [...b.studentIds, studentId];
          secBatches[i] = LabBatchModel(
            id: b.id,
            sectionId: b.sectionId,
            name: b.name,
            studentIds: updatedSids,
            studentCount: updatedSids.length,
          );
        }
      }
    }
    _studentBatchMap[studentId] = batchId;
  }

  // ----------------------------------------------------
  // FACULTY ALLOCATIONS & WORKLOAD
  // ----------------------------------------------------

  Future<List<FacultyAllocationModel>> getSectionFacultyAllocations(String sectionId) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.fetchFacultyAllocations(sectionId);
        _cachedSectionAllocations[sectionId] = list;
        return list;
      } catch (_) {}
    }
    return _cachedSectionAllocations[sectionId] ?? [];
  }

  Future<FacultyAllocationModel> assignFacultyAllocation(Map<String, dynamic> payload) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        final created = await api.assignFacultyAllocation(payload);
        final list = _cachedSectionAllocations[payload['section_id']] ?? [];
        list.removeWhere((a) => a.id == created.id);
        list.add(created);
        _cachedSectionAllocations[payload['section_id']] = list;
        return created;
      } catch (_) {}
    }

    final secId = payload['section_id'] as String;
    final subId = payload['subject_id'] as String;
    final teacherId = payload['teacher_id'] as String;
    final compType = payload['component_type'] as String? ?? 'theory';
    final batchId = payload['batch_id'] as String?;
    final weeklyHours = payload['weekly_hours'] as int? ?? (compType == 'theory' ? 3 : 2);

    final sec = _cachedSections.cast<SectionModel?>().firstWhere((s) => s?.id == secId, orElse: () => null);
    final sub = _cachedSubjects.cast<SubjectModel?>().firstWhere((s) => s?.id == subId, orElse: () => null);
    final teacher = _cachedUsers.cast<UserModel?>().firstWhere((u) => u?.id == teacherId, orElse: () => null);

    String? bName;
    if (batchId != null) {
      final batches = _cachedSectionBatches[secId] ?? [];
      final b = batches.cast<LabBatchModel?>().firstWhere((item) => item?.id == batchId, orElse: () => null);
      bName = b?.name;
    }

    final allocId = 'alloc-$secId-$subId-$compType-${batchId ?? "all"}-$teacherId';
    final alloc = FacultyAllocationModel(
      id: allocId,
      sectionId: secId,
      sectionName: sec?.name,
      subjectId: subId,
      subjectCode: sub != null ? sub.resolveCode(sec?.semesterNumber ?? 1) : subId,
      subjectName: sub?.name,
      teacherId: teacherId,
      teacherName: teacher?.fullName ?? teacherId,
      componentType: compType,
      batchId: batchId,
      batchName: bName,
      weeklyHours: weeklyHours,
    );

    final list = _cachedSectionAllocations[secId] ?? [];
    list.removeWhere((a) => a.id == allocId);
    list.add(alloc);
    _cachedSectionAllocations[secId] = list;

    return alloc;
  }

  Future<void> removeFacultyAllocation(String allocationId, String sectionId) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        await api.removeFacultyAllocation(allocationId);
      } catch (_) {}
    }

    final list = _cachedSectionAllocations[sectionId] ?? [];
    list.removeWhere((a) => a.id == allocationId);
    _cachedSectionAllocations[sectionId] = list;
  }

  Future<List<FacultyWorkloadSummaryModel>> getFacultyWorkloadSummaries({String? teacherId}) async {
    _seedDefaultAcademicHierarchyIfEmpty();
    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.fetchFacultyWorkload(teacherId: teacherId);
      } catch (_) {}
    }

    final faculty = _cachedUsers.where((u) => u.archetype == 'employee').toList();
    final List<FacultyWorkloadSummaryModel> result = [];

    for (final teacher in faculty) {
      if (teacherId != null && teacher.id != teacherId) continue;

      final teacherAllocs = <FacultyAllocationModel>[];
      int totalHours = 0;

      for (final allocList in _cachedSectionAllocations.values) {
        for (final a in allocList) {
          if (a.teacherId == teacher.id) {
            teacherAllocs.add(a);
            totalHours += a.weeklyHours;
          }
        }
      }

      result.add(FacultyWorkloadSummaryModel(
        teacherId: teacher.id,
        teacherName: teacher.fullName,
        totalWeeklyHours: totalHours,
        maxRecommendedHours: 16,
        isOverloaded: totalHours > 16,
        allocations: teacherAllocs,
      ));
    }

    result.sort((a, b) => b.totalWeeklyHours.compareTo(a.totalWeeklyHours));
    return result;
  }
}
