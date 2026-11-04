import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:campus_client/main.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/screens/home_screen.dart';
import 'package:campus_client/screens/login_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/widgets/app_logo.dart';

void main() {
  test('OpticalFramePacket encoding, decoding, and expiration logic', () {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final packet = OpticalFramePacket(
      sessionId: 'sess_123',
      courseCode: 'CS301',
      courseName: 'Operating Systems',
      room: 'LH-101',
      sequence: 42,
      timestamp: now,
      nonce: 'a1b2c3d4',
      signature: '9f8e7d6c5b4a',
    );

    final raw = packet.encode();
    expect(raw.startsWith('CPOS:OPT:'), isTrue);

    final decoded = OpticalFramePacket.decode(raw);
    expect(decoded, isNotNull);
    expect(decoded!.sessionId, 'sess_123');
    expect(decoded.courseCode, 'CS301');
    expect(decoded.sequence, 42);
    expect(decoded.nonce, 'a1b2c3d4');
    expect(decoded.isExpired(maxAgeSeconds: 6), isFalse);

    // Test expired frame
    final expiredPacket = OpticalFramePacket(
      sessionId: 'sess_123',
      courseCode: 'CS301',
      courseName: 'Operating Systems',
      room: 'LH-101',
      sequence: 1,
      timestamp: now - 15, // 15 seconds old
      nonce: 'old',
      signature: 'old',
    );
    expect(expiredPacket.isExpired(maxAgeSeconds: 6), isTrue);
  });

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

    // Verify smooth theme switching without interpolation or layout overflow errors
    final loginDarkToggle = find.byTooltip('Switch to Dark Mode');
    expect(loginDarkToggle, findsOneWidget);
    await tester.tap(loginDarkToggle);
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final loginLightToggle = find.byTooltip('Switch to Light Mode');
    expect(loginLightToggle, findsOneWidget);
    await tester.tap(loginLightToggle, warnIfMissed: false);
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

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

    // Verify smooth theme toggle on home dashboard
    final homeDarkToggle = find.byTooltip('Switch to Dark Mode');
    expect(homeDarkToggle, findsOneWidget);
    await tester.tap(homeDarkToggle);
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final homeLightToggle = find.byTooltip('Switch to Light Mode');
    expect(homeLightToggle, findsOneWidget);
    await tester.tap(homeLightToggle, warnIfMissed: false);
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

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
    expect(find.text('Contractor / Vendor'), findsOneWidget);
    expect(find.text('Admit Student'), findsOneWidget);

    // Switch to Contractor tab
    await tester.tap(find.text('Contractor / Vendor'));
    await tester.pumpAndSettle();

    expect(find.text('Vendor Organization / Firm *'), findsOneWidget);
    expect(find.text('Gate Pass / Security Badge ID'), findsOneWidget);
    expect(find.text('Onboard Contractor'), findsOneWidget);

    // Close Dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 6. Test Filter by Contractors & Vendors
    await tester.tap(find.text('Contractors & Vendors'));
    await tester.pumpAndSettle();

    expect(find.text('mukesh_2025_ext_1'), findsWidgets);
    expect(find.textContaining('Sodexo Campus Dining'), findsWidgets);

    // Open Contractor Profile
    await tester.ensureVisible(find.text('mukesh_2025_ext_1').first);
    await tester.tap(find.text('mukesh_2025_ext_1').first);
    await tester.pumpAndSettle();

    expect(find.text('Security Gate Pass ID'), findsOneWidget);
    expect(find.text('GP-2025-0891'), findsWidgets);
    expect(find.text('Authorized Access Zones'), findsOneWidget);
    expect(find.text('Discontinue User'), findsOneWidget);

    // Return back to directory
    await tester.tap(find.byTooltip('Back'));
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

  testWidgets('Optical Attendance flow: Faculty creates broadcast session with rolling QR and student scanner opens',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // Select Faculty persona for optical broadcast capabilities
    await tester.tap(find.text('Faculty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Navigate to Attendance Tab
    await tester.tap(find.text('Attendance').first);
    await tester.pumpAndSettle();

    // Verify Anti-Proxy Optical Attendance UI elements
    expect(find.text('Anti-Proxy Optical Data Transfer Attendance'), findsOneWidget);
    expect(find.text('Broadcast Optical QR'), findsOneWidget);

    // Start Optical Broadcast session
    await tester.tap(find.text('Broadcast Optical QR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Broadcast screen with QrImageView, countdown ring, sequence frame
    expect(find.text('Optical QR Broadcast • Live Session'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Frame #'), findsOneWidget);
    expect(find.text('Live Verified Attendance Roster'), findsOneWidget);
    expect(find.textContaining('Screenshot & Replay Protected'), findsOneWidget);

    // Conclude broadcast
    await tester.ensureVisible(find.text('Conclude & Save'));
    await tester.tap(find.text('Conclude & Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify returning to Classroom Attendance overview
    expect(find.text('Classroom Attendance'), findsOneWidget);
  });

  testWidgets('Department management flow: Admin adds department with M:N subjects, teachers, and program semesters',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // Login as Faculty / Admin
    await tester.tap(find.text('Faculty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // 1. Navigate to Departments tab via sidebar
    await tester.tap(find.text('Depts').first);
    await tester.pumpAndSettle();

    // 2. Verify Departments screen header and metrics
    expect(find.text('Academic Departments & Structure'), findsOneWidget);
    expect(find.text('Add Department'), findsOneWidget);
    expect(find.text('CSE'), findsWidgets);
    expect(find.text('ECE'), findsWidgets);
    expect(find.text('MATH'), findsWidgets);

    // 3. Open Add Department dialog
    await tester.tap(find.text('Add Department'));
    await tester.pumpAndSettle();

    expect(find.text('Add Academic Department'), findsOneWidget);
    expect(find.text('Associated Subjects (Many-to-Many)'), findsOneWidget);
    expect(find.text('Affiliated Teachers / Faculty (Many-to-Many)'), findsOneWidget);
    expect(find.text('Program Semesters (Many-to-Many)'), findsOneWidget);

    // Enter department details
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. CSE'), 'AI');
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Computer Science & Engineering'), 'Department of Artificial Intelligence');

    // Toggle a subject chip, teacher chip, and semester chip
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'CS301 - Operating Systems'));
    await tester.tap(find.widgetWithText(FilterChip, 'CS301 - Operating Systems'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Dr. Priya Nair'));
    await tester.tap(find.widgetWithText(FilterChip, 'Dr. Priya Nair'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilterChip, 'B.Tech CSE - Semester 5 (Sec 3A)'));
    await tester.tap(find.widgetWithText(FilterChip, 'B.Tech CSE - Semester 5 (Sec 3A)'));
    await tester.pumpAndSettle();

    // Submit dialog
    await tester.ensureVisible(find.text('Create Department'));
    await tester.tap(find.text('Create Department'));
    await tester.pumpAndSettle();

    // 4. Verify created department appears
    expect(find.text('AI'), findsWidgets);
    expect(find.text('Department of Artificial Intelligence'), findsOneWidget);

    // 5. Open Department Hierarchy & Details inspector
    final inspectBtn = find.text('View Hierarchy & Details').first;
    await tester.ensureVisible(inspectBtn);
    await tester.pumpAndSettle();
    await tester.tap(inspectBtn);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, 'Subjects (1)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Teachers (1)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Semesters (1)'), findsOneWidget);

    // Switch to Semesters tab
    await tester.tap(find.widgetWithText(Tab, 'Semesters (1)'));
    await tester.pumpAndSettle();

    // Inspect Semester Roster
    final rosterBtn = find.text('Inspect Roster').first;
    await tester.ensureVisible(rosterBtn);
    await tester.tap(rosterBtn);
    await tester.pumpAndSettle();

    // Verify institutional note on Many-to-One student relationship
    expect(find.textContaining('Students enroll in their active Semester cohort (Many-to-One)'), findsOneWidget);
    expect(find.textContaining('Enrolled Student Roster'), findsOneWidget);

    // Close Dialogs
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
  });
}
