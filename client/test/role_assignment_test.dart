import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/screens/user_management_screen.dart';
import 'package:campus_client/screens/user_profile_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/widgets/assign_role_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Role and Permission Assignment Feature Tests', () {
    testWidgets('AssignRoleDialog assigns employee coordinator and library incharge roles', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = ApiService(baseUrl: 'http://localhost:8080');
      final storage = OfflineStorageService(api: api);

      final employee = UserModel(
        id: 'usr-prof_test',
        campusHandle: 'prof_test',
        firstName: 'Test',
        lastName: 'Professor',
        email: 'prof_test@campus.edu',
        phone: '+91 98765 00000',
        archetype: 'employee',
        status: 'active',
      );
      storage.registerUser(employee);

      UserModel? updatedUser;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AssignRoleDialog(
            user: employee,
            storage: storage,
            onAssigned: (updated) {
              updatedUser = updated;
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Assign Institutional Role & Permissions'), findsOneWidget);

      // Open dropdown and select Library In-Charge
      await tester.tap(find.byKey(const Key('dropdown-role-preset')));
      await tester.pumpAndSettle();

      expect(find.text('Library In-Charge'), findsWidgets);
      await tester.tap(find.text('Library In-Charge').last);
      await tester.pumpAndSettle();

      expect(find.text('library:approve'), findsWidgets);

      // Confirm assignment
      await tester.tap(find.byKey(const Key('btn-confirm-assign-role')));
      await tester.pumpAndSettle();

      expect(updatedUser, isNotNull);
      expect(updatedUser!.assignedRoles.any((r) => r.roleCode == 'library_incharge'), isTrue);
      expect(updatedUser!.hasPermission('library:approve'), isTrue);
    });

    testWidgets('AssignRoleDialog assigns student club president with dynamic club scope and class representative', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = ApiService(baseUrl: 'http://localhost:8080');
      final storage = OfflineStorageService(api: api);

      final student = UserModel(
        id: 'usr-student_test',
        campusHandle: 'student_test',
        firstName: 'Student',
        lastName: 'Test',
        email: 'student_test@campus.edu',
        phone: '+91 98765 11111',
        archetype: 'student',
        status: 'active',
      );
      storage.registerUser(student);

      UserModel? updatedUser;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AssignRoleDialog(
            user: student,
            storage: storage,
            onAssigned: (updated) {
              updatedUser = updated;
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Assign Institutional Role & Permissions'), findsOneWidget);

      // Open dropdown and select Club President
      await tester.tap(find.byKey(const Key('dropdown-role-preset')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Club President (e.g. Club:Example:president)').last);
      await tester.pumpAndSettle();

      // Enter custom club name
      final clubInput = find.byKey(const Key('input-club-name'));
      expect(clubInput, findsOneWidget);
      await tester.enterText(clubInput, 'Example');
      await tester.pumpAndSettle();

      // Verify scope preview reflects Club:Example:president
      final scopeInput = find.byKey(const Key('input-role-scope'));
      expect(scopeInput, findsOneWidget);
      expect(find.text('Club:Example:president'), findsOneWidget);

      // Confirm assignment
      await tester.tap(find.byKey(const Key('btn-confirm-assign-role')));
      await tester.pumpAndSettle();

      expect(updatedUser, isNotNull);
      expect(updatedUser!.isClubPresident, isTrue);
      expect(updatedUser!.hasPermission('club:publish_event'), isTrue);
      expect(updatedUser!.hasPermission('club:spend_budget'), isTrue);
    });

    testWidgets('UserProfileScreen provides Assign Role & Permissions button for campus admin', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = ApiService(baseUrl: 'http://localhost:8080');
      final storage = OfflineStorageService(api: api);

      final admin = OfflineStorageService.getMockUserForHandle('campus_admin');
      final student = UserModel(
        id: 'usr-test_profile_student',
        campusHandle: 'test_profile_student',
        firstName: 'Aarav',
        lastName: 'Sharma',
        email: 'aarav@campus.edu',
        phone: '+91 98111 55555',
        archetype: 'student',
        status: 'active',
      );
      storage.registerUser(student);

      await tester.pumpWidget(MaterialApp(
        home: UserProfileScreen(
          storage: storage,
          userIdentifier: student.id,
          currentAdminUser: admin,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify assign role buttons are rendered
      final assignRoleBtn = find.byKey(const Key('btn-assign-role'));
      expect(assignRoleBtn, findsOneWidget);

      await tester.ensureVisible(assignRoleBtn);
      await tester.pumpAndSettle();

      // Tap assign role button
      await tester.tap(assignRoleBtn);
      await tester.pumpAndSettle();

      expect(find.text('Assign Institutional Role & Permissions'), findsOneWidget);
      expect(find.textContaining('Aarav Sharma (test_profile_student)'), findsOneWidget);

      // Confirm default Class Representative assignment
      await tester.tap(find.byKey(const Key('btn-confirm-assign-role')));
      await tester.pumpAndSettle();

      expect(find.text('Class Representative'), findsWidgets);
    });

    testWidgets('UserManagementScreen provides Assign Role button on user directory cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = ApiService(baseUrl: 'http://localhost:8080');
      final storage = OfflineStorageService(api: api);

      final employee = UserModel(
        id: 'usr-card_employee',
        campusHandle: 'card_employee',
        firstName: 'Sunita',
        lastName: 'Gupta',
        email: 'sunita@campus.edu',
        phone: '+91 98222 66666',
        archetype: 'employee',
        status: 'active',
      );
      storage.registerUser(employee);

      await tester.pumpWidget(MaterialApp(
        home: UserManagementScreen(
          storage: storage,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Assign Role button on directory card
      final cardAssignBtn = find.byKey(Key('btn-card-assign-role-${employee.campusHandle}'));
      expect(cardAssignBtn, findsOneWidget);

      await tester.ensureVisible(cardAssignBtn);
      await tester.pumpAndSettle();

      await tester.tap(cardAssignBtn);
      await tester.pumpAndSettle();

      expect(find.text('Assign Institutional Role & Permissions'), findsOneWidget);
      expect(find.textContaining('Sunita Gupta (card_employee)'), findsOneWidget);

      // Open dropdown and select Library In-Charge
      await tester.tap(find.byKey(const Key('dropdown-role-preset')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library In-Charge').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-confirm-assign-role')));
      await tester.pumpAndSettle();

      expect(find.text('Library In-Charge'), findsWidgets);
    });
  });
}
