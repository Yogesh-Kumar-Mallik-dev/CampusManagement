import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/academic.dart';
import '../models/complaint.dart';
import '../models/hostel.dart';
import '../models/mess.dart';
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

  Future<List<ComplaintModel>> fetchComplaints({
    String? category,
    String? status,
    String? submittedBy,
    String? viewerId,
    List<String>? allowedCategories,
  }) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (submittedBy != null && submittedBy.isNotEmpty) queryParams['submitted_by'] = submittedBy;
    if (viewerId != null && viewerId.isNotEmpty) queryParams['viewer_id'] = viewerId;
    if (allowedCategories != null && allowedCategories.isNotEmpty) {
      queryParams['allowed_categories'] = allowedCategories.join(',');
    }

    final uri = Uri.parse('$baseUrl/api/v1/complaints').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => ComplaintModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch complaints: ${res.statusCode}');
  }

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
}
