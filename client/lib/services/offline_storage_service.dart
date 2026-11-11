import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/academic.dart';
import '../models/complaint.dart';
import '../models/digilocker.dart';
import '../models/fee.dart';
import '../models/hostel.dart';
import '../models/library.dart';
import '../models/mess.dart';
import '../models/payment_order.dart';
import '../models/sessional.dart';
import '../models/user.dart';
import '../utils/invoice_pdf_generator.dart';
import '../utils/env_detector.dart';
import '../utils/receipt_pdf_generator.dart';
import 'storage_interface.dart';

class OfflineStorageService implements ICampusStorage {
  final ICampusApi api;
  final bool enableMockSeeding;

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
  final List<HostelRoomModel> _cachedHostelRooms = [];
  final List<MessMealModel> _cachedMessMeals = [];
  final List<MessRatingModel> _cachedMessRatings = [];
  final List<ComplaintModel> _cachedComplaints = [];
  final List<FeeInvoiceModel> _cachedFeeInvoices = [];
  final List<FineRecordModel> _cachedFines = [];
  final List<FeePaymentModel> _cachedFeePayments = [];
  final List<FeeReceiptModel> _cachedFeeReceipts = [];
  final List<PhysicalBookModel> _cachedPhysicalBooks = [];
  final List<BorrowRecordModel> _cachedBorrowRecords = [];
  final List<EBookModel> _cachedEBooks = [];
  final List<InternalAssessmentModel> _cachedSessionalRecords = [];
  final List<SessionalScheduleModel> _cachedSessionalSchedules = [];
  final Map<String, String> _studentSectionMap = {};
  final Map<String, String> _studentProgramMap = {};
  final Map<String, List<SectionSubjectAllocationModel>> _sectionAllocations = {};
  final Map<String, List<SyllabusVersionModel>> _cachedSyllabusVersions = {};
  final Map<String, List<LabBatchModel>> _cachedSectionBatches = {};
  final Map<String, List<FacultyAllocationModel>> _cachedSectionAllocations = {};
  final Map<String, String> _studentBatchMap = {};
  final Map<String, double> _sectionAttendanceThresholds = {};

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

  OfflineStorageService({
    required this.api,
    bool? enableMockSeeding,
  }) : enableMockSeeding = enableMockSeeding ?? isFlutterTestEnvironment {
    _lastHealthCheckTime = DateTime.now();
    if (this.enableMockSeeding) {
      _seedDefaultUsersIfEmpty();
      _seedDefaultAcademicHierarchyIfEmpty();
      _seedDefaultTimetableIfEmpty();
      _seedDefaultNoticesIfEmpty();
      _seedDefaultHostelRoomsIfEmpty();
      _seedDefaultLibraryIfEmpty();
      _seedDefaultSessionalIfEmpty();
      if (_cachedSummaries.isEmpty) {
        _cachedSummaries.addAll(_getDefaultStudentSummaries());
      }
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

    if (enableMockSeeding) {
      final clean = identifier.trim().toLowerCase();
      final user = getMockUserForHandle(clean);
      _currentUser = user;
      return user;
    }

    throw Exception(
        'Authentication failed: Unable to connect to institutional auth directory.');
  }

  void logout() {
    _currentUser = null;
  }

  static UserModel getMockUserForHandle(String clean) {
    if (clean.contains('admin') || clean.contains('director')) {
      return UserModel(
        id: 'usr-campus_admin',
        campusHandle: 'campus_admin',
        firstName: 'Campus',
        lastName: 'Administrator',
        email: 'admin@campus.edu',
        phone: '+91 98000 00001',
        archetype: 'employee',
        universityRollNo: 'ADM-2023-0001',
        status: 'active',
        activeScopes: ['global'],
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'assign-admin-1',
            userId: 'usr-campus_admin',
            roleCode: 'admin',
            roleName: 'Campus Administrator',
            scopeCode: 'global',
          ),
          UserRoleAssignmentModel(
            id: 'assign-admin-2',
            userId: 'usr-campus_admin',
            roleCode: 'campus_director',
            roleName: 'Campus Director',
            scopeCode: 'global',
          ),
        ],
        permissions: ['*'],
      );
    } else if (clean.contains('priya') || clean.contains('nair') || clean.contains('faculty') || clean.contains('hod')) {
      return UserModel(
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
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'assign-priya-1',
            userId: 'usr-priya_2024_emp_1',
            roleCode: 'hod',
            roleName: 'Head of Department',
            scopeCode: 'dept:cse',
          ),
          UserRoleAssignmentModel(
            id: 'assign-priya-2',
            userId: 'usr-priya_2024_emp_1',
            roleCode: 'faculty',
            roleName: 'Faculty Member',
            scopeCode: 'dept:cse',
          ),
        ],
        permissions: [
          'timetable:view',
          'timetable:edit',
          'timetable:declare_off',
          'attendance:mark',
          'attendance:broadcast',
          'attendance:view_roster',
          'attendance:approve',
          'syllabus:view',
          'syllabus:approve',
          'faculty:assign_workload',
          'department:manage',
          'notice:publish',
          'complaints:student',
          'complaints:employee',
        ],
      );
    } else if (clean.contains('ramesh') || clean.contains('security')) {
      return UserModel(
        id: 'usr-ramesh_2023_emp_1',
        campusHandle: 'ramesh_2023_emp_1',
        firstName: 'Ramesh',
        lastName: 'Singh',
        email: 'ramesh_2023_emp_1@campus.edu',
        phone: '+91 97222 33445',
        archetype: 'employee',
        universityRollNo: 'EMP-2023-0089',
        status: 'active',
        activeScopes: ['global', 'unit:security', 'facility:gate-1'],
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'assign-ramesh-1',
            userId: 'usr-ramesh_2023_emp_1',
            roleCode: 'warden',
            roleName: 'Hostel Warden',
            scopeCode: 'facility:gate-1',
          ),
        ],
        permissions: [
          'gatepass:approve',
          'room:inspect',
          'hostel:manage',
          'hostel:edit_room',
          'complaints:hostel',
          'complaints:campus',
        ],
      );
    } else if (clean.contains('mukesh') || clean.contains('ext_1') || clean.contains('canteen')) {
      return UserModel(
        id: 'usr-mukesh_2025_ext_1',
        campusHandle: 'mukesh_2025_ext_1',
        firstName: 'Mukesh',
        lastName: 'Verma',
        email: 'mukesh_2025_ext_1@campus.edu',
        phone: '+91 98333 44556',
        archetype: 'external',
        universityRollNo: 'GP-2025-0891',
        status: 'active',
        activeScopes: ['gate:main', 'building:canteen'],
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'assign-mukesh-1',
            userId: 'usr-mukesh_2025_ext_1',
            roleCode: 'canteen_manager',
            roleName: 'Canteen Manager',
            scopeCode: 'building:canteen',
          ),
        ],
        permissions: [
          'gatepass:present',
          'profile:view_self',
          'canteen:operate',
          'mess:edit_menu',
          'mess:manage',
          'menu:update',
          'complaints:contractor',
        ],
      );
    }
    return UserModel(
      id: 'usr-harish_2025_l_btech_1',
      campusHandle: 'harish_2025_l_btech_1',
      firstName: 'Harish',
      lastName: 'Kumar',
      email: 'harish_2025_l_btech_1@campus.edu',
      archetype: 'student',
      universityRollNo: '2025-CS-042',
      status: 'active',
      activeScopes: ['global', 'sec:cse-3a', 'club:robotics'],
      assignedRoles: [
        UserRoleAssignmentModel(
          id: 'assign-harish-1',
          userId: 'usr-harish_2025_l_btech_1',
          roleCode: 'student_base',
          roleName: 'Student Base',
          scopeCode: 'sec:cse-3a',
        ),
        UserRoleAssignmentModel(
          id: 'assign-harish-2',
          userId: 'usr-harish_2025_l_btech_1',
          roleCode: 'club_president',
          roleName: 'Club President',
          scopeCode: 'club:robotics',
        ),
      ],
      permissions: [
        'timetable:view',
        'attendance:view_self',
        'attendance:scan',
        'fees:pay',
        'notices:view',
        'club:publish_event',
        'club:spend_budget',
        'club:manage_members',
      ],
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
  List<HostelRoomModel> get cachedHostelRooms {
    _seedDefaultHostelRoomsIfEmpty();
    return List.unmodifiable(_cachedHostelRooms);
  }

  void _seedDefaultUsersIfEmpty() {
    if (!enableMockSeeding || _cachedUsers.isNotEmpty) return;
    _cachedUsers.addAll([
      UserModel(
        id: 'usr-campus_admin',
        campusHandle: 'campus_admin',
        firstName: 'Campus',
        lastName: 'Administrator',
        email: 'admin@campus.edu',
        personalEmail: 'director@campus-governance.org',
        phone: '+91 98000 00001',
        archetype: 'employee',
        universityRollNo: 'ADM-2023-0001',
        status: 'active',
        activeScopes: ['global'],
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'assign-admin-1',
            userId: 'usr-campus_admin',
            roleCode: 'admin',
            roleName: 'Campus Administrator',
            scopeCode: 'global',
          ),
          UserRoleAssignmentModel(
            id: 'assign-admin-2',
            userId: 'usr-campus_admin',
            roleCode: 'campus_director',
            roleName: 'Campus Director',
            scopeCode: 'global',
          ),
        ],
        permissions: ['*'],
        employeeRecord: {
          'joining_date': '2023-01-01T00:00:00Z',
          'employee_code': 'ADM-DIR-001',
          'employment_type': 'permanent',
          'is_academic': false,
          'is_administrative': true,
        },
        administrativeProfile: {
          'primary_unit': 'unit:administration',
          'designation': 'Campus Administrator',
          'office_location': 'Central Admin Tower 501',
        },
      ),
      UserModel(
        id: 'usr-harish_2025_l_btech_1',
        campusHandle: 'harish_2025_l_btech_1',
        firstName: 'Harish',
        lastName: 'Kumar',
        email: 'harish_2025_l_btech_1@campus.edu',
        personalEmail: 'harish.kumar@example.com',
        phone: '+91 98765 43210',
        emergencyContactName: 'Suresh Kumar (Father)',
        emergencyContactPhone: '+91 98765 00112',
        bloodGroup: 'O+',
        address: 'Room 204, Block 2, BBDIT Hostel',
        archetype: 'student',
        universityRollNo: '2025-CS-042',
        admissionApplicationNo: 'APP-2025-0819',
        universityRegNo: 'REG-2025-9921',
        status: 'active',
        activeScopes: ['global', 'sec:cse-3a', 'club:robotics'],
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'assign-harish-1',
            userId: 'usr-harish_2025_l_btech_1',
            roleCode: 'student_base',
            roleName: 'Student Base',
            scopeCode: 'sec:cse-3a',
          ),
          UserRoleAssignmentModel(
            id: 'assign-harish-2',
            userId: 'usr-harish_2025_l_btech_1',
            roleCode: 'club_president',
            roleName: 'Club President',
            scopeCode: 'club:robotics',
          ),
        ],
        permissions: [
          'timetable:view',
          'attendance:view_self',
          'attendance:scan',
          'fees:pay',
          'notices:view',
          'club:publish_event',
          'club:spend_budget',
          'club:manage_members',
        ],
        studentProfile: {
          'admission_year': 2025,
          'entry_type': 'lateral',
          'program': 'btech',
          'current_semester': 3,
          'batch_year': 2029,
          'section_scope': 'sec:cse-3a',
          'abc_id': '8912-3456-7890',
          'digilocker_verified': true,
          'digilocker_verified_at': '2025-08-15T10:30:00Z',
          'verified_documents': [
            {
              'document_type': 'apaar_abc',
              'document_title': 'APAAR / Academic Bank of Credits (ABC) ID',
              'issuer': 'National Academic Depository (NAD) / MeitY',
              'doc_ref_masked': '8912-XXXX-7890',
              'issued_year': 2023,
              'is_verified': true,
              'verification_hash': 'sha256:7b4f539e28f3a5dc1093c0d801e7492cbf3a41e97d10c7104b901a1e0b53ad62',
              'verified_at': '2025-08-15 10:30 IST',
              'status': 'verified',
            },
            {
              'document_type': 'class_x',
              'document_title': 'Secondary School Certificate (Class X)',
              'issuer': 'Central Board of Secondary Education (CBSE)',
              'doc_ref_masked': 'ROLL-12894104',
              'issued_year': 2021,
              'is_verified': true,
              'verification_hash': 'sha256:a18f23c907b8d145e69eef71410294b810938f2940ba19028e34891209384fa1',
              'verified_at': '2025-08-15 10:31 IST',
              'status': 'verified',
            },
            {
              'document_type': 'class_xii',
              'document_title': 'Senior School Certificate (Class XII - PCM)',
              'issuer': 'Central Board of Secondary Education (CBSE)',
              'doc_ref_masked': 'ROLL-61928401',
              'issued_year': 2023,
              'is_verified': true,
              'verification_hash': 'sha256:3948af019284baef71829340ab19284091823749812739481928374918273948',
              'verified_at': '2025-08-15 10:31 IST',
              'status': 'verified',
            },
            {
              'document_type': 'aadhaar_kyc',
              'document_title': 'Aadhaar Identity Verification',
              'issuer': 'Unique Identification Authority of India (UIDAI)',
              'doc_ref_masked': 'XXXX-XXXX-4091',
              'issued_year': 2024,
              'is_verified': true,
              'verification_hash': 'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
              'verified_at': '2025-08-15 10:32 IST',
              'status': 'verified',
            },
            {
              'document_type': 'domicile',
              'document_title': 'Uttar Pradesh State Domicile Certificate',
              'issuer': 'Revenue Department, Govt of Uttar Pradesh',
              'doc_ref_masked': 'UP-DOM-2023-90812',
              'issued_year': 2023,
              'is_verified': true,
              'verification_hash': 'sha256:f52f82c471829038471928409182374981729384019283749182739481729384',
              'verified_at': '2025-08-15 10:33 IST',
              'status': 'verified',
            },
          ],
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
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'assign-priya-1',
            userId: 'usr-priya_2024_emp_1',
            roleCode: 'hod',
            roleName: 'Head of Department',
            scopeCode: 'dept:cse',
          ),
          UserRoleAssignmentModel(
            id: 'assign-priya-2',
            userId: 'usr-priya_2024_emp_1',
            roleCode: 'faculty',
            roleName: 'Faculty Member',
            scopeCode: 'dept:cse',
          ),
        ],
        permissions: [
          'timetable:view',
          'timetable:edit',
          'timetable:declare_off',
          'attendance:mark',
          'attendance:broadcast',
          'attendance:view_roster',
          'attendance:approve',
          'syllabus:view',
          'syllabus:approve',
          'faculty:assign_workload',
          'department:manage',
          'notice:publish',
          'complaints:student',
          'complaints:employee',
        ],
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
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'assign-ramesh-1',
            userId: 'usr-ramesh_2023_emp_1',
            roleCode: 'warden',
            roleName: 'Hostel Warden',
            scopeCode: 'facility:gate-1',
          ),
        ],
        permissions: [
          'gatepass:approve',
          'room:inspect',
          'hostel:manage',
          'hostel:edit_room',
          'complaints:hostel',
          'complaints:campus',
        ],
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
        assignedRoles: [],
        permissions: [],
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
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'assign-mukesh-1',
            userId: 'usr-mukesh_2025_ext_1',
            roleCode: 'canteen_manager',
            roleName: 'Canteen Manager',
            scopeCode: 'building:canteen',
          ),
        ],
        permissions: [
          'gatepass:present',
          'profile:view_self',
          'canteen:operate',
          'mess:edit_menu',
          'mess:manage',
          'menu:update',
          'complaints:contractor',
        ],
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

  @override
  Future<UserModel> updateUserProfile({
    required String userId,
    String? personalEmail,
    String? phone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? bloodGroup,
    String? address,
  }) async {
    _seedDefaultUsersIfEmpty();
    await checkConnectivity();

    UserModel? updated;
    if (isOnline) {
      try {
        updated = await api.updateUserProfile(
          userId: userId,
          personalEmail: personalEmail,
          phone: phone,
          emergencyContactName: emergencyContactName,
          emergencyContactPhone: emergencyContactPhone,
          bloodGroup: bloodGroup,
          address: address,
        );
      } catch (_) {}
    }

    final idx = _cachedUsers.indexWhere((u) => u.id == userId || u.campusHandle == userId);
    if (idx != -1) {
      final current = _cachedUsers[idx];
      updated ??= current.copyWith(
        personalEmail: personalEmail ?? current.personalEmail,
        phone: phone ?? current.phone,
        emergencyContactName: emergencyContactName ?? current.emergencyContactName,
        emergencyContactPhone: emergencyContactPhone ?? current.emergencyContactPhone,
        bloodGroup: bloodGroup ?? current.bloodGroup,
        address: address ?? current.address,
      );
      _cachedUsers[idx] = updated;
    } else if (updated != null) {
      _cachedUsers.add(updated);
    } else {
      updated = UserModel(
        id: userId,
        campusHandle: userId,
        firstName: 'Campus',
        lastName: 'Member',
        email: '$userId@campus.edu',
        personalEmail: personalEmail,
        phone: phone,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        bloodGroup: bloodGroup,
        address: address,
        archetype: 'student',
      );
      _cachedUsers.add(updated);
    }
    return updated;
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

    await checkConnectivity();
    if (isOnline) {
      try {
        await api.declareDayOffBackend(
          dayOfWeek: dayOfWeek,
          scopeCode: scopeCode,
          reason: reason,
        );
      } catch (_) {}
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

    await checkConnectivity();
    if (isOnline) {
      try {
        await api.restoreDayScheduleBackend(
          dayOfWeek: dayOfWeek,
          scopeCode: scopeCode,
        );
      } catch (_) {}
    }
  }

  /// Evaluates scheduling conflicts for an instructor, room, or section.
  /// Runs both local multi-slot conflict inspection and server cross-section conflict checks.
  Future<List<TimetableConflictModel>> checkTimetableConflicts(TimetableSlotModel candidate) async {
    _seedDefaultTimetableIfEmpty();
    final List<TimetableConflictModel> conflicts = [];

    // Local in-memory validation
    if (!candidate.isFree && !candidate.isOff && !candidate.isLunch) {
      final cleanRoom = candidate.roomNumber.trim().toLowerCase();
      final cleanInst = candidate.instructorName.trim().toLowerCase();
      final cleanScope = candidate.scopeCode.trim().toLowerCase();

      for (final existing in _cachedTimetable) {
        if (existing.id == candidate.id || existing.isFree || existing.isOff || existing.isLunch) {
          continue;
        }
        if (existing.dayOfWeek != candidate.dayOfWeek) {
          continue;
        }

        // Time overlap: existing.start < candidate.end && candidate.start < existing.end
        final overlaps = existing.startTime.compareTo(candidate.endTime) < 0 &&
            candidate.startTime.compareTo(existing.endTime) < 0;
        if (!overlaps) {
          continue;
        }

        // 1. Room conflict
        final existingRoom = existing.roomNumber.trim().toLowerCase();
        if (cleanRoom.isNotEmpty && cleanRoom != '-' && cleanRoom == existingRoom) {
          conflicts.add(TimetableConflictModel(
            type: 'room',
            message: 'Room ${candidate.roomNumber} is already occupied by ${existing.courseCode} (${existing.courseName}) from ${existing.startTime} to ${existing.endTime}',
            conflictingSlot: existing,
          ));
        }

        // 2. Instructor conflict
        final existingInst = existing.instructorName.trim().toLowerCase();
        if (cleanInst.isNotEmpty && cleanInst == existingInst) {
          conflicts.add(TimetableConflictModel(
            type: 'instructor',
            message: 'Instructor ${candidate.instructorName} is already assigned to ${existing.courseCode} (${existing.scopeCode}) from ${existing.startTime} to ${existing.endTime}',
            conflictingSlot: existing,
          ));
        }

        // 3. Section conflict
        final existingScope = existing.scopeCode.trim().toLowerCase();
        if (cleanScope.isNotEmpty && cleanScope == existingScope) {
          conflicts.add(TimetableConflictModel(
            type: 'section',
            message: 'Section ${candidate.scopeCode} already has ${existing.courseCode} scheduled from ${existing.startTime} to ${existing.endTime}',
            conflictingSlot: existing,
          ));
        }
      }
    }

    // Query backend for cross-section global conflicts if online
    await checkConnectivity();
    if (isOnline) {
      try {
        final serverConflicts = await api.checkTimetableConflict(candidate);
        for (final sc in serverConflicts) {
          if (!conflicts.any((c) => c.type == sc.type && c.conflictingSlot.id == sc.conflictingSlot.id)) {
            conflicts.add(sc);
          }
        }
      } catch (_) {}
    }

    return conflicts;
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
    if (!enableMockSeeding || _cachedTimetable.isNotEmpty) return;
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
        courseCode: 'LUNCH',
        courseName: 'Midday Lunch Break',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 1,
        startTime: '12:00',
        endTime: '13:00',
        roomNumber: 'Campus Cafeteria',
        slotType: 'lunch',
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
        courseCode: 'LUNCH',
        courseName: 'Midday Lunch Break',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 2,
        startTime: '13:00',
        endTime: '14:00',
        roomNumber: 'Campus Cafeteria',
        slotType: 'lunch',
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
        courseCode: 'LUNCH',
        courseName: 'Midday Lunch Break',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 3,
        startTime: '12:00',
        endTime: '13:00',
        roomNumber: 'Campus Cafeteria',
        slotType: 'lunch',
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
        courseCode: 'LUNCH',
        courseName: 'Midday Lunch Break',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 4,
        startTime: '12:00',
        endTime: '13:00',
        roomNumber: 'Campus Cafeteria',
        slotType: 'lunch',
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
        courseCode: 'LUNCH',
        courseName: 'Midday Lunch Break',
        scopeCode: 'sec:cse-3a',
        instructorName: '',
        dayOfWeek: 5,
        startTime: '12:00',
        endTime: '13:00',
        roomNumber: 'Campus Cafeteria',
        slotType: 'lunch',
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
    if (!enableMockSeeding || _cachedNotices.isNotEmpty) return;
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
        title: 'BBDIT Hostels Optical Fiber & Wi-Fi 6 Upgrade Complete',
        content: 'Network bandwidth across Block 1 and Block 2 has been enhanced to 10Gbps symmetric uplink. Connect to the BBDIT-Secure network using your canonical identity.',
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
    if (enableMockSeeding && _cachedSummaries.isEmpty) {
      _cachedSummaries.addAll(_getDefaultStudentSummaries());
    }
    return _cachedSummaries;
  }

  @override
  double getAttendanceThreshold({String? sectionScope}) {
    if (sectionScope != null &&
        _sectionAttendanceThresholds.containsKey(sectionScope)) {
      return _sectionAttendanceThresholds[sectionScope]!;
    }
    return _sectionAttendanceThresholds['global'] ?? 75.0;
  }

  @override
  Future<void> setAttendanceThreshold({
    required String sectionScope,
    required double threshold,
  }) async {
    final clamped = threshold.clamp(40.0, 75.0);
    _sectionAttendanceThresholds[sectionScope] = clamped;
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
    if (!enableMockSeeding || _cachedDepartments.isNotEmpty) return;

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

  // ----------------------------------------------------
  // HOSTEL ROOM SYSTEM (100 - 999)
  // ----------------------------------------------------

  void _seedDefaultHostelRoomsIfEmpty() {
    if (!enableMockSeeding || _cachedHostelRooms.isNotEmpty) return;

    final now = DateTime.now();

    // Room 101: Floor 0 (101-199), Block 1, fully furnished, 2 occupants
    _cachedHostelRooms.add(HostelRoomModel(
      id: 'room-101',
      roomNumber: 101,
      blockName: 'Block 1',
      floor: 0,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
      assets: [
        HostelAssetModel(id: 'asset-101-bed-1', roomNumber: 101, assetType: 'bed', serialNumber: 'BED-101-01', installedAt: now),
        HostelAssetModel(id: 'asset-101-bed-2', roomNumber: 101, assetType: 'bed', serialNumber: 'BED-101-02', installedAt: now),
        HostelAssetModel(id: 'asset-101-bed-3', roomNumber: 101, assetType: 'bed', serialNumber: 'BED-101-03', installedAt: now),
        HostelAssetModel(id: 'asset-101-table-1', roomNumber: 101, assetType: 'table', serialNumber: 'TAB-101-01', installedAt: now),
        HostelAssetModel(id: 'asset-101-table-2', roomNumber: 101, assetType: 'table', serialNumber: 'TAB-101-02', installedAt: now),
        HostelAssetModel(id: 'asset-101-table-3', roomNumber: 101, assetType: 'table', serialNumber: 'TAB-101-03', installedAt: now),
        HostelAssetModel(id: 'asset-101-chr-1', roomNumber: 101, assetType: 'chair', serialNumber: 'CHR-101-01', installedAt: now),
        HostelAssetModel(id: 'asset-101-chr-2', roomNumber: 101, assetType: 'chair', serialNumber: 'CHR-101-02', installedAt: now),
        HostelAssetModel(id: 'asset-101-chr-3', roomNumber: 101, assetType: 'chair', serialNumber: 'CHR-101-03', installedAt: now),
        HostelAssetModel(id: 'asset-101-tl-1', roomNumber: 101, assetType: 'tubelight', serialNumber: 'TL-101-01', installedAt: now),
        HostelAssetModel(id: 'asset-101-tl-2', roomNumber: 101, assetType: 'tubelight', serialNumber: 'TL-101-02', installedAt: now),
        HostelAssetModel(id: 'asset-101-fan-1', roomNumber: 101, assetType: 'fan', serialNumber: 'FAN-101-01', installedAt: now),
        HostelAssetModel(id: 'asset-101-fan-2', roomNumber: 101, assetType: 'fan', serialNumber: 'FAN-101-02', installedAt: now),
        HostelAssetModel(id: 'asset-101-lck-1', roomNumber: 101, assetType: 'locker', serialNumber: 'LCK-101-01', installedAt: now),
        HostelAssetModel(id: 'asset-101-lck-2', roomNumber: 101, assetType: 'locker', serialNumber: 'LCK-101-02', installedAt: now),
        HostelAssetModel(id: 'asset-101-lck-3', roomNumber: 101, assetType: 'locker', serialNumber: 'LCK-101-03', installedAt: now),
      ],
      occupants: [
        HostelOccupantModel(userId: 'u-student-harish', campusHandle: 'harish_2025_l_btech_1', name: 'Harish Kumar', allottedAt: now.subtract(const Duration(days: 20))),
        HostelOccupantModel(userId: 'u-student-rohit', campusHandle: 'rohit_2025_btech_2', name: 'Rohit Verma', allottedAt: now.subtract(const Duration(days: 15))),
      ],
    ));

    // Room 102: Floor 0 (101-199), Block 1, partially furnished, 1 occupant
    _cachedHostelRooms.add(HostelRoomModel(
      id: 'room-102',
      roomNumber: 102,
      blockName: 'Block 1',
      floor: 0,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
      assets: [
        HostelAssetModel(id: 'asset-102-bed-1', roomNumber: 102, assetType: 'bed', serialNumber: 'BED-102-01', installedAt: now),
        HostelAssetModel(id: 'asset-102-bed-2', roomNumber: 102, assetType: 'bed', serialNumber: 'BED-102-02', installedAt: now),
        HostelAssetModel(id: 'asset-102-table-1', roomNumber: 102, assetType: 'table', serialNumber: 'TAB-102-01', installedAt: now),
        HostelAssetModel(id: 'asset-102-table-2', roomNumber: 102, assetType: 'table', serialNumber: 'TAB-102-02', installedAt: now),
        HostelAssetModel(id: 'asset-102-chr-1', roomNumber: 102, assetType: 'chair', serialNumber: 'CHR-102-01', installedAt: now),
        HostelAssetModel(id: 'asset-102-chr-2', roomNumber: 102, assetType: 'chair', serialNumber: 'CHR-102-02', installedAt: now),
        HostelAssetModel(id: 'asset-102-tl-1', roomNumber: 102, assetType: 'tubelight', serialNumber: 'TL-102-01', installedAt: now),
        HostelAssetModel(id: 'asset-102-tl-2', roomNumber: 102, assetType: 'tubelight', serialNumber: 'TL-102-02', installedAt: now),
        HostelAssetModel(id: 'asset-102-fan-1', roomNumber: 102, assetType: 'fan', serialNumber: 'FAN-102-01', installedAt: now),
        HostelAssetModel(id: 'asset-102-lck-1', roomNumber: 102, assetType: 'locker', serialNumber: 'LCK-102-01', installedAt: now),
        HostelAssetModel(id: 'asset-102-lck-2', roomNumber: 102, assetType: 'locker', serialNumber: 'LCK-102-02', installedAt: now),
      ],
      occupants: [
        HostelOccupantModel(userId: 'u-student-amit', campusHandle: 'amit_2025_btech_3', name: 'Amit Shah', allottedAt: now.subtract(const Duration(days: 10))),
      ],
    ));

    // Room 204: Floor 1 (201-299), Block 2, fully furnished, vacant (0 occupants)
    _cachedHostelRooms.add(HostelRoomModel(
      id: 'room-204',
      roomNumber: 204,
      blockName: 'Block 2',
      floor: 1,
      createdAt: now.subtract(const Duration(days: 20)),
      updatedAt: now,
      assets: [
        HostelAssetModel(id: 'asset-204-bed-1', roomNumber: 204, assetType: 'bed', serialNumber: 'BED-204-01', installedAt: now),
        HostelAssetModel(id: 'asset-204-bed-2', roomNumber: 204, assetType: 'bed', serialNumber: 'BED-204-02', installedAt: now),
        HostelAssetModel(id: 'asset-204-bed-3', roomNumber: 204, assetType: 'bed', serialNumber: 'BED-204-03', installedAt: now),
        HostelAssetModel(id: 'asset-204-table-1', roomNumber: 204, assetType: 'table', serialNumber: 'TAB-204-01', installedAt: now),
        HostelAssetModel(id: 'asset-204-table-2', roomNumber: 204, assetType: 'table', serialNumber: 'TAB-204-02', installedAt: now),
        HostelAssetModel(id: 'asset-204-table-3', roomNumber: 204, assetType: 'table', serialNumber: 'TAB-204-03', installedAt: now),
        HostelAssetModel(id: 'asset-204-chr-1', roomNumber: 204, assetType: 'chair', serialNumber: 'CHR-204-01', installedAt: now),
        HostelAssetModel(id: 'asset-204-chr-2', roomNumber: 204, assetType: 'chair', serialNumber: 'CHR-204-02', installedAt: now),
        HostelAssetModel(id: 'asset-204-chr-3', roomNumber: 204, assetType: 'chair', serialNumber: 'CHR-204-03', installedAt: now),
        HostelAssetModel(id: 'asset-204-tl-1', roomNumber: 204, assetType: 'tubelight', serialNumber: 'TL-204-01', installedAt: now),
        HostelAssetModel(id: 'asset-204-tl-2', roomNumber: 204, assetType: 'tubelight', serialNumber: 'TL-204-02', installedAt: now),
        HostelAssetModel(id: 'asset-204-fan-1', roomNumber: 204, assetType: 'fan', serialNumber: 'FAN-204-01', installedAt: now),
        HostelAssetModel(id: 'asset-204-fan-2', roomNumber: 204, assetType: 'fan', serialNumber: 'FAN-204-02', installedAt: now),
        HostelAssetModel(id: 'asset-204-lck-1', roomNumber: 204, assetType: 'locker', serialNumber: 'LCK-204-01', installedAt: now),
        HostelAssetModel(id: 'asset-204-lck-2', roomNumber: 204, assetType: 'locker', serialNumber: 'LCK-204-02', installedAt: now),
        HostelAssetModel(id: 'asset-204-lck-3', roomNumber: 204, assetType: 'locker', serialNumber: 'LCK-204-03', installedAt: now),
      ],
      occupants: const [],
    ));

    // Room 305: Floor 2 (301-399), Block 3, starter fixtures
    _cachedHostelRooms.add(HostelRoomModel(
      id: 'room-305',
      roomNumber: 305,
      blockName: 'Block 3',
      floor: 2,
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now,
      assets: [
        HostelAssetModel(id: 'asset-305-bed-1', roomNumber: 305, assetType: 'bed', serialNumber: 'BED-305-01', installedAt: now),
        HostelAssetModel(id: 'asset-305-table-1', roomNumber: 305, assetType: 'table', serialNumber: 'TAB-305-01', installedAt: now),
        HostelAssetModel(id: 'asset-305-chr-1', roomNumber: 305, assetType: 'chair', serialNumber: 'CHR-305-01', installedAt: now),
        HostelAssetModel(id: 'asset-305-tl-1', roomNumber: 305, assetType: 'tubelight', serialNumber: 'TL-305-01', installedAt: now),
        HostelAssetModel(id: 'asset-305-fan-1', roomNumber: 305, assetType: 'fan', serialNumber: 'FAN-305-01', installedAt: now),
        HostelAssetModel(id: 'asset-305-lck-1', roomNumber: 305, assetType: 'locker', serialNumber: 'LCK-305-01', installedAt: now),
      ],
      occupants: const [],
    ));

    // Room 402: Floor 3 (401-499), Block 4
    _cachedHostelRooms.add(HostelRoomModel(
      id: 'room-402',
      roomNumber: 402,
      blockName: 'Block 4',
      floor: 3,
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now,
      assets: [
        HostelAssetModel(id: 'asset-402-bed-1', roomNumber: 402, assetType: 'bed', serialNumber: 'BED-402-01', installedAt: now),
        HostelAssetModel(id: 'asset-402-table-1', roomNumber: 402, assetType: 'table', serialNumber: 'TAB-402-01', installedAt: now),
        HostelAssetModel(id: 'asset-402-chr-1', roomNumber: 402, assetType: 'chair', serialNumber: 'CHR-402-01', installedAt: now),
        HostelAssetModel(id: 'asset-402-tl-1', roomNumber: 402, assetType: 'tubelight', serialNumber: 'TL-402-01', installedAt: now),
        HostelAssetModel(id: 'asset-402-fan-1', roomNumber: 402, assetType: 'fan', serialNumber: 'FAN-402-01', installedAt: now),
        HostelAssetModel(id: 'asset-402-lck-1', roomNumber: 402, assetType: 'locker', serialNumber: 'LCK-402-01', installedAt: now),
      ],
      occupants: const [],
    ));
  }

  Future<List<HostelRoomModel>> getHostelRooms({int? floor}) async {
    _seedDefaultHostelRoomsIfEmpty();
    await checkConnectivity();

    if (isOnline) {
      try {
        final serverRooms = await api.fetchHostelRooms(floor: floor);
        if (serverRooms.isNotEmpty) {
          _cachedHostelRooms.clear();
          _cachedHostelRooms.addAll(serverRooms);
        }
      } catch (_) {}
    }

    final rooms = floor != null
        ? _cachedHostelRooms.where((r) => r.floor == floor).toList()
        : List<HostelRoomModel>.from(_cachedHostelRooms);

    rooms.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
    return rooms;
  }

  Future<HostelRoomModel> createHostelRoom(int roomNumber, String blockName) async {
    _seedDefaultHostelRoomsIfEmpty();
    final err = HostelRoomModel.validateRoomNumber(roomNumber);
    if (err != null) {
      throw Exception(err);
    }

    if (_cachedHostelRooms.any((r) => r.roomNumber == roomNumber)) {
      throw Exception('Hostel room $roomNumber already exists');
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        final created = await api.createHostelRoom(roomNumber, blockName);
        _cachedHostelRooms.add(created);
        return created;
      } catch (_) {}
    }

    final now = DateTime.now();
    final room = HostelRoomModel(
      id: 'room-$roomNumber',
      roomNumber: roomNumber,
      blockName: blockName.trim().isNotEmpty ? blockName.trim() : 'Block 1',
      floor: HostelRoomModel.deriveFloor(roomNumber),
      assets: const [],
      occupants: const [],
      createdAt: now,
      updatedAt: now,
    );

    _cachedHostelRooms.add(room);
    return room;
  }

  Future<HostelRoomModel> updateHostelRoom(int originalRoomNumber, int newRoomNumber, String blockName) async {
    _seedDefaultHostelRoomsIfEmpty();
    final roomIdx = _cachedHostelRooms.indexWhere((r) => r.roomNumber == originalRoomNumber);
    if (roomIdx == -1) {
      throw Exception('Hostel room $originalRoomNumber not found');
    }

    final err = HostelRoomModel.validateRoomNumber(newRoomNumber);
    if (err != null) {
      throw Exception(err);
    }

    if (newRoomNumber != originalRoomNumber && _cachedHostelRooms.any((r) => r.roomNumber == newRoomNumber)) {
      throw Exception('Hostel room $newRoomNumber already exists');
    }

    final originalRoom = _cachedHostelRooms[roomIdx];
    final cleanBlock = blockName.trim().isNotEmpty ? blockName.trim() : originalRoom.blockName;

    await checkConnectivity();
    if (isOnline) {
      try {
        final updated = await api.updateHostelRoom(
          originalRoomNumber: originalRoomNumber,
          newRoomNumber: newRoomNumber,
          blockName: cleanBlock,
        );
        _cachedHostelRooms[roomIdx] = updated;
        return updated;
      } catch (_) {}
    }

    final updatedAssets = originalRoom.assets.map((a) => a.copyWith(roomNumber: newRoomNumber)).toList();
    final updatedRoom = originalRoom.copyWith(
      roomNumber: newRoomNumber,
      blockName: cleanBlock,
      floor: HostelRoomModel.deriveFloor(newRoomNumber),
      assets: updatedAssets,
      updatedAt: DateTime.now(),
    );
    _cachedHostelRooms[roomIdx] = updatedRoom;
    return updatedRoom;
  }

  Future<HostelAssetModel> addHostelAsset(int roomNumber, String assetType, String serialNumber, String condition) async {
    _seedDefaultHostelRoomsIfEmpty();

    final roomIdx = _cachedHostelRooms.indexWhere((r) => r.roomNumber == roomNumber);
    if (roomIdx == -1) {
      throw Exception('Hostel room $roomNumber not found');
    }

    final room = _cachedHostelRooms[roomIdx];
    final normalizedType = assetType.trim().toLowerCase();

    if (!room.canAddAsset(normalizedType)) {
      final maxCap = room.maxCapacityForAssetType(normalizedType);
      final current = room.countForAssetType(normalizedType);
      throw Exception('Room $roomNumber already has $current/$maxCap ${normalizedType}s (capacity reached)');
    }

    final serialErr = HostelRoomModel.validateSerialNumber(serialNumber);
    if (serialErr != null) {
      throw Exception(serialErr);
    }

    final trimmedSerial = serialNumber.trim();
    for (final r in _cachedHostelRooms) {
      for (final a in r.assets) {
        if (a.serialNumber.toLowerCase() == trimmedSerial.toLowerCase()) {
          throw Exception('Serial number \'$trimmedSerial\' is already assigned to room ${r.roomNumber}');
        }
      }
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        final asset = await api.addHostelAsset(roomNumber, normalizedType, trimmedSerial, condition);
        final updatedAssets = List<HostelAssetModel>.from(room.assets)..add(asset);
        _cachedHostelRooms[roomIdx] = room.copyWith(assets: updatedAssets, updatedAt: DateTime.now());
        return asset;
      } catch (_) {}
    }

    final asset = HostelAssetModel(
      id: 'asset-$roomNumber-$normalizedType-${DateTime.now().millisecondsSinceEpoch}',
      roomNumber: roomNumber,
      assetType: normalizedType,
      serialNumber: trimmedSerial,
      condition: condition.isNotEmpty ? condition : 'operational',
      installedAt: DateTime.now(),
    );

    final updatedAssets = List<HostelAssetModel>.from(room.assets)..add(asset);
    _cachedHostelRooms[roomIdx] = room.copyWith(assets: updatedAssets, updatedAt: DateTime.now());
    return asset;
  }

  Future<void> removeHostelAsset(int roomNumber, String assetId) async {
    _seedDefaultHostelRoomsIfEmpty();

    final roomIdx = _cachedHostelRooms.indexWhere((r) => r.roomNumber == roomNumber);
    if (roomIdx == -1) {
      throw Exception('Hostel room $roomNumber not found');
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        await api.removeHostelAsset(roomNumber, assetId);
      } catch (_) {}
    }

    final room = _cachedHostelRooms[roomIdx];
    final updatedAssets = room.assets.where((a) => a.id != assetId && a.serialNumber != assetId).toList();
    _cachedHostelRooms[roomIdx] = room.copyWith(assets: updatedAssets, updatedAt: DateTime.now());
  }

  Future<HostelAssetModel> updateHostelAsset(int roomNumber, String assetId, {String? serialNumber, String? condition}) async {
    _seedDefaultHostelRoomsIfEmpty();
    final roomIdx = _cachedHostelRooms.indexWhere((r) => r.roomNumber == roomNumber);
    if (roomIdx == -1) {
      throw Exception('Hostel room $roomNumber not found');
    }

    final room = _cachedHostelRooms[roomIdx];
    final assetIdx = room.assets.indexWhere((a) => a.id == assetId || a.serialNumber == assetId);
    if (assetIdx == -1) {
      throw Exception('Asset $assetId not found in room $roomNumber');
    }

    final currentAsset = room.assets[assetIdx];
    final newSerial = (serialNumber != null && serialNumber.trim().isNotEmpty) ? serialNumber.trim() : currentAsset.serialNumber;
    final newCondition = (condition != null && condition.trim().isNotEmpty) ? condition.trim() : currentAsset.condition;

    final serialErr = HostelRoomModel.validateSerialNumber(newSerial);
    if (serialErr != null) {
      throw Exception(serialErr);
    }

    if (newSerial.toLowerCase() != currentAsset.serialNumber.toLowerCase()) {
      for (final r in _cachedHostelRooms) {
        for (final a in r.assets) {
          if (a.id != currentAsset.id && a.serialNumber.toLowerCase() == newSerial.toLowerCase()) {
            throw Exception('Serial number \'$newSerial\' is already assigned to room ${r.roomNumber}');
          }
        }
      }
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        final updated = await api.updateHostelAsset(
          roomNumber: roomNumber,
          assetId: currentAsset.id,
          serialNumber: newSerial,
          condition: newCondition,
        );
        final assets = List<HostelAssetModel>.from(room.assets);
        assets[assetIdx] = updated;
        _cachedHostelRooms[roomIdx] = room.copyWith(assets: assets, updatedAt: DateTime.now());
        return updated;
      } catch (_) {}
    }

    final updatedAsset = currentAsset.copyWith(
      serialNumber: newSerial,
      condition: newCondition,
    );
    final assets = List<HostelAssetModel>.from(room.assets);
    assets[assetIdx] = updatedAsset;
    _cachedHostelRooms[roomIdx] = room.copyWith(assets: assets, updatedAt: DateTime.now());
    return updatedAsset;
  }

  Future<HostelOccupantModel> assignHostelOccupant(int roomNumber, String userId, String handle, String name) async {
    _seedDefaultHostelRoomsIfEmpty();

    final roomIdx = _cachedHostelRooms.indexWhere((r) => r.roomNumber == roomNumber);
    if (roomIdx == -1) {
      throw Exception('Hostel room $roomNumber not found');
    }

    final room = _cachedHostelRooms[roomIdx];
    if (!room.canAddOccupant) {
      throw Exception('Room $roomNumber is at maximum occupant capacity (${HostelRoomModel.maxOccupants}/${HostelRoomModel.maxOccupants})');
    }

    final trimmedHandle = handle.trim();
    final trimmedUserId = userId.trim();
    for (final r in _cachedHostelRooms) {
      for (final occ in r.occupants) {
        if ((trimmedUserId.isNotEmpty && occ.userId == trimmedUserId) ||
            (trimmedHandle.isNotEmpty && occ.campusHandle == trimmedHandle)) {
          throw Exception('Resident ${occ.name} is already allocated to room ${r.roomNumber}');
        }
      }
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        final occ = await api.assignHostelOccupant(roomNumber, trimmedUserId, trimmedHandle, name);
        final updatedOccupants = List<HostelOccupantModel>.from(room.occupants)..add(occ);
        _cachedHostelRooms[roomIdx] = room.copyWith(occupants: updatedOccupants, updatedAt: DateTime.now());
        return occ;
      } catch (_) {}
    }

    final occ = HostelOccupantModel(
      userId: trimmedUserId,
      campusHandle: trimmedHandle,
      name: name.trim(),
      allottedAt: DateTime.now(),
    );

    final updatedOccupants = List<HostelOccupantModel>.from(room.occupants)..add(occ);
    _cachedHostelRooms[roomIdx] = room.copyWith(occupants: updatedOccupants, updatedAt: DateTime.now());
    return occ;
  }

  Future<void> removeHostelOccupant(int roomNumber, String userId) async {
    _seedDefaultHostelRoomsIfEmpty();

    final roomIdx = _cachedHostelRooms.indexWhere((r) => r.roomNumber == roomNumber);
    if (roomIdx == -1) {
      throw Exception('Hostel room $roomNumber not found');
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        await api.removeHostelOccupant(roomNumber, userId);
      } catch (_) {}
    }

    final room = _cachedHostelRooms[roomIdx];
    final updatedOccupants = room.occupants.where((o) => o.userId != userId && o.campusHandle != userId).toList();
    _cachedHostelRooms[roomIdx] = room.copyWith(occupants: updatedOccupants, updatedAt: DateTime.now());
  }

  // ----------------------------------------------------
  // MESS OPERATIONS (TIMETABLE, SUNDAY BRUNCH, RATINGS)
  // ----------------------------------------------------

  void _seedDefaultMessDataIfEmpty() {
    if (!enableMockSeeding || _cachedMessMeals.isNotEmpty) return;

    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    for (final day in days) {
      final dayTitle = '${day[0].toUpperCase()}${day.substring(1)}';

      // Breakfast (Mon - Sat)
      _cachedMessMeals.add(MessMealModel(
        id: 'meal-$day-breakfast',
        dayOfWeek: day,
        mealType: 'breakfast',
        startTime: '07:30',
        endTime: '09:30',
        title: '$dayTitle Breakfast',
        menuSummary: 'Idli, Vada, Sambar, Coconut Chutney, Bread Butter, Tea / Coffee',
        items: const ['Idli (3 pcs)', 'Medu Vada (1 pc)', 'Sambar', 'Chutney', 'Bread & Jam', 'Tea / Coffee'],
      ));

      // Lunch (Mon - Sat)
      _cachedMessMeals.add(MessMealModel(
        id: 'meal-$day-lunch',
        dayOfWeek: day,
        mealType: 'lunch',
        startTime: '12:30',
        endTime: '14:30',
        title: '$dayTitle Lunch',
        menuSummary: 'Steamed Basmati Rice, Chapati, Dal Tadka, Paneer Butter Masala, Curd, Green Salad',
        items: const ['Basmati Rice', 'Tawa Roti', 'Dal Tadka', 'Paneer Sabzi', 'Curd', 'Kachumber Salad'],
      ));

      // Dinner (Mon - Sat)
      _cachedMessMeals.add(MessMealModel(
        id: 'meal-$day-dinner',
        dayOfWeek: day,
        mealType: 'dinner',
        startTime: '19:30',
        endTime: '21:30',
        title: '$dayTitle Dinner',
        menuSummary: 'Phulka, Jeera Rice, Rajma Curry, Mix Veg Poriyal, Gulab Jamun, Buttermilk',
        items: const ['Phulka', 'Jeera Rice', 'Punjabi Rajma', 'Dry Mix Veg', 'Gulab Jamun', 'Spiced Buttermilk'],
      ));
    }

    // Sunday: Brunch replaces Breakfast and Lunch!
    _cachedMessMeals.add(const MessMealModel(
      id: 'meal-sunday-brunch',
      dayOfWeek: 'sunday',
      mealType: 'brunch',
      startTime: '10:00',
      endTime: '13:00',
      title: 'Sunday Grand Brunch (Replaces Breakfast & Lunch)',
      menuSummary: 'Chole Bhature, Masala Dosa Counter, Poha, Fresh Fruit Platter, Cold Coffee, Badam Milk',
      items: ['Chole Bhature (2 pcs)', 'Live Masala Dosa', 'Indori Poha', 'Cut Fruit Salad', 'Iced Cold Coffee', 'Kesar Badam Milk'],
    ));

    // Sunday Dinner
    _cachedMessMeals.add(const MessMealModel(
      id: 'meal-sunday-dinner',
      dayOfWeek: 'sunday',
      mealType: 'dinner',
      startTime: '19:30',
      endTime: '21:30',
      title: 'Sunday Special Dinner',
      menuSummary: 'Veg Biryani / Chicken Biryani, Mirchi Ka Salan, Raita, Rasmalai, Ice Cream',
      items: ['Hyderabadi Biryani', 'Mirchi Ka Salan', 'Boondi Raita', 'Rasmalai', 'Vanilla Cup'],
    ));

    // Seed Initial Student Feedback & Compulsory/Optional Messages
    final now = DateTime.now();
    _cachedMessRatings.addAll([
      MessRatingModel(
        id: 'rate-001',
        mealId: 'meal-sunday-brunch',
        dayOfWeek: 'sunday',
        mealType: 'brunch',
        userId: 'u-student-harish',
        userName: 'Harish Kumar',
        campusHandle: 'harish_2025_l_btech_1',
        rating: 'very_good',
        message: 'The Sunday live dosa counter was exceptional this week, crispy and fresh.',
        createdAt: now.subtract(const Duration(hours: 14)),
      ),
      MessRatingModel(
        id: 'rate-002',
        mealId: 'meal-sunday-brunch',
        dayOfWeek: 'sunday',
        mealType: 'brunch',
        userId: 'u-student-rohit',
        userName: 'Rohit Verma',
        campusHandle: 'rohit_2025_btech_2',
        rating: 'good',
        message: 'Brunch timings from 10:00 to 13:00 work very well on weekends.',
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
      MessRatingModel(
        id: 'rate-003',
        mealId: 'meal-saturday-dinner',
        dayOfWeek: 'saturday',
        mealType: 'dinner',
        userId: 'u-student-amit',
        userName: 'Amit Shah',
        campusHandle: 'amit_2025_btech_3',
        rating: 'poor',
        message: 'Dal was overly salty and chapatis were cold by 20:30.', // Compulsory feedback
        createdAt: now.subtract(const Duration(hours: 28)),
      ),
      MessRatingModel(
        id: 'rate-004',
        mealId: 'meal-friday-lunch',
        dayOfWeek: 'friday',
        mealType: 'lunch',
        userId: 'u-student-harish',
        userName: 'Harish Kumar',
        campusHandle: 'harish_2025_l_btech_1',
        rating: 'average',
        message: 'Paneer cubes were slightly rubbery, but the rice quality was good.', // Compulsory feedback
        createdAt: now.subtract(const Duration(hours: 46)),
      ),
      MessRatingModel(
        id: 'rate-005',
        mealId: 'meal-friday-breakfast',
        dayOfWeek: 'friday',
        mealType: 'breakfast',
        userId: 'u-student-priya',
        userName: 'Priya Sharma',
        campusHandle: 'priya_2025_btech_4',
        rating: 'very_poor',
        message: 'Chutney was fermented and smelled sour; reported to mess vendor immediately.', // Compulsory feedback
        createdAt: now.subtract(const Duration(hours: 52)),
      ),
      MessRatingModel(
        id: 'rate-006',
        mealId: 'meal-thursday-dinner',
        dayOfWeek: 'thursday',
        mealType: 'dinner',
        userId: 'u-student-rohit',
        userName: 'Rohit Verma',
        campusHandle: 'rohit_2025_btech_2',
        rating: 'abstained',
        message: '', // Optional for abstained
        createdAt: now.subtract(const Duration(hours: 70)),
      ),
    ]);
  }

  Future<List<MessMealModel>> getMessTimetable() async {
    _seedDefaultMessDataIfEmpty();
    await checkConnectivity();

    if (isOnline) {
      try {
        final serverTimetable = await api.fetchMessTimetable();
        if (serverTimetable.isNotEmpty) {
          _cachedMessMeals.clear();
          _cachedMessMeals.addAll(serverTimetable);
        }
      } catch (_) {}
    }

    return List.unmodifiable(_cachedMessMeals);
  }

  Future<MessMealModel> updateMessMeal(MessMealModel updatedMeal) async {
    _seedDefaultMessDataIfEmpty();
    final day = updatedMeal.dayOfWeek.trim().toLowerCase();
    final type = updatedMeal.mealType.trim().toLowerCase();

    if (day == 'sunday') {
      if (type != 'brunch' && type != 'dinner') {
        throw Exception('On Sunday only brunch and dinner can be served');
      }
    } else {
      if (type == 'brunch') {
        throw Exception('Brunch is only allowed on Sunday');
      }
    }

    final idx = _cachedMessMeals.indexWhere(
      (m) => m.id == updatedMeal.id || (m.dayOfWeek.toLowerCase() == day && m.mealType.toLowerCase() == type),
    );
    if (idx == -1) {
      throw Exception('Mess meal ${updatedMeal.id} not found');
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.updateMessMeal(updatedMeal);
        _cachedMessMeals[idx] = res;
        return res;
      } catch (_) {}
    }

    _cachedMessMeals[idx] = updatedMeal;
    return updatedMeal;
  }

  Future<MessReportSummary> getMessRatingsReport({String? mealId, String? rating}) async {
    _seedDefaultMessDataIfEmpty();
    await checkConnectivity();

    if (isOnline) {
      try {
        return await api.fetchMessRatingsReport(mealId: mealId, rating: rating);
      } catch (_) {}
    }

    final counts = <String, int>{
      'very_poor': 0,
      'poor': 0,
      'average': 0,
      'good': 0,
      'very_good': 0,
      'abstained': 0,
    };

    double totalScore = 0.0;
    int scoredCount = 0;
    int totalRatings = 0;
    final messages = <MessRatingModel>[];

    for (final r in _cachedMessRatings) {
      if (mealId != null && mealId.isNotEmpty && r.mealId != mealId) {
        continue;
      }

      counts[r.rating] = (counts[r.rating] ?? 0) + 1;
      totalRatings++;

      final score = r.ratingEnum.score;
      if (score != null) {
        totalScore += score.toDouble();
        scoredCount++;
      }

      if (rating == null || rating.isEmpty || r.rating == rating ||
          (rating == 'compulsory' && r.isMessageCompulsory)) {
        messages.add(r);
      }
    }

    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final avgScore = scoredCount > 0 ? (totalScore / scoredCount) : 0.0;

    return MessReportSummary(
      totalRatings: totalRatings,
      averageScore: avgScore,
      ratingCounts: counts,
      recentMessages: messages,
      sundayScheduleNote: 'On Sunday, Brunch (10:00 - 13:00) replaces Breakfast and Lunch. Dinner is served at 19:30 - 21:30.',
    );
  }

  Future<MessRatingModel> submitMessRating({
    required String mealId,
    required String userId,
    required String userName,
    required String campusHandle,
    required String rating,
    required String message,
  }) async {
    _seedDefaultMessDataIfEmpty();

    final meal = _cachedMessMeals.firstWhere(
      (m) => m.id == mealId,
      orElse: () => throw Exception('Meal $mealId not found in mess timetable'),
    );

    final ratingVal = MessRatingValue.fromCode(rating);
    final valErr = MessRatingModel.validateRatingFeedback(
      rating: ratingVal,
      message: message,
    );
    if (valErr != null) {
      throw Exception(valErr);
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        final serverRecord = await api.submitMessRating(
          mealId: mealId,
          userId: userId,
          userName: userName,
          campusHandle: campusHandle,
          rating: rating,
          message: message.trim(),
        );
        _cachedMessRatings.insert(0, serverRecord);
        return serverRecord;
      } catch (_) {}
    }

    final record = MessRatingModel(
      id: 'rate-${DateTime.now().millisecondsSinceEpoch}',
      mealId: meal.id,
      dayOfWeek: meal.dayOfWeek,
      mealType: meal.mealType,
      userId: userId.trim(),
      userName: userName.trim(),
      campusHandle: campusHandle.trim(),
      rating: rating,
      message: message.trim(),
      createdAt: DateTime.now(),
    );

    _cachedMessRatings.insert(0, record);
    return record;
  }

  // ----------------------------------------------------
  // GRIEVANCES & INSTITUTIONAL COMPLAINTS OPERATIONS
  // ----------------------------------------------------

  void _seedDefaultComplaintsIfEmpty() {
    if (!enableMockSeeding || _cachedComplaints.isNotEmpty) return;

    final now = DateTime.now();
    _cachedComplaints.addAll([
      ComplaintModel(
        id: 'cmp-001',
        title: 'Water leakage in Block 2 Floor 1 restroom',
        description: 'Constant leaking pipe in Floor 1 Block 2 restroom causing water wastage and slippery tiles.',
        category: ComplaintCategory.hostel,
        urgency: ComplaintUrgency.high,
        isAnonymous: true,
        submittedBy: 'usr-harish_2025_l_btech_1',
        submitterName: 'Anonymous Reporter',
        submitterHandle: 'anonymous',
        submitterRole: 'Anonymous',
        status: ComplaintStatus.inProgress,
        resolutionRemarks: 'Plumbing maintenance team notified and work order issued.',
        resolvedBy: 'usr-ramesh_2023_emp_1',
        createdAt: now.subtract(const Duration(hours: 48)),
        updatedAt: now.subtract(const Duration(hours: 48)),
      ),
      ComplaintModel(
        id: 'cmp-002',
        title: 'Streetlight flickering near Gate 2 walkway',
        description: 'Main pathway from academic complex to Gate 2 has dark spots due to malfunctioning LED streetlight.',
        category: ComplaintCategory.campus,
        urgency: ComplaintUrgency.medium,
        isAnonymous: true,
        submittedBy: 'usr-priya_2024_emp_1',
        submitterName: 'Anonymous Reporter',
        submitterHandle: 'anonymous',
        submitterRole: 'Anonymous',
        status: ComplaintStatus.open,
        createdAt: now.subtract(const Duration(hours: 36)),
        updatedAt: now.subtract(const Duration(hours: 36)),
      ),
      ComplaintModel(
        id: 'cmp-003',
        title: 'Grade calculation discrepancy in CS-301 Midterm Examination',
        description: 'Question 4 (Dynamic Programming, 10 marks) was marked correct with full points in answer script but recorded as 0 in gradebook portal.',
        category: ComplaintCategory.student,
        urgency: ComplaintUrgency.high,
        isAnonymous: false,
        submittedBy: 'usr-harish_2025_l_btech_1',
        submitterName: 'Harish Kumar',
        submitterHandle: 'harish_2025_l_btech_1',
        submitterRole: 'student',
        status: ComplaintStatus.open,
        isDispute: true,
        disputeTargetType: DisputeTargetType.result,
        disputeTargetId: 'CS301-Midterm-2026',
        disputeEvidence: 'Physical answer sheet shows 10 marks for Q4 Dynamic Programming, but gradebook portal records 0.',
        requestedResolution: 'Grade Recalculation (+10 marks)',
        createdAt: now.subtract(const Duration(hours: 24)),
        updatedAt: now.subtract(const Duration(hours: 24)),
      ),
      ComplaintModel(
        id: 'cmp-004',
        title: 'Office AC cooling unit non-functional in Computer Center Room 204',
        description: 'Temperature exceeds 34C in faculty lab during afternoon lab sessions due to blower motor failure.',
        category: ComplaintCategory.employee,
        urgency: ComplaintUrgency.medium,
        isAnonymous: false,
        submittedBy: 'usr-priya_2024_emp_1',
        submitterName: 'Dr. Priya Sharma',
        submitterHandle: 'priya_2024_emp_1',
        submitterRole: 'employee',
        status: ComplaintStatus.inProgress,
        resolutionRemarks: 'HVAC contractor scheduled for compressor overhaul.',
        resolvedBy: 'usr-ramesh_2023_emp_1',
        createdAt: now.subtract(const Duration(hours: 12)),
        updatedAt: now.subtract(const Duration(hours: 12)),
      ),
      ComplaintModel(
        id: 'cmp-005',
        title: 'Commercial gas cylinder unloading area blocked at Central Canteen',
        description: 'Unloading bay blocked by unauthorized vehicle parking, preventing morning delivery of fuel cylinders.',
        category: ComplaintCategory.contractor,
        urgency: ComplaintUrgency.critical,
        isAnonymous: false,
        submittedBy: 'usr-mukesh_2025_ext_1',
        submitterName: 'Mukesh Verma',
        submitterHandle: 'mukesh_2025_ext_1',
        submitterRole: 'external',
        status: ComplaintStatus.resolved,
        resolutionRemarks: 'Security personnel deployed tow truck and cleared loading dock.',
        resolvedBy: 'usr-ramesh_2023_emp_1',
        resolvedAt: now.subtract(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      ComplaintModel(
        id: 'cmp-006',
        title: 'Dispute on library overdue late fine for CLRS Algorithms',
        description: 'Book was deposited in the automated return dropbox prior to 5:00 PM on due date during network downtime.',
        category: ComplaintCategory.student,
        urgency: ComplaintUrgency.medium,
        isAnonymous: false,
        submittedBy: 'usr-harish_2025_l_btech_1',
        submitterName: 'Harish Kumar',
        submitterHandle: 'harish_2025_l_btech_1',
        submitterRole: 'student',
        status: ComplaintStatus.open,
        isDispute: true,
        disputeTargetType: DisputeTargetType.fine,
        disputeTargetId: 'fine-lib-01',
        disputeEvidence: 'Circulation desk manual register entry and automated locker check-in slip.',
        requestedResolution: 'Full Fine Waiver (₹50.00)',
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      ComplaintModel(
        id: 'cmp-007',
        title: 'Duplicate computer laboratory surcharge on Semester Fee Invoice',
        description: 'Billed twice for Advanced Computing Lab fee (₹2,500 x 2) on invoice INV-2026-001.',
        category: ComplaintCategory.student,
        urgency: ComplaintUrgency.high,
        isAnonymous: false,
        submittedBy: 'usr-harish_2025_l_btech_1',
        submitterName: 'Harish Kumar',
        submitterHandle: 'harish_2025_l_btech_1',
        submitterRole: 'student',
        status: ComplaintStatus.inProgress,
        resolutionRemarks: 'Treasury audit confirmed duplicate debit; credit note adjustment being processed.',
        resolvedBy: 'usr-ramesh_2023_emp_1',
        isDispute: true,
        disputeTargetType: DisputeTargetType.fee,
        disputeTargetId: 'INV-2026-001',
        disputeEvidence: 'Itemized invoice breakdown reflects duplicate item code LAB-CS3 under fee schedule.',
        requestedResolution: 'Fee Correction / Invoice Adjustment (-₹2,500)',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      ComplaintModel(
        id: 'cmp-008',
        title: 'Omission of approved conference travel allowance from October salary',
        description: 'Approved travel reimbursement ref DEAN/TR/2026/89 was not reconciled in October salary slip.',
        category: ComplaintCategory.employee,
        urgency: ComplaintUrgency.high,
        isAnonymous: false,
        submittedBy: 'usr-priya_2024_emp_1',
        submitterName: 'Dr. Priya Sharma',
        submitterHandle: 'priya_2024_emp_1',
        submitterRole: 'employee',
        status: ComplaintStatus.open,
        isDispute: true,
        disputeTargetType: DisputeTargetType.payroll,
        disputeTargetId: 'PAYROLL-2026-10',
        disputeEvidence: 'Dean approval memo DEAN/TR/2026/89 dated Oct 12 and boarding ticket receipts.',
        requestedResolution: 'Credit of ₹12,000 in supplementary payroll cycle',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
    ]);
  }

  @override
  Future<List<ComplaintModel>> getComplaints({
    String? category,
    String? status,
    String? submittedBy,
    String? viewerId,
    List<String>? allowedCategories,
    bool? isDispute,
    String? disputeTargetType,
  }) async {
    _seedDefaultComplaintsIfEmpty();
    await checkConnectivity();

    if (isOnline) {
      try {
        final serverComplaints = await api.fetchComplaints(
          category: category,
          status: status,
          submittedBy: submittedBy,
          viewerId: viewerId,
          allowedCategories: allowedCategories,
          isDispute: isDispute,
          disputeTargetType: disputeTargetType,
        );
        if (serverComplaints.isNotEmpty) {
          _cachedComplaints.clear();
          _cachedComplaints.addAll(serverComplaints);
        }
      } catch (_) {}
    }

    final catFilter = category?.trim().toLowerCase();
    final statusFilter = status?.trim().toLowerCase();
    final submitterFilter = submittedBy?.trim();
    final targetTypeFilter = disputeTargetType?.trim().toLowerCase();
    final allowedSet = allowedCategories?.map((c) => c.trim().toLowerCase()).toSet() ?? {};
    final hasAllowedRestrictions = allowedSet.isNotEmpty && !allowedSet.contains('*');

    final list = _cachedComplaints.where((c) {
      if (isDispute != null && c.isDispute != isDispute) {
        return false;
      }
      if (targetTypeFilter != null && targetTypeFilter.isNotEmpty && targetTypeFilter != 'all') {
        if (c.disputeTargetType != targetTypeFilter) return false;
      }
      if (catFilter != null && catFilter.isNotEmpty && catFilter != 'all' && c.category != catFilter) {
        return false;
      }
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all' && c.status != statusFilter) {
        return false;
      }
      if (submitterFilter != null && submitterFilter.isNotEmpty && c.submittedBy != submitterFilter) {
        return false;
      }
      if (submitterFilter == null && hasAllowedRestrictions && !allowedSet.contains(c.category)) {
        return false;
      }
      return true;
    }).map((c) {
      if (c.isAnonymous) {
        return c.copyWith(
          submitterName: 'Anonymous Reporter',
          submitterHandle: 'anonymous',
          submitterRole: 'Anonymous',
          submittedBy: (viewerId != null && viewerId == c.submittedBy) ? c.submittedBy : 'anonymous',
        );
      }
      return c;
    }).toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<ComplaintModel> raiseDispute(ComplaintModel dispute) async {
    _seedDefaultComplaintsIfEmpty();

    if (dispute.isAnonymous) {
      throw Exception('Formal disputes require verified identity and cannot be filed anonymously');
    }
    if ((dispute.disputeTargetId ?? '').trim().isEmpty) {
      throw Exception('Dispute target reference ID is required');
    }
    if ((dispute.requestedResolution ?? '').trim().isEmpty) {
      throw Exception('Requested resolution is required for formal dispute');
    }

    return createComplaint(dispute.copyWith(isDispute: true, isAnonymous: false));
  }

  @override
  Future<List<ComplaintModel>> getDisputes({
    String? targetType,
    String? status,
    String? submittedBy,
    String? viewerId,
  }) async {
    return getComplaints(
      isDispute: true,
      disputeTargetType: targetType,
      status: status,
      submittedBy: submittedBy,
      viewerId: viewerId,
    );
  }

  Future<ComplaintModel> createComplaint(ComplaintModel complaint) async {
    _seedDefaultComplaintsIfEmpty();

    if (complaint.title.trim().isEmpty) {
      throw Exception('Complaint title is required');
    }
    if (complaint.description.trim().isEmpty) {
      throw Exception('Complaint description is required');
    }

    if (complaint.isAnonymous && !ComplaintCategory.supportsAnonymous(complaint.category)) {
      throw Exception('Anonymous complaints are not supported for category: ${ComplaintCategory.displayName(complaint.category)}');
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        final created = await api.createComplaint(complaint);
        _cachedComplaints.insert(0, created);
        return created;
      } catch (_) {}
    }

    final now = DateTime.now();
    final newComplaint = complaint.copyWith(
      id: 'cmp-${DateTime.now().millisecondsSinceEpoch}',
      status: ComplaintStatus.open,
      submitterName: complaint.isAnonymous ? 'Anonymous Reporter' : complaint.submitterName,
      submitterHandle: complaint.isAnonymous ? 'anonymous' : complaint.submitterHandle,
      submitterRole: complaint.isAnonymous ? 'Anonymous' : complaint.submitterRole,
      createdAt: now,
      updatedAt: now,
    );

    _cachedComplaints.insert(0, newComplaint);
    return newComplaint;
  }

  Future<ComplaintModel> updateComplaintStatus({
    required String complaintId,
    required String status,
    required String remarks,
    required String resolvedBy,
  }) async {
    _seedDefaultComplaintsIfEmpty();

    final idx = _cachedComplaints.indexWhere((c) => c.id == complaintId);
    if (idx == -1) {
      throw Exception('Complaint $complaintId not found');
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        final updated = await api.updateComplaintStatus(
          complaintId: complaintId,
          status: status,
          remarks: remarks,
          resolvedBy: resolvedBy,
        );
        _cachedComplaints[idx] = updated;
        return updated;
      } catch (_) {}
    }

    final now = DateTime.now();
    final cleanStatus = status.trim().toLowerCase();
    final current = _cachedComplaints[idx];
    final updated = current.copyWith(
      status: cleanStatus,
      resolutionRemarks: remarks.trim(),
      resolvedBy: resolvedBy.trim(),
      resolvedAt: (cleanStatus == ComplaintStatus.resolved || cleanStatus == ComplaintStatus.rejected) ? now : null,
      updatedAt: now,
    );

    _cachedComplaints[idx] = updated;
    return updated;
  }

  // ----------------------------------------------------
  // INSTITUTIONAL FEES & FINES SUBSYSTEM
  // ----------------------------------------------------

  void _seedDefaultFeesIfEmpty() {
    if (!enableMockSeeding || _cachedFeeInvoices.isNotEmpty) return;

    final now = DateTime.now();
    const studentId = 'usr-harish_2025_l_btech_1';
    const studentName = 'Harish Kumar';
    const handle = 'harish_2025_l_btech_1';

    // 1. Invoices
    final inv1 = FeeInvoiceModel(
      id: 'inv-tuition-2026-sem3',
      studentId: studentId,
      studentName: studentName,
      campusHandle: handle,
      academicYear: '2026-2027',
      semesterNumber: 3,
      feeType: FeeType.tuition,
      title: 'B.Tech Semester 3 Tuition & Curriculum Fee',
      totalAmount: 65000,
      paidAmount: 30000,
      dueAmount: 35000,
      dueDate: now.add(const Duration(days: 15)),
      status: InvoiceStatus.partial,
      breakdown: const [
        FeeHeadModel(headName: 'Tuition & Instruction', amount: 45000),
        FeeHeadModel(headName: 'Computer & AI Lab Access', amount: 12000),
        FeeHeadModel(headName: 'Library & Digital Journals', amount: 5000),
        FeeHeadModel(headName: 'Examination & Assessment', amount: 3000),
      ],
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now.subtract(const Duration(days: 5)),
    );

    final inv2 = FeeInvoiceModel(
      id: 'inv-hostel-2026-sem3',
      studentId: studentId,
      studentName: studentName,
      campusHandle: handle,
      academicYear: '2026-2027',
      semesterNumber: 3,
      feeType: FeeType.hostel,
      title: 'Hostel Residency & Maintenance (BBDIT Hostel)',
      totalAmount: 25000,
      paidAmount: 0,
      dueAmount: 25000,
      dueDate: now.add(const Duration(days: 7)),
      status: InvoiceStatus.pending,
      breakdown: const [
        FeeHeadModel(headName: 'Room Rent (Double Occupancy)', amount: 18000),
        FeeHeadModel(headName: 'Electricity & High-Speed WiFi', amount: 4500),
        FeeHeadModel(headName: 'Maintenance & Sanitization', amount: 2500),
      ],
      createdAt: now.subtract(const Duration(days: 20)),
      updatedAt: now.subtract(const Duration(days: 20)),
    );

    final inv3 = FeeInvoiceModel(
      id: 'inv-mess-2026-sem3',
      studentId: studentId,
      studentName: studentName,
      campusHandle: handle,
      academicYear: '2026-2027',
      semesterNumber: 3,
      feeType: FeeType.mess,
      title: 'Mess Boarding & Dining Operations (Semester 3)',
      totalAmount: 18000,
      paidAmount: 18000,
      dueAmount: 0,
      dueDate: now.subtract(const Duration(days: 10)),
      status: InvoiceStatus.paid,
      breakdown: const [
        FeeHeadModel(headName: 'Breakfast, Lunch & Dinner', amount: 16000),
        FeeHeadModel(headName: 'Special Sunday Dining & Festive Meals', amount: 2000),
      ],
      createdAt: now.subtract(const Duration(days: 45)),
      updatedAt: now.subtract(const Duration(days: 40)),
    );

    _cachedFeeInvoices.addAll([inv1, inv2, inv3]);

    // 2. Fines
    final fine1 = FineRecordModel(
      id: 'fine-lib-01',
      studentId: studentId,
      studentName: studentName,
      campusHandle: handle,
      category: FineCategory.library,
      reason: "Overdue book: 'Introduction to Algorithms' (Cormen et al.) overdue by 15 days",
      amount: 150,
      issuedAt: now.subtract(const Duration(days: 10)),
      dueDate: now.add(const Duration(days: 5)),
      status: FineStatus.unpaid,
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now.subtract(const Duration(days: 10)),
    );

    final fine2 = FineRecordModel(
      id: 'fine-disc-01',
      studentId: studentId,
      studentName: studentName,
      campusHandle: handle,
      category: FineCategory.disciplinary,
      reason: 'Hostel late entry past 10:30 PM without approved warden e-pass',
      amount: 500,
      issuedAt: now.subtract(const Duration(days: 8)),
      dueDate: now.add(const Duration(days: 3)),
      status: FineStatus.appealed,
      appealReason: 'Was attending IEEE student branch robotics lab experiment with faculty supervisor permission',
      createdAt: now.subtract(const Duration(days: 8)),
      updatedAt: now.subtract(const Duration(days: 2)),
    );

    _cachedFines.addAll([fine1, fine2]);

    // 3. Historical Payments & Receipts
    final pay1 = FeePaymentModel(
      id: 'pay-001',
      invoiceId: inv1.id,
      studentId: studentId,
      studentName: studentName,
      amount: 30000,
      paymentMethod: 'netbanking',
      transactionRef: 'TXN-HDFC-882910',
      paymentStatus: 'success',
      paidAt: now.subtract(const Duration(days: 5)),
      receiptNumber: 'RCP-2026-00108',
    );

    final pay2 = FeePaymentModel(
      id: 'pay-002',
      invoiceId: inv3.id,
      studentId: studentId,
      studentName: studentName,
      amount: 18000,
      paymentMethod: 'upi',
      transactionRef: 'TXN-UPI-992384',
      paymentStatus: 'success',
      paidAt: now.subtract(const Duration(days: 40)),
      receiptNumber: 'RCP-2026-00109',
    );

    _cachedFeePayments.addAll([pay1, pay2]);

    final rec1 = FeeReceiptModel(
      receiptNumber: 'RCP-2026-00108',
      paymentId: pay1.id,
      invoiceId: inv1.id,
      studentId: studentId,
      studentName: studentName,
      campusHandle: handle,
      amount: 30000,
      paymentMethod: 'netbanking',
      transactionRef: 'TXN-HDFC-882910',
      issuedAt: pay1.paidAt,
      title: inv1.title,
      category: 'fee',
    );

    final rec2 = FeeReceiptModel(
      receiptNumber: 'RCP-2026-00109',
      paymentId: pay2.id,
      invoiceId: inv3.id,
      studentId: studentId,
      studentName: studentName,
      campusHandle: handle,
      amount: 18000,
      paymentMethod: 'upi',
      transactionRef: 'TXN-UPI-992384',
      issuedAt: pay2.paidAt,
      title: inv3.title,
      category: 'fee',
    );

    _cachedFeeReceipts.addAll([rec1, rec2]);
  }

  @override
  Future<FeeSummaryModel> getFeeSummary(String studentId) async {
    _seedDefaultFeesIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.getFeeSummary(studentId);
      } catch (_) {}
    }

    double totalDues = 0.0;
    double totalPaid = 0.0;
    double pendingFines = 0.0;
    DateTime? nextDueDate;
    int overdueInvoices = 0;
    int activeFinesCount = 0;

    final now = DateTime.now();

    for (final inv in _cachedFeeInvoices) {
      if (studentId.isNotEmpty && inv.studentId != studentId) continue;

      totalDues += inv.dueAmount;
      totalPaid += inv.paidAmount;

      if (!inv.isPaid) {
        if (inv.dueDate.isBefore(now)) {
          overdueInvoices++;
        }
        if (nextDueDate == null || inv.dueDate.isBefore(nextDueDate)) {
          nextDueDate = inv.dueDate;
        }
      }
    }

    for (final fine in _cachedFines) {
      if (studentId.isNotEmpty && fine.studentId != studentId) continue;

      if (fine.isUnpaid || fine.isAppealed) {
        pendingFines += fine.amount;
        activeFinesCount++;
        if (nextDueDate == null || fine.dueDate.isBefore(nextDueDate)) {
          nextDueDate = fine.dueDate;
        }
      }
    }

    return FeeSummaryModel(
      totalDues: totalDues,
      totalPaid: totalPaid,
      pendingFines: pendingFines,
      nextDueDate: nextDueDate,
      overdueInvoices: overdueInvoices,
      activeFinesCount: activeFinesCount,
    );
  }

  @override
  Future<List<FeeInvoiceModel>> getInvoices({String? studentId, String? status}) async {
    _seedDefaultFeesIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.getInvoices(studentId: studentId, status: status);
        _cachedFeeInvoices.clear();
        _cachedFeeInvoices.addAll(list);
        return list;
      } catch (_) {}
    }

    final cleanStatus = status?.trim().toLowerCase();
    final list = _cachedFeeInvoices.where((inv) {
      if (studentId != null && studentId.isNotEmpty && inv.studentId != studentId) return false;
      if (cleanStatus != null && cleanStatus.isNotEmpty && inv.status.toLowerCase() != cleanStatus) return false;
      return true;
    }).toList();

    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  @override
  Future<FeeInvoiceModel?> getInvoiceById(String id) async {
    _seedDefaultFeesIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final fetched = await api.getInvoiceById(id);
        if (fetched != null) return fetched;
      } catch (_) {}
    }

    try {
      return _cachedFeeInvoices.firstWhere((inv) => inv.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> payInvoice({
    required String invoiceId,
    required String studentId,
    required double amount,
    required String paymentMethod,
  }) async {
    _seedDefaultFeesIfEmpty();

    if (amount <= 0) {
      throw Exception('Payment amount must be greater than zero');
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.payInvoice(
          invoiceId: invoiceId,
          studentId: studentId,
          amount: amount,
          paymentMethod: paymentMethod,
        );
        return res;
      } catch (_) {}
    }

    final idx = _cachedFeeInvoices.indexWhere((inv) => inv.id == invoiceId);
    if (idx == -1) {
      throw Exception("Fee invoice '$invoiceId' not found");
    }

    final inv = _cachedFeeInvoices[idx];
    if (amount > inv.dueAmount) {
      throw Exception('Cannot pay more than invoice due amount of ₹${inv.dueAmount.toStringAsFixed(2)}');
    }

    final now = DateTime.now();
    final newPaid = inv.paidAmount + amount;
    final newDue = inv.dueAmount - amount;
    final newStatus = newDue <= 0.001 ? InvoiceStatus.paid : InvoiceStatus.partial;

    final updatedInv = inv.copyWith(
      paidAmount: newPaid,
      dueAmount: newDue <= 0.001 ? 0.0 : newDue,
      status: newStatus,
      updatedAt: now,
    );
    _cachedFeeInvoices[idx] = updatedInv;

    final receiptNumber = 'RCP-${now.year}-${(1000 + _cachedFeePayments.length + 1)}';
    final payment = FeePaymentModel(
      id: 'pay-${now.millisecondsSinceEpoch}',
      invoiceId: inv.id,
      studentId: inv.studentId,
      studentName: inv.studentName,
      amount: amount,
      paymentMethod: paymentMethod,
      transactionRef: 'TXN-${now.millisecondsSinceEpoch}',
      paymentStatus: 'success',
      paidAt: now,
      receiptNumber: receiptNumber,
    );
    _cachedFeePayments.insert(0, payment);

    final receipt = FeeReceiptModel(
      receiptNumber: receiptNumber,
      paymentId: payment.id,
      invoiceId: inv.id,
      studentId: inv.studentId,
      studentName: inv.studentName,
      campusHandle: inv.campusHandle,
      amount: amount,
      paymentMethod: paymentMethod,
      transactionRef: payment.transactionRef,
      issuedAt: now,
      title: inv.title,
      category: 'fee',
    );
    _cachedFeeReceipts.insert(0, receipt);

    return {
      'payment': payment,
      'receipt': receipt,
    };
  }

  @override
  Future<List<FineRecordModel>> getFines({String? studentId, String? status}) async {
    _seedDefaultFeesIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.getFines(studentId: studentId, status: status);
        _cachedFines.clear();
        _cachedFines.addAll(list);
        return list;
      } catch (_) {}
    }

    final cleanStatus = status?.trim().toLowerCase();
    final list = _cachedFines.where((fine) {
      if (studentId != null && studentId.isNotEmpty && fine.studentId != studentId) return false;
      if (cleanStatus != null && cleanStatus.isNotEmpty && fine.status.toLowerCase() != cleanStatus) return false;
      return true;
    }).toList();

    list.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return list;
  }

  @override
  Future<Map<String, dynamic>> payFine({
    required String fineId,
    required String studentId,
    required String paymentMethod,
  }) async {
    _seedDefaultFeesIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.payFine(
          fineId: fineId,
          studentId: studentId,
          paymentMethod: paymentMethod,
        );
        return res;
      } catch (_) {}
    }

    final idx = _cachedFines.indexWhere((f) => f.id == fineId);
    if (idx == -1) {
      throw Exception("Fine record '$fineId' not found");
    }

    final fine = _cachedFines[idx];
    if (fine.isPaid) {
      throw Exception('Fine is already paid and cleared');
    }
    if (fine.isWaived) {
      throw Exception('Fine was officially waived; no payment required');
    }

    final now = DateTime.now();
    final receiptNumber = 'RCP-${now.year}-${(2000 + _cachedFeePayments.length + 1)}';

    final payment = FeePaymentModel(
      id: 'pay-fine-${now.millisecondsSinceEpoch}',
      fineId: fine.id,
      studentId: fine.studentId,
      studentName: fine.studentName,
      amount: fine.amount,
      paymentMethod: paymentMethod,
      transactionRef: 'TXN-FINE-${now.millisecondsSinceEpoch}',
      paymentStatus: 'success',
      paidAt: now,
      receiptNumber: receiptNumber,
    );
    _cachedFeePayments.insert(0, payment);

    final receipt = FeeReceiptModel(
      receiptNumber: receiptNumber,
      paymentId: payment.id,
      fineId: fine.id,
      studentId: fine.studentId,
      studentName: fine.studentName,
      campusHandle: fine.campusHandle,
      amount: fine.amount,
      paymentMethod: paymentMethod,
      transactionRef: payment.transactionRef,
      issuedAt: now,
      title: 'Settlement: ${FineCategory.displayName(fine.category)}',
      category: 'fine',
    );
    _cachedFeeReceipts.insert(0, receipt);

    final updatedFine = fine.copyWith(
      status: FineStatus.paid,
      paidAt: now,
      receiptId: receiptNumber,
      updatedAt: now,
    );
    _cachedFines[idx] = updatedFine;

    return {
      'payment': payment,
      'receipt': receipt,
    };
  }

  @override
  Future<FineRecordModel> appealFine({
    required String fineId,
    required String reason,
  }) async {
    _seedDefaultFeesIfEmpty();

    if (reason.trim().isEmpty) {
      throw Exception('Appeal explanation is required');
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.appealFine(fineId: fineId, reason: reason);
        final idx = _cachedFines.indexWhere((f) => f.id == fineId);
        if (idx != -1) _cachedFines[idx] = res;
        return res;
      } catch (_) {}
    }

    final idx = _cachedFines.indexWhere((f) => f.id == fineId);
    if (idx == -1) {
      throw Exception("Fine record '$fineId' not found");
    }

    final fine = _cachedFines[idx];
    if (fine.isPaid) {
      throw Exception('Cannot appeal a settled and paid fine');
    }

    final now = DateTime.now();
    final updated = fine.copyWith(
      status: FineStatus.appealed,
      appealReason: reason.trim(),
      updatedAt: now,
    );
    _cachedFines[idx] = updated;
    return updated;
  }

  @override
  Future<FineRecordModel> waiveFine({
    required String fineId,
    required String waivedBy,
  }) async {
    _seedDefaultFeesIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.waiveFine(fineId: fineId, waivedBy: waivedBy);
        final idx = _cachedFines.indexWhere((f) => f.id == fineId);
        if (idx != -1) _cachedFines[idx] = res;
        return res;
      } catch (_) {}
    }

    final idx = _cachedFines.indexWhere((f) => f.id == fineId);
    if (idx == -1) {
      throw Exception("Fine record '$fineId' not found");
    }

    final fine = _cachedFines[idx];
    if (fine.isPaid) {
      throw Exception('Cannot waive a settled and paid fine');
    }

    final now = DateTime.now();
    final updated = fine.copyWith(
      status: FineStatus.waived,
      waivedBy: waivedBy.trim().isEmpty ? 'Institution Administrator' : waivedBy.trim(),
      updatedAt: now,
    );
    _cachedFines[idx] = updated;
    return updated;
  }

  @override
  Future<List<FeePaymentModel>> getFeePayments(String studentId) async {
    _seedDefaultFeesIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.getFeePayments(studentId);
        _cachedFeePayments.clear();
        _cachedFeePayments.addAll(list);
        return list;
      } catch (_) {}
    }

    final list = _cachedFeePayments.where((p) {
      if (studentId.isNotEmpty && p.studentId != studentId) return false;
      return true;
    }).toList();

    list.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return list;
  }

  @override
  Future<FeeReceiptModel> getFeeReceipt(String receiptNumber) async {
    _seedDefaultFeesIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.getFeeReceipt(receiptNumber);
      } catch (_) {}
    }

    try {
      return _cachedFeeReceipts.firstWhere((r) => r.receiptNumber == receiptNumber);
    } catch (_) {
      throw Exception("Fee receipt '$receiptNumber' not found");
    }
  }

  @override
  Future<List<int>> downloadInvoicePdf(String invoiceId) async {
    _seedDefaultFeesIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.downloadInvoicePdf(invoiceId);
      } catch (_) {}
    }

    final invoice = _cachedFeeInvoices.firstWhere(
      (inv) => inv.id == invoiceId,
      orElse: () => throw Exception("Fee invoice '$invoiceId' not found"),
    );

    return InvoicePdfGenerator.generate(invoice);
  }

  @override
  Future<List<int>> downloadReceiptPdf(String receiptNumber) async {
    _seedDefaultFeesIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.downloadReceiptPdf(receiptNumber);
      } catch (_) {}
    }

    final receipt = _cachedFeeReceipts.firstWhere(
      (rcp) => rcp.receiptNumber == receiptNumber,
      orElse: () => throw Exception("Fee receipt '$receiptNumber' not found"),
    );

    return ReceiptPdfGenerator.generate(receipt);
  }

  @override
  Future<PaymentGatewayConfigModel> getPaymentConfig() async {
    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.getPaymentConfig();
      } catch (_) {}
    }

    return const PaymentGatewayConfigModel(
      provider: 'sandbox',
      keyId: 'sandbox_inst_key_campus_9901',
      merchantName: 'Babu Banarasi Das Institute of Technology & BBDIT College of Pharmacy',
      merchantVpa: 'bbditfees@sbi',
      environment: 'sandbox',
      supportedMethods: ['upi', 'debit_card', 'credit_card', 'net_banking', 'challan'],
      virtualAccount: VirtualAccountModel(
        beneficiaryName: 'Babu Banarasi Das Institute of Technology & BBDIT College of Pharmacy',
        bankName: 'State Bank of India (SBI)',
        accountNumber: 'BBDITCOLLECT01',
        ifscCode: 'SBIN0001234',
        branchName: 'Institutional Campus Branch',
        referenceVan: 'BBDIT-GENERIC-VAN',
      ),
    );
  }

  @override
  Future<PaymentOrderModel> createPaymentOrder({
    required String entityType,
    required String entityId,
    required String studentId,
    required double amount,
    String notes = '',
  }) async {
    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.createPaymentOrder(
          entityType: entityType,
          entityId: entityId,
          studentId: studentId,
          amount: amount,
          notes: notes,
        );
      } catch (_) {}
    }

    final now = DateTime.now();
    final orderId = 'order_bbdit_${now.millisecondsSinceEpoch}';
    final cleanStudent = studentId.replaceAll('-', '').toUpperCase();
    final studentTail = cleanStudent.length > 8 ? cleanStudent.substring(cleanStudent.length - 8) : cleanStudent;
    final van = 'BBDIT$studentTail${now.millisecondsSinceEpoch % 10000}';

    final upiUri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': 'bbditfees@sbi',
        'pn': 'Babu Banarasi Das Institute of Technology & BBDIT College of Pharmacy',
        'am': amount.toStringAsFixed(2),
        'tr': 'TXN-${now.millisecondsSinceEpoch % 10000000}',
        'tn': 'BBDIT fee settlement for $entityId',
        'cu': 'INR',
      },
    );

    return PaymentOrderModel(
      orderId: orderId,
      entityType: entityType,
      entityId: entityId,
      studentId: studentId,
      studentName: 'Harish Kumar',
      amount: amount,
      currency: 'INR',
      status: 'created',
      gatewayProvider: 'sandbox',
      gatewayOrderId: orderId,
      gatewayKeyId: 'sandbox_inst_key_campus_9901',
      upiLink: upiUri.toString(),
      virtualAccount: VirtualAccountModel(
        beneficiaryName: 'Babu Banarasi Das Institute of Technology & BBDIT College of Pharmacy',
        bankName: 'State Bank of India (SBI)',
        accountNumber: van,
        ifscCode: 'SBIN0001234',
        branchName: 'Institutional Campus Branch',
        referenceVan: van,
      ),
      notes: notes,
      expiresAt: now.add(const Duration(minutes: 20)),
    );
  }

  @override
  Future<Map<String, dynamic>> verifyPaymentOrder({
    required String orderId,
    required String paymentId,
    required String paymentMethod,
    String? transactionRef,
    String? signature,
    String? utrNumber,
    String? bankName,
    String? upiVpa,
    String? cardLast4,
  }) async {
    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.verifyPaymentOrder(
          orderId: orderId,
          paymentId: paymentId,
          paymentMethod: paymentMethod,
          transactionRef: transactionRef,
          signature: signature,
          utrNumber: utrNumber,
          bankName: bankName,
          upiVpa: upiVpa,
          cardLast4: cardLast4,
        );
      } catch (_) {}
    }

    // Offline settlement fallback
    _seedDefaultFeesIfEmpty();
    final isInvoice = !orderId.contains('fine');
    if (isInvoice && _cachedFeeInvoices.isNotEmpty) {
      final inv = _cachedFeeInvoices.first;
      return await payInvoice(
        invoiceId: inv.id,
        studentId: inv.studentId,
        amount: inv.dueAmount,
        paymentMethod: paymentMethod,
      );
    } else if (_cachedFines.isNotEmpty) {
      final fine = _cachedFines.first;
      return await payFine(
        fineId: fine.id,
        studentId: fine.studentId,
        paymentMethod: paymentMethod,
      );
    }

    throw Exception('No pending fee or fine available for simulated settlement');
  }

  // Institutional Library Subsystem & Fine Portal Synchronization

  void _seedDefaultLibraryIfEmpty() {
    if (!enableMockSeeding || _cachedPhysicalBooks.isNotEmpty) return;

    final now = DateTime.now();

    // 1. Seed Physical Books Catalog
    _cachedPhysicalBooks.addAll([
      PhysicalBookModel(
        id: 'bk-algo-01',
        isbn: '978-0262033848',
        title: 'Introduction to Algorithms (CLRS 3rd Edition)',
        author: 'Thomas H. Cormen, Charles E. Leiserson',
        publisher: 'MIT Press',
        edition: '3rd Edition',
        category: 'Computer Science',
        departmentId: 'dept-cse',
        totalCopies: 5,
        availableCopies: 4,
        shelfLocation: 'Rack C-3, 2nd Floor Central Wing',
        replacementCost: 4500.0,
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      ),
      PhysicalBookModel(
        id: 'bk-os-01',
        isbn: '978-1118063330',
        title: 'Operating System Concepts',
        author: 'Abraham Silberschatz, Peter B. Galvin',
        publisher: 'Wiley',
        edition: '9th Edition',
        category: 'Computer Science',
        departmentId: 'dept-cse',
        totalCopies: 3,
        availableCopies: 2,
        shelfLocation: 'Rack D-2, 2nd Floor Central Wing',
        replacementCost: 3200.0,
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      ),
      PhysicalBookModel(
        id: 'bk-db-01',
        isbn: '978-0073523323',
        title: 'Database System Concepts',
        author: 'Abraham Silberschatz, Henry F. Korth',
        publisher: 'McGraw-Hill',
        edition: '7th Edition',
        category: 'Computer Science',
        departmentId: 'dept-cse',
        totalCopies: 6,
        availableCopies: 4,
        shelfLocation: 'Rack A-4, 2nd Floor East Wing',
        replacementCost: 4100.0,
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      ),
      PhysicalBookModel(
        id: 'bk-ai-01',
        isbn: '978-0136042594',
        title: 'Artificial Intelligence: A Modern Approach',
        author: 'Stuart Russell, Peter Norvig',
        publisher: 'Pearson',
        edition: '4th Edition',
        category: 'Artificial Intelligence',
        departmentId: 'dept-cse',
        totalCopies: 4,
        availableCopies: 0,
        shelfLocation: 'Rack C-1, 3rd Floor AI Wing',
        replacementCost: 5200.0,
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      ),
      PhysicalBookModel(
        id: 'bk-digital-01',
        isbn: '978-0132774208',
        title: 'Digital Logic and Computer Design',
        author: 'M. Morris Mano',
        publisher: 'Prentice Hall',
        edition: '5th Edition',
        category: 'Electronics',
        departmentId: 'dept-ece',
        totalCopies: 5,
        availableCopies: 3,
        shelfLocation: 'Rack B-2, 1st Floor Electronics Wing',
        replacementCost: 2800.0,
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      ),
      PhysicalBookModel(
        id: 'bk-math-01',
        isbn: '978-0073383095',
        title: 'Discrete Mathematics and Its Applications',
        author: 'Kenneth H. Rosen',
        publisher: 'McGraw-Hill',
        edition: '8th Edition',
        category: 'Mathematics',
        departmentId: 'dept-math',
        totalCopies: 7,
        availableCopies: 6,
        shelfLocation: 'Rack M-1, Ground Floor Math Wing',
        replacementCost: 3600.0,
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now,
      ),
    ]);

    // 2. Demo Student Borrows (Harish Kumar)
    const studentId = 'usr-harish_2025_l_btech_1';
    const studentName = 'Harish Kumar';
    const handle = 'harish_2025_l_btech_1';

    // Active loan (due in 9 days)
    final loan1 = BorrowRecordModel(
      id: 'brw-clrs-01',
      bookId: 'bk-algo-01',
      bookTitle: 'Introduction to Algorithms (CLRS 3rd Edition)',
      bookAuthor: 'Thomas H. Cormen, Charles E. Leiserson',
      bookIsbn: '978-0262033848',
      shelfLocation: 'Rack C-3, 2nd Floor Central Wing',
      studentId: studentId,
      studentName: studentName,
      campusHandle: handle,
      borrowedAt: now.subtract(const Duration(days: 5)),
      dueDate: now.add(const Duration(days: 9)),
      status: BorrowStatus.active,
      renewalCount: 0,
      maxRenewals: 2,
      finePerDay: 10.0,
      accruedLateFine: 0.0,
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now,
    );

    // Overdue loan (due 5 days ago, 50 INR fine linked to Fine Portal)
    const overdueFineId = 'fine-lib-overdue-01';
    final loan2 = BorrowRecordModel(
      id: 'brw-os-01',
      bookId: 'bk-os-01',
      bookTitle: 'Operating System Concepts',
      bookAuthor: 'Abraham Silberschatz, Peter B. Galvin',
      bookIsbn: '978-1118063330',
      shelfLocation: 'Rack D-2, 2nd Floor Central Wing',
      studentId: studentId,
      studentName: studentName,
      campusHandle: handle,
      borrowedAt: now.subtract(const Duration(days: 19)),
      dueDate: now.subtract(const Duration(days: 5)),
      status: BorrowStatus.overdue,
      renewalCount: 0,
      maxRenewals: 2,
      finePerDay: 10.0,
      accruedLateFine: 50.0,
      finePortalFeeId: overdueFineId,
      createdAt: now.subtract(const Duration(days: 19)),
      updatedAt: now,
    );

    // Returned loan
    final loan3 = BorrowRecordModel(
      id: 'brw-math-01',
      bookId: 'bk-math-01',
      bookTitle: 'Discrete Mathematics and Its Applications',
      bookAuthor: 'Kenneth H. Rosen',
      bookIsbn: '978-0073383095',
      shelfLocation: 'Rack M-1, Ground Floor Math Wing',
      studentId: studentId,
      studentName: studentName,
      campusHandle: handle,
      borrowedAt: now.subtract(const Duration(days: 45)),
      dueDate: now.subtract(const Duration(days: 31)),
      returnedAt: now.subtract(const Duration(days: 32)),
      status: BorrowStatus.returned,
      renewalCount: 1,
      maxRenewals: 2,
      finePerDay: 10.0,
      accruedLateFine: 0.0,
      createdAt: now.subtract(const Duration(days: 45)),
      updatedAt: now.subtract(const Duration(days: 32)),
    );

    // Seed a pending borrow request awaiting Library In-Charge approval
    final loan4 = BorrowRecordModel(
      id: 'brw-net-01',
      bookId: 'bk-net-01',
      bookTitle: 'Computer Networks: A Systems Approach',
      bookAuthor: 'Larry L. Peterson, Bruce S. Davie',
      bookIsbn: '978-0123850591',
      shelfLocation: 'Rack D-2, 2nd Floor Central Wing',
      studentId: 'usr-priya_2024_emp_1',
      studentName: 'Dr. Priya Nair',
      campusHandle: 'priya_2024_emp_1',
      borrowedAt: now.subtract(const Duration(hours: 4)),
      dueDate: now.add(const Duration(days: 14)),
      status: BorrowStatus.pendingApproval,
      renewalCount: 0,
      maxRenewals: 2,
      finePerDay: 10.0,
      accruedLateFine: 0.0,
      createdAt: now.subtract(const Duration(hours: 4)),
      updatedAt: now.subtract(const Duration(hours: 4)),
    );

    _cachedBorrowRecords.addAll([loan1, loan2, loan3, loan4]);

    // Ensure overdue fine is synchronized into the Institutional Fine Portal
    _seedDefaultFeesIfEmpty();
    if (!_cachedFines.any((f) => f.id == overdueFineId)) {
      _cachedFines.add(FineRecordModel(
        id: overdueFineId,
        studentId: studentId,
        studentName: studentName,
        campusHandle: handle,
        category: FineCategory.library,
        reason: "Overdue library loan: 'Operating System Concepts' (5 days overdue)",
        amount: 50.0,
        issuedAt: now.subtract(const Duration(days: 5)),
        dueDate: now.add(const Duration(days: 9)),
        status: FineStatus.unpaid,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      ));
    }

    // 3. Digital E-Books for Infinite Borrowing
    _cachedEBooks.addAll([
      EBookModel(
        id: 'ebk-clean-code',
        title: 'Clean Code: A Handbook of Agile Software Craftsmanship',
        author: 'Robert C. Martin',
        category: 'Computer Science',
        publisher: 'Prentice Hall',
        format: 'PDF',
        fileSize: '12.4 MB',
        totalReaders: 1420,
        downloadUrl: '/api/v1/library/ebooks/download/clean-code.pdf',
        readUrl: '/library/reader/clean-code',
        isInfiniteBorrow: true,
        description: 'Even bad code can function. But if code isn’t clean, it can bring a development organization to its knees. Master professional craftsmanship.',
        requiredSemesters: [3, 4],
        tags: ['Software Engineering', 'Best Practices', 'Refactoring'],
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now,
      ),
      EBookModel(
        id: 'ebk-deep-learning',
        title: 'Deep Learning',
        author: 'Ian Goodfellow, Yoshua Bengio, Aaron Courville',
        category: 'Artificial Intelligence',
        publisher: 'MIT Press',
        format: 'PDF',
        fileSize: '28.6 MB',
        totalReaders: 980,
        downloadUrl: '/api/v1/library/ebooks/download/deep-learning.pdf',
        readUrl: '/library/reader/deep-learning',
        isInfiniteBorrow: true,
        description: 'The definitive textbook on deep learning covering mathematical fundamentals, neural network architectures, and modern representation learning.',
        requiredSemesters: [5, 6, 7],
        tags: ['Neural Networks', 'Machine Learning', 'Mathematics'],
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now,
      ),
      EBookModel(
        id: 'ebk-design-patterns',
        title: 'Design Patterns: Elements of Reusable Object-Oriented Software',
        author: 'Erich Gamma, Richard Helm, Ralph Johnson, John Vlissides',
        category: 'Computer Science',
        publisher: 'Addison-Wesley',
        format: 'EPUB',
        fileSize: '8.1 MB',
        totalReaders: 2150,
        downloadUrl: '/api/v1/library/ebooks/download/design-patterns.epub',
        readUrl: '/library/reader/design-patterns',
        isInfiniteBorrow: true,
        description: 'Captures a wealth of experience in software engineering and presents solutions to common design problems in scalable object-oriented software.',
        requiredSemesters: [4, 5],
        tags: ['Architecture', 'Object-Oriented', 'Patterns'],
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now,
      ),
      EBookModel(
        id: 'ebk-ml-systems',
        title: 'Designing Machine Learning Systems',
        author: 'Chip Huyen',
        category: 'Artificial Intelligence',
        publisher: "O'Reilly Media",
        format: 'PDF',
        fileSize: '16.2 MB',
        totalReaders: 840,
        downloadUrl: '/api/v1/library/ebooks/download/ml-systems.pdf',
        readUrl: '/library/reader/ml-systems',
        isInfiniteBorrow: true,
        description: 'Comprehensive guide to designing reliable, scalable, and maintainable ML workflows, feature stores, and continuous model deployment.',
        requiredSemesters: [6, 7],
        tags: ['MLOps', 'System Design', 'Production ML'],
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now,
      ),
      EBookModel(
        id: 'ebk-computer-arch',
        title: 'Computer Architecture: A Quantitative Approach',
        author: 'John L. Hennessy, David A. Patterson',
        category: 'Electronics',
        publisher: 'Morgan Kaufmann',
        format: 'PDF',
        fileSize: '34.1 MB',
        totalReaders: 620,
        downloadUrl: '/api/v1/library/ebooks/download/computer-arch.pdf',
        readUrl: '/library/reader/computer-arch',
        isInfiniteBorrow: true,
        description: 'Explores hardware and microprocessor design principles, instruction-level parallelism, memory hierarchies, and vector computing.',
        requiredSemesters: [4, 5],
        tags: ['Hardware', 'Processors', 'Parallel Computing'],
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now,
      ),
      EBookModel(
        id: 'ebk-linear-algebra',
        title: 'Linear Algebra and Its Applications',
        author: 'Gilbert Strang',
        category: 'Mathematics',
        publisher: 'Cengage Learning',
        format: 'PDF',
        fileSize: '21.5 MB',
        totalReaders: 1110,
        downloadUrl: '/api/v1/library/ebooks/download/linear-algebra.pdf',
        readUrl: '/library/reader/linear-algebra',
        isInfiniteBorrow: true,
        description: 'Renowned text introducing vector spaces, linear transformations, eigenvalues, singular value decomposition, and computational applications.',
        requiredSemesters: [1, 2],
        tags: ['Mathematics', 'Linear Algebra', 'Foundations'],
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now,
      ),
      EBookModel(
        id: 'ebk-compilers-01',
        title: 'Modern Compiler Implementation in C',
        author: 'Andrew W. Appel',
        category: 'Computer Science',
        publisher: 'Cambridge University Press',
        format: 'PDF',
        fileSize: '14.2 MB',
        totalReaders: 0,
        downloadUrl: '/api/v1/library/ebooks/download/compilers.pdf',
        readUrl: '/library/reader/compilers',
        isInfiniteBorrow: true,
        description: 'Comprehensive reference textbook on lexical analysis, parsing, semantic actions, and intermediate representations.',
        requiredSemesters: [5, 6],
        tags: ['Compilers', 'C', 'Parsing', 'Lex'],
        status: EBookStatus.pendingApproval,
        submittedBy: studentId,
        submittedByName: studentName,
        submittedByRole: 'student',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      ),
    ]);
  }

  @override
  Future<LibrarySummaryModel> getLibrarySummary(String studentId) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.getLibrarySummary(studentId);
      } catch (_) {}
    }

    final now = DateTime.now();
    int activeBorrows = 0;
    int overdueBorrows = 0;
    int returnedBorrows = 0;
    double totalLateFines = 0.0;

    for (int i = 0; i < _cachedBorrowRecords.length; i++) {
      final rec = _cachedBorrowRecords[i];
      if (studentId.isNotEmpty && rec.studentId != studentId) continue;
      if (rec.isRejected) continue;

      if (rec.isReturned) {
        returnedBorrows++;
      } else if (rec.isPendingApproval || rec.isPendingRenewal || rec.isPendingReturn) {
        // Pending approval, renewal, or return counts towards quota reservation
        activeBorrows++;
      } else {
        // Active or overdue
        if (now.isAfter(rec.dueDate)) {
          overdueBorrows++;
          final days = now.difference(rec.dueDate).inDays;
          final fineDays = days > 0 ? days : 1;
          final accrued = fineDays * rec.finePerDay;
          totalLateFines += accrued;

          if (rec.status != BorrowStatus.overdue || rec.accruedLateFine != accrued) {
            _cachedBorrowRecords[i] = rec.copyWith(
              status: BorrowStatus.overdue,
              accruedLateFine: accrued,
              updatedAt: now,
            );
          }
        } else {
          activeBorrows++;
        }
      }
    }

    final totalActive = activeBorrows + overdueBorrows;
    final availableQuota = (4 - totalActive).clamp(0, 4);

    return LibrarySummaryModel(
      studentId: studentId,
      maxBorrowQuota: 4,
      activeBorrowsCount: activeBorrows,
      overdueBorrowsCount: overdueBorrows,
      availableQuota: overdueBorrows > 0 ? 0 : availableQuota,
      totalLateFineDue: totalLateFines,
      returnedHistoryCount: returnedBorrows,
      ebooksAccessedCount: _cachedEBooks.length,
    );
  }

  @override
  Future<List<PhysicalBookModel>> getPhysicalBooks({String? query, String? category}) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.getPhysicalBooks(query: query, category: category);
        _cachedPhysicalBooks.clear();
        _cachedPhysicalBooks.addAll(list);
        return list;
      } catch (_) {}
    }

    final cleanQuery = query?.trim().toLowerCase() ?? '';
    final cleanCategory = category?.trim();

    return _cachedPhysicalBooks.where((b) {
      if (cleanCategory != null &&
          cleanCategory.isNotEmpty &&
          cleanCategory != 'All Categories' &&
          b.category != cleanCategory) {
        return false;
      }
      if (cleanQuery.isNotEmpty) {
        final match = b.title.toLowerCase().contains(cleanQuery) ||
            b.author.toLowerCase().contains(cleanQuery) ||
            b.isbn.toLowerCase().contains(cleanQuery) ||
            b.shelfLocation.toLowerCase().contains(cleanQuery);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<PhysicalBookModel?> getBookById(String id) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.getBookById(id);
      } catch (_) {}
    }

    try {
      return _cachedPhysicalBooks.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BorrowRecordModel>> getBorrowRecords({String? studentId, String? status}) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.getBorrowRecords(studentId: studentId, status: status);
        _cachedBorrowRecords.clear();
        _cachedBorrowRecords.addAll(list);
        return list;
      } catch (_) {}
    }

    final now = DateTime.now();
    // Synchronize overdue status dynamically
    for (int i = 0; i < _cachedBorrowRecords.length; i++) {
      final rec = _cachedBorrowRecords[i];
      if (rec.isActive && now.isAfter(rec.dueDate)) {
        final days = now.difference(rec.dueDate).inDays;
        final fineDays = days > 0 ? days : 1;
        final accrued = fineDays * rec.finePerDay;
        if (rec.status != BorrowStatus.overdue || rec.accruedLateFine != accrued) {
          _cachedBorrowRecords[i] = rec.copyWith(
            status: BorrowStatus.overdue,
            accruedLateFine: accrued,
            updatedAt: now,
          );
        }
      }
    }

    final cleanStatus = status?.trim().toLowerCase();

    return _cachedBorrowRecords.where((r) {
      if (studentId != null && studentId.isNotEmpty && r.studentId != studentId) return false;
      if (cleanStatus != null && cleanStatus.isNotEmpty && cleanStatus != 'all') {
        if (cleanStatus == 'active' && !r.isActive) return false;
        if (cleanStatus == 'overdue' && !r.isOverdue) return false;
        if (cleanStatus == 'returned' && !r.isReturned) return false;
        if ((cleanStatus == 'pending_approval' || cleanStatus == 'pending approval') && !r.isPendingApproval) return false;
        if ((cleanStatus == 'pending_renewal' || cleanStatus == 'pending renewal') && !r.isPendingRenewal) return false;
        if ((cleanStatus == 'pending_return' || cleanStatus == 'pending return') && !r.isPendingReturn) return false;
        if (cleanStatus == 'rejected' && !r.isRejected) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<BorrowRecordModel> borrowBook({
    required String studentId,
    required String bookId,
    String? approvedBy,
    String? approvedByName,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.borrowBook(
          studentId: studentId,
          bookId: bookId,
          approvedBy: approvedBy,
          approvedByName: approvedByName,
        );
        _cachedBorrowRecords.insert(0, res);
        // decrement local copy
        final bIdx = _cachedPhysicalBooks.indexWhere((b) => b.id == bookId);
        if (bIdx != -1) {
          final b = _cachedPhysicalBooks[bIdx];
          _cachedPhysicalBooks[bIdx] = b.copyWith(
            availableCopies: (b.availableCopies - 1).clamp(0, b.totalCopies),
          );
        }
        return res;
      } catch (e) {
        rethrow;
      }
    }

    // Offline validation
    final now = DateTime.now();

    // Check active and overdue loans
    int activeBorrowsCount = 0;
    bool hasOverdue = false;
    for (final rec in _cachedBorrowRecords) {
      if (rec.studentId == studentId && !rec.isReturned && !rec.isRejected) {
        if (rec.isActive && now.isAfter(rec.dueDate)) {
          hasOverdue = true;
        }
        activeBorrowsCount++;
      }
    }

    if (hasOverdue) {
      throw Exception('Cannot borrow new books while overdue loans remain unreturned');
    }
    if (activeBorrowsCount >= 4) {
      throw Exception('Borrowing quota limit reached (Maximum 4 books permitted concurrently)');
    }

    final bookIdx = _cachedPhysicalBooks.indexWhere((b) => b.id == bookId);
    if (bookIdx == -1) {
      throw Exception('Book not found in institutional catalog');
    }

    final book = _cachedPhysicalBooks[bookIdx];
    if (book.availableCopies <= 0) {
      throw Exception("All copies of '${book.title}' are currently checked out");
    }

    // Decrement available copies (reserved)
    _cachedPhysicalBooks[bookIdx] = book.copyWith(
      availableCopies: book.availableCopies - 1,
      updatedAt: now,
    );

    final isAutoApproved = approvedBy != null && approvedBy.isNotEmpty;
    final borrowId = 'brw-${DateTime.now().millisecondsSinceEpoch}';
    final newBorrow = BorrowRecordModel(
      id: borrowId,
      bookId: book.id,
      bookTitle: book.title,
      bookAuthor: book.author,
      bookIsbn: book.isbn,
      shelfLocation: book.shelfLocation,
      studentId: studentId,
      studentName: _currentUser?.fullName ?? 'Student',
      campusHandle: _currentUser?.campusHandle ?? studentId,
      borrowedAt: now,
      dueDate: now.add(const Duration(days: 14)),
      status: isAutoApproved ? BorrowStatus.active : BorrowStatus.pendingApproval,
      approvedBy: isAutoApproved ? approvedBy : null,
      approvedByName: isAutoApproved ? approvedByName : null,
      approvedAt: isAutoApproved ? now : null,
      renewalCount: 0,
      maxRenewals: 2,
      finePerDay: 10.0,
      accruedLateFine: 0.0,
      createdAt: now,
      updatedAt: now,
    );

    _cachedBorrowRecords.insert(0, newBorrow);
    return newBorrow;
  }

  @override
  Future<BorrowRecordModel> approveBorrowRequest({
    required String borrowId,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.approveBorrowRequest(
          borrowId: borrowId,
          approvedBy: approvedBy,
          approvedByName: approvedByName,
          remarks: remarks,
        );
        final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
        if (idx != -1) _cachedBorrowRecords[idx] = res;
        return res;
      } catch (e) {
        rethrow;
      }
    }

    final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
    if (idx == -1) {
      throw Exception('Borrow request record not found');
    }

    final record = _cachedBorrowRecords[idx];
    if (record.status != BorrowStatus.pendingApproval) {
      throw Exception('Cannot approve borrow request that is not in pending approval status');
    }

    final now = DateTime.now();
    final updated = record.copyWith(
      status: BorrowStatus.active,
      approvedBy: approvedBy,
      approvedByName: approvedByName,
      approvedAt: now,
      borrowedAt: now,
      dueDate: now.add(const Duration(days: 14)),
      updatedAt: now,
    );

    _cachedBorrowRecords[idx] = updated;
    return updated;
  }

  @override
  Future<BorrowRecordModel> rejectBorrowRequest({
    required String borrowId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.rejectBorrowRequest(
          borrowId: borrowId,
          rejectedBy: rejectedBy,
          rejectionReason: rejectionReason,
        );
        final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
        if (idx != -1) _cachedBorrowRecords[idx] = res;
        // restore copy
        final bIdx = _cachedPhysicalBooks.indexWhere((b) => b.id == res.bookId);
        if (bIdx != -1) {
          final b = _cachedPhysicalBooks[bIdx];
          _cachedPhysicalBooks[bIdx] = b.copyWith(
            availableCopies: (b.availableCopies + 1).clamp(0, b.totalCopies),
          );
        }
        return res;
      } catch (e) {
        rethrow;
      }
    }

    final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
    if (idx == -1) {
      throw Exception('Borrow request record not found');
    }

    final record = _cachedBorrowRecords[idx];
    if (record.status != BorrowStatus.pendingApproval) {
      throw Exception('Cannot reject borrow request that is not in pending approval status');
    }

    final now = DateTime.now();
    final updated = record.copyWith(
      status: BorrowStatus.rejected,
      rejectionReason: rejectionReason,
      updatedAt: now,
    );

    _cachedBorrowRecords[idx] = updated;

    // Restore available copies
    final bIdx = _cachedPhysicalBooks.indexWhere((b) => b.id == record.bookId);
    if (bIdx != -1) {
      final b = _cachedPhysicalBooks[bIdx];
      _cachedPhysicalBooks[bIdx] = b.copyWith(
        availableCopies: (b.availableCopies + 1).clamp(0, b.totalCopies),
        updatedAt: now,
      );
    }

    return updated;
  }

  @override
  Future<BorrowRecordModel> returnBook({
    required String borrowId,
    required String studentId,
    String? approvedBy,
    String? approvedByName,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.returnBook(
          borrowId: borrowId,
          studentId: studentId,
          approvedBy: approvedBy,
          approvedByName: approvedByName,
        );
        final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
        if (idx != -1) _cachedBorrowRecords[idx] = res;
        if (res.isReturned) {
          final bIdx = _cachedPhysicalBooks.indexWhere((b) => b.id == res.bookId);
          if (bIdx != -1) {
            final b = _cachedPhysicalBooks[bIdx];
            _cachedPhysicalBooks[bIdx] = b.copyWith(
              availableCopies: (b.availableCopies + 1).clamp(0, b.totalCopies),
            );
          }
        }
        return res;
      } catch (e) {
        rethrow;
      }
    }

    final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
    if (idx == -1) {
      throw Exception('Borrow record not found');
    }

    final record = _cachedBorrowRecords[idx];
    if (record.isReturned) {
      throw Exception('Book is already marked as returned');
    }

    final now = DateTime.now();

    if (approvedBy != null && approvedBy.isNotEmpty) {
      double lateFine = 0.0;
      String? finePortalId = record.finePortalFeeId;

      if (now.isAfter(record.dueDate)) {
        final days = now.difference(record.dueDate).inDays;
        final fineDays = days > 0 ? days : 1;
        lateFine = fineDays * record.finePerDay;

        // Issue fine to fine portal if not already issued
        if (finePortalId == null) {
          finePortalId = 'fine-lib-rtn-${record.id}';
          _seedDefaultFeesIfEmpty();
          _cachedFines.add(FineRecordModel(
            id: finePortalId,
            studentId: record.studentId,
            studentName: record.studentName,
            campusHandle: record.campusHandle,
            category: FineCategory.library,
            reason: "Late book return fine for '${record.bookTitle}' ($fineDays days late)",
            amount: lateFine,
            issuedAt: now,
            dueDate: now.add(const Duration(days: 14)),
            status: FineStatus.unpaid,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      final returnedRecord = record.copyWith(
        status: BorrowStatus.returned,
        returnedAt: now,
        returnApprovedBy: approvedBy,
        returnApprovedByName: approvedByName ?? approvedBy,
        returnApprovedAt: now,
        accruedLateFine: lateFine,
        finePortalFeeId: finePortalId,
        updatedAt: now,
      );
      _cachedBorrowRecords[idx] = returnedRecord;

      // Increment available copies of physical book
      final bIdx = _cachedPhysicalBooks.indexWhere((b) => b.id == record.bookId);
      if (bIdx != -1) {
        final b = _cachedPhysicalBooks[bIdx];
        _cachedPhysicalBooks[bIdx] = b.copyWith(
          availableCopies: (b.availableCopies + 1).clamp(0, b.totalCopies),
          updatedAt: now,
        );
      }

      return returnedRecord;
    }

    // Student initiating return: awaiting library in-charge verification
    final pendingReturnRecord = record.copyWith(
      status: BorrowStatus.pendingReturn,
      updatedAt: now,
    );
    _cachedBorrowRecords[idx] = pendingReturnRecord;
    return pendingReturnRecord;
  }

  @override
  Future<BorrowRecordModel> approveReturnRequest({
    required String borrowId,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.approveReturnRequest(
          borrowId: borrowId,
          approvedBy: approvedBy,
          approvedByName: approvedByName,
          remarks: remarks,
        );
        final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
        if (idx != -1) _cachedBorrowRecords[idx] = res;
        final bIdx = _cachedPhysicalBooks.indexWhere((b) => b.id == res.bookId);
        if (bIdx != -1) {
          final b = _cachedPhysicalBooks[bIdx];
          _cachedPhysicalBooks[bIdx] = b.copyWith(
            availableCopies: (b.availableCopies + 1).clamp(0, b.totalCopies),
            updatedAt: DateTime.now(),
          );
        }
        return res;
      } catch (e) {
        rethrow;
      }
    }

    final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
    if (idx == -1) {
      throw Exception('Borrow record not found');
    }

    final record = _cachedBorrowRecords[idx];
    if (record.isReturned) {
      throw Exception('Book is already marked as returned');
    }

    final now = DateTime.now();
    double lateFine = 0.0;
    String? finePortalId = record.finePortalFeeId;

    if (now.isAfter(record.dueDate)) {
      final days = now.difference(record.dueDate).inDays;
      final fineDays = days > 0 ? days : 1;
      lateFine = fineDays * record.finePerDay;

      if (finePortalId == null) {
        finePortalId = 'fine-lib-rtn-${record.id}';
        _seedDefaultFeesIfEmpty();
        _cachedFines.add(FineRecordModel(
          id: finePortalId,
          studentId: record.studentId,
          studentName: record.studentName,
          campusHandle: record.campusHandle,
          category: FineCategory.library,
          reason: "Late book return fine for '${record.bookTitle}' ($fineDays days late)",
          amount: lateFine,
          issuedAt: now,
          dueDate: now.add(const Duration(days: 14)),
          status: FineStatus.unpaid,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }

    final returnedRecord = record.copyWith(
      status: BorrowStatus.returned,
      returnedAt: now,
      returnApprovedBy: approvedBy,
      returnApprovedByName: approvedByName,
      returnApprovedAt: now,
      accruedLateFine: lateFine,
      finePortalFeeId: finePortalId,
      updatedAt: now,
    );
    _cachedBorrowRecords[idx] = returnedRecord;

    final bIdx = _cachedPhysicalBooks.indexWhere((b) => b.id == record.bookId);
    if (bIdx != -1) {
      final b = _cachedPhysicalBooks[bIdx];
      _cachedPhysicalBooks[bIdx] = b.copyWith(
        availableCopies: (b.availableCopies + 1).clamp(0, b.totalCopies),
        updatedAt: now,
      );
    }

    return returnedRecord;
  }

  @override
  Future<BorrowRecordModel> rejectReturnRequest({
    required String borrowId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.rejectReturnRequest(
          borrowId: borrowId,
          rejectedBy: rejectedBy,
          rejectionReason: rejectionReason,
        );
        final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
        if (idx != -1) _cachedBorrowRecords[idx] = res;
        return res;
      } catch (e) {
        rethrow;
      }
    }

    final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
    if (idx == -1) {
      throw Exception('Borrow record not found');
    }

    final record = _cachedBorrowRecords[idx];
    final now = DateTime.now();
    final updated = record.copyWith(
      status: record.isOverdue ? BorrowStatus.overdue : BorrowStatus.active,
      returnRejectionReason: rejectionReason,
      updatedAt: now,
    );
    _cachedBorrowRecords[idx] = updated;
    return updated;
  }

  @override
  Future<BorrowRecordModel> renewBook({
    required String borrowId,
    required String studentId,
    String? approvedBy,
    String? approvedByName,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.renewBook(
          borrowId: borrowId,
          studentId: studentId,
          approvedBy: approvedBy,
          approvedByName: approvedByName,
        );
        final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
        if (idx != -1) _cachedBorrowRecords[idx] = res;
        return res;
      } catch (e) {
        rethrow;
      }
    }

    final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
    if (idx == -1) {
      throw Exception('Borrow record not found');
    }

    final record = _cachedBorrowRecords[idx];
    if (record.isReturned) {
      throw Exception('Cannot renew a book that has already been returned');
    }

    final now = DateTime.now();
    if (now.isAfter(record.dueDate)) {
      throw Exception('Overdue books cannot be renewed; please return the copy and settle late fines');
    }
    if (record.renewalCount >= record.maxRenewals) {
      throw Exception('Maximum renewal limit reached (2 renewals maximum permitted)');
    }

    if (approvedBy != null && approvedBy.isNotEmpty) {
      final renewedRecord = record.copyWith(
        dueDate: record.dueDate.add(const Duration(days: 14)),
        renewalCount: record.renewalCount + 1,
        status: BorrowStatus.active,
        renewalApprovedBy: approvedBy,
        renewalApprovedByName: approvedByName ?? approvedBy,
        renewalApprovedAt: now,
        updatedAt: now,
      );
      _cachedBorrowRecords[idx] = renewedRecord;
      return renewedRecord;
    }

    final pendingRenewalRecord = record.copyWith(
      status: BorrowStatus.pendingRenewal,
      updatedAt: now,
    );
    _cachedBorrowRecords[idx] = pendingRenewalRecord;
    return pendingRenewalRecord;
  }

  @override
  Future<BorrowRecordModel> approveRenewalRequest({
    required String borrowId,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.approveRenewalRequest(
          borrowId: borrowId,
          approvedBy: approvedBy,
          approvedByName: approvedByName,
          remarks: remarks,
        );
        final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
        if (idx != -1) _cachedBorrowRecords[idx] = res;
        return res;
      } catch (e) {
        rethrow;
      }
    }

    final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
    if (idx == -1) {
      throw Exception('Borrow record not found');
    }

    final record = _cachedBorrowRecords[idx];
    if (record.renewalCount >= record.maxRenewals) {
      throw Exception('Maximum renewal limit reached (2 renewals maximum permitted)');
    }

    final now = DateTime.now();
    final renewedRecord = record.copyWith(
      dueDate: record.dueDate.add(const Duration(days: 14)),
      renewalCount: record.renewalCount + 1,
      status: BorrowStatus.active,
      renewalApprovedBy: approvedBy,
      renewalApprovedByName: approvedByName,
      renewalApprovedAt: now,
      updatedAt: now,
    );
    _cachedBorrowRecords[idx] = renewedRecord;
    return renewedRecord;
  }

  @override
  Future<BorrowRecordModel> rejectRenewalRequest({
    required String borrowId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.rejectRenewalRequest(
          borrowId: borrowId,
          rejectedBy: rejectedBy,
          rejectionReason: rejectionReason,
        );
        final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
        if (idx != -1) _cachedBorrowRecords[idx] = res;
        return res;
      } catch (e) {
        rethrow;
      }
    }

    final idx = _cachedBorrowRecords.indexWhere((r) => r.id == borrowId);
    if (idx == -1) {
      throw Exception('Borrow record not found');
    }

    final record = _cachedBorrowRecords[idx];
    final now = DateTime.now();
    final updated = record.copyWith(
      status: record.isOverdue ? BorrowStatus.overdue : BorrowStatus.active,
      renewalRejectionReason: rejectionReason,
      updatedAt: now,
    );
    _cachedBorrowRecords[idx] = updated;
    return updated;
  }

  @override
  Future<List<EBookModel>> getEBooks({String? query, String? category}) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.getEBooks(query: query, category: category);
        _cachedEBooks.clear();
        _cachedEBooks.addAll(list);
        return list;
      } catch (_) {}
    }

    final cleanQuery = query?.trim().toLowerCase() ?? '';
    final cleanCategory = category?.trim();

    return _cachedEBooks.where((e) {
      if (cleanCategory != null &&
          cleanCategory.isNotEmpty &&
          cleanCategory != 'All Categories' &&
          e.category != cleanCategory) {
        return false;
      }
      if (cleanQuery.isNotEmpty) {
        final match = e.title.toLowerCase().contains(cleanQuery) ||
            e.author.toLowerCase().contains(cleanQuery) ||
            e.description.toLowerCase().contains(cleanQuery) ||
            e.tags.any((t) => t.toLowerCase().contains(cleanQuery));
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<PhysicalBookModel> createPhysicalBook(PhysicalBookModel book) async {
    _seedDefaultLibraryIfEmpty();

    final now = DateTime.now();
    final withId = book.id.isEmpty
        ? book.copyWith(
            id: 'bk-${now.millisecondsSinceEpoch}',
            availableCopies: book.availableCopies == 0 ? book.totalCopies : book.availableCopies,
            createdAt: now,
            updatedAt: now,
          )
        : book;

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.createPhysicalBook(withId);
        _cachedPhysicalBooks.removeWhere((b) => b.id == res.id);
        _cachedPhysicalBooks.insert(0, res);
        return res;
      } catch (_) {}
    }

    _cachedPhysicalBooks.removeWhere((b) => b.id == withId.id);
    _cachedPhysicalBooks.insert(0, withId);
    return withId;
  }

  @override
  Future<void> deletePhysicalBook(String id) async {
    _seedDefaultLibraryIfEmpty();

    // Check if book has active or pending loans
    final hasActiveLoans = _cachedBorrowRecords.any((b) =>
        b.bookId == id &&
        (b.isActive || b.isOverdue || b.isPendingApproval || b.isPendingRenewal || b.isPendingReturn));
    if (hasActiveLoans) {
      throw Exception('Cannot remove catalogue: book currently has active or pending loans');
    }

    await checkConnectivity();
    if (isOnline) {
      try {
        await api.deletePhysicalBook(id);
      } catch (_) {}
    }

    _cachedPhysicalBooks.removeWhere((b) => b.id == id);
  }

  final Map<String, List<int>> _uploadedPdfs = {};

  @override
  Future<Map<String, dynamic>> uploadPdfDocument({
    required List<int> bytes,
    required String filename,
  }) async {
    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.uploadPdfDocument(bytes: bytes, filename: filename);
      } catch (_) {}
    }

    final now = DateTime.now();
    final fileId = 'pdf-${now.millisecondsSinceEpoch}';
    _uploadedPdfs[fileId] = bytes;

    return {
      'file_id': fileId,
      'original_name': filename,
      'filename': '${fileId}_$filename',
      'size_bytes': bytes.length,
      'size_formatted': '${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB',
      'url': '/api/v1/uploads?id=$fileId',
      'uploaded_at': now.toIso8601String(),
    };
  }

  @override
  Future<EBookModel> createEBook(EBookModel ebook) async {
    _seedDefaultLibraryIfEmpty();

    final now = DateTime.now();
    final withId = ebook.id.isEmpty
        ? ebook.copyWith(
            id: 'ebk-${now.millisecondsSinceEpoch}',
            format: ebook.format.isEmpty ? 'PDF' : ebook.format,
            downloadUrl: ebook.downloadUrl.isEmpty
                ? '/api/v1/library/ebooks/download/ebk-${now.millisecondsSinceEpoch}.pdf'
                : ebook.downloadUrl,
            readUrl: ebook.readUrl.isEmpty
                ? '/library/reader/ebk-${now.millisecondsSinceEpoch}'
                : ebook.readUrl,
            createdAt: now,
            updatedAt: now,
          )
        : ebook;

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.createEBook(withId);
        _cachedEBooks.removeWhere((e) => e.id == res.id);
        _cachedEBooks.insert(0, res);
        return res;
      } catch (_) {}
    }

    _cachedEBooks.removeWhere((e) => e.id == withId.id);
    _cachedEBooks.insert(0, withId);
    return withId;
  }

  @override
  Future<EBookModel> approveEBook({
    required String ebookId,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.approveEBook(
          ebookId: ebookId,
          approvedBy: approvedBy,
          approvedByName: approvedByName,
          remarks: remarks,
        );
        final idx = _cachedEBooks.indexWhere((e) => e.id == ebookId);
        if (idx != -1) _cachedEBooks[idx] = res;
        return res;
      } catch (_) {}
    }

    final idx = _cachedEBooks.indexWhere((e) => e.id == ebookId);
    if (idx == -1) {
      throw Exception('E-Book not found');
    }

    final now = DateTime.now();
    final updated = _cachedEBooks[idx].copyWith(
      status: EBookStatus.approved,
      approvedBy: approvedBy,
      approvedByName: approvedByName,
      approvedAt: now,
      updatedAt: now,
    );
    _cachedEBooks[idx] = updated;
    return updated;
  }

  @override
  Future<EBookModel> rejectEBook({
    required String ebookId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.rejectEBook(
          ebookId: ebookId,
          rejectedBy: rejectedBy,
          rejectionReason: rejectionReason,
        );
        final idx = _cachedEBooks.indexWhere((e) => e.id == ebookId);
        if (idx != -1) _cachedEBooks[idx] = res;
        return res;
      } catch (_) {}
    }

    final idx = _cachedEBooks.indexWhere((e) => e.id == ebookId);
    if (idx == -1) {
      throw Exception('E-Book not found');
    }

    final now = DateTime.now();
    final updated = _cachedEBooks[idx].copyWith(
      status: EBookStatus.rejected,
      rejectionReason: rejectionReason,
      updatedAt: now,
    );
    _cachedEBooks[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteEBook(String id) async {
    _seedDefaultLibraryIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        await api.deleteEBook(id);
      } catch (_) {}
    }

    _cachedEBooks.removeWhere((e) => e.id == id);
  }

  // =========================================================================
  // AKTU Sessional & Continuous Internal Evaluation Subsystem
  // =========================================================================

  void _seedDefaultSessionalIfEmpty() {
    if (!enableMockSeeding || _cachedSessionalRecords.isNotEmpty) return;

    _cachedSessionalSchedules.addAll([
      SessionalScheduleModel(
        id: 'sch-ct1-cs301',
        examType: 'CT-1',
        subjectCode: 'CS301',
        subjectName: 'Operating Systems',
        semesterNumber: 5,
        examDate: '2025-11-24',
        timeSlot: '10:00 AM - 11:30 AM',
        hallNumber: 'LT-101',
        totalCapacity: 60,
        invigilatorName: 'Prof. Neha Sharma',
        rollRange: '2100970100001 - 2100970100060',
      ),
      SessionalScheduleModel(
        id: 'sch-ct1-cs302',
        examType: 'CT-1',
        subjectCode: 'CS302',
        subjectName: 'Database Management Systems',
        semesterNumber: 5,
        examDate: '2025-11-25',
        timeSlot: '10:00 AM - 11:30 AM',
        hallNumber: 'LT-101',
        totalCapacity: 60,
        invigilatorName: 'Dr. Arun Kumar (HOD)',
        rollRange: '2100970100001 - 2100970100060',
      ),
      SessionalScheduleModel(
        id: 'sch-ct1-cs303',
        examType: 'CT-1',
        subjectCode: 'CS303',
        subjectName: 'Design & Analysis of Algorithms',
        semesterNumber: 5,
        examDate: '2025-11-26',
        timeSlot: '10:00 AM - 11:30 AM',
        hallNumber: 'LT-102',
        totalCapacity: 60,
        invigilatorName: 'Prof. Neha Sharma',
        rollRange: '2100970100001 - 2100970100060',
      ),
      SessionalScheduleModel(
        id: 'sch-ct2-cs301',
        examType: 'CT-2',
        subjectCode: 'CS301',
        subjectName: 'Operating Systems',
        semesterNumber: 5,
        examDate: '2025-12-15',
        timeSlot: '02:00 PM - 03:30 PM',
        hallNumber: 'LT-101',
        totalCapacity: 60,
        invigilatorName: 'Prof. Neha Sharma',
        rollRange: '2100970100001 - 2100970100060',
      ),
      SessionalScheduleModel(
        id: 'sch-put-cs301',
        examType: 'PUT',
        subjectCode: 'CS301',
        subjectName: 'Operating Systems (Pre-University Test)',
        semesterNumber: 5,
        examDate: '2026-01-05',
        timeSlot: '09:30 AM - 12:30 PM',
        hallNumber: 'Auditorium Hall A',
        totalCapacity: 120,
        invigilatorName: 'Dr. Arun Kumar (HOD)',
        rollRange: '2100970100001 - 2100970100120',
      ),
    ]);

    final students = [
      ('usr-harish_2025_l_btech_1', 'Harish Kumar', '2100970100045'),
      ('usr-priya_singh_cse', 'Priya Singh', '2100970100046'),
      ('usr-rahul_verma_cse', 'Rahul Verma', '2100970100047'),
      ('usr-ananya_gupta_cse', 'Ananya Gupta', '2100970100048'),
      ('usr-vikas_yadav_cse', 'Vikas Yadav', '2100970100049'),
    ];

    final subjects = [
      ('CS301', 'Operating Systems', false),
      ('CS302', 'Database Management Systems', false),
      ('CS303', 'Design & Analysis of Algorithms', false),
      ('CS301L', 'Operating Systems Lab', true),
    ];

    final Map<String, Map<String, List<double>>> scoreMap = {
      'usr-harish_2025_l_btech_1': {
        'CS301': [26.0, 24.0, 78.0, 8.5],
        'CS302': [28.0, 27.0, 82.0, 9.0],
        'CS303': [22.0, 25.0, 70.0, 8.0],
        'CS301L': [18.0, 17.5, 9.0],
      },
      'usr-priya_singh_cse': {
        'CS301': [29.0, 28.5, 91.0, 9.5],
        'CS302': [27.0, 26.0, 84.0, 9.0],
        'CS303': [28.0, 29.0, 88.0, 9.5],
        'CS301L': [19.0, 19.0, 9.5],
      },
      'usr-rahul_verma_cse': {
        'CS301': [18.0, 16.0, 52.0, 7.0],
        'CS302': [19.0, 15.0, 48.0, 6.5],
        'CS303': [14.0, 16.0, 45.0, 6.0],
        'CS301L': [14.0, 13.0, 7.5],
      },
      'usr-ananya_gupta_cse': {
        'CS301': [25.0, 23.0, 75.0, 8.0],
        'CS302': [26.0, 24.0, 76.0, 8.5],
        'CS303': [24.0, 22.0, 72.0, 8.0],
        'CS301L': [17.0, 18.0, 8.5],
      },
      'usr-vikas_yadav_cse': {
        'CS301': [12.0, 10.0, 34.0, 5.0],
        'CS302': [11.0, 9.0, 30.0, 4.5],
        'CS303': [10.0, 8.0, 28.0, 4.0],
        'CS301L': [11.0, 10.0, 6.0],
      },
    };

    for (final st in students) {
      for (final sub in subjects) {
        final code = sub.$1;
        final name = sub.$2;
        final isPrac = sub.$3;
        final scores = scoreMap[st.$1]?[code] ?? [0.0, 0.0, 0.0, 0.0];

        double calcSessional = 0.0;
        double totalInternal = 0.0;
        String formula = '';

        if (isPrac) {
          final labCont = scores[0];
          final labViva = scores[1];
          final labAtt = scores[2];
          final tot = (labCont + labViva + labAtt);
          calcSessional = double.parse(tot.toStringAsFixed(1));
          totalInternal = calcSessional;
          formula = 'Lab Continuous (20) + Viva (20) + Lab Conduct (10) [Max 50]';
        } else {
          final ct1 = scores[0];
          final ct2 = scores[1];
          final ta = scores[3];
          final sessional20 = ((ct1 + ct2) / 3.0);
          calcSessional = double.parse(sessional20.toStringAsFixed(1));
          final tot = calcSessional + ta;
          totalInternal = double.parse(tot.toStringAsFixed(1));
          formula = '((CT1 + CT2) / 2) * (20/30) + Teacher Assessment (10) [Max 30]';
        }

        _cachedSessionalRecords.add(InternalAssessmentModel(
          id: 'rec-$code-${st.$3}',
          studentId: st.$1,
          studentName: st.$2,
          universityRollNo: st.$3,
          subjectCode: code,
          subjectName: name,
          semesterNumber: 5,
          section: 'Section B',
          isPractical: isPrac,
          ct1Score: isPrac ? 0.0 : scores[0],
          ct2Score: isPrac ? 0.0 : scores[1],
          putScore: isPrac ? 0.0 : scores[2],
          taScore: isPrac ? 0.0 : scores[3],
          labContinuousScore: isPrac ? scores[0] : 0.0,
          labVivaScore: isPrac ? scores[1] : 0.0,
          labAttendanceScore: isPrac ? scores[2] : 0.0,
          calculatedSessional: calcSessional,
          totalInternalMarks: totalInternal,
          maxInternalMarks: isPrac ? 50.0 : 30.0,
          formulaUsed: formula,
          isFrozen: false,
          status: 'submitted',
        ));
      }
    }
  }

  @override
  Future<List<InternalAssessmentModel>> getSessionalRecords({
    String? studentId,
    String? subjectCode,
    int? semester,
  }) async {
    _seedDefaultSessionalIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.fetchSessionalRecords(
          studentId: studentId,
          subjectCode: subjectCode,
          semester: semester,
        );
        for (final r in list) {
          final idx = _cachedSessionalRecords.indexWhere((e) => e.id == r.id);
          if (idx >= 0) {
            _cachedSessionalRecords[idx] = r;
          } else {
            _cachedSessionalRecords.add(r);
          }
        }
        return list;
      } catch (_) {}
    }

    return _cachedSessionalRecords.where((r) {
      if (studentId != null &&
          studentId.isNotEmpty &&
          r.studentId != studentId &&
          r.universityRollNo != studentId) {
        return false;
      }
      if (subjectCode != null && subjectCode.isNotEmpty && r.subjectCode != subjectCode) {
        return false;
      }
      if (semester != null && semester > 0 && r.semesterNumber != semester) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<InternalAssessmentModel> updateSessionalMarks(Map<String, dynamic> payload) async {
    _seedDefaultSessionalIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final updated = await api.updateSessionalMarks(payload);
        final idx = _cachedSessionalRecords.indexWhere((e) => e.id == updated.id);
        if (idx >= 0) {
          _cachedSessionalRecords[idx] = updated;
        }
        return updated;
      } catch (_) {}
    }

    final recordId = payload['record_id']?.toString() ?? '';
    final subjectCode = payload['subject_code']?.toString() ?? '';
    final studentId = payload['student_id']?.toString() ?? '';

    final idx = _cachedSessionalRecords.indexWhere((r) {
      if (recordId.isNotEmpty && r.id == recordId) return true;
      if (subjectCode.isNotEmpty &&
          r.subjectCode == subjectCode &&
          (r.studentId == studentId || r.universityRollNo == studentId)) {
        return true;
      }
      return false;
    });

    if (idx < 0) {
      throw Exception('Assessment record not found');
    }

    final target = _cachedSessionalRecords[idx];
    if (target.isFrozen) {
      throw Exception('Marks are frozen and cannot be modified');
    }

    double ct1 = payload['ct1_score'] != null ? (payload['ct1_score'] as num).toDouble() : target.ct1Score;
    double ct2 = payload['ct2_score'] != null ? (payload['ct2_score'] as num).toDouble() : target.ct2Score;
    double put = payload['put_score'] != null ? (payload['put_score'] as num).toDouble() : target.putScore;
    double ta = payload['ta_score'] != null ? (payload['ta_score'] as num).toDouble() : target.taScore;
    double labCont = payload['lab_continuous_score'] != null ? (payload['lab_continuous_score'] as num).toDouble() : target.labContinuousScore;
    double labViva = payload['lab_viva_score'] != null ? (payload['lab_viva_score'] as num).toDouble() : target.labVivaScore;
    double labAtt = payload['lab_attendance_score'] != null ? (payload['lab_attendance_score'] as num).toDouble() : target.labAttendanceScore;

    double calcSessional = 0.0;
    double totalInternal = 0.0;

    if (target.isPractical) {
      labCont = labCont.clamp(0.0, 20.0);
      labViva = labViva.clamp(0.0, 20.0);
      labAtt = labAtt.clamp(0.0, 10.0);
      final tot = labCont + labViva + labAtt;
      calcSessional = double.parse(tot.toStringAsFixed(1));
      totalInternal = calcSessional;
    } else {
      ct1 = ct1.clamp(0.0, 30.0);
      ct2 = ct2.clamp(0.0, 30.0);
      ta = ta.clamp(0.0, 10.0);
      final sessional20 = ((ct1 + ct2) / 3.0).clamp(0.0, 20.0);
      calcSessional = double.parse(sessional20.toStringAsFixed(1));
      final tot = (calcSessional + ta).clamp(0.0, 30.0);
      totalInternal = double.parse(tot.toStringAsFixed(1));
    }

    final updated = target.copyWith(
      ct1Score: ct1,
      ct2Score: ct2,
      putScore: put,
      taScore: ta,
      labContinuousScore: labCont,
      labVivaScore: labViva,
      labAttendanceScore: labAtt,
      calculatedSessional: calcSessional,
      totalInternalMarks: totalInternal,
      remarks: payload['remarks']?.toString() ?? target.remarks,
    );

    _cachedSessionalRecords[idx] = updated;
    return updated;
  }

  @override
  Future<AKTUInternalAwardListModel> freezeSessionalMarks(Map<String, dynamic> payload) async {
    _seedDefaultSessionalIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final res = await api.freezeSessionalMarks(payload);
        for (final r in res.records) {
          final idx = _cachedSessionalRecords.indexWhere((e) => e.id == r.id);
          if (idx >= 0) {
            _cachedSessionalRecords[idx] = r;
          }
        }
        return res;
      } catch (_) {}
    }

    final subjectCode = payload['subject_code']?.toString() ?? '';
    final semester = payload['semester'] is int
        ? payload['semester'] as int
        : int.tryParse(payload['semester']?.toString() ?? '5') ?? 5;
    final frozenBy = payload['frozen_by']?.toString() ?? 'dr_arun_kumar';
    final nowStr = DateTime.now().toIso8601String();

    final matched = <InternalAssessmentModel>[];
    for (int i = 0; i < _cachedSessionalRecords.length; i++) {
      final r = _cachedSessionalRecords[i];
      if (r.subjectCode == subjectCode && (semester <= 0 || r.semesterNumber == semester)) {
        final frozenRec = r.copyWith(
          isFrozen: true,
          frozenBy: frozenBy,
          frozenAt: nowStr,
          status: 'frozen',
          remarks: payload['remarks']?.toString() ?? r.remarks,
        );
        _cachedSessionalRecords[i] = frozenRec;
        matched.add(frozenRec);
      }
    }

    if (matched.isEmpty) {
      throw Exception('No records found for subject $subjectCode');
    }

    return _compileAwardList(subjectCode, semester, matched, frozenBy, nowStr);
  }

  @override
  Future<List<SessionalScheduleModel>> getSessionalSchedules({
    int? semester,
    String? examType,
  }) async {
    _seedDefaultSessionalIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final list = await api.fetchSessionalSchedules(semester: semester, examType: examType);
        _cachedSessionalSchedules.clear();
        _cachedSessionalSchedules.addAll(list);
        return list;
      } catch (_) {}
    }

    return _cachedSessionalSchedules.where((s) {
      if (semester != null && semester > 0 && s.semesterNumber != semester) {
        return false;
      }
      if (examType != null && examType.isNotEmpty && s.examType != examType) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<List<DeskSeatingModel>> getSeatingLayout({
    String? hallNumber,
    String? examType,
  }) async {
    _seedDefaultSessionalIfEmpty();

    final hall = hallNumber ?? 'LT-101';
    final exam = examType ?? 'CT-1';

    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.fetchSeatingLayout(hallNumber: hall, examType: exam);
      } catch (_) {}
    }

    return [
      DeskSeatingModel(
        deskNumber: 'D-01',
        hallNumber: hall,
        seatIndex: 1,
        studentRollNo: '2100970100045',
        studentName: 'Harish Kumar',
        subjectCode: 'CS301',
        subjectName: 'Operating Systems',
        examType: exam,
      ),
      DeskSeatingModel(
        deskNumber: 'D-02',
        hallNumber: hall,
        seatIndex: 2,
        studentRollNo: '2100970100046',
        studentName: 'Priya Singh',
        subjectCode: 'CS301',
        subjectName: 'Operating Systems',
        examType: exam,
      ),
      DeskSeatingModel(
        deskNumber: 'D-03',
        hallNumber: hall,
        seatIndex: 3,
        studentRollNo: '2100970100047',
        studentName: 'Rahul Verma',
        subjectCode: 'CS301',
        subjectName: 'Operating Systems',
        examType: exam,
      ),
      DeskSeatingModel(
        deskNumber: 'D-04',
        hallNumber: hall,
        seatIndex: 4,
        studentRollNo: '2100970100048',
        studentName: 'Ananya Gupta',
        subjectCode: 'CS301',
        subjectName: 'Operating Systems',
        examType: exam,
      ),
      DeskSeatingModel(
        deskNumber: 'D-05',
        hallNumber: hall,
        seatIndex: 5,
        studentRollNo: '2100970100049',
        studentName: 'Vikas Yadav',
        subjectCode: 'CS301',
        subjectName: 'Operating Systems',
        examType: exam,
      ),
    ];
  }

  @override
  Future<AKTUInternalAwardListModel> getAwardList({
    required String subjectCode,
    int? semester,
  }) async {
    _seedDefaultSessionalIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.fetchAwardList(subjectCode: subjectCode, semester: semester);
      } catch (_) {}
    }

    final matched = _cachedSessionalRecords.where((r) {
      if (r.subjectCode != subjectCode) return false;
      if (semester != null && semester > 0 && r.semesterNumber != semester) return false;
      return true;
    }).toList();

    if (matched.isEmpty) {
      throw Exception('No records found for subject $subjectCode');
    }

    final frozenBy = matched.first.frozenBy ?? '';
    final frozenAt = matched.first.frozenAt ?? '';

    return _compileAwardList(subjectCode, semester ?? 5, matched, frozenBy, frozenAt);
  }

  AKTUInternalAwardListModel _compileAwardList(
    String subjectCode,
    int semester,
    List<InternalAssessmentModel> list,
    String frozenBy,
    String frozenAt,
  ) {
    final total = list.length;
    final isPractical = list.isNotEmpty && list.first.isPractical;
    final subjectName = list.isNotEmpty ? list.first.subjectName : subjectCode;
    final maxMarks = isPractical ? 50.0 : 30.0;
    final passThreshold = maxMarks * 0.40;

    double sum = 0.0;
    double highest = -1.0;
    double lowest = 999.0;
    int passCount = 0;
    int deficitCount = 0;
    bool isAllFrozen = true;

    for (final r in list) {
      final score = r.totalInternalMarks;
      sum += score;
      if (score > highest) highest = score;
      if (score < lowest) lowest = score;
      if (score >= passThreshold) {
        passCount++;
      } else {
        deficitCount++;
      }
      if (!r.isFrozen) isAllFrozen = false;
    }

    if (lowest > highest) lowest = 0.0;
    if (highest < 0) highest = 0.0;

    final avg = total > 0 ? double.parse((sum / total).toStringAsFixed(1)) : 0.0;
    final passPct = total > 0 ? double.parse(((passCount / total) * 100).toStringAsFixed(1)) : 0.0;

    // Cryptographic signature
    final sigRaw = '$subjectCode|$semester|$frozenBy|$frozenAt|${list.map((e) => '${e.universityRollNo}:${e.totalInternalMarks}').join('|')}';
    final signature = sha256.convert(utf8.encode(sigRaw)).toString();

    return AKTUInternalAwardListModel(
      departmentCode: 'CSE',
      departmentName: 'Computer Science & Engineering',
      programName: 'B.Tech Computer Science',
      semesterNumber: semester,
      subjectCode: subjectCode,
      subjectName: subjectName,
      academicSession: '2025-2026',
      isPractical: isPractical,
      maxInternalMarks: maxMarks,
      totalStudents: total,
      passCount: passCount,
      failCount: total - passCount,
      passPercentage: passPct,
      averageMarks: avg,
      highestMarks: highest,
      lowestMarks: lowest,
      deficitCount: deficitCount,
      isFrozen: isAllFrozen,
      frozenBy: frozenBy.isNotEmpty ? frozenBy : null,
      frozenAt: frozenAt.isNotEmpty ? frozenAt : null,
      digitalSignature: isAllFrozen ? signature : null,
      records: list,
    );
  }

  @override
  Future<UserModel> syncDigiLocker(String userId) async {
    _seedDefaultUsersIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final synced = await api.syncDigiLocker(userId);
        final idx = _cachedUsers.indexWhere((u) => u.id == userId || u.campusHandle == userId);
        if (idx >= 0) {
          _cachedUsers[idx] = synced;
        }
        return synced;
      } catch (_) {}
    }

    final user = await getUserProfile(userId);
    return user;
  }

  @override
  Future<DigiLockerAuthResponse> getDigiLockerAuthUrl({
    required String studentId,
    String? redirectUri,
  }) async {
    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.getDigiLockerAuthUrl(studentId: studentId, redirectUri: redirectUri);
      } catch (_) {}
    }

    final state = 'demo_state_${DateTime.now().millisecondsSinceEpoch}';
    final verifier = 'demo_verifier_${DateTime.now().millisecondsSinceEpoch}';
    return DigiLockerAuthResponse(
      authUrl: 'https://digilocker.meripehchan.gov.in/public/oauth2/1/authorize?response_type=code&client_id=campus_erp_demo_client&state=$state',
      state: state,
      codeVerifier: verifier,
      environment: 'sandbox',
    );
  }

  @override
  Future<UserModel> exchangeDigiLockerToken({
    required String studentId,
    required String code,
    required String state,
    required String codeVerifier,
  }) async {
    _seedDefaultUsersIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final synced = await api.exchangeDigiLockerToken(
          studentId: studentId,
          code: code,
          state: state,
          codeVerifier: codeVerifier,
        );
        final idx = _cachedUsers.indexWhere((u) => u.id == studentId || u.campusHandle == studentId);
        if (idx >= 0) {
          _cachedUsers[idx] = synced;
        }
        return synced;
      } catch (_) {}
    }

    final user = await getUserProfile(studentId);
    final now = DateTime.now();
    final nowStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} IST';

    final verifiedDocs = [
      VerifiedDocumentModel(
        documentType: 'apaar_abc',
        documentTitle: 'APAAR / Academic Bank of Credits (ABC) ID',
        issuer: 'National Academic Depository (NAD) / MeitY',
        docRefMasked: '8912-XXXX-7890',
        issuedYear: 2023,
        isVerified: true,
        verificationHash: 'sha256:${sha256.convert(utf8.encode('apaar:8912-3456-7890:nad:2023'))}',
        verifiedAt: nowStr,
        status: 'verified',
      ),
      VerifiedDocumentModel(
        documentType: 'class_x',
        documentTitle: 'Secondary School Certificate (Class X)',
        issuer: 'Central Board of Secondary Education (CBSE)',
        docRefMasked: 'ROLL-12894104',
        issuedYear: 2021,
        isVerified: true,
        verificationHash: 'sha256:${sha256.convert(utf8.encode('cbse:class_x:12894104:2021'))}',
        verifiedAt: nowStr,
        status: 'verified',
      ),
      VerifiedDocumentModel(
        documentType: 'class_xii',
        documentTitle: 'Senior School Certificate (Class XII - PCM)',
        issuer: 'Central Board of Secondary Education (CBSE)',
        docRefMasked: 'ROLL-61928401',
        issuedYear: 2023,
        isVerified: true,
        verificationHash: 'sha256:${sha256.convert(utf8.encode('cbse:class_xii:61928401:2023'))}',
        verifiedAt: nowStr,
        status: 'verified',
      ),
      VerifiedDocumentModel(
        documentType: 'aadhaar_kyc',
        documentTitle: 'Aadhaar e-KYC Verification Record',
        issuer: 'Unique Identification Authority of India (UIDAI)',
        docRefMasked: 'XXXX-XXXX-4091',
        issuedYear: 2023,
        isVerified: true,
        verificationHash: 'sha256:${sha256.convert(utf8.encode('uidai:aadhaar:4091:kyc_verified'))}',
        verifiedAt: nowStr,
        status: 'verified',
      ),
      VerifiedDocumentModel(
        documentType: 'domicile',
        documentTitle: 'State Domicile Certificate',
        issuer: 'Revenue Department, Govt of Uttar Pradesh',
        docRefMasked: 'UP/DOM/2021/88921',
        issuedYear: 2021,
        isVerified: true,
        verificationHash: 'sha256:${sha256.convert(utf8.encode('up_edistrict:domicile:88921:2021'))}',
        verifiedAt: nowStr,
        status: 'verified',
      ),
    ];

    final updated = user.copyWith(
      studentProfile: {
        if (user.studentProfile != null) ...user.studentProfile!,
        'abc_id': '8912-3456-7890',
        'digilocker_verified': true,
        'digilocker_verified_at': now.toIso8601String(),
        'verified_documents': verifiedDocs.map((e) => e.toJson()).toList(),
      },
    );

    final idx = _cachedUsers.indexWhere((u) => u.id == studentId || u.campusHandle == studentId);
    if (idx >= 0) {
      _cachedUsers[idx] = updated;
    }

    return updated;
  }

  @override
  Future<DigiLockerStatusModel> getDigiLockerStatus({required String studentId}) async {
    _seedDefaultUsersIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        return await api.getDigiLockerStatus(studentId: studentId);
      } catch (_) {}
    }

    final user = await getUserProfile(studentId);
    final verifiedDate = user.digiLockerVerifiedAt != null
        ? DateTime.tryParse(user.digiLockerVerifiedAt!)
        : null;

    return DigiLockerStatusModel(
      studentId: studentId,
      isConnected: user.isDigiLockerVerified,
      abcId: user.abcId,
      verifiedAt: verifiedDate,
      documentsCount: user.verifiedDocuments.length,
      documents: user.verifiedDocuments,
      environmentMode: 'sandbox',
    );
  }

  @override
  Future<UserModel> disconnectDigiLocker({required String studentId}) async {
    _seedDefaultUsersIfEmpty();

    await checkConnectivity();
    if (isOnline) {
      try {
        final synced = await api.disconnectDigiLocker(studentId: studentId);
        final idx = _cachedUsers.indexWhere((u) => u.id == studentId || u.campusHandle == studentId);
        if (idx >= 0) {
          _cachedUsers[idx] = synced;
        }
        return synced;
      } catch (_) {}
    }

    final user = await getUserProfile(studentId);
    final updated = user.copyWith(
      studentProfile: {
        if (user.studentProfile != null) ...user.studentProfile!,
        'abc_id': null,
        'digilocker_verified': false,
        'digilocker_verified_at': null,
        'verified_documents': [],
      },
    );

    final idx = _cachedUsers.indexWhere((u) => u.id == studentId || u.campusHandle == studentId);
    if (idx >= 0) {
      _cachedUsers[idx] = updated;
    }

    return updated;
  }
}
