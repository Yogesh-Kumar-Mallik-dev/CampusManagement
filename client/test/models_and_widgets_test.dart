import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/models/complaint.dart';
import 'package:campus_client/models/hostel.dart';
import 'package:campus_client/models/mess.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/theme/svg_icons.dart';
import 'package:campus_client/widgets/app_skeleton.dart';

void main() {
  group('Models Serialization, Deserialization, and CopyWith Tests', () {
    test('Academic models round-trip serialization', () {
      final now = DateTime.now();

      // CourseModel
      final course = CourseModel(
        id: 'crs-1',
        code: 'CS101',
        name: 'Computer Science',
        credits: 4,
        semester: 1,
      );
      final courseJson = course.toJson();
      final courseParsed = CourseModel.fromJson(courseJson);
      expect(courseParsed.id, equals(course.id));
      expect(courseParsed.code, equals(course.code));

      // TimetableSlotModel
      final slot = TimetableSlotModel(
        id: 'slot-1',
        courseId: 'crs-1',
        courseCode: 'CS101',
        courseName: 'CS',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. Test',
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '10:00',
        roomNumber: 'LH-1',
        slotType: 'regular',
      );
      final slotJson = slot.toJson();
      final slotParsed = TimetableSlotModel.fromJson(slotJson);
      expect(slotParsed.id, equals(slot.id));
      final slotCopied = slot.copyWith(roomNumber: 'LH-2');
      expect(slotCopied.roomNumber, equals('LH-2'));

      // TimetableConflictModel
      final conflict = TimetableConflictModel(
        type: 'room',
        message: 'Clash in LH-1',
        conflictingSlot: slot,
      );
      final conflictJson = conflict.toJson();
      final conflictParsed = TimetableConflictModel.fromJson(conflictJson);
      expect(conflictParsed.type, equals('room'));

      // AttendanceRecordModel
      final attRecord = AttendanceRecordModel(
        id: 'att-1',
        sessionId: 'ses-1',
        studentId: 'usr-1',
        studentName: 'Harish',
        campusHandle: 'harish_1',
        status: 'present',
      );
      final attJson = attRecord.toJson();
      final attParsed = AttendanceRecordModel.fromJson(attJson);
      expect(attParsed.id, equals(attRecord.id));

      // AttendanceSessionModel
      final attSession = AttendanceSessionModel(
        id: 'ses-1',
        courseId: 'crs-1',
        courseCode: 'CS101',
        courseName: 'CS',
        scopeCode: 'sec:cse-3a',
        sessionDate: '2026-11-09',
        topic: 'Sorting algorithms',
        records: [attRecord],
      );
      final sessionJson = attSession.toJson();
      final sessionParsed = AttendanceSessionModel.fromJson(sessionJson);
      expect(sessionParsed.id, equals(attSession.id));

      // NoticeModel
      final notice = NoticeModel(
        id: 'not-1',
        title: 'Notice Title',
        content: 'Content here',
        category: 'exam',
        targetScopeCode: 'global',
        priority: 'high',
        publishedAt: now,
      );
      final noticeJson = notice.toJson();
      final noticeParsed = NoticeModel.fromJson(noticeJson);
      expect(noticeParsed.id, equals(notice.id));

      // DepartmentModel & ProgramModel
      final dept = DepartmentModel(
        id: 'dept-cse',
        code: 'CSE',
        name: 'Computer Science',
        description: 'Department of Computer Science',
        hodId: 'usr-hod',
        hodName: 'Dr. HOD',
      );
      final deptJson = dept.toJson();
      final deptParsed = DepartmentModel.fromJson(deptJson);
      expect(deptParsed.code, equals('CSE'));

      final prog = ProgramModel(
        id: 'prog-1',
        code: 'BTECH',
        name: 'Bachelor of Technology',
        degreeLevel: 'UG',
        totalSemesters: 8,
      );
      final progJson = prog.toJson();
      final progParsed = ProgramModel.fromJson(progJson);
      expect(progParsed.code, equals('BTECH'));

      // SubjectModel & SyllabusVersionModel
      final syl = SyllabusVersionModel(
        id: 'syl-1',
        subjectId: 'sub-1',
        revisionCode: 'Rev-1',
        effectiveFromYear: '2026',
        isActive: true,
        content: 'Algorithms curriculum',
        createdAt: now,
      );
      final sylJson = syl.toJson();
      final sylParsed = SyllabusVersionModel.fromJson(sylJson);
      expect(sylParsed.revisionCode, equals('Rev-1'));

      final subj = SubjectModel(
        id: 'sub-1',
        code: 'CS101',
        name: 'Prog in C',
        credits: 4,
        departmentIds: ['dept-cse'],
        activeSyllabus: syl,
      );
      final subjJson = subj.toJson();
      final subjParsed = SubjectModel.fromJson(subjJson);
      expect(subjParsed.code, equals('CS101'));

      // SemesterModel, SectionModel, LabBatchModel
      final sem = SemesterModel(
        id: 'sem-1',
        programId: 'prog-1',
        programCode: 'BTECH',
        programName: 'B.Tech CSE',
        semesterNumber: 1,
        academicYear: '2026-2027',
        section: 'A',
        displayName: 'Semester 1 - Sec A',
      );
      final semJson = sem.toJson();
      final semParsed = SemesterModel.fromJson(semJson);
      expect(semParsed.semesterNumber, equals(1));

      final sec = SectionModel(
        id: 'sec-1',
        name: 'Section A',
        semesterNumber: 1,
        academicYear: '2026-2027',
        displayName: 'CSE 1A',
        studentCount: 30,
      );
      final secJson = sec.toJson();
      final secParsed = SectionModel.fromJson(secJson);
      expect(secParsed.name, equals('Section A'));

      final batch = LabBatchModel(
        id: 'batch-1',
        sectionId: 'sec-1',
        name: 'Batch A1',
        studentCount: 15,
      );
      final batchJson = batch.toJson();
      final batchParsed = LabBatchModel.fromJson(batchJson);
      expect(batchParsed.name, equals('Batch A1'));

      // FacultyAllocationModel & Workload
      final alloc = FacultyAllocationModel(
        id: 'alloc-1',
        sectionId: 'sec-1',
        sectionName: 'Section A',
        teacherId: 'usr-1',
        teacherName: 'Prof. Test',
        subjectId: 'sub-1',
        subjectName: 'Data Structures',
        subjectCode: 'CS101',
        componentType: 'theory',
        weeklyHours: 4,
      );
      final allocJson = alloc.toJson();
      final allocParsed = FacultyAllocationModel.fromJson(allocJson);
      expect(allocParsed.weeklyHours, equals(4));

      final workload = FacultyWorkloadSummaryModel(
        teacherId: 'usr-1',
        teacherName: 'Prof. Test',
        totalWeeklyHours: 12,
        maxRecommendedHours: 16,
        isOverloaded: false,
        allocations: [alloc],
      );
      final workloadJson = workload.toJson();
      final workloadParsed = FacultyWorkloadSummaryModel.fromJson(workloadJson);
      expect(workloadParsed.isOverloaded, isFalse);
    });

    test('Hostel and Mess models serialization', () {
      final now = DateTime.now();

      // Hostel models
      final asset = HostelAssetModel(
        id: 'ast-1',
        roomNumber: 101,
        assetType: 'bed',
        serialNumber: 'BED-101',
        condition: 'good',
        installedAt: now,
      );
      final assetJson = asset.toJson();
      final assetParsed = HostelAssetModel.fromJson(assetJson);
      expect(assetParsed.serialNumber, equals('BED-101'));

      final occupant = HostelOccupantModel(
        userId: 'usr-1',
        campusHandle: 'stud_1',
        name: 'Student One',
        allottedAt: now,
      );
      final occupantJson = occupant.toJson();
      final occupantParsed = HostelOccupantModel.fromJson(occupantJson);
      expect(occupantParsed.campusHandle, equals('stud_1'));

      final room = HostelRoomModel(
        id: 'rm-101',
        roomNumber: 101,
        floor: 1,
        blockName: 'Block A',
        assets: [asset],
        occupants: [occupant],
        createdAt: now,
        updatedAt: now,
      );
      final roomJson = room.toJson();
      final roomParsed = HostelRoomModel.fromJson(roomJson);
      expect(roomParsed.roomNumber, equals(101));
      expect(roomParsed.bedCount, equals(1));
      expect(roomParsed.occupantCount, equals(1));

      // Mess models
      final meal = MessMealModel(
        id: 'meal-1',
        dayOfWeek: 'monday',
        mealType: 'lunch',
        startTime: '12:30',
        endTime: '14:30',
        title: 'Monday Lunch',
        menuSummary: 'Rice, Dal, Paneer',
        items: ['Rice', 'Dal'],
      );
      final mealJson = meal.toJson();
      final mealParsed = MessMealModel.fromJson(mealJson);
      expect(mealParsed.title, equals('Monday Lunch'));

      final rating = MessRatingModel(
        id: 'rat-1',
        mealId: 'meal-1',
        dayOfWeek: 'monday',
        mealType: 'lunch',
        userId: 'usr-1',
        userName: 'User One',
        campusHandle: 'user_1',
        rating: 'good',
        message: 'Tasty meal',
        createdAt: now,
      );
      final ratingJson = rating.toJson();
      final ratingParsed = MessRatingModel.fromJson(ratingJson);
      expect(ratingParsed.rating, equals('good'));
      expect(ratingParsed.isMessageCompulsory, isFalse);

      final valErr = MessRatingModel.validateRatingFeedback(
        rating: MessRatingValue.veryPoor,
        message: '',
      );
      expect(valErr, isNotNull);
    });

    test('User and Complaint models serialization', () {
      final now = DateTime.now();

      // UserModel
      final roleAssignment = UserRoleAssignmentModel(
        id: 'ura-1',
        userId: 'usr-1',
        roleCode: 'student',
        scopeCode: 'global',
        isActive: true,
      );
      final roleJson = roleAssignment.toJson();
      final roleParsed = UserRoleAssignmentModel.fromJson(roleJson);
      expect(roleParsed.roleCode, equals('student'));

      final user = UserModel(
        id: 'usr-1',
        campusHandle: 'test_student',
        firstName: 'Test',
        lastName: 'Student',
        email: 'test@campus.edu',
        archetype: 'student',
        status: 'active',
        assignedRoles: [roleAssignment],
        permissions: ['complaints:file', 'timetable:read'],
      );
      final userJson = user.toJson();
      final userParsed = UserModel.fromJson(userJson);
      expect(userParsed.fullName, equals('Test Student'));
      expect(userParsed.hasPermission('complaints:file'), isTrue);
      expect(userParsed.hasPermission('non_existent:permission'), isFalse);

      final userCopied = user.copyWith(firstName: 'UpdatedName');
      expect(userCopied.firstName, equals('UpdatedName'));

      // ComplaintModel
      final complaint = ComplaintModel(
        id: 'cmp-1',
        title: 'WiFi Down',
        description: 'Hostel Block B 2nd floor WiFi not working',
        category: ComplaintCategory.hostel,
        urgency: ComplaintUrgency.high,
        status: ComplaintStatus.open,
        isAnonymous: false,
        submittedBy: 'usr-1',
        submitterHandle: 'test_student',
        submitterName: 'Test Student',
        submitterRole: 'student',
        createdAt: now,
        updatedAt: now,
      );
      final cmpJson = complaint.toJson();
      final cmpParsed = ComplaintModel.fromJson(cmpJson);
      expect(cmpParsed.title, equals('WiFi Down'));
      expect(cmpParsed.urgency, equals(ComplaintUrgency.high));
    });
  });

  group('UI Widgets and Prewarm Coverage Tests', () {
    test('AppSvgIcon prewarmCoreIcons caches all core icons', () {
      AppSvgIcon.prewarmCoreIcons();
    });

    testWidgets('AppSkeleton renders rectangular placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppSkeleton(width: 100, height: 20),
                AppSkeleton.rect(height: 40),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(AppSkeleton), findsNWidgets(2));
    });

    testWidgets('InlineStateError renders message and triggers retry on tap', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineStateError(
              message: 'Failed to load data',
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Failed to load data'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}
