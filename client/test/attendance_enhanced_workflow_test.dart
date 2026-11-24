import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/screens/attendance_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiService api;
  late OfflineStorageService storage;

  setUp(() {
    api = ApiService(baseUrl: 'http://localhost:8080');
    storage = OfflineStorageService(api: api, enableMockSeeding: false);
  });

  group('Enhanced Optical Attendance Workflow Tests', () {
    test('OpticalFramePacket serialization preserves teacher, substitute, fingerprint and duration units', () {
      final packet = OpticalFramePacket(
        sessionId: 'sess-test-101',
        courseCode: 'CS301',
        courseName: 'Database Management Systems',
        subjectCode: 'CS301',
        subjectName: 'Database Management Systems',
        teacherId: 'usr-teach-01',
        teacherName: 'Dr. Ada Lovelace',
        isSubstitute: true,
        substituteForName: 'Prof. Charles Babbage',
        programName: 'B.Tech CSE',
        academicYear: 3,
        sectionScope: 'sec:cse-3a',
        room: 'Lab-402',
        sequence: 42,
        timestamp: 1732450000,
        nonce: '883921',
        fingerprintCode: 'fp-code-crypto99',
        durationHours: 2,
        attendanceUnits: 2,
        signature: 'sig-hmac-sha256',
      );

      final encoded = packet.encode();
      expect(encoded.startsWith('CPOS:OPT:'), isTrue);

      final decoded = OpticalFramePacket.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.sessionId, equals('sess-test-101'));
      expect(decoded.courseCode, equals('CS301'));
      expect(decoded.courseName, equals('Database Management Systems'));
      expect(decoded.teacherId, equals('usr-teach-01'));
      expect(decoded.teacherName, equals('Dr. Ada Lovelace'));
      expect(decoded.isSubstitute, isTrue);
      expect(decoded.substituteForName, equals('Prof. Charles Babbage'));
      expect(decoded.programName, equals('B.Tech CSE'));
      expect(decoded.academicYear, equals(3));
      expect(decoded.sectionScope, equals('sec:cse-3a'));
      expect(decoded.room, equals('Lab-402'));
      expect(decoded.sequence, equals(42));
      expect(decoded.timestamp, equals(1732450000));
      expect(decoded.nonce, equals('883921'));
      expect(decoded.fingerprintCode, equals('fp-code-crypto99'));
      expect(decoded.durationHours, equals(2));
      expect(decoded.attendanceUnits, equals(2));
      expect(decoded.signature, equals('sig-hmac-sha256'));
    });

    testWidgets('Host launches 2-hour substitute optical broadcast session', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final teacher = UserModel(
        id: 'usr-prof-1',
        campusHandle: 'prof_adams',
        firstName: 'John',
        lastName: 'Adams',
        email: 'jadams@campus.edu',
        archetype: 'employee',
        status: 'active',
        activeScopes: const ['sec:cse-3a'],
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'role-fac-1',
            userId: 'usr-prof-1',
            roleCode: 'faculty',
            roleName: 'Faculty',
          ),
        ],
        permissions: const ['attendance:write', 'attendance:read'],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AttendanceScreen(
            storage: storage,
            currentUser: teacher,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open broadcast setup dialog
      final broadcastBtn = find.text('Broadcast Optical QR');
      expect(broadcastBtn, findsOneWidget);
      await tester.tap(broadcastBtn);
      await tester.pumpAndSettle();

      // Configure 2-hour double lecture/lab block
      final duration2hrRadio = find.byKey(const Key('radio-duration-2hr'));
      expect(duration2hrRadio, findsOneWidget);
      await tester.tap(duration2hrRadio);
      await tester.pumpAndSettle();

      // Check substitute assignment
      final substituteCheckbox = find.byKey(const Key('checkbox-is-substitute'));
      expect(substituteCheckbox, findsOneWidget);
      await tester.tap(substituteCheckbox);
      await tester.pumpAndSettle();

      // Enter substitute teacher name
      final substituteNameInput = find.byKey(const Key('input-substitute-name'));
      expect(substituteNameInput, findsOneWidget);
      await tester.enterText(substituteNameInput, 'Prof. Katherine Johnson');
      await tester.pumpAndSettle();

      // Launch stream
      final launchBtn = find.byKey(const Key('btn-confirm-start-broadcast'));
      expect(launchBtn, findsOneWidget);
      await tester.tap(launchBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify active optical session was configured properly
      final active = storage.activeOpticalSession;
      expect(active, isNotNull);
      expect(active!.durationHours, equals(2));
      expect(active.attendanceUnits, equals(2));
      expect(active.isSubstitute, isTrue);
      expect(active.substituteForName, equals('Prof. Katherine Johnson'));

      // Verify broadcast UI elements
      expect(find.text('2 Hours (2 Units)'), findsOneWidget);
      expect(find.text('SUB: Prof. Katherine Johnson'), findsOneWidget);
      expect(find.text('BROADCASTING LIVE'), findsOneWidget);

      // Clean up timers
      await tester.tap(find.text('Conclude & Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Student section authorization gate blocks un-enrolled students', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Start an active optical session for sec:cse-3a
      await storage.startOpticalSession(
        courseId: 'CS301',
        courseCode: 'CS301',
        courseName: 'Database Management Systems',
        subjectCode: 'CS301',
        subjectName: 'Database Management Systems',
        scopeCode: 'sec:cse-3a',
        sectionScope: 'sec:cse-3a',
        roomNumber: 'LH-101',
        markedByUserId: 'usr-teach-1',
        markedByName: 'Prof. Turing',
        teacherId: 'usr-teach-1',
        teacherName: 'Prof. Turing',
        durationHours: 2,
        attendanceUnits: 2,
      );

      // Student from sec:ece-3a
      final eceStudent = UserModel(
        id: 'usr-stu-ece-99',
        campusHandle: 'bob_ece',
        firstName: 'Bob',
        lastName: 'ECE',
        email: 'bob@ece.campus.edu',
        archetype: 'student',
        status: 'active',
        activeScopes: const ['sec:ece-3a'],
        studentProfile: const {'section_scope': 'sec:ece-3a'},
        permissions: const ['attendance:read'],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AttendanceScreen(
            storage: storage,
            currentUser: eceStudent,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open optical scanner
      final scanBtn = find.text('Scan Rolling QR');
      expect(scanBtn, findsOneWidget);
      await tester.tap(scanBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate capturing frame from active cse session
      final simulateBtn = find.byKey(const Key('btn-simulate-camera-feed'));
      expect(simulateBtn, findsOneWidget);
      await tester.tap(simulateBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify authorization gate error message is displayed
      expect(find.textContaining('Unauthorized Section'), findsOneWidget);

      // Verify no verified records added
      expect(storage.activeOpticalSession!.verifiedRecords, isEmpty);
    });

    testWidgets('Authorized student scans QR, stamps fingerprint signature, and claims 2 attendance units', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Start active optical session for sec:cse-3a with 2 attendance units
      await storage.startOpticalSession(
        courseId: 'CS301',
        courseCode: 'CS301',
        courseName: 'Database Management Systems',
        subjectCode: 'CS301',
        subjectName: 'Database Management Systems',
        scopeCode: 'sec:cse-3a',
        sectionScope: 'sec:cse-3a',
        roomNumber: 'LH-101',
        markedByUserId: 'usr-teach-1',
        markedByName: 'Prof. Margaret Hamilton',
        teacherId: 'usr-teach-1',
        teacherName: 'Prof. Margaret Hamilton',
        durationHours: 2,
        attendanceUnits: 2,
      );

      // Student enrolled in sec:cse-3a
      final cseStudent = UserModel(
        id: 'usr-stu-cse-01',
        campusHandle: 'alice_cse',
        firstName: 'Alice',
        lastName: 'Liddell',
        email: 'alice@cse.campus.edu',
        archetype: 'student',
        status: 'active',
        activeScopes: const ['sec:cse-3a'],
        studentProfile: const {'section_scope': 'sec:cse-3a'},
        permissions: const ['attendance:read'],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AttendanceScreen(
            storage: storage,
            currentUser: cseStudent,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open optical scanner
      await tester.tap(find.text('Scan Rolling QR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate capturing optical frame
      await tester.tap(find.byKey(const Key('btn-simulate-camera-feed')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify successful verification display
      expect(find.text('Attendance Recorded • Present'), findsOneWidget);
      expect(find.text('2x Units'), findsOneWidget);
      expect(find.textContaining('Prof. Margaret Hamilton'), findsOneWidget);

      // Verify record registered in active session
      final roster = await storage.getOpticalRoster(storage.activeOpticalSession!.id);
      expect(roster.length, equals(1));
      expect(roster.first.studentId, equals('usr-stu-cse-01'));
      expect(roster.first.origin, equals('optical'));
      expect(roster.first.attendanceUnits, equals(2));
      expect(roster.first.canBeRemovedByTeacher, isFalse);
    });

    testWidgets('Teacher manual addition and optical immutability rule', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final teacher = UserModel(
        id: 'usr-prof-1',
        campusHandle: 'prof_adams',
        firstName: 'John',
        lastName: 'Adams',
        email: 'jadams@campus.edu',
        archetype: 'employee',
        status: 'active',
        activeScopes: const ['sec:cse-3a'],
        assignedRoles: [
          UserRoleAssignmentModel(
            id: 'role-fac-1',
            userId: 'usr-prof-1',
            roleCode: 'faculty',
            roleName: 'Faculty',
          ),
        ],
        permissions: const ['attendance:write', 'attendance:read'],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AttendanceScreen(
            storage: storage,
            currentUser: teacher,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Launch broadcast to enter broadcast view
      await tester.tap(find.text('Broadcast Optical QR'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn-confirm-start-broadcast')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final activeSess = storage.activeOpticalSession!;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final key = utf8.encode(activeSess.sessionSecret);
      final sigData = '${activeSess.id}:1:$nowSec:123456';
      final hmacSha256 = Hmac(sha256, key);
      final sig = hmacSha256.convert(utf8.encode(sigData)).toString().substring(0, 16);

      final opticalPacket = OpticalFramePacket(
        sessionId: activeSess.id,
        courseCode: 'CS301',
        courseName: 'Database Management Systems',
        subjectCode: 'CS301',
        subjectName: 'Database Management Systems',
        teacherId: teacher.id,
        teacherName: teacher.fullName,
        sectionScope: 'sec:cse-3a',
        room: 'LH-101',
        sequence: 1,
        timestamp: nowSec,
        nonce: '123456',
        fingerprintCode: 'fp-test-1',
        durationHours: 2,
        attendanceUnits: 2,
        signature: sig,
      );

      final studentUser = UserModel(
        id: 'stu-opt-1',
        campusHandle: 'opt_student',
        firstName: 'Optical',
        lastName: 'Student',
        email: 'optical@campus.edu',
        archetype: 'student',
        status: 'active',
        activeScopes: const ['sec:cse-3a'],
        studentProfile: const {'section_scope': 'sec:cse-3a'},
      );

      await storage.verifyOpticalAttendance(
        packet: opticalPacket,
        student: studentUser,
        fingerprintCode: 'fp-test-1',
        studentSignature: 'student-sig-1',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Add a student manually
      final addManualBtn = find.byKey(const Key('btn-open-manual-add-dialog'));
      expect(addManualBtn, findsOneWidget);
      await tester.tap(addManualBtn);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('input-manual-student-id')), 'STU-MANUAL-77');
      await tester.enterText(find.byKey(const Key('input-manual-student-name')), 'Grace Hopper');
      await tester.enterText(find.byKey(const Key('input-manual-student-handle')), '@gracehopper');

      await tester.tap(find.byKey(const Key('btn-submit-manual-student')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify both students present in roster
      expect(find.widgetWithText(ListTile, 'Grace Hopper'), findsOneWidget);
      expect(find.text('MANUAL'), findsOneWidget);

      // Verify manual record has remove button and remove it
      final manualRemoveButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.key != null && widget.key.toString().contains('STU-MANUAL-77'),
      );
      expect(manualRemoveButton, findsOneWidget);
      await tester.tap(manualRemoveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Grace Hopper was removed from UI roster
      expect(find.widgetWithText(ListTile, 'Grace Hopper'), findsNothing);

      // Immutability rule: Attempting to remove optical student throws exception
      expect(
        () => storage.removeManualOpticalRecord(
          sessionId: activeSess.id,
          recordId: 'rec-${activeSess.id}-stu-opt-1',
        ),
        throwsA(isA<Exception>()),
      );

      // Clean up timers
      await tester.tap(find.text('Conclude & Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
