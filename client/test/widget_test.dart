import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/main.dart';
import 'package:campus_client/screens/home_screen.dart';
import 'package:campus_client/screens/login_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/widgets/app_logo.dart';

void main() {
  testWidgets('Campus app renders login screen and logs in to home dashboard',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // 1. Verify Login Screen renders with high-definition logo, no signup, and quick persona shortcuts
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Institutional Sign In'), findsOneWidget);
    expect(find.text('Campus Handle or Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Faculty'), findsOneWidget);

    // Verify Login Screen is strictly non-scrollable (no SingleChildScrollView)
    expect(find.descendant(of: find.byType(LoginScreen), matching: find.byType(SingleChildScrollView)), findsNothing);

    // 2. Perform Login action
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // 3. Verify transition to Home Dashboard
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Academic Operations'), findsOneWidget);
    expect(find.text('Timetable'), findsWidgets);
    expect(find.text('Attendance'), findsWidgets);
    expect(find.text('Targeted Notices'), findsWidgets);
    expect(find.text('Directory & Identities'), findsOneWidget);

    // 4. Navigate to User Directory tab
    await tester.tap(find.text('Directory & Identities'));
    await tester.pumpAndSettle();

    expect(find.text('Campus Directory & Identity Management'), findsOneWidget);
    expect(find.text('Onboard User'), findsOneWidget);
    expect(find.text('harish_2025_l_btech_1'), findsWidgets);

    // 5. Open Onboard User Dialog
    await tester.tap(find.text('Onboard User'));
    await tester.pumpAndSettle();

    expect(find.text('Onboard New Campus Identity'), findsOneWidget);
    expect(find.text('Student Admission'), findsOneWidget);
    expect(find.text('Employee Onboarding'), findsOneWidget);
    expect(find.text('Admit Student'), findsOneWidget);

    // Close Dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('User profile screen displays canonical handle, identity facts, and admin controls',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Tap "View Profile" on dashboard banner
    await tester.tap(find.text('View Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Official Identity & Verification'), findsOneWidget);
    expect(find.text('Academic Enrollment & Progress'), findsOneWidget);
    expect(find.text('Scoped RBAC Authority'), findsOneWidget);
    expect(find.text('Discontinue User'), findsOneWidget);
  });
}
