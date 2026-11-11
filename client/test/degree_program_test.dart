import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/screens/department_management_screen.dart';
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

  group('ProgramModel Hierarchy Tests', () {
    test('ProgramModel handles branch toggle and duration semantics', () {
      final prog = ProgramModel(
        id: 'prog-btech',
        name: 'Bachelor of Technology',
        code: 'BTECH',
        degreeLevel: 'undergraduate',
        totalSemesters: 8,
        hasBranches: true,
        branches: ['Computer Science', 'Electrical'],
        durationYears: 4,
      );

      final json = prog.toJson();
      expect(json['has_branches'], isTrue);
      expect(json['duration_years'], equals(4));
      expect(json['branches'], contains('Computer Science'));

      final reconstructed = ProgramModel.fromJson(json);
      expect(reconstructed.id, equals('prog-btech'));
      expect(reconstructed.hasBranches, isTrue);
      expect(reconstructed.durationYears, equals(4));
      expect(reconstructed.branches.length, equals(2));
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
        branches: ['Data Science', 'Cloud Computing'],
        durationYears: 3,
      );

      expect(updated.hasBranches, isTrue);
      expect(updated.durationYears, equals(3));
      expect(updated.branches, contains('Data Science'));
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

    testWidgets('Switching to Degree Programs displays Program -> Branch -> Duration hierarchy',
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
    });

    testWidgets('Add Degree Program dialog supports branch toggle and duration',
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

      // Add a custom branch
      await tester.enterText(
        find.byKey(const Key('input-program-branch-name')),
        'Urban Planning',
      );
      await tester.tap(find.byKey(const Key('btn-add-branch-chip')));
      await tester.pumpAndSettle();

      expect(find.text('Urban Planning'), findsOneWidget);

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

    testWidgets('Add branch dialog appends branch to an existing program card',
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

        expect(find.widgetWithText(ElevatedButton, 'Add Branch'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Artificial Intelligence & Data Science'),
          'Robotics & Automation',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Branch'));
        await tester.pumpAndSettle();

        expect(find.text('Robotics & Automation'), findsWidgets);
      }
    });
  });
}
