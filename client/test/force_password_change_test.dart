import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/screens/login_screen.dart';
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
    });
  });
}
