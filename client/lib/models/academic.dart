import 'dart:convert';

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
  final String slotType; // 'lecture', 'lab', 'tutorial'

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
