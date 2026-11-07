import 'dart:convert';
import 'user.dart';

class CourseModel {
  final String id;
  final String code;
  final String name;
  final int credits;
  final int semester;

  CourseModel({
    required this.id,
    required this.code,
    required this.name,
    required this.credits,
    required this.semester,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      credits: json['credits'] ?? 3,
      semester: json['semester'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'credits': credits,
        'semester': semester,
      };
}

class TimetableSlotModel {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String scopeCode;
  final String instructorName;
  final int dayOfWeek; // 1 = Monday ... 7 = Sunday
  final String startTime;
  final String endTime;
  final String roomNumber;
  final String slotType; // 'lecture', 'lab', 'tutorial', 'free', 'off'

  TimetableSlotModel({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.scopeCode,
    required this.instructorName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.roomNumber,
    required this.slotType,
  });

  bool get isFree => slotType.toLowerCase() == 'free';
  bool get isOff => slotType.toLowerCase() == 'off';
  bool get isOccupied => !isFree && !isOff && (courseCode.isNotEmpty || courseName.isNotEmpty);

  TimetableSlotModel copyWith({
    String? id,
    String? courseId,
    String? courseCode,
    String? courseName,
    String? scopeCode,
    String? instructorName,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? roomNumber,
    String? slotType,
  }) {
    return TimetableSlotModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      scopeCode: scopeCode ?? this.scopeCode,
      instructorName: instructorName ?? this.instructorName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      roomNumber: roomNumber ?? this.roomNumber,
      slotType: slotType ?? this.slotType,
    );
  }

  String get dayName {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Day $dayOfWeek';
    }
  }

  factory TimetableSlotModel.fromJson(Map<String, dynamic> json) {
    return TimetableSlotModel(
      id: json['id'] ?? '',
      courseId: json['course_id'] ?? '',
      courseCode: json['course_code'] ?? '',
      courseName: json['course_name'] ?? '',
      scopeCode: json['scope_code'] ?? '',
      instructorName: json['instructor_name'] ?? '',
      dayOfWeek: json['day_of_week'] ?? 1,
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      roomNumber: json['room_number'] ?? '',
      slotType: json['slot_type'] ?? 'lecture',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'course_id': courseId,
        'course_code': courseCode,
        'course_name': courseName,
        'scope_code': scopeCode,
        'instructor_name': instructorName,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'room_number': roomNumber,
        'slot_type': slotType,
      };
}

class TimetableConflictModel {
  final String type; // 'room', 'instructor', 'section'
  final String message;
  final TimetableSlotModel conflictingSlot;

  TimetableConflictModel({
    required this.type,
    required this.message,
    required this.conflictingSlot,
  });

  factory TimetableConflictModel.fromJson(Map<String, dynamic> json) {
    return TimetableConflictModel(
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      conflictingSlot: TimetableSlotModel.fromJson(
        Map<String, dynamic>.from(json['conflicting_slot'] ?? {}),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
        'conflicting_slot': conflictingSlot.toJson(),
      };
}

class AttendanceRecordModel {
  final String id;
  final String sessionId;
  final String studentId;
  final String studentName;
  final String campusHandle;
  String status; // 'present', 'absent', 'late', 'excused'
  final String remarks;

  AttendanceRecordModel({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.campusHandle,
    required this.status,
    this.remarks = '',
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id'] ?? '',
      sessionId: json['session_id'] ?? '',
      studentId: json['student_id'] ?? '',
      studentName: json['student_name'] ?? '',
      campusHandle: json['campus_handle'] ?? '',
      status: json['status'] ?? 'present',
      remarks: json['remarks'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'student_id': studentId,
        'student_name': studentName,
        'campus_handle': campusHandle,
        'status': status,
        'remarks': remarks,
      };
}

class AttendanceSessionModel {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String scopeCode;
  final String sessionDate;
  final String topic;
  final List<AttendanceRecordModel> records;

  AttendanceSessionModel({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.scopeCode,
    required this.sessionDate,
    required this.topic,
    required this.records,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['records'] as List? ?? [];
    return AttendanceSessionModel(
      id: json['id'] ?? '',
      courseId: json['course_id'] ?? '',
      courseCode: json['course_code'] ?? '',
      courseName: json['course_name'] ?? '',
      scopeCode: json['scope_code'] ?? '',
      sessionDate: json['session_date'] ?? '',
      topic: json['topic'] ?? '',
      records: rawList.map((r) => AttendanceRecordModel.fromJson(r)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'course_id': courseId,
        'course_code': courseCode,
        'course_name': courseName,
        'scope_code': scopeCode,
        'session_date': sessionDate,
        'topic': topic,
        'records': records.map((r) => r.toJson()).toList(),
      };
}

class AttendanceSummaryModel {
  final String courseId;
  final String courseCode;
  final String courseName;
  final int totalSessions;
  final int attended;
  final double percentage;

  AttendanceSummaryModel({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.totalSessions,
    required this.attended,
    required this.percentage,
  });

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSummaryModel(
      courseId: json['course_id'] ?? '',
      courseCode: json['course_code'] ?? '',
      courseName: json['course_name'] ?? '',
      totalSessions: json['total_sessions'] ?? 0,
      attended: json['attended'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NoticeModel {
  final String id;
  final String title;
  final String content;
  final String category;
  final String targetScopeCode;
  final String priority;
  final DateTime publishedAt;

  NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.targetScopeCode,
    required this.priority,
    required this.publishedAt,
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? 'general',
      targetScopeCode: json['target_scope_code'] ?? 'global',
      priority: json['priority'] ?? 'normal',
      publishedAt: DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'category': category,
        'target_scope_code': targetScopeCode,
        'priority': priority,
        'published_at': publishedAt.toIso8601String(),
      };
}

class OpticalSessionModel {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String scopeCode;
  final String roomNumber;
  final String markedByUserId;
  final String markedByName;
  final String sessionSecret;
  final int refreshIntervalMs;
  final DateTime startedAt;
  final DateTime expiresAt;
  final bool isActive;
  final List<AttendanceRecordModel> verifiedRecords;

  OpticalSessionModel({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.scopeCode,
    required this.roomNumber,
    required this.markedByUserId,
    required this.markedByName,
    required this.sessionSecret,
    this.refreshIntervalMs = 1500,
    required this.startedAt,
    required this.expiresAt,
    this.isActive = true,
    this.verifiedRecords = const [],
  });

  factory OpticalSessionModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['verified_records'] as List? ?? [];
    return OpticalSessionModel(
      id: json['id'] ?? '',
      courseId: json['course_id'] ?? '',
      courseCode: json['course_code'] ?? '',
      courseName: json['course_name'] ?? '',
      scopeCode: json['scope_code'] ?? '',
      roomNumber: json['room_number'] ?? '',
      markedByUserId: json['marked_by_user_id'] ?? '',
      markedByName: json['marked_by_name'] ?? '',
      sessionSecret: json['session_secret'] ?? '',
      refreshIntervalMs: json['refresh_interval_ms'] ?? 1500,
      startedAt: DateTime.tryParse(json['started_at'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? DateTime.now().add(const Duration(hours: 2)),
      isActive: json['is_active'] ?? true,
      verifiedRecords: rawList.map((e) => AttendanceRecordModel.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'course_id': courseId,
        'course_code': courseCode,
        'course_name': courseName,
        'scope_code': scopeCode,
        'room_number': roomNumber,
        'marked_by_user_id': markedByUserId,
        'marked_by_name': markedByName,
        'session_secret': sessionSecret,
        'refresh_interval_ms': refreshIntervalMs,
        'started_at': startedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_active': isActive,
        'verified_records': verifiedRecords.map((r) => r.toJson()).toList(),
      };
}

class OpticalFramePacket {
  final String sessionId;
  final String courseCode;
  final String courseName;
  final String room;
  final int sequence;
  final int timestamp;
  final String nonce;
  final String signature;

  OpticalFramePacket({
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.room,
    required this.sequence,
    required this.timestamp,
    required this.nonce,
    required this.signature,
  });

  String encode() {
    final payload = {
      't': 'OPT',
      'sid': sessionId,
      'cc': courseCode,
      'cn': courseName,
      'rm': room,
      'seq': sequence,
      'ts': timestamp,
      'nc': nonce,
      'sig': signature.length > 16 ? signature.substring(0, 16) : signature,
    };
    final jsonStr = jsonEncode(payload);
    return 'CPOS:OPT:${base64Url.encode(utf8.encode(jsonStr))}';
  }

  static OpticalFramePacket? decode(String raw) {
    try {
      if (!raw.startsWith('CPOS:OPT:')) return null;
      final b64 = raw.substring('CPOS:OPT:'.length);
      final jsonStr = utf8.decode(base64Url.decode(b64));
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return OpticalFramePacket(
        sessionId: map['sid'] ?? '',
        courseCode: map['cc'] ?? '',
        courseName: map['cn'] ?? '',
        room: map['rm'] ?? '',
        sequence: map['seq'] ?? 0,
        timestamp: map['ts'] ?? 0,
        nonce: map['nc'] ?? '',
        signature: map['sig'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  bool isExpired({int maxAgeSeconds = 6}) {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = nowSeconds - timestamp;
    return diff > maxAgeSeconds || diff < -3;
  }
}

class OpticalVerificationResult {
  final bool verified;
  final String message;
  final String sessionId;
  final String courseCode;
  final String courseName;
  final String studentName;
  final String handle;
  final int sequence;
  final DateTime recordedAt;

  OpticalVerificationResult({
    required this.verified,
    required this.message,
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.studentName,
    required this.handle,
    required this.sequence,
    required this.recordedAt,
  });

  factory OpticalVerificationResult.fromJson(Map<String, dynamic> json) {
    return OpticalVerificationResult(
      verified: json['verified'] ?? false,
      message: json['message'] ?? '',
      sessionId: json['session_id'] ?? '',
      courseCode: json['course_code'] ?? '',
      courseName: json['course_name'] ?? '',
      studentName: json['student_name'] ?? '',
      handle: json['campus_handle'] ?? '',
      sequence: json['sequence'] ?? 0,
      recordedAt: DateTime.tryParse(json['recorded_at'] ?? '') ?? DateTime.now(),
    );
  }
}


// -----------------------------------------------------------------------------
// DEPARTMENTS & ACADEMIC HIERARCHY (M:N and N:1)
// -----------------------------------------------------------------------------

class DepartmentModel {
  final String id;
  final String code;
  final String name;
  final String description;
  final String? hodId;
  final String? hodName;
  final List<String> subjectIds;
  final List<String> teacherIds;
  final List<String> semesterIds;
  final int subjectCount;
  final int teacherCount;
  final int semesterCount;

  DepartmentModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    this.hodId,
    this.hodName,
    this.subjectIds = const [],
    this.teacherIds = const [],
    this.semesterIds = const [],
    this.subjectCount = 0,
    this.teacherCount = 0,
    this.semesterCount = 0,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      hodId: json['hod_id'],
      hodName: json['hod_name'],
      subjectIds: (json['subject_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      teacherIds: (json['teacher_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      semesterIds: (json['semester_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      subjectCount: json['subject_count'] ?? 0,
      teacherCount: json['teacher_count'] ?? 0,
      semesterCount: json['semester_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        if (hodId != null) 'hod_id': hodId,
        if (hodName != null) 'hod_name': hodName,
        'subject_ids': subjectIds,
        'teacher_ids': teacherIds,
        'semester_ids': semesterIds,
        'subject_count': subjectCount,
        'teacher_count': teacherCount,
        'semester_count': semesterCount,
      };
}

class ProgramModel {
  final String id;
  final String code;
  final String name;
  final String degreeLevel;
  final int totalSemesters;

  ProgramModel({
    required this.id,
    required this.code,
    required this.name,
    required this.degreeLevel,
    required this.totalSemesters,
  });

  factory ProgramModel.fromJson(Map<String, dynamic> json) {
    return ProgramModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      degreeLevel: json['degree_level'] ?? 'undergraduate',
      totalSemesters: json['total_semesters'] ?? 8,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'degree_level': degreeLevel,
        'total_semesters': totalSemesters,
      };
}

class SyllabusVersionModel {
  final String id;
  final String subjectId;
  final String revisionCode;
  final String effectiveFromYear;
  final String? effectiveToYear;
  final bool isActive;
  final String content;
  final String? changeSummary;
  final String? approvedBy;
  final String? approvedAt;
  final DateTime? createdAt;

  SyllabusVersionModel({
    required this.id,
    required this.subjectId,
    required this.revisionCode,
    required this.effectiveFromYear,
    this.effectiveToYear,
    required this.isActive,
    required this.content,
    this.changeSummary,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
  });

  factory SyllabusVersionModel.fromJson(Map<String, dynamic> json) {
    return SyllabusVersionModel(
      id: json['id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      revisionCode: json['revision_code'] ?? '',
      effectiveFromYear: json['effective_from_year'] ?? '',
      effectiveToYear: json['effective_to_year'],
      isActive: json['is_active'] ?? false,
      content: json['content'] ?? '',
      changeSummary: json['change_summary'],
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'revision_code': revisionCode,
        'effective_from_year': effectiveFromYear,
        'effective_to_year': effectiveToYear,
        'is_active': isActive,
        'content': content,
        'change_summary': changeSummary,
        'approved_by': approvedBy,
        'approved_at': approvedAt,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

class SubjectModel {
  final String id;
  final String code;
  final String? oddSemCode;
  final String? evenSemCode;
  final String name;
  final int credits;
  final List<String> departmentIds;
  final SyllabusVersionModel? activeSyllabus;

  SubjectModel({
    required this.id,
    required this.code,
    this.oddSemCode,
    this.evenSemCode,
    required this.name,
    required this.credits,
    this.departmentIds = const [],
    this.activeSyllabus,
  });

  String resolveCode(int semNumber) {
    if (semNumber % 2 == 1 && oddSemCode != null && oddSemCode!.trim().isNotEmpty) {
      return oddSemCode!;
    }
    if (semNumber % 2 == 0 && evenSemCode != null && evenSemCode!.trim().isNotEmpty) {
      return evenSemCode!;
    }
    return code;
  }

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      oddSemCode: json['odd_sem_code'],
      evenSemCode: json['even_sem_code'],
      name: json['name'] ?? '',
      credits: json['credits'] ?? 3,
      departmentIds: (json['department_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      activeSyllabus: json['active_syllabus'] != null
          ? SyllabusVersionModel.fromJson(json['active_syllabus'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'odd_sem_code': oddSemCode,
        'even_sem_code': evenSemCode,
        'name': name,
        'credits': credits,
        'department_ids': departmentIds,
        if (activeSyllabus != null) 'active_syllabus': activeSyllabus!.toJson(),
      };
}

class SemesterModel {
  final String id;
  final String programId;
  final String programCode;
  final String programName;
  final int semesterNumber;
  final String academicYear;
  final String section;
  final String displayName;
  final List<String> subjectIds;
  final List<String> teacherIds;
  final int studentCount;

  SemesterModel({
    required this.id,
    required this.programId,
    required this.programCode,
    required this.programName,
    required this.semesterNumber,
    required this.academicYear,
    required this.section,
    required this.displayName,
    this.subjectIds = const [],
    this.teacherIds = const [],
    this.studentCount = 0,
  });

  factory SemesterModel.fromJson(Map<String, dynamic> json) {
    return SemesterModel(
      id: json['id'] ?? '',
      programId: json['program_id'] ?? '',
      programCode: json['program_code'] ?? '',
      programName: json['program_name'] ?? '',
      semesterNumber: json['semester_number'] ?? 1,
      academicYear: json['academic_year'] ?? '',
      section: json['section'] ?? '',
      displayName: json['display_name'] ?? '',
      subjectIds: (json['subject_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      teacherIds: (json['teacher_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      studentCount: json['student_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'program_id': programId,
        'program_code': programCode,
        'program_name': programName,
        'semester_number': semesterNumber,
        'academic_year': academicYear,
        'section': section,
        'display_name': displayName,
        'subject_ids': subjectIds,
        'teacher_ids': teacherIds,
        'student_count': studentCount,
      };
}

class DepartmentDetailModel {
  final DepartmentModel department;
  final List<SubjectModel> subjects;
  final List<UserModel> teachers;
  final List<SemesterModel> semesters;

  DepartmentDetailModel({
    required this.department,
    required this.subjects,
    required this.teachers,
    required this.semesters,
  });

  factory DepartmentDetailModel.fromJson(Map<String, dynamic> json) {
    return DepartmentDetailModel(
      department: DepartmentModel.fromJson(json['department'] ?? {}),
      subjects: (json['subjects'] as List?)?.map((e) => SubjectModel.fromJson(e)).toList() ?? [],
      teachers: (json['teachers'] as List?)?.map((e) => UserModel.fromJson(e)).toList() ?? [],
      semesters: (json['semesters'] as List?)?.map((e) => SemesterModel.fromJson(e)).toList() ?? [],
    );
  }
}

class SemesterDetailModel {
  final SemesterModel semester;
  final List<SubjectModel> subjects;
  final List<UserModel> teachers;
  final List<UserModel> students;

  SemesterDetailModel({
    required this.semester,
    required this.subjects,
    required this.teachers,
    required this.students,
  });

  factory SemesterDetailModel.fromJson(Map<String, dynamic> json) {
    return SemesterDetailModel(
      semester: SemesterModel.fromJson(json['semester'] ?? {}),
      subjects: (json['subjects'] as List?)?.map((e) => SubjectModel.fromJson(e)).toList() ?? [],
      teachers: (json['teachers'] as List?)?.map((e) => UserModel.fromJson(e)).toList() ?? [],
      students: (json['students'] as List?)?.map((e) => UserModel.fromJson(e)).toList() ?? [],
    );
  }
}

class SectionModel {
  final String id;
  final String name;
  final int semesterNumber;
  final String academicYear;
  final String displayName;
  final String? departmentId;
  final List<String> programIds;
  final List<String> programNames;
  final List<String> subjectIds;
  final List<String> teacherIds;
  final int studentCount;

  SectionModel({
    required this.id,
    required this.name,
    required this.semesterNumber,
    required this.academicYear,
    required this.displayName,
    this.departmentId,
    this.programIds = const [],
    this.programNames = const [],
    this.subjectIds = const [],
    this.teacherIds = const [],
    this.studentCount = 0,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) {
    return SectionModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      semesterNumber: json['semester_number'] ?? 1,
      academicYear: json['academic_year'] ?? '',
      displayName: json['display_name'] ?? '',
      departmentId: json['department_id'],
      programIds: (json['program_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      programNames: (json['program_names'] as List?)?.map((e) => e.toString()).toList() ?? [],
      subjectIds: (json['subject_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      teacherIds: (json['teacher_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      studentCount: json['student_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'semester_number': semesterNumber,
        'academic_year': academicYear,
        'display_name': displayName,
        'department_id': departmentId,
        'program_ids': programIds,
        'program_names': programNames,
        'subject_ids': subjectIds,
        'teacher_ids': teacherIds,
        'student_count': studentCount,
      };
}

class SectionSubjectAllocationModel {
  final String subjectId;
  final String subjectCode;
  final String subjectName;
  final int credits;
  final String? programId;
  final String? programCode;
  final String? programName;
  final String? teacherId;
  final String? teacherName;

  SectionSubjectAllocationModel({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.credits,
    this.programId,
    this.programCode,
    this.programName,
    this.teacherId,
    this.teacherName,
  });

  bool get isSharedCore => programId == null || programId!.isEmpty;

  factory SectionSubjectAllocationModel.fromJson(Map<String, dynamic> json) {
    return SectionSubjectAllocationModel(
      subjectId: json['subject_id'] ?? '',
      subjectCode: json['subject_code'] ?? '',
      subjectName: json['subject_name'] ?? '',
      credits: json['credits'] ?? 3,
      programId: json['program_id'],
      programCode: json['program_code'],
      programName: json['program_name'],
      teacherId: json['teacher_id'],
      teacherName: json['teacher_name'],
    );
  }

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'subject_code': subjectCode,
        'subject_name': subjectName,
        'credits': credits,
        'program_id': programId,
        'program_code': programCode,
        'program_name': programName,
        'teacher_id': teacherId,
        'teacher_name': teacherName,
      };
}

class SectionDetailModel {
  final SectionModel section;
  final List<ProgramModel> programs;
  final List<SubjectModel> subjects;
  final List<SectionSubjectAllocationModel> subjectAllocations;
  final List<UserModel> teachers;
  final List<UserModel> students;
  final Map<String, int> programBreakdown;
  final List<LabBatchModel> labBatches;
  final List<FacultyAllocationModel> facultyAllocations;

  SectionDetailModel({
    required this.section,
    required this.programs,
    required this.subjects,
    required this.subjectAllocations,
    required this.teachers,
    required this.students,
    required this.programBreakdown,
    this.labBatches = const [],
    this.facultyAllocations = const [],
  });

  factory SectionDetailModel.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['program_breakdown'] as Map<String, dynamic>? ?? {};
    final breakdown = <String, int>{};
    breakdownRaw.forEach((k, v) {
      if (v is num) breakdown[k] = v.toInt();
    });

    return SectionDetailModel(
      section: SectionModel.fromJson(json['section'] ?? {}),
      programs: (json['programs'] as List?)?.map((e) => ProgramModel.fromJson(e)).toList() ?? [],
      subjects: (json['subjects'] as List?)?.map((e) => SubjectModel.fromJson(e)).toList() ?? [],
      subjectAllocations: (json['subject_allocations'] as List?)
              ?.map((e) => SectionSubjectAllocationModel.fromJson(e))
              .toList() ??
          [],
      teachers: (json['teachers'] as List?)?.map((e) => UserModel.fromJson(e)).toList() ?? [],
      students: (json['students'] as List?)?.map((e) => UserModel.fromJson(e)).toList() ?? [],
      programBreakdown: breakdown,
      labBatches: (json['lab_batches'] as List?)?.map((e) => LabBatchModel.fromJson(e)).toList() ?? [],
      facultyAllocations: (json['faculty_allocations'] as List?)
              ?.map((e) => FacultyAllocationModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class LabBatchModel {
  final String id;
  final String sectionId;
  final String name;
  final List<String> studentIds;
  final int studentCount;

  LabBatchModel({
    required this.id,
    required this.sectionId,
    required this.name,
    this.studentIds = const [],
    this.studentCount = 0,
  });

  factory LabBatchModel.fromJson(Map<String, dynamic> json) {
    return LabBatchModel(
      id: json['id'] ?? '',
      sectionId: json['section_id'] ?? '',
      name: json['name'] ?? '',
      studentIds: (json['student_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      studentCount: json['student_count'] ?? ((json['student_ids'] as List?)?.length ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'section_id': sectionId,
        'name': name,
        'student_ids': studentIds,
        'student_count': studentCount,
      };
}

class FacultyAllocationModel {
  final String id;
  final String sectionId;
  final String? sectionName;
  final String subjectId;
  final String? subjectCode;
  final String? subjectName;
  final String teacherId;
  final String? teacherName;
  final String componentType; // 'theory', 'practical', 'tutorial'
  final String? batchId;
  final String? batchName;
  final int weeklyHours;

  FacultyAllocationModel({
    required this.id,
    required this.sectionId,
    this.sectionName,
    required this.subjectId,
    this.subjectCode,
    this.subjectName,
    required this.teacherId,
    this.teacherName,
    required this.componentType,
    this.batchId,
    this.batchName,
    this.weeklyHours = 3,
  });

  factory FacultyAllocationModel.fromJson(Map<String, dynamic> json) {
    return FacultyAllocationModel(
      id: json['id'] ?? '',
      sectionId: json['section_id'] ?? '',
      sectionName: json['section_name'],
      subjectId: json['subject_id'] ?? '',
      subjectCode: json['subject_code'],
      subjectName: json['subject_name'],
      teacherId: json['teacher_id'] ?? '',
      teacherName: json['teacher_name'],
      componentType: json['component_type'] ?? 'theory',
      batchId: json['batch_id'],
      batchName: json['batch_name'],
      weeklyHours: json['weekly_hours'] ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'section_id': sectionId,
        'section_name': sectionName,
        'subject_id': subjectId,
        'subject_code': subjectCode,
        'subject_name': subjectName,
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'component_type': componentType,
        'batch_id': batchId,
        'batch_name': batchName,
        'weekly_hours': weeklyHours,
      };
}

class FacultyWorkloadSummaryModel {
  final String teacherId;
  final String teacherName;
  final String? departmentId;
  final String? departmentCode;
  final int totalWeeklyHours;
  final int maxRecommendedHours;
  final bool isOverloaded;
  final List<FacultyAllocationModel> allocations;

  FacultyWorkloadSummaryModel({
    required this.teacherId,
    required this.teacherName,
    this.departmentId,
    this.departmentCode,
    required this.totalWeeklyHours,
    this.maxRecommendedHours = 16,
    required this.isOverloaded,
    this.allocations = const [],
  });

  factory FacultyWorkloadSummaryModel.fromJson(Map<String, dynamic> json) {
    return FacultyWorkloadSummaryModel(
      teacherId: json['teacher_id'] ?? '',
      teacherName: json['teacher_name'] ?? '',
      departmentId: json['department_id'],
      departmentCode: json['department_code'],
      totalWeeklyHours: json['total_weekly_hours'] ?? 0,
      maxRecommendedHours: json['max_recommended_hours'] ?? 16,
      isOverloaded: json['is_overloaded'] ?? false,
      allocations: (json['allocations'] as List?)
              ?.map((e) => FacultyAllocationModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'department_id': departmentId,
        'department_code': departmentCode,
        'total_weekly_hours': totalWeeklyHours,
        'max_recommended_hours': maxRecommendedHours,
        'is_overloaded': isOverloaded,
        'allocations': allocations.map((e) => e.toJson()).toList(),
      };
}

