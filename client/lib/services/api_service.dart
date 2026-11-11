import 'dart:convert';
import 'package:http/http.dart' as http;
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
import 'storage_interface.dart';

class ApiService implements ICampusApi {
  @override
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8080'});

  Future<UserModel> login(String identifier, String password) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/v1/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': identifier,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 4));

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(res.body);
      final userMap = data['user'] as Map<String, dynamic>;
      final scopes = (data['scopes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          ['global'];
      final permissions = (data['permissions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final assignedRoles = data['assigned_roles'] ?? [];

      return UserModel.fromJson({
        ...userMap,
        'active_scopes': scopes,
        'assigned_roles': assignedRoles,
        'permissions': permissions,
      });
    }
    throw Exception('Authentication failed (${res.statusCode})');
  }

  Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(milliseconds: 150));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<CourseModel>> fetchCourses() async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/courses'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => CourseModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load courses (${res.statusCode})');
  }

  Future<List<TimetableSlotModel>> fetchTimetable(String scope) async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/v1/academics/timetable?scope=$scope'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => TimetableSlotModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load timetable (${res.statusCode})');
  }

  Future<TimetableSlotModel> saveTimetableSlot(TimetableSlotModel slot) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/timetable'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(slot.toJson()),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return TimetableSlotModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to save timetable slot (${res.statusCode})');
  }

  Future<bool> deleteTimetableSlot(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/v1/academics/timetable?id=$id'),
    );
    return res.statusCode == 200 || res.statusCode == 204;
  }

  Future<List<TimetableConflictModel>> checkTimetableConflict(TimetableSlotModel slot) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/academics/timetable/check-conflict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(slot.toJson()),
      );
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List raw = data['conflicts'] ?? [];
        return raw.map((e) => TimetableConflictModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> declareDayOffBackend({
    required int dayOfWeek,
    required String scopeCode,
    required String reason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/academics/timetable/day-off'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'day_of_week': dayOfWeek,
          'scope_code': scopeCode,
          'reason': reason,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> restoreDayScheduleBackend({
    required int dayOfWeek,
    required String scopeCode,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/academics/timetable/restore-day'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'day_of_week': dayOfWeek,
          'scope_code': scopeCode,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<List<NoticeModel>> fetchNotices(List<String> scopes) async {
    final scopeParam = scopes.join(',');
    final res = await http
        .get(Uri.parse('$baseUrl/api/v1/notices?scopes=$scopeParam'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => NoticeModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load notices (${res.statusCode})');
  }

  Future<List<AttendanceSummaryModel>> fetchAttendanceSummary(
      String studentId) async {
    final res = await http.get(
        Uri.parse('$baseUrl/api/v1/attendance/summary?student_id=$studentId'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => AttendanceSummaryModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load attendance summary (${res.statusCode})');
  }

  Future<bool> pushAttendanceBatch(
      String markedByUserId, List<AttendanceSessionModel> sessions) async {
    final body = jsonEncode({
      'sessions': sessions.map((s) => s.toJson()).toList(),
    });
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/attendance/sync'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-ID': markedByUserId,
      },
      body: body,
    );
    return res.statusCode == 200;
  }

  Future<List<UserModel>> fetchUsers({
    String? archetype,
    String? status,
    String? search,
  }) async {
    final params = <String, String>{};
    if (archetype != null && archetype.isNotEmpty && archetype != 'all') {
      params['archetype'] = archetype;
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    final uri = Uri.parse('$baseUrl/api/v1/users').replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => UserModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load users (${res.statusCode})');
  }

  Future<UserModel> fetchUserProfile(String idOrHandle) async {
    final isHandle = !idOrHandle.startsWith('usr-');
    final query = isHandle ? 'handle=$idOrHandle' : 'id=$idOrHandle';
    final res = await http.get(Uri.parse('$baseUrl/api/v1/users/profile?$query'));
    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(res.body);
      final userMap = data['user'] as Map<String, dynamic>;
      // Combine aggregate data into UserModel
      return UserModel(
        id: userMap['id'] ?? '',
        campusHandle: userMap['campus_handle'] ?? '',
        firstName: userMap['first_name'] ?? '',
        lastName: userMap['last_name'] ?? '',
        email: userMap['email'] ?? '',
        personalEmail: userMap['personal_email'],
        phone: userMap['phone'],
        emergencyContactName: userMap['emergency_contact_name'],
        emergencyContactPhone: userMap['emergency_contact_phone'],
        bloodGroup: userMap['blood_group'] ?? userMap['bloodGroup'],
        address: userMap['address'],
        archetype: userMap['archetype'] ?? 'student',
        universityRollNo: userMap['university_roll_no'],
        admissionApplicationNo: userMap['admission_application_no'],
        universityRegNo: userMap['university_reg_no'],
        status: userMap['status'] ?? 'active',
        discontinuationReason: userMap['discontinuation_reason'],
        discontinuedAt: userMap['discontinued_at']?.toString(),
        discontinuedBy: userMap['discontinued_by'],
        studentProfile: data['student_profile'],
        employeeRecord: data['employee_record'],
        academicProfile: data['academic_profile'],
        administrativeProfile: data['administrative_profile'],
        activeScopes: (data['assigned_roles'] as List?)
                ?.map((r) => (r['scope_code'] ?? 'global').toString())
                .toSet()
                .toList() ??
            ['global'],
      );
    }
    throw Exception('Failed to load user profile (${res.statusCode})');
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
    final payload = <String, dynamic>{
      'user_id': userId,
    };
    if (personalEmail != null) payload['personal_email'] = personalEmail;
    if (phone != null) payload['phone'] = phone;
    if (emergencyContactName != null) payload['emergency_contact_name'] = emergencyContactName;
    if (emergencyContactPhone != null) payload['emergency_contact_phone'] = emergencyContactPhone;
    if (bloodGroup != null) payload['blood_group'] = bloodGroup;
    if (address != null) payload['address'] = address;

    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/users/profile/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      final userMap = jsonDecode(res.body) as Map<String, dynamic>;
      return UserModel.fromJson(userMap);
    }
    throw Exception('Failed to update user profile (${res.statusCode})');
  }

  Future<UserModel> createStudent(Map<String, dynamic> req) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/users/student'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(req),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return UserModel.fromJson(data['user']);
    }
    throw Exception('Failed to create student: ${res.body}');
  }

  Future<UserModel> createEmployee(Map<String, dynamic> req) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/users/employee'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(req),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return UserModel.fromJson(data['user']);
    }
    throw Exception('Failed to create employee: ${res.body}');
  }

  Future<UserModel> createContractor(Map<String, dynamic> req) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/users/contractor'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(req),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return UserModel.fromJson(data['user']);
    }
    throw Exception('Failed to create contractor: ${res.body}');
  }

  Future<UserModel> discontinueUser({
    required String userId,
    required String status,
    required String reason,
    required String discontinuedBy,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/users/discontinue'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'status': status,
        'reason': reason,
        'discontinued_by': discontinuedBy,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return UserModel.fromJson(data['user']);
    }
    throw Exception('Failed to discontinue user: ${res.body}');
  }

  Future<UserModel> reactivateUser(String userId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/users/reactivate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return UserModel.fromJson(data['user']);
    }
    throw Exception('Failed to reactivate user: ${res.body}');
  }

  @override
  Future<bool> assignUserRole({
    required String userId,
    required String roleCode,
    required String scopeCode,
    DateTime? validUntil,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/permissions/assign'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'role_code': roleCode,
        'scope_code': scopeCode,
        if (validUntil != null) 'valid_until': validUntil.toIso8601String(),
      }),
    );
    return res.statusCode == 200;
  }

  // ----------------------------------------------------
  // OPTICAL DATA TRANSFER ATTENDANCE
  // ----------------------------------------------------

  Future<OpticalSessionModel> startOpticalSession(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/attendance/optical/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return OpticalSessionModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to start optical session: ${res.body}');
  }

  Future<OpticalVerificationResult> verifyOpticalAttendance(Map<String, dynamic> req) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/attendance/optical/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(req),
    );
    if (res.statusCode == 200) {
      return OpticalVerificationResult.fromJson(jsonDecode(res.body));
    }
    final body = jsonDecode(res.body);
    throw Exception(body['message'] ?? res.body);
  }

  Future<List<AttendanceRecordModel>> fetchOpticalSessionRoster(String sessionId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/attendance/optical/roster?session_id=$sessionId'),
    );
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((e) => AttendanceRecordModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load optical roster (${res.statusCode})');
  }

  Future<void> endOpticalSession(String sessionId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/attendance/optical/end'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to conclude optical session');
    }
  }

  // ----------------------------------------------------
  // DEPARTMENTS & ACADEMIC HIERARCHY
  // ----------------------------------------------------

  Future<List<DepartmentModel>> fetchDepartments() async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/departments'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => DepartmentModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch departments (${res.statusCode})');
  }

  Future<DepartmentModel> createDepartment(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/departments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return DepartmentModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create department: ${res.body}');
  }

  Future<DepartmentDetailModel> fetchDepartmentDetail(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/departments?id=$id'));
    if (res.statusCode == 200) {
      return DepartmentDetailModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch department detail (${res.statusCode})');
  }

  Future<List<ProgramModel>> fetchPrograms() async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/programs'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => ProgramModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch programs (${res.statusCode})');
  }

  Future<List<SubjectModel>> fetchSubjects() async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/subjects'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => SubjectModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch subjects (${res.statusCode})');
  }

  Future<SubjectModel> createSubject(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/subjects'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return SubjectModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create subject: ${res.body}');
  }

  Future<List<SyllabusVersionModel>> fetchSyllabusAudit(String subjectId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/subjects/syllabus?subject_id=$subjectId'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => SyllabusVersionModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch syllabus audit (${res.statusCode})');
  }

  Future<SyllabusVersionModel> reviseSyllabus(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/subjects/syllabus'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return SyllabusVersionModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to revise syllabus: ${res.body}');
  }

  Future<List<SemesterModel>> fetchSemesters() async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/semesters'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => SemesterModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch semesters (${res.statusCode})');
  }

  Future<SemesterDetailModel> fetchSemesterDetail(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/semesters?id=$id'));
    if (res.statusCode == 200) {
      return SemesterDetailModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch semester detail (${res.statusCode})');
  }

  Future<List<UserModel>> fetchTeachers() async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/teachers'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => UserModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch teachers (${res.statusCode})');
  }

  // ----------------------------------------------------
  // CROSS-PROGRAM SECTIONS
  // ----------------------------------------------------

  Future<List<SectionModel>> fetchSections() async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/sections'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => SectionModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch sections (${res.statusCode})');
  }

  Future<SectionModel> createSection(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/sections'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return SectionModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create section: ${res.body}');
  }

  Future<SectionDetailModel> fetchSectionDetail(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/sections?id=$id'));
    if (res.statusCode == 200) {
      return SectionDetailModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch section detail (${res.statusCode})');
  }

  Future<void> assignStudentToSection({
    required String studentId,
    required String sectionId,
    required String programId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/sections/assign-student'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'student_id': studentId,
        'section_id': sectionId,
        'program_id': programId,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to assign student to section: ${res.body}');
    }
  }

  Future<void> transferStudentSection({
    required String studentId,
    required String targetSectionId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/sections/transfer-student'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'student_id': studentId,
        'target_section_id': targetSectionId,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to transfer student section: ${res.body}');
    }
  }

  Future<int> mergeSectionCohorts({
    required String sourceSectionId,
    required String targetSectionId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/sections/merge'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'source_section_id': sourceSectionId,
        'target_section_id': targetSectionId,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['students_migrated'] ?? 0;
    }
    throw Exception('Failed to merge section cohorts: ${res.body}');
  }

  // ----------------------------------------------------
  // LAB BATCHES & PRACTICALS
  // ----------------------------------------------------

  Future<List<LabBatchModel>> fetchSectionBatches(String sectionId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/sections/batches?section_id=$sectionId'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => LabBatchModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch section batches (${res.statusCode})');
  }

  Future<LabBatchModel> createLabBatch(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/sections/batches'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return LabBatchModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create lab batch: ${res.body}');
  }

  Future<List<LabBatchModel>> autoPartitionBatches(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/sections/batches/auto-partition'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      final List data = jsonDecode(res.body);
      return data.map((e) => LabBatchModel.fromJson(e)).toList();
    }
    throw Exception('Failed to auto-partition batches: ${res.body}');
  }

  Future<void> assignStudentBatch({
    required String batchId,
    required String studentId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/sections/batches/assign-student'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'batch_id': batchId,
        'student_id': studentId,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to assign student to batch: ${res.body}');
    }
  }

  // ----------------------------------------------------
  // FACULTY SUBJECT ALLOCATIONS & WORKLOAD
  // ----------------------------------------------------

  Future<List<FacultyAllocationModel>> fetchFacultyAllocations(String sectionId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/allocations?section_id=$sectionId'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => FacultyAllocationModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch faculty allocations (${res.statusCode})');
  }

  Future<FacultyAllocationModel> assignFacultyAllocation(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/academics/allocations'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return FacultyAllocationModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to assign faculty allocation: ${res.body}');
  }

  Future<void> removeFacultyAllocation(String allocationId) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/v1/academics/allocations?id=$allocationId'));
    if (res.statusCode != 200) {
      throw Exception('Failed to remove faculty allocation: ${res.body}');
    }
  }

  Future<List<FacultyWorkloadSummaryModel>> fetchFacultyWorkload({String? teacherId}) async {
    final uri = teacherId != null && teacherId.isNotEmpty
        ? Uri.parse('$baseUrl/api/v1/academics/faculty/workload?teacher_id=$teacherId')
        : Uri.parse('$baseUrl/api/v1/academics/faculty/workload');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final dynamic data = jsonDecode(res.body);
      if (data is List) {
        return data.map((e) => FacultyWorkloadSummaryModel.fromJson(e)).toList();
      } else if (data is Map<String, dynamic>) {
        return [FacultyWorkloadSummaryModel.fromJson(data)];
      }
    }
    throw Exception('Failed to fetch faculty workload (${res.statusCode})');
  }

  // ----------------------------------------------------
  // HOSTEL ROOM SYSTEM (100 - 999)
  // ----------------------------------------------------

  Future<List<HostelRoomModel>> fetchHostelRooms({int? floor}) async {
    final uri = floor != null
        ? Uri.parse('$baseUrl/api/v1/hostel/rooms?floor=$floor')
        : Uri.parse('$baseUrl/api/v1/hostel/rooms');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => HostelRoomModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch hostel rooms (${res.statusCode})');
  }

  Future<HostelRoomModel> createHostelRoom(int roomNumber, String blockName) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/hostel/rooms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'room_number': roomNumber,
        'block_name': blockName,
      }),
    );
    if (res.statusCode == 201) {
      return HostelRoomModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create hostel room: ${res.body}');
  }

  Future<HostelRoomModel> updateHostelRoom({
    required int originalRoomNumber,
    required int newRoomNumber,
    required String blockName,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/v1/hostel/rooms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'original_room_number': originalRoomNumber,
        'new_room_number': newRoomNumber,
        'block_name': blockName,
      }),
    );
    if (res.statusCode == 200) {
      return HostelRoomModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update hostel room: ${res.body}');
  }

  Future<HostelAssetModel> addHostelAsset(int roomNumber, String assetType, String serialNumber, String condition) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/hostel/rooms/assets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'room_number': roomNumber,
        'asset_type': assetType,
        'serial_number': serialNumber,
        'condition': condition,
      }),
    );
    if (res.statusCode == 201) {
      return HostelAssetModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to add asset: ${res.body}');
  }

  Future<void> removeHostelAsset(int roomNumber, String assetId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/v1/hostel/rooms/assets?room_number=$roomNumber&asset_id=$assetId'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to remove asset: ${res.body}');
    }
  }

  Future<HostelAssetModel> updateHostelAsset({
    required int roomNumber,
    required String assetId,
    required String serialNumber,
    required String condition,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/v1/hostel/rooms/assets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'room_number': roomNumber,
        'asset_id': assetId,
        'serial_number': serialNumber,
        'condition': condition,
      }),
    );
    if (res.statusCode == 200) {
      return HostelAssetModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update asset: ${res.body}');
  }

  Future<HostelOccupantModel> assignHostelOccupant(int roomNumber, String userId, String handle, String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/hostel/rooms/occupants'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'room_number': roomNumber,
        'user_id': userId,
        'campus_handle': handle,
        'name': name,
      }),
    );
    if (res.statusCode == 201) {
      return HostelOccupantModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to assign occupant: ${res.body}');
  }

  Future<void> removeHostelOccupant(int roomNumber, String userId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/v1/hostel/rooms/occupants?room_number=$roomNumber&user_id=$userId'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to remove occupant: ${res.body}');
    }
  }

  // ----------------------------------------------------
  // MESS OPERATIONS (TIMETABLE, SUNDAY BRUNCH, RATINGS)
  // ----------------------------------------------------

  Future<List<MessMealModel>> fetchMessTimetable() async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/mess/timetable'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => MessMealModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch mess timetable (${res.statusCode})');
  }

  Future<MessMealModel> updateMessMeal(MessMealModel meal) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/v1/mess/meals'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(meal.toJson()),
    );
    if (res.statusCode == 200) {
      return MessMealModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update mess meal: ${res.body}');
  }

  Future<MessReportSummary> fetchMessRatingsReport({String? mealId, String? rating}) async {
    final queryParams = <String, String>{};
    if (mealId != null && mealId.isNotEmpty) queryParams['meal_id'] = mealId;
    if (rating != null && rating.isNotEmpty) queryParams['rating'] = rating;

    final uri = Uri.parse('$baseUrl/api/v1/mess/ratings').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return MessReportSummary.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch mess ratings report (${res.statusCode})');
  }

  Future<MessRatingModel> submitMessRating({
    required String mealId,
    required String userId,
    required String userName,
    required String campusHandle,
    required String rating,
    required String message,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/mess/ratings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'meal_id': mealId,
        'user_id': userId,
        'user_name': userName,
        'campus_handle': campusHandle,
        'rating': rating,
        'message': message,
      }),
    );
    if (res.statusCode == 201) {
      return MessRatingModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to submit mess rating: ${res.body}');
  }

  // ----------------------------------------------------
  // GRIEVANCES & COMPLAINTS SYSTEM
  // ----------------------------------------------------

  @override
  Future<List<ComplaintModel>> fetchComplaints({
    String? category,
    String? status,
    String? submittedBy,
    String? viewerId,
    List<String>? allowedCategories,
    bool? isDispute,
    String? disputeTargetType,
  }) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (submittedBy != null && submittedBy.isNotEmpty) queryParams['submitted_by'] = submittedBy;
    if (viewerId != null && viewerId.isNotEmpty) queryParams['viewer_id'] = viewerId;
    if (allowedCategories != null && allowedCategories.isNotEmpty) {
      queryParams['allowed_categories'] = allowedCategories.join(',');
    }
    if (isDispute != null) queryParams['is_dispute'] = isDispute ? 'true' : 'false';
    if (disputeTargetType != null && disputeTargetType.isNotEmpty) {
      queryParams['dispute_target_type'] = disputeTargetType;
    }

    final uri = Uri.parse('$baseUrl/api/v1/complaints').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => ComplaintModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch complaints: ${res.statusCode}');
  }

  @override
  Future<ComplaintModel> createComplaint(ComplaintModel complaint) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/complaints'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(complaint.toJson()),
    );
    if (res.statusCode == 201) {
      return ComplaintModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create complaint: ${res.body}');
  }

  @override
  Future<ComplaintModel> raiseDispute(ComplaintModel dispute) async {
    return createComplaint(dispute.copyWith(isDispute: true));
  }

  @override
  Future<List<ComplaintModel>> getDisputes({
    String? targetType,
    String? status,
    String? submittedBy,
    String? viewerId,
  }) async {
    return fetchComplaints(
      isDispute: true,
      disputeTargetType: targetType,
      status: status,
      submittedBy: submittedBy,
      viewerId: viewerId,
    );
  }

  @override
  Future<ComplaintModel> updateComplaintStatus({
    required String complaintId,
    required String status,
    required String remarks,
    required String resolvedBy,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/v1/complaints/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'complaint_id': complaintId,
        'status': status,
        'remarks': remarks,
        'resolved_by': resolvedBy,
      }),
    );
    if (res.statusCode == 200) {
      return ComplaintModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update complaint status: ${res.body}');
  }

  // ----------------------------------------------------
  // INSTITUTIONAL FEES & FINES SUBSYSTEM
  // ----------------------------------------------------

  @override
  Future<FeeSummaryModel> getFeeSummary(String studentId) => fetchFeeSummary(studentId);

  Future<FeeSummaryModel> fetchFeeSummary(String studentId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/fees/summary?student_id=$studentId'));
    if (res.statusCode == 200) {
      return FeeSummaryModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch fee summary: ${res.statusCode}');
  }

  @override
  Future<List<FeeInvoiceModel>> getInvoices({String? studentId, String? status}) =>
      fetchInvoices(studentId: studentId, status: status);

  Future<List<FeeInvoiceModel>> fetchInvoices({String? studentId, String? status}) async {
    final queryParams = <String, String>{};
    if (studentId != null && studentId.isNotEmpty) queryParams['student_id'] = studentId;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse('$baseUrl/api/v1/fees/invoices').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => FeeInvoiceModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch invoices: ${res.statusCode}');
  }

  @override
  Future<FeeInvoiceModel?> getInvoiceById(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/fees/invoices?id=$id'));
    if (res.statusCode == 200) {
      return FeeInvoiceModel.fromJson(jsonDecode(res.body));
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> payInvoice({
    required String invoiceId,
    required String studentId,
    required double amount,
    required String paymentMethod,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/fees/pay'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'invoice_id': invoiceId,
        'student_id': studentId,
        'amount': amount,
        'payment_method': paymentMethod,
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to pay invoice: ${res.body}');
  }

  @override
  Future<List<FineRecordModel>> getFines({String? studentId, String? status}) =>
      fetchFines(studentId: studentId, status: status);

  Future<List<FineRecordModel>> fetchFines({String? studentId, String? status}) async {
    final queryParams = <String, String>{};
    if (studentId != null && studentId.isNotEmpty) queryParams['student_id'] = studentId;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse('$baseUrl/api/v1/fees/fines').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => FineRecordModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch fines: ${res.statusCode}');
  }

  @override
  Future<Map<String, dynamic>> payFine({
    required String fineId,
    required String studentId,
    required String paymentMethod,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/fees/fines/pay'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fine_id': fineId,
        'student_id': studentId,
        'payment_method': paymentMethod,
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to pay fine: ${res.body}');
  }

  @override
  Future<FineRecordModel> appealFine({
    required String fineId,
    required String reason,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/fees/fines/appeal'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fine_id': fineId,
        'reason': reason,
      }),
    );
    if (res.statusCode == 200) {
      return FineRecordModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to appeal fine: ${res.body}');
  }

  @override
  Future<FineRecordModel> waiveFine({
    required String fineId,
    required String waivedBy,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/fees/fines/waive'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fine_id': fineId,
        'waived_by': waivedBy,
      }),
    );
    if (res.statusCode == 200) {
      return FineRecordModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to waive fine: ${res.body}');
  }

  @override
  Future<List<FeePaymentModel>> getFeePayments(String studentId) => fetchFeePayments(studentId);

  Future<List<FeePaymentModel>> fetchFeePayments(String studentId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/fees/payments?student_id=$studentId'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => FeePaymentModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch payments: ${res.statusCode}');
  }

  @override
  Future<FeeReceiptModel> getFeeReceipt(String receiptNumber) => fetchReceipt(receiptNumber);

  Future<FeeReceiptModel> fetchReceipt(String receiptNumber) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/fees/receipt?receipt_number=$receiptNumber'));
    if (res.statusCode == 200) {
      return FeeReceiptModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch receipt: ${res.statusCode}');
  }

  @override
  Future<List<int>> downloadInvoicePdf(String invoiceId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/fees/invoices/pdf?id=$invoiceId'));
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    throw Exception('Failed to download invoice PDF (${res.statusCode}): ${res.body}');
  }

  @override
  Future<List<int>> downloadReceiptPdf(String receiptNumber) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/fees/receipts/pdf?number=$receiptNumber'));
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    throw Exception('Failed to download receipt PDF (${res.statusCode}): ${res.body}');
  }

  @override
  Future<PaymentGatewayConfigModel> getPaymentConfig() async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/payments/config'));
    if (res.statusCode == 200) {
      return PaymentGatewayConfigModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to get payment config (${res.statusCode}): ${res.body}');
  }

  @override
  Future<PaymentOrderModel> createPaymentOrder({
    required String entityType,
    required String entityId,
    required String studentId,
    required double amount,
    String notes = '',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/payments/order'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'entity_type': entityType,
        'entity_id': entityId,
        'student_id': studentId,
        'amount': amount,
        'notes': notes,
      }),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return PaymentOrderModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create payment order (${res.statusCode}): ${res.body}');
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
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/payments/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'order_id': orderId,
        'payment_id': paymentId,
        'payment_method': paymentMethod,
        'transaction_ref': ?transactionRef,
        'signature': ?signature,
        'utr_number': ?utrNumber,
        'bank_name': ?bankName,
        'upi_vpa': ?upiVpa,
        'card_last4': ?cardLast4,
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to verify payment (${res.statusCode}): ${res.body}');
  }

  // Institutional Library Subsystem
  @override
  Future<LibrarySummaryModel> getLibrarySummary(String studentId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/library/summary?student_id=$studentId'));
    if (res.statusCode == 200) {
      return LibrarySummaryModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to get library summary (${res.statusCode}): ${res.body}');
  }

  @override
  Future<List<PhysicalBookModel>> getPhysicalBooks({String? query, String? category}) async {
    final uri = Uri.parse('$baseUrl/api/v1/library/books').replace(queryParameters: {
      if (query != null && query.isNotEmpty) 'q': query,
      if (category != null && category.isNotEmpty && category != 'All Categories') 'category': category,
    });
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((e) => PhysicalBookModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to get physical books (${res.statusCode}): ${res.body}');
  }

  @override
  Future<PhysicalBookModel?> getBookById(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/library/books?id=$id'));
    if (res.statusCode == 200) {
      return PhysicalBookModel.fromJson(jsonDecode(res.body));
    }
    return null;
  }

  @override
  Future<List<BorrowRecordModel>> getBorrowRecords({String? studentId, String? status}) async {
    final uri = Uri.parse('$baseUrl/api/v1/library/borrows').replace(queryParameters: {
      if (studentId != null && studentId.isNotEmpty) 'student_id': studentId,
      if (status != null && status.isNotEmpty && status != 'all') 'status': status,
    });
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((e) => BorrowRecordModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to get borrow records (${res.statusCode}): ${res.body}');
  }

  @override
  Future<BorrowRecordModel> borrowBook({
    required String studentId,
    required String bookId,
    String? approvedBy,
    String? approvedByName,
  }) async {
    final payload = <String, dynamic>{
      'student_id': studentId,
      'book_id': bookId,
    };
    if (approvedBy != null) payload['approved_by'] = approvedBy;
    if (approvedByName != null) payload['approved_by_name'] = approvedByName;

    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/borrow'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return BorrowRecordModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to borrow book');
  }

  @override
  Future<BorrowRecordModel> approveBorrowRequest({
    required String borrowId,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  }) async {
    final payload = <String, dynamic>{
      'borrow_id': borrowId,
      'approved_by': approvedBy,
      'approved_by_name': approvedByName,
    };
    if (remarks != null) payload['remarks'] = remarks;

    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/borrow/approve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return BorrowRecordModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to approve borrow request');
  }

  @override
  Future<BorrowRecordModel> rejectBorrowRequest({
    required String borrowId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/borrow/reject'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'borrow_id': borrowId,
        'rejected_by': rejectedBy,
        'rejection_reason': rejectionReason,
      }),
    );
    if (res.statusCode == 200) {
      return BorrowRecordModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to reject borrow request');
  }

  @override
  Future<BorrowRecordModel> returnBook({
    required String borrowId,
    required String studentId,
    String? approvedBy,
    String? approvedByName,
  }) async {
    final payload = <String, dynamic>{
      'borrow_id': borrowId,
      'student_id': studentId,
    };
    if (approvedBy != null) payload['approved_by'] = approvedBy;
    if (approvedByName != null) payload['approved_by_name'] = approvedByName;

    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/return'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return BorrowRecordModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to return book');
  }

  @override
  Future<BorrowRecordModel> approveReturnRequest({
    required String borrowId,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  }) async {
    final payload = <String, dynamic>{
      'borrow_id': borrowId,
      'approved_by': approvedBy,
      'approved_by_name': approvedByName,
    };
    if (remarks != null) payload['remarks'] = remarks;

    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/return/approve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return BorrowRecordModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to approve return request');
  }

  @override
  Future<BorrowRecordModel> rejectReturnRequest({
    required String borrowId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/return/reject'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'borrow_id': borrowId,
        'rejected_by': rejectedBy,
        'rejection_reason': rejectionReason,
      }),
    );
    if (res.statusCode == 200) {
      return BorrowRecordModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to reject return request');
  }

  @override
  Future<BorrowRecordModel> renewBook({
    required String borrowId,
    required String studentId,
    String? approvedBy,
    String? approvedByName,
  }) async {
    final payload = <String, dynamic>{
      'borrow_id': borrowId,
      'student_id': studentId,
    };
    if (approvedBy != null) payload['approved_by'] = approvedBy;
    if (approvedByName != null) payload['approved_by_name'] = approvedByName;

    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/renew'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return BorrowRecordModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to renew book');
  }

  @override
  Future<BorrowRecordModel> approveRenewalRequest({
    required String borrowId,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  }) async {
    final payload = <String, dynamic>{
      'borrow_id': borrowId,
      'approved_by': approvedBy,
      'approved_by_name': approvedByName,
    };
    if (remarks != null) payload['remarks'] = remarks;

    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/renew/approve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return BorrowRecordModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to approve renewal request');
  }

  @override
  Future<BorrowRecordModel> rejectRenewalRequest({
    required String borrowId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/renew/reject'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'borrow_id': borrowId,
        'rejected_by': rejectedBy,
        'rejection_reason': rejectionReason,
      }),
    );
    if (res.statusCode == 200) {
      return BorrowRecordModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to reject renewal request');
  }

  @override
  Future<List<EBookModel>> getEBooks({String? query, String? category}) async {
    final uri = Uri.parse('$baseUrl/api/v1/library/ebooks').replace(queryParameters: {
      if (query != null && query.isNotEmpty) 'q': query,
      if (category != null && category.isNotEmpty && category != 'All Categories') 'category': category,
    });
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((e) => EBookModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to get e-books (${res.statusCode}): ${res.body}');
  }

  @override
  Future<PhysicalBookModel> createPhysicalBook(PhysicalBookModel book) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/books'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(book.toJson()),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return PhysicalBookModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to add physical book');
  }

  @override
  Future<void> deletePhysicalBook(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/v1/library/books?id=$id'));
    if (res.statusCode == 200 || res.statusCode == 204) {
      return;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to remove physical book');
  }

  @override
  Future<Map<String, dynamic>> uploadPdfDocument({
    required List<int> bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/upload/pdf');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['error'] ?? 'Failed to upload PDF file (${response.statusCode})');
  }

  @override
  Future<List<int>> downloadPdfDocument(String fileId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/uploads?id=$fileId'));
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    throw Exception('Failed to download PDF document ($fileId): status ${res.statusCode}');
  }

  @override
  Future<List<int>> downloadEBookPdf(String ebookId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/library/ebooks/$ebookId/download'));
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    // Fallback: try direct uploads endpoint
    return await downloadPdfDocument(ebookId);
  }

  @override
  Future<EBookModel> createEBook(EBookModel ebook) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/ebooks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(ebook.toJson()),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return EBookModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to add e-book');
  }

  @override
  Future<EBookModel> approveEBook({
    required String ebookId,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  }) async {
    final payload = <String, dynamic>{
      'ebook_id': ebookId,
      'approved_by': approvedBy,
      'approved_by_name': approvedByName,
    };
    if (remarks != null) {
      payload['remarks'] = remarks;
    }
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/ebooks/approve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return EBookModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to approve e-book');
  }

  @override
  Future<EBookModel> rejectEBook({
    required String ebookId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    final payload = <String, dynamic>{
      'ebook_id': ebookId,
      'rejected_by': rejectedBy,
      'rejection_reason': rejectionReason,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/library/ebooks/reject'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return EBookModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to reject e-book');
  }

  @override
  Future<void> deleteEBook(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/v1/library/ebooks?id=$id'));
    if (res.statusCode == 200 || res.statusCode == 204) {
      return;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to remove e-book');
  }

  // AKTU Sessional & Continuous Assessment Subsystem
  @override
  Future<List<InternalAssessmentModel>> fetchSessionalRecords({
    String? studentId,
    String? subjectCode,
    int? semester,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/sessional/records').replace(queryParameters: {
      if (studentId != null && studentId.isNotEmpty) 'student_id': studentId,
      if (subjectCode != null && subjectCode.isNotEmpty) 'subject_code': subjectCode,
      if (semester != null && semester > 0) 'semester': semester.toString(),
    });
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((e) => InternalAssessmentModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch sessional records (${res.statusCode}): ${res.body}');
  }

  @override
  Future<InternalAssessmentModel> updateSessionalMarks(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/sessional/marks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return InternalAssessmentModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to update sessional marks');
  }

  @override
  Future<AKTUInternalAwardListModel> freezeSessionalMarks(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/sessional/freeze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return AKTUInternalAwardListModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to freeze marks');
  }

  @override
  Future<List<SessionalScheduleModel>> fetchSessionalSchedules({
    int? semester,
    String? examType,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/sessional/schedule').replace(queryParameters: {
      if (semester != null && semester > 0) 'semester': semester.toString(),
      if (examType != null && examType.isNotEmpty) 'exam_type': examType,
    });
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((e) => SessionalScheduleModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch sessional schedules (${res.statusCode}): ${res.body}');
  }

  @override
  Future<List<DeskSeatingModel>> fetchSeatingLayout({
    String? hallNumber,
    String? examType,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/sessional/seating').replace(queryParameters: {
      if (hallNumber != null && hallNumber.isNotEmpty) 'hall_number': hallNumber,
      if (examType != null && examType.isNotEmpty) 'exam_type': examType,
    });
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((e) => DeskSeatingModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch seating layout (${res.statusCode}): ${res.body}');
  }

  @override
  Future<AKTUInternalAwardListModel> fetchAwardList({
    required String subjectCode,
    int? semester,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/sessional/award-list').replace(queryParameters: {
      'subject_code': subjectCode,
      if (semester != null && semester > 0) 'semester': semester.toString(),
    });
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return AKTUInternalAwardListModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch award list (${res.statusCode}): ${res.body}');
  }

  @override
  Future<UserModel> syncDigiLocker(String userId) async {
    return fetchUserProfile(userId);
  }

  @override
  Future<DigiLockerAuthResponse> getDigiLockerAuthUrl({
    required String studentId,
    String? redirectUri,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/digilocker/auth-url').replace(queryParameters: {
      'student_id': studentId,
      if (redirectUri != null && redirectUri.isNotEmpty) 'redirect_uri': redirectUri,
    });
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return DigiLockerAuthResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to get DigiLocker auth URL (${res.statusCode}): ${res.body}');
  }

  @override
  Future<UserModel> exchangeDigiLockerToken({
    required String studentId,
    required String code,
    required String state,
    required String codeVerifier,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/digilocker/exchange'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'student_id': studentId,
        'code': code,
        'state': state,
        'code_verifier': codeVerifier,
      }),
    );
    if (res.statusCode == 200) {
      return fetchUserProfile(studentId);
    }
    final err = jsonDecode(res.body);
    throw Exception(err['error'] ?? 'Failed to exchange DigiLocker token');
  }

  @override
  Future<DigiLockerStatusModel> getDigiLockerStatus({required String studentId}) async {
    final uri = Uri.parse('$baseUrl/api/v1/digilocker/status').replace(queryParameters: {
      'student_id': studentId,
    });
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return DigiLockerStatusModel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to get DigiLocker status (${res.statusCode}): ${res.body}');
  }

  @override
  Future<UserModel> disconnectDigiLocker({required String studentId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/digilocker/disconnect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'student_id': studentId}),
    );
    if (res.statusCode == 200) {
      return fetchUserProfile(studentId);
    }
    throw Exception('Failed to disconnect DigiLocker: ${res.body}');
  }
}
