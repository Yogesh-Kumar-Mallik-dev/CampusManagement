import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/academic.dart';
import '../models/user.dart';

class ApiService {
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

      return UserModel(
        id: userMap['id'] ?? 'usr-$identifier',
        campusHandle: userMap['campus_handle'] ?? identifier,
        firstName: userMap['first_name'] ?? 'Campus',
        lastName: userMap['last_name'] ?? 'User',
        email: userMap['email'] ?? '$identifier@campus.edu',
        archetype: userMap['archetype'] ?? 'student',
        activeScopes: scopes,
      );
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
}
