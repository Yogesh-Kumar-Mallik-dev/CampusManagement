class InternalAssessmentModel {
  final String id;
  final String studentId;
  final String studentName;
  final String universityRollNo;
  final String subjectCode;
  final String subjectName;
  final int semesterNumber;
  final String section;
  final bool isPractical;
  final double ct1Score;
  final double ct2Score;
  final double putScore;
  final double taScore;
  final double labContinuousScore;
  final double labVivaScore;
  final double labAttendanceScore;
  final double calculatedSessional;
  final double totalInternalMarks;
  final double maxInternalMarks;
  final String formulaUsed;
  final bool isFrozen;
  final String? frozenBy;
  final String? frozenAt;
  final String status;
  final String? remarks;

  InternalAssessmentModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.universityRollNo,
    required this.subjectCode,
    required this.subjectName,
    required this.semesterNumber,
    this.section = 'Section B',
    this.isPractical = false,
    this.ct1Score = 0.0,
    this.ct2Score = 0.0,
    this.putScore = 0.0,
    this.taScore = 0.0,
    this.labContinuousScore = 0.0,
    this.labVivaScore = 0.0,
    this.labAttendanceScore = 0.0,
    this.calculatedSessional = 0.0,
    this.totalInternalMarks = 0.0,
    this.maxInternalMarks = 30.0,
    this.formulaUsed = '',
    this.isFrozen = false,
    this.frozenBy,
    this.frozenAt,
    this.status = 'submitted',
    this.remarks,
  });

  factory InternalAssessmentModel.fromJson(Map<String, dynamic> json) {
    return InternalAssessmentModel(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      studentName: json['student_name'] ?? '',
      universityRollNo: json['university_roll_no'] ?? '',
      subjectCode: json['subject_code'] ?? '',
      subjectName: json['subject_name'] ?? '',
      semesterNumber: json['semester_number'] is int
          ? json['semester_number']
          : int.tryParse(json['semester_number']?.toString() ?? '5') ?? 5,
      section: json['section'] ?? 'Section B',
      isPractical: json['is_practical'] ?? false,
      ct1Score: (json['ct1_score'] as num?)?.toDouble() ?? 0.0,
      ct2Score: (json['ct2_score'] as num?)?.toDouble() ?? 0.0,
      putScore: (json['put_score'] as num?)?.toDouble() ?? 0.0,
      taScore: (json['ta_score'] as num?)?.toDouble() ?? 0.0,
      labContinuousScore: (json['lab_continuous_score'] as num?)?.toDouble() ?? 0.0,
      labVivaScore: (json['lab_viva_score'] as num?)?.toDouble() ?? 0.0,
      labAttendanceScore: (json['lab_attendance_score'] as num?)?.toDouble() ?? 0.0,
      calculatedSessional: (json['calculated_sessional'] as num?)?.toDouble() ?? 0.0,
      totalInternalMarks: (json['total_internal_marks'] as num?)?.toDouble() ?? 0.0,
      maxInternalMarks: (json['max_internal_marks'] as num?)?.toDouble() ?? 30.0,
      formulaUsed: json['formula_used'] ?? '',
      isFrozen: json['is_frozen'] ?? false,
      frozenBy: json['frozen_by'],
      frozenAt: json['frozen_at'],
      status: json['status'] ?? 'submitted',
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'university_roll_no': universityRollNo,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'semester_number': semesterNumber,
      'section': section,
      'is_practical': isPractical,
      'ct1_score': ct1Score,
      'ct2_score': ct2Score,
      'put_score': putScore,
      'ta_score': taScore,
      'lab_continuous_score': labContinuousScore,
      'lab_viva_score': labVivaScore,
      'lab_attendance_score': labAttendanceScore,
      'calculated_sessional': calculatedSessional,
      'total_internal_marks': totalInternalMarks,
      'max_internal_marks': maxInternalMarks,
      'formula_used': formulaUsed,
      'is_frozen': isFrozen,
      'frozen_by': frozenBy,
      'frozen_at': frozenAt,
      'status': status,
      'remarks': remarks,
    };
  }

  InternalAssessmentModel copyWith({
    double? ct1Score,
    double? ct2Score,
    double? putScore,
    double? taScore,
    double? labContinuousScore,
    double? labVivaScore,
    double? labAttendanceScore,
    double? calculatedSessional,
    double? totalInternalMarks,
    bool? isFrozen,
    String? frozenBy,
    String? frozenAt,
    String? status,
    String? remarks,
  }) {
    return InternalAssessmentModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      universityRollNo: universityRollNo,
      subjectCode: subjectCode,
      subjectName: subjectName,
      semesterNumber: semesterNumber,
      section: section,
      isPractical: isPractical,
      ct1Score: ct1Score ?? this.ct1Score,
      ct2Score: ct2Score ?? this.ct2Score,
      putScore: putScore ?? this.putScore,
      taScore: taScore ?? this.taScore,
      labContinuousScore: labContinuousScore ?? this.labContinuousScore,
      labVivaScore: labVivaScore ?? this.labVivaScore,
      labAttendanceScore: labAttendanceScore ?? this.labAttendanceScore,
      calculatedSessional: calculatedSessional ?? this.calculatedSessional,
      totalInternalMarks: totalInternalMarks ?? this.totalInternalMarks,
      maxInternalMarks: maxInternalMarks,
      formulaUsed: formulaUsed,
      isFrozen: isFrozen ?? this.isFrozen,
      frozenBy: frozenBy ?? this.frozenBy,
      frozenAt: frozenAt ?? this.frozenAt,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
    );
  }
}

class SessionalScheduleModel {
  final String id;
  final String examType; // 'CT-1', 'CT-2', 'PUT'
  final String subjectCode;
  final String subjectName;
  final int semesterNumber;
  final String examDate;
  final String timeSlot;
  final String hallNumber;
  final int totalCapacity;
  final String invigilatorName;
  final String rollRange;

  SessionalScheduleModel({
    required this.id,
    required this.examType,
    required this.subjectCode,
    required this.subjectName,
    required this.semesterNumber,
    required this.examDate,
    required this.timeSlot,
    required this.hallNumber,
    this.totalCapacity = 60,
    required this.invigilatorName,
    required this.rollRange,
  });

  factory SessionalScheduleModel.fromJson(Map<String, dynamic> json) {
    return SessionalScheduleModel(
      id: json['id'] ?? '',
      examType: json['exam_type'] ?? 'CT-1',
      subjectCode: json['subject_code'] ?? '',
      subjectName: json['subject_name'] ?? '',
      semesterNumber: json['semester_number'] is int
          ? json['semester_number']
          : int.tryParse(json['semester_number']?.toString() ?? '5') ?? 5,
      examDate: json['exam_date'] ?? '',
      timeSlot: json['time_slot'] ?? '',
      hallNumber: json['hall_number'] ?? '',
      totalCapacity: json['total_capacity'] ?? 60,
      invigilatorName: json['invigilator_name'] ?? '',
      rollRange: json['roll_range'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_type': examType,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'semester_number': semesterNumber,
      'exam_date': examDate,
      'time_slot': timeSlot,
      'hall_number': hallNumber,
      'total_capacity': totalCapacity,
      'invigilator_name': invigilatorName,
      'roll_range': rollRange,
    };
  }
}

class DeskSeatingModel {
  final String deskNumber;
  final String hallNumber;
  final int seatIndex;
  final String studentRollNo;
  final String studentName;
  final String subjectCode;
  final String subjectName;
  final String examType;

  DeskSeatingModel({
    required this.deskNumber,
    required this.hallNumber,
    required this.seatIndex,
    required this.studentRollNo,
    required this.studentName,
    required this.subjectCode,
    required this.subjectName,
    required this.examType,
  });

  factory DeskSeatingModel.fromJson(Map<String, dynamic> json) {
    return DeskSeatingModel(
      deskNumber: json['desk_number'] ?? '',
      hallNumber: json['hall_number'] ?? '',
      seatIndex: json['seat_index'] ?? 0,
      studentRollNo: json['student_roll_no'] ?? '',
      studentName: json['student_name'] ?? '',
      subjectCode: json['subject_code'] ?? '',
      subjectName: json['subject_name'] ?? '',
      examType: json['exam_type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'desk_number': deskNumber,
      'hall_number': hallNumber,
      'seat_index': seatIndex,
      'student_roll_no': studentRollNo,
      'student_name': studentName,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'exam_type': examType,
    };
  }
}

class AKTUInternalAwardListModel {
  final String departmentCode;
  final String departmentName;
  final String programName;
  final int semesterNumber;
  final String subjectCode;
  final String subjectName;
  final String academicSession;
  final bool isPractical;
  final double maxInternalMarks;
  final int totalStudents;
  final int passCount;
  final int failCount;
  final double passPercentage;
  final double averageMarks;
  final double highestMarks;
  final double lowestMarks;
  final int deficitCount;
  final bool isFrozen;
  final String? frozenBy;
  final String? frozenAt;
  final String? digitalSignature;
  final List<InternalAssessmentModel> records;

  AKTUInternalAwardListModel({
    required this.departmentCode,
    required this.departmentName,
    required this.programName,
    required this.semesterNumber,
    required this.subjectCode,
    required this.subjectName,
    required this.academicSession,
    this.isPractical = false,
    this.maxInternalMarks = 30.0,
    required this.totalStudents,
    required this.passCount,
    required this.failCount,
    required this.passPercentage,
    required this.averageMarks,
    required this.highestMarks,
    required this.lowestMarks,
    required this.deficitCount,
    this.isFrozen = false,
    this.frozenBy,
    this.frozenAt,
    this.digitalSignature,
    this.records = const [],
  });

  factory AKTUInternalAwardListModel.fromJson(Map<String, dynamic> json) {
    final recList = (json['records'] as List<dynamic>?)
            ?.map((e) => InternalAssessmentModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return AKTUInternalAwardListModel(
      departmentCode: json['department_code'] ?? 'CSE',
      departmentName: json['department_name'] ?? 'Computer Science & Engineering',
      programName: json['program_name'] ?? 'B.Tech Computer Science',
      semesterNumber: json['semester_number'] is int
          ? json['semester_number']
          : int.tryParse(json['semester_number']?.toString() ?? '5') ?? 5,
      subjectCode: json['subject_code'] ?? '',
      subjectName: json['subject_name'] ?? '',
      academicSession: json['academic_session'] ?? '2025-2026',
      isPractical: json['is_practical'] ?? false,
      maxInternalMarks: (json['max_internal_marks'] as num?)?.toDouble() ?? 30.0,
      totalStudents: json['total_students'] ?? recList.length,
      passCount: json['pass_count'] ?? 0,
      failCount: json['fail_count'] ?? 0,
      passPercentage: (json['pass_percentage'] as num?)?.toDouble() ?? 0.0,
      averageMarks: (json['average_marks'] as num?)?.toDouble() ?? 0.0,
      highestMarks: (json['highest_marks'] as num?)?.toDouble() ?? 0.0,
      lowestMarks: (json['lowest_marks'] as num?)?.toDouble() ?? 0.0,
      deficitCount: json['deficit_count'] ?? 0,
      isFrozen: json['is_frozen'] ?? false,
      frozenBy: json['frozen_by'],
      frozenAt: json['frozen_at'],
      digitalSignature: json['digital_signature'],
      records: recList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'department_code': departmentCode,
      'department_name': departmentName,
      'program_name': programName,
      'semester_number': semesterNumber,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'academic_session': academicSession,
      'is_practical': isPractical,
      'max_internal_marks': maxInternalMarks,
      'total_students': totalStudents,
      'pass_count': passCount,
      'fail_count': failCount,
      'pass_percentage': passPercentage,
      'average_marks': averageMarks,
      'highest_marks': highestMarks,
      'lowest_marks': lowestMarks,
      'deficit_count': deficitCount,
      'is_frozen': isFrozen,
      'frozen_by': frozenBy,
      'frozen_at': frozenAt,
      'digital_signature': digitalSignature,
      'records': records.map((e) => e.toJson()).toList(),
    };
  }
}
