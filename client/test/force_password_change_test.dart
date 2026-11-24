import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/screens/login_screen.dart';
import 'package:campus_client/screens/user_management_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/widgets/force_password_change_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiService api;
  late OfflineStorageService storage;

  setUp(() {
    api = ApiService(baseUrl: 'http://localhost:8080');
    storage = OfflineStorageService(api: api, enableMockSeeding: false);
  });

  group('First-Time User Creation & Mandatory Password Change Tests', () {
    test('User creation sets mustChangePassword to true and username equals initial password', () async {
      final student = await storage.createStudent({
        'first_name': 'Rohit',
        'last_name': 'Kumar',
        'email': 'rohit@campus.edu',
        'admission_year': 2026,
        'entry_type': 'regular',
        'program': 'btech',
      });

      expect(student.mustChangePassword, isTrue);
      expect(student.campusHandle, isNotEmpty);

      final employee = await storage.createEmployee({
        'first_name': 'Pooja',
        'last_name': 'Sharma',
        'email': 'pooja@campus.edu',
        'joining_year': 2026,
        'employment_type': 'permanent',
        'is_academic': true,
      });

      expect(employee.mustChangePassword, isTrue);
      expect(employee.campusHandle, isNotEmpty);

      final contractor = await storage.createContractor({
        'first_name': 'Mukesh',
        'last_name': 'Singh',
        'vendor_organization': 'Campus Security Services',
        'onboarding_year': 2026,
      });

      expect(contractor.mustChangePassword, isTrue);
      expect(contractor.campusHandle, isNotEmpty);
    });

    testWidgets('First-time login forces user to change temporary initial password before entering', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create new student user
      final student = await storage.createStudent({
        'first_name': 'Ankit',
        'last_name': 'Verma',
        'email': 'ankit@campus.edu',
        'admission_year': 2026,
        'entry_type': 'regular',
        'program': 'btech',
      });

      UserModel? loggedInUser;

      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(
          storage: storage,
          onLoginSuccess: (user) {
            loggedInUser = user;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Enter campus handle and initial password (which equals the campus handle)
      final handleField = find.byType(TextFormField).first;
      final passField = find.byType(TextFormField).last;

      await tester.enterText(handleField, student.campusHandle);
      await tester.enterText(passField, student.campusHandle);
      await tester.pumpAndSettle();

      // Tap Sign In button
      final signInBtn = find.text('Sign In');
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      // Verify that ForcePasswordChangeDialog appears automatically!
      expect(find.byType(ForcePasswordChangeDialog), findsOneWidget);
      expect(find.text('Password Change Required'), findsOneWidget);
      expect(find.textContaining('temporary password'), findsAtLeastNWidgets(1));

      // User has not been allowed into the dashboard yet
      expect(loggedInUser, isNull);

      // Attempt submitting without entering new password (length validation)
      final submitBtn = find.byKey(const Key('btn-submit-password-change'));
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('New password must be at least 6 characters.'), findsOneWidget);

      // Attempt setting same password as initial username
      final newPassField = find.widgetWithText(TextFormField, 'Minimum 6 characters');
      final confirmPassField = find.widgetWithText(TextFormField, 'Re-enter new password');

      await tester.enterText(newPassField, student.campusHandle);
      await tester.enterText(confirmPassField, student.campusHandle);
      await tester.pumpAndSettle();

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('New password must be different from your temporary initial password.'), findsOneWidget);

      // Attempt mismatched passwords
      await tester.enterText(newPassField, 'securePass2026!');
      await tester.enterText(confirmPassField, 'differentPass2026!');
      await tester.pumpAndSettle();

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('New password and confirmation do not match.'), findsOneWidget);

      // Enter matching valid permanent password
      await tester.enterText(newPassField, 'securePass2026!');
      await tester.enterText(confirmPassField, 'securePass2026!');
      await tester.pumpAndSettle();

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify dialog closes and onLoginSuccess is invoked with mustChangePassword = false
      expect(find.byType(ForcePasswordChangeDialog), findsNothing);
      expect(loggedInUser, isNotNull);
      expect(loggedInUser!.mustChangePassword, isFalse);

      // Verify subsequent login directly signs in with new password without prompting password change
      final subsequentUser = await storage.authenticate(student.campusHandle, 'securePass2026!');
      expect(subsequentUser.mustChangePassword, isFalse);

      // And old temporary initial password is now rejected
      expect(
        () async => await storage.authenticate(student.campusHandle, student.campusHandle),
        throwsA(isA<Exception>()),
      );
    });

    test('User created with custom initial password can authenticate and must change password on first login', () async {
      const customPass = 'InitPass!2026';
      final student = await storage.createStudent({
        'first_name': 'Meera',
        'last_name': 'Nair',
        'email': 'meera@campus.edu',
        'admission_year': 2026,
        'entry_type': 'regular',
        'program': 'btech',
        'initial_password': customPass,
      });

      expect(student.mustChangePassword, isTrue);
      expect(student.initialPassword, equals(customPass));

      // 1. Initial login with custom initial password succeeds
      final loggedIn = await storage.authenticate(student.campusHandle, customPass);
      expect(loggedIn.mustChangePassword, isTrue);

      // 2. Change password to permanent password
      final changed = await storage.changePassword(
        identifier: student.campusHandle,
        currentPassword: customPass,
        newPassword: 'MyPermanentPassword2026!',
      );
      expect(changed.mustChangePassword, isFalse);

      // 3. Old initial password is now invalid
      expect(
        () async => await storage.authenticate(student.campusHandle, customPass),
        throwsA(isA<Exception>()),
      );

      // 4. Subsequent login with new permanent password succeeds and does not require password change
      final finalUser = await storage.authenticate(student.campusHandle, 'MyPermanentPassword2026!');
      expect(finalUser.mustChangePassword, isFalse);
    });

    testWidgets('Admin onboards user and credentials dialog presents username, email, and initial password with mandatory notice', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testAdmin = UserModel(
        id: 'usr-campus_admin',
        campusHandle: 'campus_admin',
        firstName: 'Campus',
        lastName: 'Admin',
        email: 'admin@campus.edu',
        archetype: 'employee',
        permissions: const ['*'],
      );

      // Seed an active program so the student form has a valid degree program
      await storage.createProgram(ProgramModel(
        id: 'prog-btech-cse',
        code: 'BTECH-CSE',
        name: 'B.Tech Computer Science',
        degreeLevel: 'undergraduate',
        totalSemesters: 8,
        durationYears: 4,
      ));

      await tester.pumpWidget(MaterialApp(
        home: UserManagementScreen(
          storage: storage,
          currentUser: testAdmin,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap 'Onboard User'
      await tester.tap(find.text('Onboard User'));
      await tester.pumpAndSettle();

      // Enter First and Last Name in the creation dialog
      final firstNameField = find.widgetWithText(TextField, 'Enter first name');
      final lastNameField = find.widgetWithText(TextField, 'Enter last name');
      await tester.enterText(firstNameField, 'Deepak');
      await tester.enterText(lastNameField, 'Joshi');
      await tester.pumpAndSettle();

      // Verify that initial credential configuration section renders
      expect(find.text('Initial Account Credentials'), findsOneWidget);
      expect(find.text('Auto-generate secure temporary password'), findsOneWidget);
      expect(find.text('Password Change Mandatory'), findsOneWidget);

      // Tap Admit Student
      await tester.tap(find.text('Admit Student'));
      await tester.pumpAndSettle();

      // Verify Credentials Modal is shown!
      expect(find.text('Account Created Successfully'), findsOneWidget);
      expect(find.text('Mandatory First-Login Password Change'), findsOneWidget);
      expect(find.text('Campus Handle (Username)'), findsOneWidget);
      expect(find.text('Institutional Email'), findsOneWidget);
      expect(find.text('Temporary Password'), findsOneWidget);
      expect(find.text('Copy All Credentials'), findsOneWidget);

      // Tap Done to dismiss
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Account Created Successfully'), findsNothing);
    });
  });
}
