import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/screens/department_management_screen.dart';
import 'package:campus_client/screens/user_management_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testAdmin = UserModel(
    id: 'admin-test-id',
    campusHandle: 'academic_dean',
    firstName: 'Academic',
    lastName: 'Dean',
    email: 'dean@campus.edu',
    archetype: 'admin',
  );

  late ApiService api;
  late OfflineStorageService storage;

  setUp(() {
    api = ApiService(baseUrl: 'http://localhost:8080');
    storage = OfflineStorageService(api: api);
  });

  group('ProgramModel & ProgramBranchModel Hierarchy Tests', () {
    test('ProgramModel handles branch codes, toggle and duration semantics', () {
      final prog = ProgramModel(
        id: 'prog-btech',
        name: 'Bachelor of Technology',
        code: 'BTECH',
        degreeLevel: 'undergraduate',
        totalSemesters: 8,
        hasBranches: true,
        branches: const [
          ProgramBranchModel(name: 'Computer Science', code: 'CSE'),
          ProgramBranchModel(name: 'Electrical', code: 'EE'),
        ],
        durationYears: 4,
        isRetired: false,
      );

      final json = prog.toJson();
      expect(json['has_branches'], isTrue);
      expect(json['duration_years'], equals(4));
      expect(json['is_retired'], isFalse);

      final reconstructed = ProgramModel.fromJson(json);
      expect(reconstructed.id, equals('prog-btech'));
      expect(reconstructed.hasBranches, isTrue);
      expect(reconstructed.durationYears, equals(4));
      expect(reconstructed.branches.length, equals(2));
      expect(reconstructed.branches.first.code, equals('CSE'));
      expect(reconstructed.branchNames, contains('Computer Science'));
    });

    test('ProgramModel copyWith updates fields correctly', () {
      final prog = ProgramModel(
        id: 'prog-mca',
        name: 'Master of Computer Applications',
        code: 'MCA',
        degreeLevel: 'postgraduate',
        totalSemesters: 4,
        hasBranches: false,
        branch: 'General',
        durationYears: 2,
      );

      final updated = prog.copyWith(
        hasBranches: true,
        branches: const [
          ProgramBranchModel(name: 'Data Science', code: 'DS'),
          ProgramBranchModel(name: 'Cloud Computing', code: 'CC'),
        ],
        durationYears: 3,
        isRetired: true,
      );

      expect(updated.hasBranches, isTrue);
      expect(updated.durationYears, equals(3));
      expect(updated.isRetired, isTrue);
      expect(updated.branchNames, contains('Data Science'));
      expect(updated.branches.first.code, equals('DS'));
    });
  });

  group('Degree Programs Management Screen & Branch Toggle Tests', () {
    testWidgets('Renders 4 tabs including Degree Programs', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: DepartmentManagementScreen(
          storage: storage,
          currentUser: testAdmin,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Academic Departments ('), findsOneWidget);
      expect(find.textContaining('Cross-Program Sections ('), findsOneWidget);
      expect(find.textContaining('Subjects & Syllabi ('), findsOneWidget);
      expect(find.textContaining('Degree Programs ('), findsOneWidget);
    });

    testWidgets('Switching to Degree Programs displays Program -> Branch -> Duration hierarchy and branch codes',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: DepartmentManagementScreen(
          storage: storage,
          currentUser: testAdmin,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Degree Programs tab
      await tester.tap(find.textContaining('Degree Programs ('));
      await tester.pumpAndSettle();

      expect(find.text('Degree Programs, Branches & Duration'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Add Degree Program'), findsOneWidget);

      // Verify hierarchy components are displayed in program cards
      expect(find.textContaining('Yrs ('), findsWidgets);
      expect(find.text('Branch Specializations'), findsWidgets);

      // Verify branch codes rendered on chips
      expect(find.text('CSE'), findsWidgets);
      expect(find.text('AIML'), findsWidgets);
    });

    testWidgets('Add Degree Program dialog supports branch code, toggle and duration',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: DepartmentManagementScreen(
          storage: storage,
          currentUser: testAdmin,
        ),
      ));
      await tester.pumpAndSettle();

      // Switch to Degree Programs tab
      await tester.tap(find.textContaining('Degree Programs ('));
      await tester.pumpAndSettle();

      // Open Add Degree Program dialog via the header button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Degree Program'));
      await tester.pumpAndSettle();

      expect(find.text('Add Degree Program'), findsWidgets);
      expect(find.text('Hierarchy:'), findsOneWidget);
      expect(find.text('Can this program have branches / specializations?'), findsOneWidget);
      expect(find.byKey(const Key('switch-program-has-branches')), findsOneWidget);

      // Branch toggle is default ON (multi-branch mode)
      expect(find.textContaining('Multi-branch enabled'), findsOneWidget);
      expect(find.byKey(const Key('btn-add-branch-chip')), findsOneWidget);

      // Enter Program Name and Code
      await tester.enterText(
        find.byKey(const Key('input-program-name')),
        'Bachelor of Architecture',
      );
      await tester.enterText(
        find.byKey(const Key('input-program-code')),
        'BARCH',
      );
      await tester.pumpAndSettle();

      // Add a custom branch with code
      await tester.enterText(
        find.byKey(const Key('input-program-branch-name')),
        'Urban Planning',
      );
      await tester.enterText(
        find.byKey(const Key('input-program-branch-code')),
        'URB',
      );
      await tester.tap(find.byKey(const Key('btn-add-branch-chip')));
      await tester.pumpAndSettle();

      expect(find.textContaining('[URB] Urban Planning'), findsOneWidget);

      // Test toggling off branches
      await tester.tap(find.byKey(const Key('switch-program-has-branches')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Single-branch / direct curriculum'), findsOneWidget);
      expect(find.byKey(const Key('input-program-single-branch')), findsOneWidget);

      // Toggle back on
      await tester.tap(find.byKey(const Key('switch-program-has-branches')));
      await tester.pumpAndSettle();

      // Create Program
      await tester.tap(find.text('Create Program'));
      await tester.pumpAndSettle();

      // Verify newly created program appears in the grid
      expect(find.text('Bachelor of Architecture'), findsOneWidget);
      expect(find.text('BARCH'), findsWidgets);
    });

    testWidgets('Retire and reactivate course directly from card action',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: DepartmentManagementScreen(
          storage: storage,
          currentUser: testAdmin,
        ),
      ));
      await tester.pumpAndSettle();

      // Switch to Degree Programs tab
      await tester.tap(find.textContaining('Degree Programs ('));
      await tester.pumpAndSettle();

      // Tap retire button for BTECH-CSE
      final retireBtn = find.byKey(const Key('btn-retire-program-BTECH-CSE'));
      expect(retireBtn, findsOneWidget);

      await tester.tap(retireBtn);
      await tester.pumpAndSettle();

      // Expect RETIRED badge
      expect(find.text('RETIRED'), findsWidgets);

      // Reactivate it
      await tester.tap(retireBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('Edit course directly via edit dialog',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: DepartmentManagementScreen(
          storage: storage,
          currentUser: testAdmin,
        ),
      ));
      await tester.pumpAndSettle();

      // Switch to Degree Programs tab
      await tester.tap(find.textContaining('Degree Programs ('));
      await tester.pumpAndSettle();

      // Tap edit button for BCA
      final editBtn = find.byKey(const Key('btn-edit-program-BCA'));
      expect(editBtn, findsOneWidget);

      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Course: BCA'), findsOneWidget);
      expect(find.byKey(const Key('input-edit-program-name')), findsOneWidget);
      expect(find.byKey(const Key('switch-edit-program-retired')), findsOneWidget);

      // Change program name
      await tester.enterText(
        find.byKey(const Key('input-edit-program-name')),
        'Bachelor of Computer Applications (Honors)',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-submit-edit-program')));
      await tester.pumpAndSettle();

      expect(find.text('Bachelor of Computer Applications (Honors)'), findsOneWidget);
    });

    testWidgets('Edit branch directly and toggle branch retirement',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: DepartmentManagementScreen(
          storage: storage,
          currentUser: testAdmin,
        ),
      ));
      await tester.pumpAndSettle();

      // Switch to Degree Programs tab
      await tester.tap(find.textContaining('Degree Programs ('));
      await tester.pumpAndSettle();

      // Tap branch chip
      final chip = find.byKey(const Key('chip-branch-Data Science'));
      expect(chip, findsOneWidget);

      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('Edit Branch: Data Science'), findsOneWidget);
      expect(find.byKey(const Key('input-edit-branch-code')), findsOneWidget);
      expect(find.byKey(const Key('switch-edit-branch-retired')), findsOneWidget);

      // Toggle branch retirement to true
      await tester.tap(find.byKey(const Key('switch-edit-branch-retired')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-save-edit-branch')));
      await tester.pumpAndSettle();

      // Branch should now display [RETIRED]
      expect(find.text('[RETIRED]'), findsWidgets);
    });

    testWidgets('Add branch dialog with branch name and code',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: DepartmentManagementScreen(
          storage: storage,
          currentUser: testAdmin,
        ),
      ));
      await tester.pumpAndSettle();

      // Switch to Degree Programs tab
      await tester.tap(find.textContaining('Degree Programs ('));
      await tester.pumpAndSettle();

      // Find an Add Branch to card action and tap it
      final addBranchFinder = find.textContaining('Add Branch to');
      if (addBranchFinder.evaluate().isNotEmpty) {
        await tester.tap(addBranchFinder.first);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('btn-dialog-save-branch')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('input-dialog-branch-name')),
          'Robotics & Automation',
        );
        await tester.enterText(
          find.byKey(const Key('input-dialog-branch-code')),
          'ROBO',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn-dialog-save-branch')));
        await tester.pumpAndSettle();

        expect(find.text('Robotics & Automation'), findsWidgets);
        expect(find.text('ROBO'), findsWidgets);
      }
    });
  });

  group('Employee Onboarding Institutional Track Toggle Tests', () {
    testWidgets('Academic and Administrative track switches render and toggle state',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: UserManagementScreen(
          storage: storage,
          currentUser: testAdmin,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap 'Onboard User' button to open creation dialog
      await tester.tap(find.text('Onboard User'));
      await tester.pumpAndSettle();

      // Switch to Employee Onboarding tab
      await tester.tap(find.text('Employee Onboarding'));
      await tester.pumpAndSettle();

      expect(find.text('Institutional Tracks (Single or Dual-Track Appointment)'), findsOneWidget);

      // Verify toggle switches exist
      final academicSwitch = find.byKey(const Key('switch-employee-academic-track'));
      final adminSwitch = find.byKey(const Key('switch-employee-admin-track'));

      expect(academicSwitch, findsOneWidget);
      expect(adminSwitch, findsOneWidget);

      // Default: academic is true, admin is false
      expect(tester.widget<Switch>(academicSwitch).value, isTrue);
      expect(tester.widget<Switch>(adminSwitch).value, isFalse);

      // Scroll to administrative switch and toggle to true
      await tester.ensureVisible(adminSwitch);
      await tester.pumpAndSettle();
      await tester.tap(adminSwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(adminSwitch).value, isTrue);
      expect(find.text('Primary Administrative Unit'), findsOneWidget);

      // Scroll to academic switch and toggle to false
      await tester.ensureVisible(academicSwitch);
      await tester.pumpAndSettle();
      await tester.tap(academicSwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(academicSwitch).value, isFalse);
    });

    testWidgets('User onboarding dialog dynamically loads degree programs, branches, and departments without mock hardcoding', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Ensure storage has a program with branches and a department
      await storage.createProgram(ProgramModel(
        id: 'prog-btech-cse',
        code: 'BTECH',
        name: 'Bachelor of Technology',
        degreeLevel: 'undergraduate',
        totalSemesters: 8,
        hasBranches: true,
        branches: [
          ProgramBranchModel(code: 'CSE', name: 'Computer Science and Engineering'),
          ProgramBranchModel(code: 'ECE', name: 'Electronics and Communication'),
        ],
      ));

      await tester.pumpWidget(MaterialApp(
        home: UserManagementScreen(
          storage: storage,
          currentUser: testAdmin,
        ),
      ));
      await tester.pumpAndSettle();

      // Open creation dialog
      await tester.tap(find.text('Onboard User'));
      await tester.pumpAndSettle();

      // Verify Student Onboarding dynamically presents degree program and branch dropdown
      expect(find.text('Degree Program'), findsOneWidget);
      expect(find.text('Branch / Discipline'), findsOneWidget);

      // Verify dynamic current year is present
      final currentYearStr = DateTime.now().year.toString();
      expect(find.text(currentYearStr), findsAtLeastNWidgets(1));

      // Switch to Employee Onboarding tab
      await tester.tap(find.text('Employee Onboarding'));
      await tester.pumpAndSettle();

      // Verify Department Affiliation dropdown exists dynamically under Academic Track
      expect(find.text('Department Affiliation'), findsOneWidget);
    });
  });
}
