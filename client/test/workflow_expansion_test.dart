import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/screens/home_screen.dart';
import 'package:campus_client/screens/mess_screen.dart';
import 'package:campus_client/screens/notices_screen.dart';
import 'package:campus_client/screens/sessional_exam_screen.dart';
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

  group('Release Readiness - Workflow Expansion Tests', () {
    testWidgets('Notice Issuing Portal: Admin publishes scoped notice', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adminUser = UserModel(
        id: 'usr-admin-1',
        campusHandle: 'admin_exec',
        firstName: 'Governance',
        lastName: 'Admin',
        email: 'admin@campus.edu',
        archetype: 'employee',
        status: 'active',
        permissions: ['*'],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoticesScreen(
            storage: storage,
            userScopes: const ['global', 'dept:cse'],
            currentUser: adminUser,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final issueNoticeBtn = find.byKey(const Key('btn-issue-notice'));
      expect(issueNoticeBtn, findsOneWidget);

      await tester.tap(issueNoticeBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog-publish-notice')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('input-notice-title')),
        'Annual Institutional Symposium 2026',
      );
      await tester.enterText(
        find.byKey(const Key('input-notice-content')),
        'All academic departments are invited to submit papers for the symposium.',
      );

      final submitBtn = find.byKey(const Key('btn-submit-notice'));
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Annual Institutional Symposium 2026'), findsOneWidget);
    });

    testWidgets('Mess Menu Authoring: Caterer adds meal slot to timetable', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final contractorUser = UserModel(
        id: 'usr-vendor-1',
        campusHandle: 'caterer_lead',
        firstName: 'Mess',
        lastName: 'Contractor',
        email: 'caterer@campus.edu',
        archetype: 'external',
        status: 'active',
        contractorProfile: {
          'vendor_organization': 'Apex Campus Caterers',
          'gate_pass_id': 'GP-FOOD-2026',
          'permitted_scopes': ['building:canteen'],
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessScreen(
            storage: storage,
            currentUser: contractorUser,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final addMealBtn = find.byKey(const Key('btn-add-mess-meal'));
      expect(addMealBtn, findsOneWidget);

      await tester.tap(addMealBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog-add-mess-meal')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('input-add-meal-title')), 'Evening Herbal Tea & Snacks');
      await tester.enterText(find.byKey(const Key('input-add-meal-summary')), 'Fresh biscuits and herbal tea.');
      await tester.enterText(find.byKey(const Key('input-add-meal-items')), 'Herbal Tea, Cookies, Samosa');

      final submitMealBtn = find.byKey(const Key('btn-save-new-meal'));
      expect(submitMealBtn, findsOneWidget);
      await tester.tap(submitMealBtn);
      await tester.pumpAndSettle();

      final meals = await storage.getMessTimetable();
      expect(meals.any((m) => m.title == 'Evening Herbal Tea & Snacks'), isTrue);
    });

    test('Coursework Assignments & Grading: Storage service lifecycle', () async {
      final createdAssign = await storage.createAssignment({
        'course_id': 'cs402',
        'section_scope': 'sec:cse-4a',
        'title': 'Machine Learning Lab Assignment 1',
        'description': 'Implement linear regression gradient descent from scratch in Python.',
        'due_date': '2026-12-01T23:59:59Z',
        'max_score': 30,
        'weightage': 15,
        'created_by': 'prof-sharma',
      });

      expect(createdAssign.id, isNotEmpty);
      expect(createdAssign.title, 'Machine Learning Lab Assignment 1');

      final assigns = await storage.getAssignments(sectionId: 'sec:cse-4a', subjectId: 'cs402');
      expect(assigns.length, 1);
      expect(assigns.first.id, createdAssign.id);

      final submission = await storage.submitAssignment({
        'assignment_id': createdAssign.id,
        'student_id': 'stud-001',
        'student_name': 'Rohan Gupta',
        'student_roll': '26CS001',
        'content': 'Code repository submitted with notebook and test benchmarks.',
      });

      expect(submission.id, isNotEmpty);
      expect(submission.studentName, 'Rohan Gupta');
      expect(submission.marksAwarded, isNull);

      final subs = await storage.getSubmissions(createdAssign.id);
      expect(subs.length, 1);

      final graded = await storage.gradeSubmission(
        submissionId: submission.id,
        marks: 28,
        feedback: 'Clean vectorized implementation with proper convergence proofs.',
        gradedBy: 'prof-sharma',
      );

      expect(graded.marksAwarded, 28);
      expect(graded.feedback, contains('Clean vectorized implementation'));
    });

    testWidgets('Coursework & Grading Screen: Faculty opens assignment UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final facultyUser = UserModel(
        id: 'usr-fac-1',
        campusHandle: 'prof_roy',
        firstName: 'Ananya',
        lastName: 'Roy',
        email: 'ananya@campus.edu',
        archetype: 'employee',
        status: 'active',
        employeeRecord: {'is_academic': true},
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SessionalExamScreen(
            storage: storage,
            currentUser: facultyUser,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final courseworkTab = find.text('Coursework & Assignments');
      expect(courseworkTab, findsOneWidget);
      await tester.tap(courseworkTab);
      await tester.pumpAndSettle();

      final createBtn = find.byKey(const Key('btn-create-assignment'));
      expect(createBtn, findsOneWidget);

      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog-create-assignment')), findsOneWidget);
    });

    testWidgets('Contractor Digital Gate Pass & Checkpoint Access Logging', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final contractorUser = UserModel(
        id: 'usr-contractor-99',
        campusHandle: 'vendor_security',
        firstName: 'Suresh',
        lastName: 'Verma',
        email: 'suresh@apexservices.in',
        archetype: 'external',
        status: 'active',
        contractorProfile: {
          'vendor_organization': 'Apex Facility Services',
          'gate_pass_id': 'GP-SEC-2026-091',
          'permitted_scopes': ['building:facilities', 'building:canteen'],
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            storage: storage,
            currentUser: contractorUser,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final gatePassCard = find.byKey(const Key('card-contractor-gate-pass'));
      expect(gatePassCard, findsOneWidget);

      await tester.tap(gatePassCard);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog-contractor-gate-pass')), findsOneWidget);
      expect(find.text('GP-SEC-2026-091'), findsOneWidget);
      expect(find.text('Apex Facility Services'), findsOneWidget);
      expect(find.text('ACTIVE • VERIFIED'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('input-gate-vehicle-reg')),
        'DL-04-CA-5678',
      );

      final checkInBtn = find.byKey(const Key('btn-log-gate-checkin'));
      expect(checkInBtn, findsOneWidget);
      await tester.tap(checkInBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Check-In recorded at Gate 1'), findsOneWidget);
      expect(find.textContaining('Biometric & pass token logged in gate ledger.'), findsOneWidget);

      final checkOutBtn = find.byKey(const Key('btn-log-gate-checkout'));
      expect(checkOutBtn, findsOneWidget);
      await tester.tap(checkOutBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Check-Out recorded at Gate 1'), findsOneWidget);
      expect(find.textContaining('Access session closed successfully'), findsOneWidget);
    });
  });
}
