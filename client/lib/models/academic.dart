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

  AttendanceRecordModel({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.campusHandle,
    required this.status,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id'] ?? '',
      sessionId: json['session_id'] ?? '',
      studentId: json['student_id'] ?? '',
      studentName: json['student_name'] ?? '',
      campusHandle: json['campus_handle'] ?? '',
      status: json['status'] ?? 'present',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'student_id': studentId,
        'student_name': studentName,
        'campus_handle': campusHandle,
        'status': status,
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
