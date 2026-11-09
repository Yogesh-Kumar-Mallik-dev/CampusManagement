import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/facade/campus_facade.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/models/complaint.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';

void main() {
  group('CampusFacade Unified Domain Orchestration Tests', () {
    late OfflineStorageService storage;
    late ApiService api;
    late CampusFacade facade;

    setUp(() {
      api = ApiService(baseUrl: 'http://localhost:8080');
      storage = OfflineStorageService(api: api);
      facade = CampusFacade(storage: storage, api: api);
    });

    test('Facade handles authentication, session, and user profile lifecycle',
        () async {
      // 1. Authenticate student
      final user = await facade.login('harish_student', 'password123');
      expect(user.campusHandle, equals('harish_2025_l_btech_1'));
      expect(user.archetype, equals('student'));

      // 2. Fetch profile
      final profile = await facade.getUserProfile(user.id);
      expect(profile.campusHandle, equals('harish_2025_l_btech_1'));

      // 3. User listings
      final users = await facade.getUsers();
      expect(users.isNotEmpty, isTrue);

      // 4. Logout
      facade.logout();
    });

    test('Facade orchestrates Timetable, Courses, and Day-Off declarations',
        () async {
      final timetable = await facade.getTimetable('sec:cse-3a');
      expect(timetable.isNotEmpty, isTrue);

      final courses = facade.getCachedCourses();
      expect(courses, isA<List<CourseModel>>());

      // Conflict check
      final candidateSlot = TimetableSlotModel(
        id: 'slot-test-candidate',
        courseId: 'crs-cse-301',
        courseCode: 'CS301',
        courseName: 'Operating Systems',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. John Doe',
        dayOfWeek: 1, // Monday
        startTime: '09:00',
        endTime: '10:00',
        roomNumber: 'LH-101',
        slotType: 'regular',
      );
      final conflicts = await facade.checkTimetableConflicts(candidateSlot);
      expect(conflicts, isA<List<TimetableConflictModel>>());

      // Day-off declaration
      await facade.declareDayOff(
        dayOfWeek: 2, // Tuesday
        reason: 'National Holiday',
        scopeCode: 'sec:cse-3a',
      );
      final tuesdaySlots = await facade.getTimetable('sec:cse-3a');
      expect(
        tuesdaySlots.where((s) => s.dayOfWeek == 2 && s.isOff).length,
        equals(8),
      );

      // Restore day
      await facade.restoreDaySchedule(
        dayOfWeek: 2,
        scopeCode: 'sec:cse-3a',
      );
      final restoredSlots = await facade.getTimetable('sec:cse-3a');
      expect(
        restoredSlots.any((s) => s.dayOfWeek == 2 && !s.isOff),
        isTrue,
      );
    });

    test('Facade manages Academic Hierarchy: Departments, Programs, Subjects, and Sections',
        () async {
      final depts = await facade.getDepartments();
      expect(depts.isNotEmpty, isTrue);

      final programs = await facade.getPrograms();
      expect(programs.isNotEmpty, isTrue);

      final subjects = await facade.getSubjects();
      expect(subjects.isNotEmpty, isTrue);

      final semesters = await facade.getSemesters();
      expect(semesters.isNotEmpty, isTrue);

      final sections = await facade.getSections();
      expect(sections.isNotEmpty, isTrue);

      // Department detail
      final deptDetail = await facade.getDepartmentDetail(depts.first.id);
      expect(deptDetail.department.id, equals(depts.first.id));
      expect(deptDetail.teachers.isNotEmpty, isTrue);

      // Syllabus audit trail
      final audit = await facade.getSubjectSyllabusAudit(subjects.first.id);
      expect(audit, isA<List<SyllabusVersionModel>>());
    });

    test('Facade manages Hostel residential operations and fixtures', () async {
      final rooms = await facade.getHostelRooms();
      expect(rooms.isNotEmpty, isTrue);

      // Create new hostel room
      final newRoom = await facade.createHostelRoom(242, 'North Wing');
      expect(newRoom.roomNumber, equals(242));
      expect(newRoom.blockName, equals('North Wing'));

      // Add asset to room
      final asset = await facade.addHostelAsset(
        242,
        'fan',
        'FAN-242-01',
        'good',
      );
      expect(asset.roomNumber, equals(242));
      expect(asset.serialNumber, equals('FAN-242-01'));

      // Assign occupant
      final occupant = await facade.assignHostelOccupant(
        242,
        'usr-test-student',
        'test_student',
        'Test Student',
      );
      expect(occupant.userId, equals('usr-test-student'));
      expect(occupant.campusHandle, equals('test_student'));

      // Remove occupant
      await facade.removeHostelOccupant(242, 'usr-test-student');

      // Remove asset
      await facade.removeHostelAsset(242, asset.id);
    });

    test('Facade coordinates Dining Mess timetable, meals, and rating reviews',
        () async {
      final meals = await facade.getMessTimetable();
      expect(meals.isNotEmpty, isTrue);

      // Submit valid rating
      final rating = await facade.submitMessRating(
        mealId: meals.first.id,
        userId: 'usr-student-harish',
        userName: 'Harish Kumar',
        campusHandle: 'harish_student',
        rating: 'good',
        message: 'The meal was well prepared and nutritious.',
      );
      expect(rating.rating, equals('good'));

      // Get feedback report
      final report = await facade.getMessRatingsReport();
      expect(report.totalRatings, greaterThanOrEqualTo(1));
    });

    test('Facade orchestrates Institutional Complaints and status updates',
        () async {
      final initialComplaints = await facade.getComplaints();
      expect(initialComplaints.isNotEmpty, isTrue);

      // Create new complaint
      final now = DateTime.now();
      final complaint = ComplaintModel(
        id: 'complaint-facade-test',
        title: 'Water filter maintenance required',
        description: 'First floor North wing water purifier requires filter replacement',
        category: ComplaintCategory.hostel,
        urgency: ComplaintUrgency.medium,
        isAnonymous: false,
        submittedBy: 'usr-student-harish',
        submitterHandle: 'harish_student',
        submitterName: 'Harish Kumar',
        submitterRole: 'student',
        createdAt: now,
        updatedAt: now,
      );

      final created = await facade.createComplaint(complaint);
      expect(created.id, isNotEmpty);
      expect(created.status, equals(ComplaintStatus.open));

      // Update complaint status
      final updated = await facade.updateComplaintStatus(
        complaintId: created.id,
        status: ComplaintStatus.inProgress,
        remarks: 'Assigned to hostel maintenance crew',
        resolvedBy: 'warden_kumar',
      );
      expect(updated.status, equals(ComplaintStatus.inProgress));
      expect(updated.resolvedBy, equals('warden_kumar'));
    });
  });
}
