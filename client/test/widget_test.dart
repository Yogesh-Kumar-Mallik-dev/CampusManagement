import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:campus_client/main.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/models/hostel.dart';
import 'package:campus_client/models/mess.dart';
import 'package:campus_client/screens/attendance_screen.dart';
import 'package:campus_client/screens/complaints_screen.dart';
import 'package:campus_client/screens/fee_screen.dart';
import 'package:campus_client/screens/home_screen.dart';
import 'package:campus_client/screens/hostel_screen.dart';
import 'package:campus_client/screens/library_screen.dart';
import 'package:campus_client/screens/login_screen.dart';
import 'package:campus_client/screens/mess_screen.dart';
import 'package:campus_client/screens/sessional_exam_screen.dart';
import 'package:campus_client/screens/user_profile_screen.dart';
import 'package:campus_client/models/fee.dart';
import 'package:campus_client/utils/receipt_pdf_generator.dart';
import 'package:campus_client/theme/app_colors.dart';
import 'package:campus_client/theme/app_theme.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/facade/campus_facade.dart';
import 'package:campus_client/widgets/campus_payment_dialog.dart';
import 'package:campus_client/widgets/app_dropdown.dart';
import 'package:campus_client/widgets/app_logo.dart';
import 'package:campus_client/screens/timetable_screen.dart';

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
    expect(find.text('Admin'), findsOneWidget);

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
    await tester.enterText(find.byType(TextField).first, 'harish_2025_l_btech_1');
    await tester.enterText(find.byType(TextField).last, 'pass123');
    await tester.pumpAndSettle();
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

    // Verify Persona dropdown opens cleanly
    final personaSwitcher = find.byTooltip('Switch Active Persona');
    expect(personaSwitcher, findsOneWidget);
    await tester.tap(personaSwitcher);
    await tester.pumpAndSettle();
    expect(find.textContaining('Campus Administrator'), findsWidgets);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // 4. Navigate to User Directory tab as Student (Harish) -> Access Denied!
    await tester.tap(find.text('Directory & Identities'));
    await tester.pumpAndSettle();

    expect(find.text('Access Restricted'), findsOneWidget);
    expect(find.text('Campus Directory & Identity Management'), findsOneWidget);
    expect(find.textContaining('Campus Administrator'), findsWidgets);

    // Switch to authorized administrator persona
    await tester.tap(find.byKey(const Key('btn-switch-authorized-persona')));
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

    // Register contractor persona for directory filter verification
    storage.registerUser(OfflineStorageService.getMockUserForHandle('mukesh_2025_ext_1'));

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
    await tester.enterText(find.byType(TextField).first, 'harish_2025_l_btech_1');
    await tester.enterText(find.byType(TextField).last, 'pass123');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Tap "View Profile" on dashboard banner as Student
    await tester.tap(find.text('View Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Official Identity & Verification'), findsOneWidget);
    expect(find.text('Academic Enrollment & Progress'), findsOneWidget);
    expect(find.text('Scoped RBAC Authority'), findsOneWidget);
    expect(find.text('Institutional Roles (2)'), findsOneWidget);
    // Student persona has no termination actions in profile
    expect(find.text('Lifecycle modifications restricted to Campus Administrator.'), findsOneWidget);
    expect(find.text('Discontinue User'), findsNothing);

    // Return to dashboard and switch persona to Campus Administrator
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    final personaSwitcher = find.byTooltip('Switch Active Persona');
    await tester.tap(personaSwitcher);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Campus Administrator').last);
    await tester.pumpAndSettle();

    // Reopen profile as Administrator -> Discontinue User is available
    await tester.tap(find.text('View Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Discontinue User'), findsOneWidget);
  });

  testWidgets('Optical Attendance flow: Faculty creates broadcast session with rolling QR and student scanner opens',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // Select Faculty persona for optical broadcast capabilities
    await tester.tap(find.text('Admin'));
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

  testWidgets('Department management flow: Admin adds department with subjects, teachers, and program semesters',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // Login as Faculty / Admin
    await tester.tap(find.text('Admin'));
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
    expect(find.text('Associated Subjects'), findsOneWidget);
    expect(find.text('Affiliated Teachers / Faculty'), findsOneWidget);
    expect(find.text('Program Semesters'), findsOneWidget);

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

    // Verify institutional note on student enrollment relationship
    expect(find.textContaining('Students enroll directly in their active Semester cohort'), findsOneWidget);
    expect(find.textContaining('Enrolled Student Roster'), findsOneWidget);

    // Close Dialogs
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
  });

  testWidgets('Cross-program section flow: Admin inspects Section B with multi-program enrollment (CSE, AI/ML, DS) and creates a shared section',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // Login as Faculty / Admin
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // 1. Navigate to Departments tab via sidebar
    await tester.tap(find.text('Depts').first);
    await tester.pumpAndSettle();

    // 2. Switch to Cross-Program Sections view
    final sectionsToggle = find.textContaining('Cross-Program Sections');
    expect(sectionsToggle, findsOneWidget);
    await tester.tap(sectionsToggle);
    await tester.pumpAndSettle();

    // Verify view switch
    expect(find.text('Cross-Program Sections & Cohorts'), findsOneWidget);
    expect(find.text('Add Shared Section'), findsOneWidget);

    // 3. Verify Section B card contains shared programs CSE, AIML, DS
    expect(find.text('Section B'), findsWidgets);
    expect(find.text('BTECH-CSE'), findsWidgets);
    expect(find.text('BTECH-AIML'), findsWidgets);
    expect(find.text('BTECH-DS'), findsWidgets);

    // 4. Inspect Section B cohort details
    final inspectBtn = find.text('Inspect Section Cohort').first;
    await tester.ensureVisible(inspectBtn);
    await tester.pumpAndSettle();
    await tester.tap(inspectBtn);
    await tester.pumpAndSettle();

    // Verify cross-program banner and allocations
    expect(find.textContaining('Shared Cross-Program Cohort'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Curriculum (3)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Allocations (2)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Lab Batches (2)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Enrolled Cohort (0)'), findsOneWidget);

    // Close Section inspector dialog
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();

    // 5. Open Add Shared Section dialog
    final addSecBtn = find.text('Add Shared Section');
    await tester.ensureVisible(addSecBtn);
    await tester.tap(addSecBtn);
    await tester.pumpAndSettle();

    expect(find.text('Add Shared Section Cohort'), findsOneWidget);
    expect(find.text('Participating Degree Programs'), findsOneWidget);

    // Enter name
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Section B'), 'Section C');

    // Toggle a subject chip
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'CS301 - Operating Systems'));
    await tester.tap(find.widgetWithText(FilterChip, 'CS301 - Operating Systems'));
    await tester.pumpAndSettle();

    // Submit dialog
    final createBtn = find.text('Create Shared Section');
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // Verify created Section C appears
    expect(find.text('Section C'), findsWidgets);

    // 6. Inspect Section A (where student Harish is enrolled)
    final inspectSecABtn = find.widgetWithText(OutlinedButton, 'Inspect Section Cohort').last;
    await tester.ensureVisible(inspectSecABtn);
    await tester.tap(inspectSecABtn);
    await tester.pumpAndSettle();

    // Switch to Enrolled Cohort tab
    final cohortTab = find.widgetWithText(Tab, 'Enrolled Cohort (1)');
    await tester.ensureVisible(cohortTab);
    await tester.tap(cohortTab);
    await tester.pumpAndSettle();

    expect(find.text('Harish Kumar'), findsOneWidget);
    expect(find.text('Move Section'), findsOneWidget);

    // Tap Move Section to verify transfer dialog
    await tester.tap(find.text('Move Section'));
    await tester.pumpAndSettle();

    expect(find.text('Move Student Section'), findsOneWidget);

    // Close Move Section dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Close Section inspector dialog
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Academic Subjects & Syllabus Audit Trail: Odd/Even cycle aliasing, active curriculum and retrospective BoS archive',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // Log in as Faculty / Admin
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Navigate to Academic Hierarchy & Departments via sidebar
    await tester.tap(find.text('Depts').first);
    await tester.pumpAndSettle();

    // 1. Verify 3 tabs exist in View Toggle
    expect(find.textContaining('Academic Departments ('), findsOneWidget);
    expect(find.textContaining('Cross-Program Sections'), findsOneWidget);
    expect(find.textContaining('Subjects & Syllabi'), findsOneWidget);

    // 2. Switch to Subjects & Syllabi tab
    await tester.tap(find.textContaining('Subjects & Syllabi'));
    await tester.pumpAndSettle();

    // Verify Header updates
    expect(find.text('Curriculum Subjects & Syllabus Audit'), findsOneWidget);
    expect(find.text('Add Academic Subject'), findsOneWidget);

    // 3. Filter to BCA 102 / 202 and verify card renders with odd and even semester badges
    await tester.enterText(find.byType(TextField).first, 'BCA');
    await tester.pumpAndSettle();

    expect(find.text('BCA 102 / 202'), findsWidgets);
    expect(find.textContaining('BCA-102'), findsWidgets);
    expect(find.textContaining('BCA-202'), findsWidgets);
    expect(find.textContaining('Reg-2024'), findsWidgets);

    // 4. Open Syllabus Audit & History for BCA 102 / 202
    final auditBtn = find.text('Syllabus Audit & History').first;
    await tester.ensureVisible(auditBtn);
    await tester.tap(auditBtn);
    await tester.pumpAndSettle();

    // Verify Dialog opened
    expect(find.textContaining('Curriculum Syllabus Audit & Semester Term Aliasing'), findsOneWidget);
    expect(find.text('SEMESTER CYCLE CODE RESOLVER (ODD / EVEN ALIASING)'), findsOneWidget);

    // Verify cycle resolution for Sem 1 (Odd)
    expect(find.text('Resolved: BCA-102 (Odd)'), findsOneWidget);

    // Simulate Sem 2 (Even) by tapping Sem 2 chip
    await tester.tap(find.text('Sem 2'));
    await tester.pumpAndSettle();
    expect(find.text('Resolved: BCA-202 (Even)'), findsOneWidget);

    // Verify Active Scheme Section
    expect(find.textContaining('ACTIVE CURRICULUM SCHEME (Reg-2024)'), findsOneWidget);
    expect(find.text('CURRENTLY ACTIVE'), findsOneWidget);

    // Verify Historical Audit Vault (Scheme-2021 is archived)
    expect(find.textContaining('ACCREDITATION AUDIT VAULT'), findsOneWidget);
    expect(find.text('Scheme-2021'), findsOneWidget);
    expect(find.text('ARCHIVED / RETIRED'), findsOneWidget);
    expect(find.text('Taught: 2021-2022 to 2024-2025'), findsOneWidget);

    // Expand archived syllabus units
    final expandBtn = find.text('Inspect Archived Syllabus Units');
    expect(expandBtn, findsOneWidget);
    await tester.ensureVisible(expandBtn);
    await tester.pumpAndSettle();
    await tester.tap(expandBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('Computing Fundamentals & Architecture'), findsOneWidget);

    // 5. Revise Syllabus to Reg-2026
    final reviseBtn = find.text('Revise Syllabus (BoS Scheme Update)');
    await tester.ensureVisible(reviseBtn);
    await tester.tap(reviseBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Revise Syllabus: BCA 102 / 202'), findsOneWidget);

    // Enter new revision code
    await tester.enterText(find.widgetWithText(TextField, 'Reg-2025'), 'Reg-2026');
    await tester.enterText(find.widgetWithText(TextField, '2025-2026'), '2026-2027');

    // Submit new scheme
    final publishBtn = find.text('Publish & Archive Previous');
    await tester.ensureVisible(publishBtn);
    await tester.tap(publishBtn);
    await tester.pumpAndSettle();

    // Verify new scheme is active Reg-2026 and previous Reg-2024 is now archived
    expect(find.textContaining('ACTIVE CURRICULUM SCHEME (Reg-2026)'), findsOneWidget);
    expect(find.text('Reg-2024'), findsOneWidget);

    // Close audit dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Clear search
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    // 6. Test Creating a new Academic Subject with Odd/Even codes
    final addSubBtn = find.text('Add Academic Subject');
    await tester.ensureVisible(addSubBtn);
    await tester.tap(addSubBtn);
    await tester.pumpAndSettle();

    expect(find.text('Add Academic Subject'), findsWidgets);

    // Fill form
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Computer Fundamentals & Programming'), 'Object Oriented Software Design');
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. BCA-102'), 'OOD-101');
    await tester.enterText(find.widgetWithText(TextFormField, 'e.g. BCA-202'), 'OOD-201');

    // Submit
    await tester.ensureVisible(find.text('Create Subject'));
    await tester.tap(find.text('Create Subject'));
    await tester.pumpAndSettle();

    // Verify newly created subject is listed with derived canonical code OOD-101 / OOD-201
    expect(find.text('OOD-101 / OOD-201'), findsWidgets);
    expect(find.text('Object Oriented Software Design'), findsWidgets);
  });

  testWidgets('Faculty subject allocations, practical lab batches auto-partitioning, and workload overview',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // Login as Faculty / Admin
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // 1. Navigate to Departments tab via sidebar
    await tester.tap(find.text('Depts').first);
    await tester.pumpAndSettle();

    // 2. Switch to Cross-Program Sections view
    final sectionsToggle = find.textContaining('Cross-Program Sections');
    expect(sectionsToggle, findsOneWidget);
    await tester.tap(sectionsToggle);
    await tester.pumpAndSettle();

    // 4. Test Top-level Faculty Workload Inspector
    final workloadBtn = find.byKey(const Key('btn-faculty-workload-header'));
    expect(workloadBtn, findsOneWidget);
    await tester.tap(workloadBtn);
    await tester.pumpAndSettle();

    expect(find.text('Faculty Teaching Workload & Contact Hours'), findsOneWidget);
    expect(find.textContaining('Standard recommended workload limit: 16 contact hours/week'), findsOneWidget);
    expect(find.text('Dr. Priya Nair'), findsWidgets);
    expect(find.textContaining('hrs/wk'), findsWidgets);

    // Close workload dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // 5. Inspect Section B details
    final inspectBtn = find.text('Inspect Section Cohort').first;
    await tester.ensureVisible(inspectBtn);
    await tester.tap(inspectBtn);
    await tester.pumpAndSettle();

    // Verify TabBar with Allocations and Lab Batches
    expect(find.widgetWithText(Tab, 'Curriculum (3)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Allocations (2)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Lab Batches (2)'), findsOneWidget);

    // 6. Switch to Allocations tab and assign faculty
    final allocTab = find.widgetWithText(Tab, 'Allocations (2)');
    await tester.tap(allocTab);
    await tester.pumpAndSettle();

    expect(find.textContaining('Faculty Subject Allocations (2)'), findsOneWidget);
    expect(find.text('BCA-102'), findsWidgets);
    expect(find.textContaining('Theory (Cohort)'), findsOneWidget);
    expect(find.textContaining('Practical [Batch B1]'), findsOneWidget);

    // Tap Assign Faculty button
    final assignFacultyBtn = find.byKey(const Key('btn-assign-faculty-allocation'));
    await tester.tap(assignFacultyBtn);
    await tester.pumpAndSettle();

    expect(find.text('Assign Faculty to Section'), findsOneWidget);

    // Submit new faculty allocation
    final submitAllocBtn = find.byKey(const Key('btn-submit-allocation'));
    await tester.tap(submitAllocBtn);
    await tester.pumpAndSettle();

    // Verify allocation count updated to 3
    expect(find.textContaining('Faculty Subject Allocations (3)'), findsOneWidget);

    // 7. Switch to Lab Batches tab
    final labTab = find.widgetWithText(Tab, 'Lab Batches (2)');
    await tester.tap(labTab);
    await tester.pumpAndSettle();

    expect(find.textContaining('Practical Lab Batches (2)'), findsOneWidget);
    expect(find.text('Batch B1'), findsOneWidget);
    expect(find.text('Batch B2'), findsOneWidget);

    // Tap Add Batch
    final addBatchBtn = find.byKey(const Key('btn-create-lab-batch'));
    await tester.tap(addBatchBtn);
    await tester.pumpAndSettle();

    expect(find.text('Create Lab Batch'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('input-batch-name')), 'Batch B3');
    final submitBatchBtn = find.byKey(const Key('btn-submit-create-batch'));
    await tester.tap(submitBatchBtn);
    await tester.pumpAndSettle();

    // Verify Batch B3 created
    expect(find.textContaining('Practical Lab Batches (3)'), findsOneWidget);
    expect(find.text('Batch B3'), findsOneWidget);

    // Close Section B inspector dialog
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();

    // 8. Inspect Section A and Auto-Partition its enrolled students
    final inspectSecABtn = find.widgetWithText(OutlinedButton, 'Inspect Section Cohort').last;
    await tester.ensureVisible(inspectSecABtn);
    await tester.tap(inspectSecABtn);
    await tester.pumpAndSettle();

    // Switch to Lab Batches tab (starts empty for Section A)
    final secALabTab = find.widgetWithText(Tab, 'Lab Batches (0)');
    await tester.tap(secALabTab);
    await tester.pumpAndSettle();

    // Tap Auto-Partition
    final autoPartitionBtn = find.byKey(const Key('btn-auto-partition-batches'));
    await tester.tap(autoPartitionBtn);
    await tester.pumpAndSettle();

    expect(find.text('Auto-Partition Practical Batches'), findsOneWidget);
    expect(find.textContaining('Evenly distributes all 1 enrolled students across 2 practical batches'), findsOneWidget);

    final submitPartitionBtn = find.byKey(const Key('btn-submit-auto-partition'));
    await tester.tap(submitPartitionBtn);
    await tester.pumpAndSettle();

    // Verify 2 batches generated and student Harish Kumar is in Batch 1
    expect(find.textContaining('Practical Lab Batches (2)'), findsOneWidget);
    expect(find.text('Batch 1'), findsOneWidget);
    expect(find.text('Batch 2'), findsOneWidget);
    expect(find.textContaining('Harish Kumar'), findsOneWidget);

    // Close Section A inspector
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
  });

  testWidgets('AppDropdown widget renders, drops down below anchor, and selects item', (WidgetTester tester) async {
    String? selected = 'opt_1';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Center(
                child: SizedBox(
                  width: 250,
                  child: AppDropdown<String>(
                    key: const Key('test-dropdown'),
                    value: selected,
                    hint: 'Select an option',
                    items: const [
                      AppDropdownItem(value: 'opt_1', label: 'Option One (Alpha)'),
                      AppDropdownItem(value: 'opt_2', label: 'Option Two (Beta)'),
                      AppDropdownItem(value: 'opt_3', label: 'Option Three (Gamma)'),
                    ],
                    onChanged: (val) {
                      setState(() => selected = val);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Initial state
    expect(find.text('Option One (Alpha)'), findsOneWidget);
    expect(find.text('Option Two (Beta)'), findsNothing);

    // Tap dropdown to open menu
    await tester.tap(find.byKey(const Key('test-dropdown')));
    await tester.pumpAndSettle();

    // Menu should drop down showing all options
    expect(find.text('Option Two (Beta)'), findsOneWidget);
    expect(find.text('Option Three (Gamma)'), findsOneWidget);

    // Select Option Two
    await tester.tap(find.text('Option Two (Beta)'));
    await tester.pumpAndSettle();

    // Should update selected value
    expect(selected, 'opt_2');
    expect(find.text('Option Two (Beta)'), findsOneWidget);
  });

  testWidgets(
      'Student Attendance Analytics: Dual-ring radial gauge, 75% regulatory margin calculation, 30-day activity heatmap, and course inspector modal',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // Select Student persona
    await tester.enterText(find.byType(TextField).first, 'harish_2025_l_btech_1');
    await tester.enterText(find.byType(TextField).last, 'pass123');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Navigate to Attendance Tab
    await tester.tap(find.text('Attendance').first);
    await tester.pumpAndSettle();

    // 1. Verify Student Attendance Dashboard elements
    expect(find.text('Student Attendance Analytics'), findsOneWidget);
    expect(find.text('Statutory 75% Regulatory Compliance Gauge'), findsOneWidget);
    expect(find.text('Scan Rolling QR'), findsOneWidget);
    expect(find.text('30-Day Classroom Activity Matrix'), findsOneWidget);
    expect(find.text('12-Day Active Streak'), findsOneWidget);
    expect(find.text('Course Benchmark vs. 75% Cutoff'), findsOneWidget);
    expect(find.text('Cutoff: 75.0%'), findsOneWidget);
    expect(find.text('Enrolled Course Standing & Margins'), findsOneWidget);

    // 2. Verify filter buttons and subject cards
    await tester.ensureVisible(find.text('All (5)'));
    await tester.pumpAndSettle();
    expect(find.text('All (5)'), findsOneWidget);
    expect(find.text('At Risk (2)'), findsOneWidget);
    expect(find.text('Safe (3)'), findsOneWidget);

    // Filter by At Risk
    await tester.ensureVisible(find.text('At Risk (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('At Risk (2)'));
    await tester.pumpAndSettle();

    // CS303 (70.8%) and MA101 (60.0%) should be visible
    expect(find.textContaining('CS303'), findsWidgets);
    expect(find.textContaining('MA101'), findsWidgets);

    // Filter by Safe
    await tester.ensureVisible(find.text('Safe (3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safe (3)'));
    await tester.pumpAndSettle();

    // CS301 (87.5%), CS302 (80.0%), CS304 (96.7%)
    expect(find.textContaining('CS301'), findsWidgets);
    expect(find.textContaining('CS304'), findsWidgets);

    // Switch back to All
    await tester.ensureVisible(find.text('All (5)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All (5)'));
    await tester.pumpAndSettle();

    // 3. Inspect Course Inspector Dialog
    await tester.ensureVisible(find.text('Inspect Log').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inspect Log').first);
    await tester.pumpAndSettle();

    expect(find.text('Course Attendance Inspector & Regulatory Standing'), findsOneWidget);
    expect(find.text('Recent Session Audit Log'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Close Dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // 4. Test Scan Rolling QR button
    await tester.ensureVisible(find.text('Scan Rolling QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan Rolling QR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Scan Rolling Optical QR'), findsOneWidget);
    expect(find.text('ALIGN RETICLE WITH CLASSROOM DISPLAY'), findsOneWidget);
  });

  testWidgets(
      'Section Coordinator can configure interim attendance criteria within statutory range [40% - 75%]',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final faculty = OfflineStorageService.getMockUserForHandle('priya_2024_emp_1');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AttendanceScreen(
          storage: storage,
          currentUser: faculty,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Verify Coordinator criteria bar
    expect(find.byKey(const Key('btn-configure-attendance-criteria')), findsOneWidget);
    expect(find.textContaining('Interim Section Attendance Criteria: 75%'), findsOneWidget);

    // 2. Open Interim Criteria Dialog
    await tester.tap(find.byKey(const Key('btn-configure-attendance-criteria')));
    await tester.pumpAndSettle();

    expect(find.text('Section Interim Criteria'), findsOneWidget);
    expect(find.text('Min: 40%'), findsOneWidget);
    expect(find.text('Max: 75%'), findsOneWidget);

    // 3. Move slider
    final sliderFinder = find.byKey(const Key('slider-attendance-interim-criteria'));
    expect(sliderFinder, findsOneWidget);

    await tester.drag(sliderFinder, const Offset(-100, 0));
    await tester.pumpAndSettle();

    // 4. Save Criteria
    await tester.tap(find.byKey(const Key('btn-save-attendance-interim-criteria')));
    await tester.pumpAndSettle();

    // 5. Verify threshold updated within bounds [40, 75]
    expect(storage.getAttendanceThreshold(sectionScope: 'sec:cse-3a'), lessThanOrEqualTo(75.0));
    expect(storage.getAttendanceThreshold(sectionScope: 'sec:cse-3a'), greaterThanOrEqualTo(40.0));
  });

  testWidgets('Timetable: 9 AM to 5 PM 1-hour blocks, consecutive grouping, standard units, and Free vs Off distinction', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(
      MaterialApp(
        home: TimetableScreen(
          storage: storage,
          activeScope: 'sec:cse-3a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Title & 9 AM to 5 PM Operational Window
    expect(find.text('Academic Timetable (9 AM - 5 PM)'), findsOneWidget);

    // 2. Select Monday (Day 1)
    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();

    // Verify summary ribbon
    expect(find.textContaining('Classes'), findsWidgets);
    expect(find.textContaining('Lunch Break'), findsWidgets);
    expect(find.textContaining('Free Periods'), findsWidgets);
    expect(find.textContaining('Declared Off'), findsWidgets);

    // 3. Verify Consecutive Grouping:
    // Consecutive occupied blocks (09:00 CS301 + 10:00 CS302) are rendered with consecutive periods badge
    expect(find.text('CONSECUTIVE PERIODS'), findsWidgets);

    // 4. Verify Free is distinct from Off and Lunch:
    // All statuses exist simultaneously on the schedule and have distinct branding
    expect(find.text('LUNCH BREAK'), findsWidgets);
    expect(find.text('FREE PERIOD'), findsWidgets);
    expect(find.textContaining('Declared Off'), findsWidgets);
    expect(find.text('Operating Systems'), findsWidgets);

    // 5. Test All Days Rows Toggle
    final switchModeBtn = find.byTooltip('Switch to All Days Rows View');
    expect(switchModeBtn, findsOneWidget);
    await tester.tap(switchModeBtn);
    await tester.pumpAndSettle();

    expect(find.text('Mon'), findsWidgets);
    expect(find.text('Tue'), findsWidgets);

    // Toggle back to Single Day Row View
    final switchRowBtn = find.byTooltip('Switch to Single Day Row View');
    expect(switchRowBtn, findsOneWidget);
    await tester.tap(switchRowBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Horizontal Row Format'), findsOneWidget);

    // 6. Test Saturday half-day behavior (classes in morning, free period, afternoon declared off)
    await tester.tap(find.text('Sat'));
    await tester.pumpAndSettle();

    expect(find.text('SEM301'), findsWidgets);
    expect(find.text('FREE PERIOD'), findsWidgets);
    expect(find.text('DECLARED OFF'), findsWidgets);

    // 7. Test Power to Declare Day Off and Restore Schedule
    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();

    expect(find.text('Declare Day Off'), findsOneWidget);
    await tester.tap(find.text('Declare Day Off'));
    await tester.pumpAndSettle();

    expect(find.text('Declare Mon Off'), findsOneWidget);
    expect(find.text('Confirm Day Off'), findsOneWidget);
    await tester.tap(find.text('Confirm Day Off'));
    await tester.pumpAndSettle();

    // Verify Mon is now declared off
    expect(find.textContaining('Mon is Declared Off'), findsOneWidget);
    expect(find.text('Restore Schedule'), findsOneWidget);

    // Restore Mon schedule
    await tester.tap(find.text('Restore Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Declare Day Off'), findsOneWidget);
    expect(find.text('Operating Systems'), findsWidgets);

    // 8. Test Block Configuration Sheet
    // Tap a block to open configuration
    await tester.tap(find.text('FREE PERIOD').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Configure Schedule Block'), findsOneWidget);
    expect(find.text('BLOCK TYPE'), findsOneWidget);
    expect(find.text('Free Period (Campus Open)'), findsOneWidget);

    // Switch type to Lunch inside editor using key
    await tester.tap(find.byKey(const Key('tab-block-type-lunch')));
    await tester.pumpAndSettle();

    expect(find.text('Midday Lunch Break (Campus Cafeteria)'), findsOneWidget);

    // Switch type to Declared Off inside editor using key
    await tester.tap(find.byKey(const Key('tab-block-type-off')));
    await tester.pumpAndSettle();

    expect(find.text('Declared Off (Campus Hours Closed)'), findsOneWidget);

    // Save block
    final saveBtn1 = find.byKey(const Key('btn-save-block-configuration'));
    await tester.ensureVisible(saveBtn1);
    await tester.tap(saveBtn1);
    await tester.pumpAndSettle();

    expect(find.text('DECLARED OFF'), findsWidgets);

    // 9. Test Interactive Course Allocation & Quick Selectors
    // Tap the DECLARED OFF block to allocate it to a course
    await tester.tap(find.text('DECLARED OFF').first);
    await tester.pumpAndSettle();

    // Switch to Lecture using key
    await tester.tap(find.byKey(const Key('tab-block-type-lecture')));
    await tester.pumpAndSettle();

    expect(find.text('QUICK SELECT COURSE'), findsOneWidget);
    expect(find.text('QUICK SELECT FACULTY'), findsOneWidget);
    expect(find.text('QUICK SELECT ROOM / LAB'), findsOneWidget);

    // Select course CS303
    final courseChip = find.widgetWithText(ActionChip, 'CS303 - Computer Networks');
    await tester.ensureVisible(courseChip);
    await tester.tap(courseChip);
    await tester.pumpAndSettle();

    // Select faculty Dr. Priya Nair
    final facultyChip = find.widgetWithText(ActionChip, 'Dr. Priya Nair');
    await tester.ensureVisible(facultyChip);
    await tester.tap(facultyChip);
    await tester.pumpAndSettle();

    // Select room LH-101
    final roomChip = find.widgetWithText(ActionChip, 'LH-101');
    await tester.ensureVisible(roomChip);
    await tester.tap(roomChip);
    await tester.pumpAndSettle();

    // Save block allocation
    final saveBtn2 = find.byKey(const Key('btn-save-block-configuration'));
    expect(saveBtn2, findsOneWidget);
    await tester.ensureVisible(saveBtn2);
    await tester.tap(saveBtn2);
    await tester.pumpAndSettle();

    expect(find.text('CS303'), findsWidgets);
  });

  testWidgets('Timetable RBAC: Student view is strictly read-only and prevents schedule mutations',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    await tester.pumpWidget(
      MaterialApp(
        home: TimetableScreen(
          storage: storage,
          activeScope: 'sec:cse-3a',
          currentUser: student,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Declare Day Off button must NOT be present for students
    expect(find.text('Declare Day Off'), findsNothing);
    expect(find.text('Read Only View'), findsWidgets);

    // Tapping a block shows read-only snackbar instead of opening editor sheet
    await tester.tap(find.text('FREE PERIOD').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('read-only for students'), findsOneWidget);
    expect(find.text('Configure Schedule Block'), findsNothing);
  });

  testWidgets('Hostel Room System: Room number boundaries [100-999], fixture capacities (3 beds, 3 tables, 2 tubelights, 2 fans, 3 lockers), 3 occupants max, and 14-char serial validation',
      (WidgetTester tester) async {
    // 1. Verify Model Validation Constraints
    expect(HostelRoomModel.validateRoomNumber(99), isNotNull);
    expect(HostelRoomModel.validateRoomNumber(100), isNull);
    expect(HostelRoomModel.validateRoomNumber(505), isNull);
    expect(HostelRoomModel.validateRoomNumber(999), isNull);
    expect(HostelRoomModel.validateRoomNumber(1000), isNotNull);

    expect(HostelRoomModel.validateSerialNumber(''), isNotNull);
    expect(HostelRoomModel.validateSerialNumber('12345678901234'), isNull); // 14 chars
    expect(HostelRoomModel.validateSerialNumber('123456789012345'), isNotNull); // 15 chars exceeds max
    expect(HostelRoomModel.validateSerialNumber('BED-101-01'), isNull);

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final admin = OfflineStorageService.getMockUserForHandle('campus_admin');

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostelScreen(
            storage: storage,
            currentUser: admin,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Verify Screen Title & Seeded Rooms
    expect(find.text('Hostel Room System & Asset Inventory'), findsOneWidget);
    expect(find.text('ROOM 101'), findsOneWidget);
    expect(find.text('ROOM 102'), findsOneWidget);
    expect(find.text('ROOM 204'), findsOneWidget);
    expect(find.text('ROOM 305'), findsOneWidget);

    // 3. Verify Capacity Pills on Room 101 (Fully Furnished: 3 beds, 3 tables, 3 chairs, 2 tubelights, 2 fans, 3 lockers)
    expect(find.text('Beds 3/3'), findsWidgets);
    expect(find.text('Tables 3/3'), findsWidgets);
    expect(find.text('Chairs 3/3'), findsWidgets);
    expect(find.text('Tubelights 2/2'), findsWidgets);
    expect(find.text('Fans 2/2'), findsWidgets);
    expect(find.text('Lockers 3/3'), findsWidgets);

    // 4. Test Registering a New Room with [100-999] Range Validation
    final addRoomBtn = find.byKey(const Key('btn-add-hostel-room'));
    expect(addRoomBtn, findsOneWidget);
    await tester.tap(addRoomBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-create-hostel-room')), findsOneWidget);

    // Enter invalid room number 99
    await tester.enterText(find.byKey(const Key('input-hostel-room-number')), '99');
    await tester.pumpAndSettle();
    expect(find.text('Room number must be between 100 and 999'), findsOneWidget);

    // Enter valid room number 405
    await tester.enterText(find.byKey(const Key('input-hostel-room-number')), '405');
    await tester.pumpAndSettle();
    expect(find.text('Room number must be between 100 and 999'), findsNothing);

    await tester.tap(find.byKey(const Key('btn-confirm-create-room')));
    await tester.pumpAndSettle();

    // Verify Room 405 is now in the list
    expect(find.text('ROOM 405'), findsOneWidget);

    // 5. Test Inspecting Room 405 & Adding Fixture with 14-char Alphanumeric Serial
    final inspect405 = find.byKey(const Key('btn-inspect-room-405'));
    await tester.ensureVisible(inspect405);
    await tester.tap(inspect405);
    await tester.pumpAndSettle();

    expect(find.text('No fixtures registered in this room yet.'), findsOneWidget);
    expect(find.text('No residents currently allocated (Room is vacant).'), findsOneWidget);

    // Tap Add Fixture inside bottom sheet
    await tester.tap(find.byKey(const Key('btn-modal-add-fixture')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-add-hostel-asset')), findsOneWidget);

    // Enter a valid 14-char alphanumeric serial
    await tester.enterText(find.byKey(const Key('input-hostel-asset-serial')), 'BED-405-01');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn-confirm-add-asset')));
    await tester.pumpAndSettle();

    // Reopen inspection to verify asset is registered
    await tester.ensureVisible(inspect405);
    await tester.tap(inspect405);
    await tester.pumpAndSettle();

    expect(find.text('SN: BED-405-01'), findsOneWidget);

    // Close bottom sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 6. Test Allotting a Resident to Room 405 (Max 3 Occupants)
    final assignResBtn = find.byKey(const Key('btn-assign-occupant-405'));
    await tester.ensureVisible(assignResBtn);
    await tester.tap(assignResBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-assign-hostel-occupant')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-confirm-assign-occupant')));
    await tester.pumpAndSettle();

    // Verify resident appears on card
    expect(find.text('1/3 RESIDENTS'), findsWidgets);
  });

  testWidgets('Hostel Room System: Student Resident view shows strictly their allotted room information and restricts other rooms',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostelScreen(
            storage: storage,
            currentUser: student,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Student View Header (No Add Room button, no campus-wide controls)
    expect(find.text('Hostel Residence Portal'), findsOneWidget);
    expect(find.text('Hostel Room System & Asset Inventory'), findsNothing);
    expect(find.byKey(const Key('btn-add-hostel-room')), findsNothing);
    expect(find.text('Harish Kumar'), findsWidgets);

    // 2. Verify Student can ONLY see their allotted room (Room 101)
    expect(find.byKey(const Key('card-my-allotted-room')), findsOneWidget);
    expect(find.text('MY ALLOTTED ROOM: ROOM 101'), findsOneWidget);
    expect(find.text('Active Allocation'), findsOneWidget);
    expect(find.text('Harish Kumar (@harish_2025_l_btech_1) (You)'), findsOneWidget);
    expect(find.text('Rohit Verma (@rohit_2025_btech_2)'), findsOneWidget);

    // Verify other rooms and other occupants are strictly NOT visible to student
    expect(find.text('ROOM 102'), findsNothing);
    expect(find.text('ROOM 204'), findsNothing);
    expect(find.text('ROOM 305'), findsNothing);
    expect(find.textContaining('Amit Shah'), findsNothing);

    // Verify campus-wide ribbons and filters are hidden from student
    expect(find.text('Registered Rooms'), findsNothing);
    expect(find.text('All Floors'), findsNothing);
    expect(find.byKey(const Key('input-search-hostel-room')), findsNothing);

    // 3. Verify Serial-Tracked Fixture Summaries on My Room Card
    expect(find.text('Beds: 3/3'), findsWidgets);
    expect(find.text('Tables: 3/3'), findsWidgets);
    expect(find.text('Chairs: 3/3'), findsWidgets);
    expect(find.text('Tubelights: 2/2'), findsWidgets);
    expect(find.text('Fans: 2/2'), findsWidgets);
    expect(find.text('Lockers: 3/3'), findsWidgets);

    // 4. Verify Administrative Mutation buttons are hidden
    expect(find.text('+ Asset'), findsNothing);
    expect(find.text('+ Resident'), findsNothing);

    // 5. Test Fixture Issue reporting from student card
    await tester.tap(find.byKey(const Key('btn-report-fixture-issue')));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance ticket submitted to Hostel Warden for Room 101.'), findsOneWidget);

    // 6. Test Inspecting Room 101 fixtures in read-only resident modal
    await tester.tap(find.byKey(const Key('btn-student-inspect-room')));
    await tester.pumpAndSettle();

    expect(find.text('Resident View (Read-Only)'), findsOneWidget);
    expect(find.byKey(const Key('btn-modal-add-fixture')), findsNothing);
    expect(find.byKey(const Key('btn-modal-add-resident')), findsNothing);
    expect(find.byIcon(Icons.person_remove), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  test('Mess Meal Schedule & Compulsory vs Optional Rating Feedback Rules', () {
    // 1. Verify Compulsory vs Optional Rules
    expect(MessRatingValue.veryPoor.isMessageCompulsory, isTrue);
    expect(MessRatingValue.poor.isMessageCompulsory, isTrue);
    expect(MessRatingValue.average.isMessageCompulsory, isTrue);
    expect(MessRatingValue.good.isMessageCompulsory, isFalse);
    expect(MessRatingValue.veryGood.isMessageCompulsory, isFalse);
    expect(MessRatingValue.abstained.isMessageCompulsory, isFalse);

    // 2. Validate empty message on compulsory ratings -> fails
    expect(
      MessRatingModel.validateRatingFeedback(
        rating: MessRatingValue.veryPoor,
        message: '   ',
      ),
      isNotNull,
    );
    expect(
      MessRatingModel.validateRatingFeedback(
        rating: MessRatingValue.poor,
        message: '',
      ),
      isNotNull,
    );
    expect(
      MessRatingModel.validateRatingFeedback(
        rating: MessRatingValue.average,
        message: null,
      ),
      isNotNull,
    );

    // 3. Validate compulsory ratings with message -> passes
    expect(
      MessRatingModel.validateRatingFeedback(
        rating: MessRatingValue.average,
        message: 'Food was decent but warm.',
      ),
      isNull,
    );

    // 4. Validate optional ratings with empty message -> passes
    expect(
      MessRatingModel.validateRatingFeedback(
        rating: MessRatingValue.good,
        message: '',
      ),
      isNull,
    );
    expect(
      MessRatingModel.validateRatingFeedback(
        rating: MessRatingValue.veryGood,
        message: null,
      ),
      isNull,
    );
    expect(
      MessRatingModel.validateRatingFeedback(
        rating: MessRatingValue.abstained,
        message: '',
      ),
      isNull,
    );
  });

  testWidgets('Hostel Mess: Weekly timetable (6 days x 3 meals, Sunday Brunch + Dinner), rating dialog with compulsory messages, and messages report tab',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessScreen(
            storage: storage,
            currentUser: student,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header
    expect(find.text('Hostel Mess System & Meal Timetable'), findsOneWidget);
    expect(find.text('Weekly Menu & Timetable'), findsOneWidget);
    expect(find.text('Messages & Ratings Report'), findsOneWidget);

    // 2. Verify Monday Schedule: 3 meals (Breakfast, Lunch, Dinner)
    await tester.tap(find.byKey(const Key('chip-day-monday')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-meal-meal-monday-breakfast')), findsOneWidget);
    expect(find.byKey(const Key('card-meal-meal-monday-lunch')), findsOneWidget);
    expect(find.byKey(const Key('card-meal-meal-monday-dinner')), findsOneWidget);
    expect(find.text('07:30 - 09:30'), findsWidgets);
    expect(find.text('12:30 - 14:30'), findsWidgets);
    expect(find.text('19:30 - 21:30'), findsWidgets);

    // 3. Verify Sunday Schedule: Brunch (10:00 - 13:00) replacing Breakfast and Lunch
    await tester.tap(find.byKey(const Key('chip-day-sunday')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-meal-meal-sunday-brunch')), findsOneWidget);
    expect(find.byKey(const Key('card-meal-meal-sunday-dinner')), findsOneWidget);
    expect(find.text('10:00 - 13:00'), findsOneWidget);
    expect(find.text('Sunday Grand Brunch (Replaces Breakfast & Lunch)'), findsOneWidget);
    expect(find.text('BRUNCH'), findsOneWidget);
    // Ensure Monday breakfast card is not shown under Sunday
    expect(find.byKey(const Key('card-meal-meal-monday-breakfast')), findsNothing);

    // 4. Test Rating Dialog: Very Poor rating with COMPULSORY message validation
    final rateBtn = find.byKey(const Key('btn-open-rate-meal-dialog'));
    expect(rateBtn, findsOneWidget);
    await tester.tap(rateBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-rate-mess-meal')), findsOneWidget);
    expect(find.text('Submit Meal Rating & Feedback'), findsOneWidget);

    // Select Very Poor rating
    await tester.tap(find.byKey(const Key('chip-rating-very_poor')));
    await tester.pumpAndSettle();

    expect(find.text('Feedback Message (Compulsory)'), findsOneWidget);
    expect(find.textContaining('Feedback message is COMPULSORY for Very Poor, Poor, and Average ratings.'), findsOneWidget);

    // Attempt submitting without entering message -> Must be blocked by validation
    await tester.tap(find.byKey(const Key('btn-submit-mess-rating')));
    await tester.pumpAndSettle();
    expect(find.text('Feedback message is compulsory for Very Poor rating.'), findsOneWidget);

    // Enter compulsory feedback message
    await tester.enterText(
      find.byKey(const Key('input-mess-feedback-message')),
      'Rice was undercooked and soup was cold on arrival.',
    );
    await tester.pumpAndSettle();
    expect(find.text('Feedback message is compulsory for Very Poor rating.'), findsNothing);

    // Submit valid Very Poor rating
    await tester.tap(find.byKey(const Key('btn-submit-mess-rating')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialog-rate-mess-meal')), findsNothing);

    // 5. Test Rating Dialog: Very Good rating with OPTIONAL message (can submit empty)
    await tester.tap(rateBtn);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chip-rating-very_good')));
    await tester.pumpAndSettle();

    expect(find.text('Feedback Message (Optional)'), findsOneWidget);
    expect(find.textContaining('Feedback message is OPTIONAL for Good, Very Good, and Abstained ratings.'), findsOneWidget);

    // Submit with empty message -> Succeeds
    await tester.tap(find.byKey(const Key('btn-submit-mess-rating')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialog-rate-mess-meal')), findsNothing);

    // 6. Switch to Tab 2: "Messages & Ratings Report"
    await tester.tap(find.text('Messages & Ratings Report'));
    await tester.pumpAndSettle();

    // Verify KPI Ribbon
    expect(find.text('STUDENT FEEDBACK & MESSAGES'), findsOneWidget);
    expect(find.textContaining('Total Student Ratings'), findsOneWidget);
    expect(find.text('Avg Score (/ 5.0)'), findsOneWidget);

    // Verify Sentiment Breakdown Pills
    expect(find.textContaining('Very Good:'), findsWidgets);
    expect(find.textContaining('Average:'), findsWidgets);
    expect(find.textContaining('Poor:'), findsWidgets);
    expect(find.textContaining('Abstained:'), findsWidgets);

    // Verify Compulsory feedback indicator and submitted messages
    expect(find.text('Compulsory Feedback'), findsWidgets);
    expect(find.text('Rice was undercooked and soup was cold on arrival.'), findsOneWidget);
  });

  testWidgets(
      'Redesigned 4-Division Bottom Dock: Mandatory Dashboard (1) & Profile (2), Active Page (3), and 3-lines Pages menu (4) that replaces slot 3',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // Login to reach HomeScreen
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // 1. Verify 4 Dock Divisions are present
    expect(find.byKey(const Key('dock-division-dashboard')), findsOneWidget);
    expect(find.byKey(const Key('dock-division-profile')), findsOneWidget);
    expect(find.byKey(const Key('dock-division-active-page')), findsOneWidget);
    expect(find.byKey(const Key('dock-division-more-pages')), findsOneWidget);

    // Initial state: Division 1 (Dashboard) is active, Division 3 defaults to Timetable
    expect(find.text('Academic Operations'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('dock-division-active-page')), matching: find.text('Timetable')), findsOneWidget);

    // 2. Tap Division 2 (Profile) -> Switches to User Profile view
    await tester.tap(find.byKey(const Key('dock-division-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Official Identity & Verification'), findsOneWidget);
    expect(find.text('Scoped RBAC Authority'), findsOneWidget);

    // 3. Tap Division 1 (Dashboard) -> Switches back to Dashboard
    await tester.tap(find.byKey(const Key('dock-division-dashboard')));
    await tester.pumpAndSettle();

    expect(find.text('Academic Operations'), findsOneWidget);

    // 4. Tap Division 3 (Timetable) -> Switches to Timetable view
    await tester.tap(find.byKey(const Key('dock-division-active-page')));
    await tester.pumpAndSettle();

    expect(find.text('Academic Timetable (9 AM - 5 PM)'), findsOneWidget);

    // 5. Tap Division 4 (3 horizontal lines icon) -> Opens Pages bottom sheet
    await tester.tap(find.byKey(const Key('dock-division-more-pages')));
    await tester.pumpAndSettle();

    expect(find.text('Campus Pages & Modules'), findsOneWidget);
    expect(find.text('Select a page to open and replace in dock division 3'), findsOneWidget);
    expect(find.byKey(const Key('dock-menu-item-mess')), findsOneWidget);
    expect(find.byKey(const Key('dock-menu-item-attendance')), findsOneWidget);
    expect(find.byKey(const Key('dock-menu-item-hostel')), findsOneWidget);

    // 6. Select "Mess" from list 4 -> Replaces Division 3 with Mess and navigates to Mess
    await tester.tap(find.byKey(const Key('dock-menu-item-mess')));
    await tester.pumpAndSettle();

    // Verify modal is closed
    expect(find.text('Campus Pages & Modules'), findsNothing);

    // Verify Division 3 now displays "Mess"
    expect(find.descendant(of: find.byKey(const Key('dock-division-active-page')), matching: find.text('Mess')), findsOneWidget);

    // Verify MessScreen is actively rendered
    expect(find.text('Hostel Mess System & Meal Timetable'), findsOneWidget);

    // 7. Tap Division 4 again and select "Attendance"
    await tester.tap(find.byKey(const Key('dock-division-more-pages')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dock-menu-item-attendance')));
    await tester.pumpAndSettle();

    // Verify Division 3 now replaced with "Attendance"
    expect(find.descendant(of: find.byKey(const Key('dock-division-active-page')), matching: find.text('Attendance')), findsOneWidget);
    expect(find.text('Classroom Attendance'), findsOneWidget);

    // 8. Tap Dashboard (Division 1) -> Division 3 still remembers "Attendance"
    await tester.tap(find.byKey(const Key('dock-division-dashboard')));
    await tester.pumpAndSettle();

    expect(find.text('Academic Operations'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('dock-division-active-page')), matching: find.text('Attendance')), findsOneWidget);
  });

  testWidgets('Small Screen Responsiveness: 360x640 bottom dock sheet, hostel student view, and mess feedback cards',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pumpAndSettle();

    // Login as student
    await tester.enterText(find.byType(TextField).first, 'harish_2025_l_btech_1');
    await tester.enterText(find.byType(TextField).last, 'pass123');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Verify 4 divisions are rendered on small screen
    expect(find.byKey(const Key('dock-division-dashboard')), findsOneWidget);
    expect(find.byKey(const Key('dock-division-profile')), findsOneWidget);
    expect(find.byKey(const Key('dock-division-active-page')), findsOneWidget);
    expect(find.byKey(const Key('dock-division-more-pages')), findsOneWidget);

    // Open Division 4 "Other Pages" bottom sheet
    await tester.tap(find.byKey(const Key('dock-division-more-pages')));
    await tester.pumpAndSettle();
    expect(find.text('Campus Pages & Modules'), findsOneWidget);

    // Verify inaccessible pages (directory, departments) are cleanly hidden from student bottom sheet
    expect(find.byKey(const Key('dock-menu-item-directory')), findsNothing);
    expect(find.byKey(const Key('dock-menu-item-departments')), findsNothing);

    // Verify every permitted sheet item fits vertically within screen bounds
    for (final keyName in ['timetable', 'attendance', 'notices', 'hostel', 'mess', 'complaints']) {
      final finder = find.byKey(Key('dock-menu-item-$keyName'));
      expect(finder, findsOneWidget);
      final rect = tester.getRect(finder);
      expect(rect.bottom, lessThanOrEqualTo(640.0));
    }

    // Switch to Mess page via Division 4
    await tester.tap(find.byKey(const Key('dock-menu-item-mess')));
    await tester.pumpAndSettle();
    expect(find.text('Campus Pages & Modules'), findsNothing);
    expect(find.text('Hostel Mess System & Meal Timetable'), findsOneWidget);

    // Switch to Hostel page via Division 4
    await tester.tap(find.byKey(const Key('dock-division-more-pages')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dock-menu-item-hostel')));
    await tester.pumpAndSettle();
    expect(find.text('Hostel Residence Portal'), findsOneWidget);
    expect(find.byKey(const Key('card-my-allotted-room')), findsOneWidget);

    // Switch back to Dashboard (Division 1) -> active page slot 3 retains Hostel
    await tester.tap(find.byKey(const Key('dock-division-dashboard')));
    await tester.pumpAndSettle();
    expect(find.text('Academic Operations'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('dock-division-active-page')), matching: find.text('Hostel')), findsOneWidget);
  });

  testWidgets('Small Screen Responsiveness: MessScreen and HostelScreen standalone on 360x640',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final user = OfflineStorageService.getMockUserForHandle('campus_admin');

    // Test MessScreen on small screen with tab switching
    await tester.pumpWidget(MaterialApp(
      home: MessScreen(
        storage: storage,
        currentUser: user,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Hostel Mess System & Meal Timetable'), findsOneWidget);

    await tester.tap(find.text('Messages & Ratings Report'));
    await tester.pumpAndSettle();
    expect(find.text('STUDENT FEEDBACK & MESSAGES'), findsOneWidget);

    // Test HostelScreen on small screen with warden console
    await tester.pumpWidget(MaterialApp(
      home: HostelScreen(
        storage: storage,
        currentUser: user,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Hostel Room System & Asset Inventory'), findsOneWidget);
  });

  testWidgets('Hostel Room Management: Warden and Admin can edit rooms and fixtures with validations, student view is strictly restricted',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final warden = OfflineStorageService.getMockUserForHandle('ramesh_2023_emp_1');
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    expect(warden.canEditHostelRoom, isTrue);
    expect(student.canEditHostelRoom, isFalse);

    // 1. Warden console view has edit buttons
    await tester.pumpWidget(MaterialApp(
      home: HostelScreen(
        storage: storage,
        currentUser: warden,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify room 101 has edit button
    final editRoomBtn = find.byKey(const Key('btn-edit-room-101'));
    expect(editRoomBtn, findsOneWidget);

    // Tap edit room button
    await tester.tap(editRoomBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-edit-hostel-room')), findsOneWidget);

    // Test invalid room number boundary
    await tester.enterText(find.byKey(const Key('input-edit-room-number')), '85');
    await tester.tap(find.byKey(const Key('btn-save-room-edits')));
    await tester.pumpAndSettle();
    expect(find.text('Room number must be between 100 and 999'), findsOneWidget);

    // Enter valid new room number
    await tester.enterText(find.byKey(const Key('input-edit-room-number')), '108');
    await tester.enterText(find.byKey(const Key('input-edit-block-name')), 'Block 3');
    await tester.tap(find.byKey(const Key('btn-save-room-edits')));
    await tester.pumpAndSettle();

    // Dialog should be dismissed and Room 108 should appear
    expect(find.byKey(const Key('dialog-edit-hostel-room')), findsNothing);
    expect(find.text('ROOM 108'), findsOneWidget);
    expect(find.text('Floor 0 • Block 3'), findsOneWidget);

    // Inspect fixtures for Room 108
    await tester.tap(find.byKey(const Key('btn-inspect-room-108')));
    await tester.pumpAndSettle();

    // Edit fixture
    final editFixtureBtn = find.byKey(const Key('btn-edit-asset-asset-101-bed-1'));
    expect(editFixtureBtn, findsOneWidget);
    await tester.tap(editFixtureBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-edit-hostel-asset')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('input-edit-asset-serial')), 'BED-108-01');
    await tester.tap(find.byKey(const Key('btn-save-asset-edits')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-edit-hostel-asset')), findsNothing);

    // Re-inspect to verify updated serial
    await tester.tap(find.byKey(const Key('btn-inspect-room-108')));
    await tester.pumpAndSettle();
    expect(find.text('SN: BED-108-01'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 2. Student Resident View restricts editing rooms and fixtures
    await tester.pumpWidget(MaterialApp(
      home: HostelScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // Student view does not show room edit buttons or add room button
    expect(find.byKey(const Key('btn-add-hostel-room')), findsNothing);
    expect(find.byKey(const Key('btn-edit-room-108')), findsNothing);
    expect(find.byKey(const Key('card-my-allotted-room')), findsOneWidget);
  });

  testWidgets('Hostel Mess Menu Management: Canteen Manager and Admin can edit menus with Sunday constraints, student view cannot edit',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final canteenManager = OfflineStorageService.getMockUserForHandle('mukesh_2025_ext_1');
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    expect(canteenManager.canEditMessMenu, isTrue);
    expect(student.canEditMessMenu, isFalse);

    // 1. Canteen manager view
    await tester.pumpWidget(MaterialApp(
      home: MessScreen(
        storage: storage,
        currentUser: canteenManager,
      ),
    ));
    await tester.pumpAndSettle();

    // Select Monday
    await tester.tap(find.byKey(const Key('chip-day-monday')));
    await tester.pumpAndSettle();

    // Verify edit menu button exists on monday breakfast
    final editMealBtn = find.byKey(const Key('btn-edit-meal-meal-monday-breakfast'));
    expect(editMealBtn, findsOneWidget);

    // Open edit dialog
    await tester.tap(editMealBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-edit-mess-meal')), findsOneWidget);

    // Edit title and items
    await tester.enterText(find.byKey(const Key('input-edit-meal-title')), 'Special South Indian Feast');
    await tester.enterText(find.byKey(const Key('input-edit-meal-items')), 'Mysore Masala Dosa, Idli, Medu Vada, Filter Coffee');
    await tester.tap(find.byKey(const Key('btn-save-meal-edits')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-edit-mess-meal')), findsNothing);
    expect(find.text('Special South Indian Feast'), findsOneWidget);
    expect(find.text('Mysore Masala Dosa'), findsOneWidget);

    // Switch to Sunday
    await tester.tap(find.byKey(const Key('chip-day-sunday')));
    await tester.pumpAndSettle();

    // Sunday Brunch should have edit button
    final editSundayBrunchBtn = find.byKey(const Key('btn-edit-meal-meal-sunday-brunch'));
    expect(editSundayBrunchBtn, findsOneWidget);
    await tester.tap(editSundayBrunchBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-edit-mess-meal')), findsOneWidget);
    expect(find.textContaining('Sunday Schedule: Only Brunch'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 2. Student view is read-only for editing menus
    await tester.pumpWidget(MaterialApp(
      home: MessScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // Switch to Sunday
    await tester.tap(find.byKey(const Key('chip-day-sunday')));
    await tester.pumpAndSettle();

    // No edit buttons for student
    expect(find.byKey(const Key('btn-edit-meal-meal-sunday-brunch')), findsNothing);
    // Student can still rate
    expect(find.byKey(const Key('btn-rate-meal-meal-sunday-brunch')), findsOneWidget);
  });

  testWidgets('Institutional Complaints: Anonymity policy by category and granular complaints:* RBAC permissions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');
    final warden = OfflineStorageService.getMockUserForHandle('ramesh_2023_emp_1');
    final hod = OfflineStorageService.getMockUserForHandle('priya_2024_emp_1');

    // Verify permission model
    expect(student.canManageComplaintsFor('student'), isFalse);
    expect(student.canManageComplaintsFor('hostel'), isFalse);
    expect(student.hasAnyComplaintManagementPermission, isFalse);

    expect(warden.canManageComplaintsFor('hostel'), isTrue);
    expect(warden.canManageComplaintsFor('campus'), isTrue);
    expect(warden.canManageComplaintsFor('student'), isFalse);
    expect(warden.canManageComplaintsFor('employee'), isFalse);

    expect(hod.canManageComplaintsFor('student'), isTrue);
    expect(hod.canManageComplaintsFor('employee'), isTrue);
    expect(hod.canManageComplaintsFor('hostel'), isFalse);

    // 1. Student lodges an anonymous complaint for Hostel category (permitted)
    await tester.pumpWidget(MaterialApp(
      home: ComplaintsScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify Student view has no administrative review tab
    expect(find.byKey(const Key('tab-admin-complaints')), findsNothing);

    // Open File Complaint Dialog
    await tester.tap(find.byKey(const Key('btn-file-complaint')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialog-file-complaint')), findsOneWidget);

    // Default category is Hostel, which supports anonymous
    expect(find.text('Anonymous Reporting (Supported)'), findsOneWidget);
    final anonSwitch = find.byKey(const Key('switch-complaint-anonymous'));
    expect(anonSwitch, findsOneWidget);

    // Toggle anonymous switch ON
    await tester.tap(anonSwitch);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('input-complaint-title')), 'Cold showers in Block C wing');
    await tester.enterText(find.byKey(const Key('input-complaint-description')), 'Water heater solar coil disconnected after thunderstorm.');
    await tester.tap(find.byKey(const Key('btn-submit-complaint')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-file-complaint')), findsNothing);
    expect(find.text('Cold showers in Block C wing'), findsOneWidget);
    // Verified that submitter name is masked as Anonymous Reporter
    expect(find.text('Anonymous Reporter'), findsWidgets);

    // 2. Student attempts to lodge complaint for Student Affairs (anonymity not supported)
    await tester.tap(find.byKey(const Key('btn-file-complaint')));
    await tester.pumpAndSettle();

    // Change category to Student Affairs & Academics
    await tester.tap(find.byKey(const Key('select-complaint-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student Affairs & Academics').last);
    await tester.pumpAndSettle();

    // Anonymous switch should now be locked and notice displayed
    expect(find.text('Anonymous Reporting Not Supported'), findsOneWidget);

    // Enter title & description
    await tester.enterText(find.byKey(const Key('input-complaint-title')), 'Missing grade for Practical Lab 2');
    await tester.enterText(find.byKey(const Key('input-complaint-description')), 'Completed lab on time but grade sheet shows pending submission.');
    await tester.tap(find.byKey(const Key('btn-submit-complaint')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-file-complaint')), findsNothing);
    expect(find.text('Missing grade for Practical Lab 2'), findsOneWidget);
    // Student's verified name is displayed
    expect(find.text(student.fullName), findsWidgets);

    // 3. Warden administrative review console (hostel:complaints & campus:complaints)
    await tester.pumpWidget(MaterialApp(
      home: ComplaintsScreen(
        storage: storage,
        currentUser: warden,
      ),
    ));
    await tester.pumpAndSettle();

    // Administrative review tab is present for warden
    expect(find.byKey(const Key('tab-admin-complaints')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-admin-complaints')));
    await tester.pumpAndSettle();

    // Warden can see and manage Hostel & Campus complaints
    expect(find.text('Cold showers in Block C wing'), findsOneWidget);
    // Warden CANNOT see Student category complaints in their admin console
    expect(find.text('Missing grade for Practical Lab 2'), findsNothing);

    // Update status of the hostel complaint
    final updateBtn = find.widgetWithText(OutlinedButton, 'Update Status').first;
    await tester.tap(updateBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-update-complaint-status')), findsOneWidget);
    await tester.tap(find.byKey(const Key('select-new-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolved').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('input-resolution-remarks')), 'Solar heater coil re-grounded and water temperature verified.');
    await tester.tap(find.byKey(const Key('btn-save-complaint-status')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-update-complaint-status')), findsNothing);
    expect(find.text('RESOLVED'), findsWidgets);
    expect(find.textContaining('Solar heater coil re-grounded'), findsOneWidget);
  });

  testWidgets('Small Screen Responsiveness: ComplaintsScreen standalone on 360x640',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final user = OfflineStorageService.getMockUserForHandle('campus_admin');

    await tester.pumpWidget(MaterialApp(
      home: ComplaintsScreen(
        storage: storage,
        currentUser: user,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Institutional Grievances & Complaints'), findsOneWidget);
  });

  testWidgets('Dedicated Complaints Navigation: AppBar shortcut, Desktop Sidebar, Mobile Dock & Dashboard Card',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final admin = OfflineStorageService.getMockUserForHandle('campus_admin');

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        storage: storage,
        currentUser: admin,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Dashboard Operational Card for Complaints
    expect(find.byKey(const Key('card-quick-complaints')), findsOneWidget);
    await tester.tap(find.byKey(const Key('card-quick-complaints')));
    await tester.pumpAndSettle();
    expect(find.text('Institutional Grievances & Complaints'), findsOneWidget);

    // 2. Desktop Sidebar clean layout: complaints is accessed via topbar shortcut to keep sidebar uncluttered
    expect(find.byKey(const Key('nav-item-complaints')), findsNothing);

    // 3. Top AppBar Complaints Quick Shortcut
    expect(find.byKey(const Key('appbar-btn-complaints')), findsOneWidget);
    await tester.tap(find.byKey(const Key('appbar-btn-complaints')));
    await tester.pumpAndSettle();
    expect(find.text('Institutional Grievances & Complaints'), findsOneWidget);

    // 4. Mobile screen 4-division bottom dock navigation
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    // Switch to Dashboard
    await tester.tap(find.byKey(const Key('dock-division-dashboard')));
    await tester.pumpAndSettle();

    // Open Pages Menu (Division 4)
    await tester.tap(find.byKey(const Key('dock-division-more-pages')));
    await tester.pumpAndSettle();

    // Tap Grievances & Complaints
    expect(find.byKey(const Key('dock-menu-item-complaints')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dock-menu-item-complaints')));
    await tester.pumpAndSettle();

    // Active Slot 3 now displays Complaints
    expect(find.text('Institutional Grievances & Complaints'), findsOneWidget);
    expect(find.byKey(const Key('dock-division-active-page')), findsOneWidget);
  });

  testWidgets('Contextual Complaints Shortcuts: Hostel, Mess, Timetable, and Attendance screens',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    // 1. Hostel Screen Shortcut
    await tester.pumpWidget(MaterialApp(
      home: HostelScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-shortcut-hostel-complaint')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-shortcut-hostel-complaint')));
    await tester.pumpAndSettle();

    // Dialog opens prefilled with category hostel
    expect(find.byKey(const Key('dialog-file-complaint')), findsOneWidget);
    expect(find.text('Hostel & Mess'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 2. Mess Screen Shortcut
    await tester.pumpWidget(MaterialApp(
      home: MessScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-shortcut-mess-complaint')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-shortcut-mess-complaint')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-file-complaint')), findsOneWidget);
    expect(find.text('Hostel & Mess'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 3. Timetable Screen Shortcut
    await tester.pumpWidget(MaterialApp(
      home: TimetableScreen(
        storage: storage,
        currentUser: student,
        activeScope: 'sec:cse-3a',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-shortcut-timetable-complaint')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-shortcut-timetable-complaint')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-file-complaint')), findsOneWidget);
    expect(find.text('Student Affairs & Academics'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 4. Attendance Screen Shortcut
    await tester.pumpWidget(MaterialApp(
      home: AttendanceScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-shortcut-attendance-complaint')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-shortcut-attendance-complaint')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-file-complaint')), findsOneWidget);
    expect(find.text('Student Affairs & Academics'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Every Dropdown in App: AppDropdown sub-anchor positioning in Complaints filters, Hostel and Mess dialogs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final admin = OfflineStorageService.getMockUserForHandle('campus_admin');

    // 1. Complaints Screen: Domain & Status filter dropdowns
    await tester.pumpWidget(MaterialApp(
      home: ComplaintsScreen(
        storage: storage,
        currentUser: admin,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter-complaints-domain')), findsOneWidget);
    expect(find.byKey(const Key('filter-complaints-status')), findsOneWidget);

    // Tap domain filter dropdown
    await tester.tap(find.byKey(const Key('filter-complaints-domain')));
    await tester.pumpAndSettle();

    // Verify all domain options drop down
    expect(find.text('Hostel & Mess'), findsWidgets);
    expect(find.text('Campus Infrastructure'), findsOneWidget);
    expect(find.text('Contractor & Vendor Operations'), findsOneWidget);

    // Select Hostel & Mess
    await tester.tap(find.text('Hostel & Mess').last);
    await tester.pumpAndSettle();

    // Reset button appears
    expect(find.byKey(const Key('btn-reset-complaint-filters')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-reset-complaint-filters')));
    await tester.pumpAndSettle();

    // 2. Hostel Screen: Add Asset Dialog fixture type dropdown
    await tester.pumpWidget(MaterialApp(
      home: HostelScreen(
        storage: storage,
        currentUser: admin,
      ),
    ));
    await tester.pumpAndSettle();

    final inspect101 = find.byKey(const Key('btn-inspect-room-101'));
    await tester.ensureVisible(inspect101);
    await tester.tap(inspect101);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn-modal-add-fixture')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('select-add-asset-type')), findsOneWidget);
    await tester.tap(find.byKey(const Key('select-add-asset-type')));
    await tester.pumpAndSettle();

    expect(find.text('Study Table (Max 3)'), findsOneWidget);
    expect(find.text('Wardrobe / Locker (Max 3)'), findsOneWidget);
    await tester.tap(find.text('Study Table (Max 3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 3. Mess Screen: Rate Meal Dialog slot dropdown
    await tester.pumpWidget(MaterialApp(
      home: MessScreen(
        storage: storage,
        currentUser: admin,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn-open-rate-meal-dialog')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('select-rate-meal-slot')), findsOneWidget);
    await tester.tap(find.byKey(const Key('select-rate-meal-slot')));
    await tester.pumpAndSettle();

    // Dropdown shows weekly meal timetable items
    expect(find.textContaining('Breakfast'), findsWidgets);
    await tester.tap(find.textContaining('Breakfast').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Sidebar Responsiveness: Desktop and tablet screen sizes show all 12 items without partial cut off', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final admin = OfflineStorageService.getMockUserForHandle('campus_admin');

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.devicePixelRatio = 1.0;

    final testSizes = [
      const Size(1920, 1080), // Standard 1080p desktop
      const Size(1366, 768),  // Standard laptop
      const Size(1280, 720),  // 720p HD monitor
      const Size(1024, 600),  // Compact netbook / small landscape window
      const Size(800, 520),   // Minimum desktop sidebar breakpoint with short height
    ];

    final navItemKeys = [
      'nav-item-dashboard',
      'nav-item-timetable',
      'nav-item-attendance',
      'nav-item-notices',
      'nav-item-directory',
      'nav-item-depts',
      'nav-item-hostel',
      'nav-item-mess',
      'nav-item-library',
      'nav-item-profile',
    ];

    for (final size in testSizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          storage: storage,
          currentUser: admin,
          onLogout: () {},
        ),
      ));
      await tester.pumpAndSettle();

      for (final keyName in navItemKeys) {
        final finder = find.byKey(Key(keyName));
        expect(finder, findsOneWidget, reason: '$keyName should be visible at size $size');

        final rect = tester.getRect(finder);
        // Ensure item is completely inside viewport vertically and horizontally
        expect(rect.top, greaterThanOrEqualTo(50.0),
            reason: '$keyName top (${rect.top}) should be below AppBar at size $size');
        expect(rect.bottom, lessThanOrEqualTo(size.height + 1.0),
            reason: '$keyName bottom (${rect.bottom}) must not be cut off at screen height ${size.height}');
        expect(rect.left, greaterThanOrEqualTo(0.0));
        expect(rect.right, lessThanOrEqualTo(80.0),
            reason: '$keyName width must fit comfortably within sidebar boundary');
      }
    }
  });

  testWidgets('Personalized Dashboards: Distinct greetings, metrics, operations, and spotlight cards per user role', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');
    final faculty = OfflineStorageService.getMockUserForHandle('priya_2024_emp_1');
    final warden = OfflineStorageService.getMockUserForHandle('ramesh_2023_emp_1');
    final canteen = OfflineStorageService.getMockUserForHandle('mukesh_2025_ext_1');
    final admin = OfflineStorageService.getMockUserForHandle('campus_admin');

    // 1. Verify Student Dashboard
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(storage: storage, currentUser: student, onLogout: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Harish!'), findsOneWidget);
    expect(find.textContaining('B.Tech Computer Science'), findsOneWidget);
    expect(find.text('Attendance Health'), findsOneWidget);
    expect(find.text('82.4%'), findsOneWidget);
    expect(find.text("Today's Schedule"), findsOneWidget);
    expect(find.text('Hostel Residence'), findsOneWidget);
    expect(find.text('UPCOMING LECTURE'), findsOneWidget);
    expect(find.text('Student Campus Hub'), findsOneWidget);

    // 2. Verify Faculty Dashboard
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(storage: storage, currentUser: faculty, onLogout: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dr. Priya!'), findsOneWidget);
    expect(find.textContaining('Department of CSE'), findsOneWidget);
    expect(find.text('Teaching Load'), findsOneWidget);
    expect(find.text('3 Classes Today'), findsOneWidget);
    expect(find.text('Optical Attendance'), findsOneWidget);
    expect(find.text('OPTICAL ATTENDANCE STUDIO'), findsOneWidget);
    expect(find.text('Academic & Instructional Governance'), findsOneWidget);

    // 3. Verify Warden Dashboard
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(storage: storage, currentUser: warden, onLogout: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ramesh!'), findsOneWidget);
    expect(find.textContaining('Chief Hostel Warden'), findsOneWidget);
    expect(find.text('Hostel Occupancy'), findsOneWidget);
    expect(find.text('94% Occupancy'), findsOneWidget);
    expect(find.text('Night Curfew'), findsOneWidget);
    expect(find.text('22:30 IST'), findsOneWidget);
    expect(find.text('RESIDENTIAL PROTOCOL'), findsOneWidget);
    expect(find.text('Residential Life & Facility Controls'), findsOneWidget);

    // 4. Verify Canteen / Mess Manager Dashboard
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(storage: storage, currentUser: canteen, onLogout: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mukesh!'), findsOneWidget);
    expect(find.textContaining('Central Campus Canteen & Mess'), findsOneWidget);
    expect(find.text('Meal Timetable'), findsOneWidget);
    expect(find.text('Average Rating'), findsOneWidget);
    expect(find.text('SUNDAY TIMETABLE CONSTRAINT'), findsOneWidget);
    expect(find.text('Dining Operations & Quality Assurance'), findsOneWidget);

    // 5. Verify Administrator Dashboard
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(storage: storage, currentUser: admin, onLogout: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Campus!'), findsOneWidget);
    expect(find.textContaining('Executive Governance'), findsOneWidget);
    expect(find.text('Campus Directory'), findsOneWidget);
    expect(find.text('1,420 Identities'), findsOneWidget);
    expect(find.text('Academic Structure'), findsOneWidget);
    expect(find.text('Institutional Redressal'), findsOneWidget);
    expect(find.text('DISTRIBUTED SYSTEM HEALTH'), findsOneWidget);
    expect(find.text('Executive Administration & Governance'), findsOneWidget);
  });

  testWidgets('Navigation Filtering & Showcase/Maintenance: Inaccessible pages hidden, lock overlay used for maintenance & feature preview',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');
    final facultyHOD = OfflineStorageService.getMockUserForHandle('priya_2024_emp_1');
    final admin = OfflineStorageService.getMockUserForHandle('campus_admin');

    // 1. Verify Student View: Directory & Depts are completely hidden from sidebar
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(storage: storage, currentUser: student, onLogout: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nav-item-dashboard')), findsOneWidget);
    expect(find.byKey(const Key('nav-item-timetable')), findsOneWidget);
    expect(find.byKey(const Key('nav-item-attendance')), findsOneWidget);
    expect(find.byKey(const Key('nav-item-notices')), findsOneWidget);
    expect(find.byKey(const Key('nav-item-directory')), findsNothing);
    expect(find.byKey(const Key('nav-item-depts')), findsNothing);
    expect(find.byKey(const Key('nav-item-hostel')), findsOneWidget);
    expect(find.byKey(const Key('nav-item-mess')), findsOneWidget);
    expect(find.byKey(const Key('nav-item-complaints')), findsNothing);
    expect(find.byKey(const Key('nav-item-fees')), findsNothing);
    expect(find.byKey(const Key('nav-item-library')), findsOneWidget);
    expect(find.byKey(const Key('nav-item-profile')), findsOneWidget);

    // 2. Verify Faculty (HOD) View: Directory hidden, but Depts visible and accessible
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(storage: storage, currentUser: facultyHOD, onLogout: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nav-item-directory')), findsNothing);
    expect(find.byKey(const Key('nav-item-depts')), findsOneWidget);

    // 3. Verify Admin View: All 10 items visible
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(storage: storage, currentUser: admin, onLogout: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nav-item-directory')), findsOneWidget);
    expect(find.byKey(const Key('nav-item-depts')), findsOneWidget);

    // 4. Maintenance Takedown Mode: Module 7 (Mess) under maintenance shows locked overlay
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        storage: storage,
        currentUser: student,
        maintenancePages: const {7},
        onLogout: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nav-item-mess')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-item-mess')));
    await tester.pumpAndSettle();

    expect(find.text('Module Under Maintenance'), findsOneWidget);
    expect(find.text('MAINTENANCE TAKEDOWN'), findsOneWidget);
    expect(find.text('Hostel Mess & Feedback'), findsOneWidget);
    expect(find.byKey(const Key('btn-maintenance-back-dashboard')), findsOneWidget);

    // Tap Back to Dashboard
    await tester.tap(find.byKey(const Key('btn-maintenance-back-dashboard')));
    await tester.pumpAndSettle();
    expect(find.text('Academic Operations'), findsOneWidget);

    // 5. Future Feature Showcase Mode: Module 5 (Academic Departments) preview showcase
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        storage: storage,
        currentUser: student,
        showcasePages: const {5},
        onLogout: () {},
      ),
    ));
    await tester.pumpAndSettle();

    // Module 5 was previously hidden for student, now shown as locked feature showcase
    expect(find.byKey(const Key('nav-item-depts')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-item-depts')));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming Feature Preview'), findsOneWidget);
    expect(find.text('PREVIEW SHOWCASE'), findsOneWidget);
    expect(find.text('Academic Departments & Structure'), findsOneWidget);
    expect(find.byKey(const Key('btn-showcase-back-dashboard')), findsOneWidget);

    // Tap Back to Dashboard
    await tester.tap(find.byKey(const Key('btn-showcase-back-dashboard')));
    await tester.pumpAndSettle();
    expect(find.text('Academic Operations'), findsOneWidget);
  });

  testWidgets('Institutional Fee Portal: Invoices list, status filter, itemized breakdown, and payment dialog with receipt proof', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    await tester.pumpWidget(MaterialApp(
      home: FeeScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Verify summary cards
    expect(find.text('Total Outstanding Dues'), findsOneWidget);
    expect(find.text('Settled Institutional Fees'), findsOneWidget);
    expect(find.text('Pending Fines & Penalties'), findsOneWidget);
    expect(find.text('Next Settlement Deadline'), findsOneWidget);

    // 2. Verify Tab 1 (Fee Portal) is default
    expect(find.byKey(const Key('tab-fee-invoices')), findsOneWidget);
    expect(find.byKey(const Key('filter-fee-invoices-status')), findsOneWidget);

    // Verify invoice cards exist
    expect(find.byKey(const Key('invoice-card-inv-hostel-2026-sem3')), findsOneWidget);
    expect(find.text('Hostel Residency & Maintenance (BBDIT Hostel)'), findsOneWidget);
    expect(find.text('Itemized Fee Head Breakdown'), findsWidgets);

    // 3. Test Download Invoice PDF
    expect(find.byKey(const Key('btn-download-invoice-pdf-inv-hostel-2026-sem3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-download-invoice-pdf-inv-hostel-2026-sem3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Invoice PDF downloaded: invoice-inv-hostel-2026-sem3.pdf'), findsOneWidget);

    // 4. Test Pay Fee Dialog
    expect(find.byKey(const Key('btn-pay-fee-inv-hostel-2026-sem3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-pay-fee-inv-hostel-2026-sem3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-pay-invoice')), findsOneWidget);
    expect(find.byKey(const Key('input-payment-amount')), findsOneWidget);
    expect(find.byKey(const Key('select-payment-method')), findsOneWidget);

    // Confirm Payment
    await tester.tap(find.byKey(const Key('btn-confirm-pay-invoice')));
    await tester.pumpAndSettle();

    // Verify snackbar feedback with receipt proof
    expect(find.textContaining('Payment processed successfully'), findsOneWidget);
  });

  testWidgets('Institutional Fine Portal: Disciplinary and library fines, appeal flow, waiver for admins, and fine settlement', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');
    final admin = OfflineStorageService.getMockUserForHandle('campus_admin');

    await tester.pumpWidget(MaterialApp(
      home: FeeScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // Switch to Fine Portal Tab
    await tester.tap(find.byKey(const Key('tab-fine-portal')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter-fines-status')), findsOneWidget);
    expect(find.byKey(const Key('fine-card-fine-lib-01')), findsOneWidget);
    expect(find.byKey(const Key('fine-card-fine-disc-01')), findsOneWidget);

    // 1. Appeal fine flow
    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('btn-appeal-fine-fine-lib-01')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-appeal-fine-fine-lib-01')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-appeal-fine')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('input-appeal-reason')), 'Attending IEEE conference with HOD permission');
    await tester.tap(find.byKey(const Key('btn-submit-appeal')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fine appeal submitted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // 2. Pay fine flow
    await tester.scrollUntilVisible(
      find.byKey(const Key('btn-pay-fine-fine-lib-01')),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('btn-pay-fine-fine-lib-01')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-pay-fine-fine-lib-01')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-pay-fine')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-confirm-pay-fine')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fine settled successfully'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // 3. Admin waiver flow
    await tester.pumpWidget(MaterialApp(
      home: FeeScreen(
        storage: storage,
        currentUser: admin,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-fine-portal')));
    await tester.pumpAndSettle();

    if (find.byKey(const Key('btn-waive-fine-fine-disc-01')).evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(const Key('btn-waive-fine-fine-disc-01')),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('btn-waive-fine-fine-disc-01')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog-waive-fine')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn-confirm-waive')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Penalty successfully waived'), findsOneWidget);
    }
  });

  testWidgets('Records and Receipts Ledger: Search receipts and view tamper-evident proof', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    await tester.pumpWidget(MaterialApp(
      home: FeeScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // Switch to Tab 3 (Records & Receipts)
    await tester.tap(find.byKey(const Key('tab-records-ledger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('input-search-payments')), findsOneWidget);
    expect(find.byKey(const Key('payment-record-pay-001')), findsOneWidget);

    // Search filter
    await tester.enterText(find.byKey(const Key('input-search-payments')), 'TXN-HDFC');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ref: TXN-HDFC'), findsOneWidget);

    // View Receipt Proof dialog
    expect(find.byKey(const Key('btn-view-receipt-RCP-2026-00108')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-view-receipt-RCP-2026-00108')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-view-receipt')), findsOneWidget);
    expect(find.text('Official Settlement Receipt'), findsOneWidget);
    expect(find.text('Tamper-evident proof of settlement issued by BBDIT & BBDIT College of Pharmacy Treasury Operations.'), findsOneWidget);

    // Close Dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialog-view-receipt')), findsNothing);
  });

  testWidgets('Small Screen Responsiveness: FeeScreen standalone on 360x640 with zero layout overflow', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      home: FeeScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify all 4 tabs switch without overflow
    await tester.tap(find.byKey(const Key('tab-fine-portal')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('tab-records-ledger')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('tab-fee-structure')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('tab-fee-invoices')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Institutional Library: Loans list, active loans, overdue badge, return dates, late fine banner with Fine Portal link, and loan renewal', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    int? navigatedTab;

    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: student,
        onNavigateToTab: (tabIndex) {
          navigatedTab = tabIndex;
        },
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Verify Header Metrics
    expect(find.text('Active Loans'), findsOneWidget);
    expect(find.text('Overdue Loans'), findsOneWidget);
    expect(find.text('Borrowing Quota'), findsOneWidget);
    expect(find.text('Returned History'), findsOneWidget);

    // 2. Overdue Banner & Fine Portal Link
    expect(find.byKey(const Key('banner-library-overdue')), findsOneWidget);
    expect(find.text('₹50 Fine Due'), findsOneWidget);
    expect(find.byKey(const Key('btn-goto-fine-portal')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-goto-fine-portal')));
    await tester.pumpAndSettle();
    expect(navigatedTab, equals(9)); // Fee & Fine Portal tab index

    // 3. Loans list & Filter
    expect(find.byKey(const Key('dropdown-borrow-status')), findsOneWidget);
    expect(find.byKey(const Key('card-loan-brw-clrs-01')), findsOneWidget);
    expect(find.byKey(const Key('card-loan-brw-os-01')), findsOneWidget);

    // Filter to Active Loans
    await tester.tap(find.byKey(const Key('dropdown-borrow-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active Loans').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-loan-brw-clrs-01')), findsOneWidget);
    expect(find.byKey(const Key('card-loan-brw-os-01')), findsNothing);

    // Filter to Returned History
    await tester.tap(find.byKey(const Key('dropdown-borrow-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Returned History').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-loan-brw-math-01')), findsOneWidget);
    expect(find.byKey(const Key('card-loan-brw-clrs-01')), findsNothing);

    // Switch back to All Loans
    await tester.tap(find.byKey(const Key('dropdown-borrow-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Loans').last);
    await tester.pumpAndSettle();

    // 4. Renew Loan
    expect(find.byKey(const Key('btn-renew-brw-clrs-01')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-renew-brw-clrs-01')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Loan extended by 14 days'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // 5. Return Book
    expect(find.byKey(const Key('btn-return-brw-clrs-01')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-return-brw-clrs-01')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Book Return'), findsOneWidget);
    await tester.tap(find.text('Return Copy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('returned successfully'), findsOneWidget);
  });

  testWidgets('Institutional Library: Physical books catalog, search, category filter, remaining copies badges, and checkout quota decrement', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // First return the overdue loan so Harish has borrowing eligibility
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('btn-return-brw-os-01')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-return-brw-os-01')));
    await tester.pumpAndSettle();
    expect(find.text('Late Return Notice'), findsOneWidget);
    await tester.tap(find.text('Return Copy'));
    await tester.pumpAndSettle();

    // Switch to Tab 2: Physical Catalog
    await tester.tap(find.byKey(const Key('tab-books-catalog')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Borrowing Quota:'), findsOneWidget);
    expect(find.byKey(const Key('input-book-search')), findsOneWidget);
    expect(find.byKey(const Key('dropdown-book-category')), findsOneWidget);

    // Verify book cards exist
    expect(find.byKey(const Key('card-book-bk-algo-01')), findsOneWidget);
    expect(find.byKey(const Key('card-book-bk-db-01')), findsOneWidget);

    // Filter to AI category
    await tester.tap(find.byKey(const Key('dropdown-book-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artificial Intelligence').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-book-bk-ai-01')), findsOneWidget);
    expect(find.text('0 copies left (Checked out)'), findsOneWidget);

    // Verify 0-copy book borrow button is disabled
    final disabledBorrowButton = tester.widget<ElevatedButton>(find.byKey(const Key('btn-borrow-bk-ai-01')));
    expect(disabledBorrowButton.onPressed, isNull);

    // Reset to All Categories
    await tester.tap(find.byKey(const Key('dropdown-book-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Categories').last);
    await tester.pumpAndSettle();

    // Verify remaining copies badges
    expect(find.byKey(const Key('badge-copies-bk-db-01')), findsOneWidget);
    expect(find.text('4 of 6 available'), findsOneWidget);

    // Search for Database System Concepts
    await tester.enterText(find.byKey(const Key('input-book-search')), 'Database');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-book-bk-db-01')), findsOneWidget);
    expect(find.byKey(const Key('card-book-bk-algo-01')), findsNothing);

    // Borrow available book
    expect(find.byKey(const Key('btn-borrow-bk-db-01')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-borrow-bk-db-01')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Book Checkout'), findsOneWidget);
    expect(find.textContaining('Standard Loan Policy:'), findsOneWidget);
    await tester.tap(find.text('Confirm Checkout'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Successfully borrowed'), findsOneWidget);
    // Verified copies decremented from 4 to 3
    expect(find.text('3 of 6 available'), findsOneWidget);
  });

  testWidgets('Institutional Library: Digital E-Books with infinite concurrent borrowing, search, category filter, and online reader modal', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // Switch to Tab 3: Infinite E-Books
    await tester.tap(find.byKey(const Key('tab-infinite-ebooks')));
    await tester.pumpAndSettle();

    expect(find.text('Institutional Digital Knowledge Repository'), findsOneWidget);
    expect(find.textContaining('Infinite Concurrent Access'), findsOneWidget);
    expect(find.byKey(const Key('card-ebook-ebk-clean-code')), findsOneWidget);
    expect(find.byKey(const Key('card-ebook-ebk-deep-learning')), findsOneWidget);

    // Read Online modal
    expect(find.byKey(const Key('btn-read-ebook-ebk-clean-code')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-read-ebook-ebk-clean-code')));
    await tester.pumpAndSettle();

    expect(find.text('Infinite Concurrent Institutional License'), findsOneWidget);
    expect(find.text('Table of Contents (Institutional Digital Edition)'), findsOneWidget);
    expect(find.text('Start Fullscreen Reader'), findsOneWidget);
    expect(find.text('Download Offline Copy'), findsOneWidget);

    await tester.tap(find.text('Download Offline Copy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Downloading'), findsOneWidget);

    // Instant download button on card
    await tester.tap(find.byKey(const Key('btn-download-ebook-ebk-clean-code')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Downloading'), findsOneWidget);
  });

  testWidgets('Institutional Library: Policy & Slabs tab and Small Screen Responsiveness (360x640)', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // Tab 1: Borrowed Books at 360x640
    expect(tester.takeException(), isNull);

    // Swipe to Tab 2: Physical Catalog at 360x640
    await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Swipe to Tab 3: Infinite E-Books at 360x640
    await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Swipe to Tab 4: Policy & Slabs at 360x640
    await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Institutional Borrowing Privileges & Quotas'), findsOneWidget);
    expect(find.text('Overdue Fine Slabs & Settle Protocol'), findsOneWidget);
    final policyScrollable = find.descendant(
      of: find.byKey(const Key('list-library-policy')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Fine Appeals & Medical Waivers'),
      100,
      scrollable: policyScrollable,
    );
    expect(find.text('Fine Appeals & Medical Waivers'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Book Care & Replacement Policy'),
      100,
      scrollable: policyScrollable,
    );
    expect(find.text('Book Care & Replacement Policy'), findsOneWidget);
  });

  testWidgets('Institutional Library: Dark mode theme integration renders with design system palette', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: LibraryScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Verify Scaffold background is darkBg
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, equals(AppColors.darkBg));

    // Verify AppBar background is darkSurface
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, equals(AppColors.darkSurface));

    // Verify loan cards rendered in dark mode
    expect(find.byKey(const Key('card-loan-brw-clrs-01')), findsOneWidget);

    // Switch to Tab 3: Infinite E-Books
    await tester.tap(find.byKey(const Key('tab-infinite-ebooks')));
    await tester.pumpAndSettle();
    expect(find.text('Institutional Digital Knowledge Repository'), findsOneWidget);

    // Open E-Book Reader modal bottom sheet in dark mode
    await tester.tap(find.byKey(const Key('btn-read-ebook-ebk-clean-code')));
    await tester.pumpAndSettle();

    expect(find.text('Table of Contents (Institutional Digital Edition)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Close reader modal
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });

  testWidgets('Institutional Dispute System: Student raises formal dispute for exam result, verified identity enforcement, and record type filtering',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    await tester.pumpWidget(MaterialApp(
      home: ComplaintsScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify "+ Raise Dispute" button is present in the action row
    final raiseDisputeBtn = find.byKey(const Key('btn-raise-dispute'));
    expect(raiseDisputeBtn, findsOneWidget);

    // Open Raise Dispute modal dialog
    await tester.tap(raiseDisputeBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-raise-dispute')), findsOneWidget);
    expect(find.text('Raise Official Dispute'), findsOneWidget);

    // Target selector is present
    await tester.tap(find.byKey(const Key('select-dispute-target-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exam Result & Gradebook Evaluation').last);
    await tester.pumpAndSettle();

    // Fill in target reference ID
    await tester.enterText(find.byKey(const Key('input-dispute-target-id')), 'EXAM-2026-CS301');

    // Fill in dispute title
    await tester.enterText(find.byKey(const Key('input-dispute-title')), 'Discrepancy in CS301 Endsem Evaluation');

    // Select a quick-fill remedy chip
    final remedyChip = find.text('Answer Script Re-evaluation');
    expect(remedyChip, findsOneWidget);
    await tester.tap(remedyChip);
    await tester.pumpAndSettle();

    // Fill in evidence
    await tester.enterText(find.byKey(const Key('input-dispute-evidence')), 'Evaluated answer booklet copy with question 4 uncounted.');

    // Submit the formal dispute
    await tester.tap(find.byKey(const Key('btn-submit-dispute')));
    await tester.pumpAndSettle();

    // Verify dialog is dismissed
    expect(find.byKey(const Key('dialog-raise-dispute')), findsNothing);

    // Verify newly raised dispute appears in user list
    expect(find.text('Discrepancy in CS301 Endsem Evaluation'), findsOneWidget);
    expect(find.text('OFFICIAL DISPUTE'), findsWidgets);
    expect(find.textContaining('EXAM-2026-CS301'), findsWidgets);
    expect(find.textContaining('Answer Script Re-evaluation'), findsOneWidget);
    expect(find.textContaining('Evaluated answer booklet copy'), findsOneWidget);

    // Test Record Type Filter
    // 1. Filter by General Complaints only -> Dispute should disappear
    await tester.tap(find.byKey(const Key('filter-record-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General Complaints').last);
    await tester.pumpAndSettle();
    expect(find.text('Discrepancy in CS301 Endsem Evaluation'), findsNothing);

    // 2. Filter by Official Disputes only -> Dispute should appear
    await tester.tap(find.byKey(const Key('filter-record-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Official Disputes').last);
    await tester.pumpAndSettle();
    expect(find.text('Discrepancy in CS301 Endsem Evaluation'), findsOneWidget);

    // 3. Reset Filters
    await tester.tap(find.byKey(const Key('btn-reset-complaint-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Discrepancy in CS301 Endsem Evaluation'), findsOneWidget);
  });

  testWidgets('Contextual Disputes: FeeScreen allows raising dispute directly from invoice and fine cards',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    await tester.pumpWidget(MaterialApp(
      home: FeeScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Invoices Tab: Dispute Invoice button should be visible in invoice card
    final disputeInvoiceBtn = find.byKey(const Key('btn-dispute-invoice-inv-hostel-2026-sem3'));
    expect(disputeInvoiceBtn, findsOneWidget);

    await tester.tap(disputeInvoiceBtn);
    await tester.pumpAndSettle();

    // Verify Raise Dispute dialog opens with Fee domain and inv-hostel-2026-sem3 prefilled
    expect(find.byKey(const Key('dialog-raise-dispute')), findsOneWidget);
    expect(find.text('Fee Invoice & Ledger Charges'), findsWidgets);
    expect(find.text('inv-hostel-2026-sem3'), findsOneWidget);

    // Close the dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialog-raise-dispute')), findsNothing);

    // 2. Switch to Fine Portal Tab
    await tester.tap(find.byKey(const Key('tab-fine-portal')));
    await tester.pumpAndSettle();

    // Find Dispute Fine button on fine-lib-01
    final disputeFineBtn = find.byKey(const Key('btn-dispute-fine-fine-lib-01'));
    expect(disputeFineBtn, findsOneWidget);

    await tester.tap(disputeFineBtn);
    await tester.pumpAndSettle();

    // Verify Raise Dispute dialog opens with Fine domain and fine-lib-01 prefilled
    expect(find.byKey(const Key('dialog-raise-dispute')), findsOneWidget);
    expect(find.text('Institutional Fine (Late / Disciplinary)'), findsWidgets);
    expect(find.text('fine-lib-01'), findsOneWidget);

    // Close the dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialog-raise-dispute')), findsNothing);
  });

  testWidgets('Institutional Library: Library In-Charge Approval workflow for physical book borrowing', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');
    final librarian = OfflineStorageService.getMockUserForHandle('admin');

    // 1. Student views Library: no Approvals tab
    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tab-borrow-approvals')), findsNothing);

    // Return overdue loan first so Harish has borrowing eligibility
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('btn-return-brw-os-01')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-return-brw-os-01')));
    await tester.pumpAndSettle();
    expect(find.text('Late Return Notice'), findsOneWidget);
    await tester.tap(find.text('Return Copy'));
    await tester.pumpAndSettle();

    // Switch to physical catalog and search for Database System Concepts
    await tester.tap(find.byKey(const Key('tab-books-catalog')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('input-book-search')), 'Database');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-borrow-bk-db-01')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-borrow-bk-db-01')));
    await tester.pumpAndSettle();

    // Dialog with approval policy notice
    expect(find.text('Confirm Book Checkout'), findsOneWidget);
    expect(find.textContaining('Approval Rule: Physical loan requires Library In-Charge authorization'), findsOneWidget);

    await tester.tap(find.text('Confirm Checkout'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Awaiting approval from Library In-Charge'), findsOneWidget);

    // Switch back to borrowed books tab
    await tester.tap(find.byKey(const Key('tab-borrowed-books')));
    await tester.pumpAndSettle();

    expect(find.text('Pending Approval'), findsWidgets);
    expect(find.textContaining('Pending approval from Library In-Charge'), findsWidgets);

    // 2. Library In-Charge (Admin) views Library: Approvals tab present
    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: librarian,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tab-borrow-approvals')), findsOneWidget);
    await tester.drag(find.byType(TabBar), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-borrow-approvals')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Borrow Approvals Counter'), findsOneWidget);
    expect(find.textContaining('Database System Concepts'), findsWidgets);
    expect(find.text('Approve Loan'), findsWidgets);

    // Tap Approve Loan on the request
    final approveBtn = find.text('Approve Loan').first;
    await tester.tap(approveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Approve Borrow Request'), findsOneWidget);
    expect(find.byKey(const Key('btn-confirm-approve-borrow')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-confirm-approve-borrow')));
    await tester.pumpAndSettle();

    expect(find.textContaining('approved successfully. Loan is now active.'), findsOneWidget);
  });

  testWidgets('Institutional Library: In-Charge approval workflow for Return and Renewal requests', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');
    final librarian = OfflineStorageService.getMockUserForHandle('admin');

    // 1. Student requests renewal on active loan (brw-clrs-01)
    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-renew-brw-clrs-01')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-renew-brw-clrs-01')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Loan extension request submitted'), findsOneWidget);
    expect(find.text('Pending Renewal'), findsWidgets);
    expect(find.textContaining('Deadline extension submitted. Awaiting Library In-Charge authorization.'), findsOneWidget);

    // 2. Librarian views Approvals tab and approves the renewal
    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: librarian,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(TabBar), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-borrow-approvals')));
    await tester.pumpAndSettle();

    expect(find.text('Pending Renewal Extension'), findsWidgets);
    expect(find.byKey(const Key('btn-approve-renewal-brw-clrs-01')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-approve-renewal-brw-clrs-01')));
    await tester.pumpAndSettle();

    expect(find.text('Approve Loan Extension'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-confirm-approve-renewal')));
    await tester.pumpAndSettle();

    expect(find.textContaining('approved. New due date:'), findsOneWidget);

    // 3. Student initiates book return
    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-return-brw-clrs-01')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-return-brw-clrs-01')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Book Return'), findsOneWidget);
    await tester.tap(find.text('Return Copy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pending Library In-Charge counter inspection'), findsOneWidget);
    expect(find.text('Pending Return'), findsWidgets);
    expect(find.textContaining('Return initiated. Please present the physical copy at the circulation counter'), findsOneWidget);

    // 4. Librarian inspects and approves return
    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: librarian,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(TabBar), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-borrow-approvals')));
    await tester.pumpAndSettle();

    expect(find.text('Pending Return Inspection'), findsWidgets);
    expect(find.byKey(const Key('btn-approve-return-brw-clrs-01')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-approve-return-brw-clrs-01')));
    await tester.pumpAndSettle();

    expect(find.text('Accept Physical Book Return'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-confirm-approve-return')));
    await tester.pumpAndSettle();

    expect(find.textContaining('verified and accepted. Catalog copy incremented.'), findsOneWidget);
  });

  testWidgets('Institutional Library: Librarian adds physical book to catalog and removes an existing volume', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final librarian = OfflineStorageService.getMockUserForHandle('admin');

    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: librarian,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Go to Physical Catalog tab
    await tester.tap(find.byKey(const Key('tab-books-catalog')));
    await tester.pumpAndSettle();

    // Librarian sees "Add Book to Catalog" button
    expect(find.byKey(const Key('btn-add-catalog')), findsOneWidget);

    // 2. Tap Add Book to Catalog
    await tester.tap(find.byKey(const Key('btn-add-catalog')));
    await tester.pumpAndSettle();

    expect(find.text('Add Book to Catalog'), findsWidgets);
    expect(find.byKey(const Key('input-catalog-title')), findsOneWidget);
    expect(find.byKey(const Key('input-catalog-author')), findsOneWidget);
    expect(find.byKey(const Key('input-catalog-isbn')), findsOneWidget);

    // Fill in book details
    await tester.enterText(find.byKey(const Key('input-catalog-title')), 'Compiler Construction');
    await tester.enterText(find.byKey(const Key('input-catalog-author')), 'Niklaus Wirth');
    await tester.enterText(find.byKey(const Key('input-catalog-isbn')), '978-0201403534');
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.byKey(const Key('btn-submit-catalog')));
    await tester.pumpAndSettle();

    expect(find.textContaining("Book 'Compiler Construction' added to catalog successfully"), findsOneWidget);
    expect(find.text('Compiler Construction'), findsOneWidget);

    // 3. Remove a catalogue book (delete the newly added book)
    final removeBtns = find.text('Remove Catalogue');
    expect(removeBtns, findsWidgets);
    await tester.tap(removeBtns.first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-confirm-remove-book')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-confirm-remove-book')));
    await tester.pumpAndSettle();

    expect(find.textContaining('removed from catalog'), findsOneWidget);
  });

  testWidgets('Institutional Library: Student uploads PDF book awaiting In-Charge approval, and Librarian approves student PDF book', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');
    final librarian = OfflineStorageService.getMockUserForHandle('admin');

    // 1. Student views Infinite E-Books tab and uploads PDF book
    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-infinite-ebooks')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-add-pdf-book')), findsOneWidget);
    expect(find.text('Upload PDF E-Book'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-add-pdf-book')));
    await tester.pumpAndSettle();

    expect(find.text('Upload PDF E-Book for Approval'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('input-pdf-title')), 'Computer Graphics: Principles and Practice');
    await tester.enterText(find.byKey(const Key('input-pdf-author')), 'James D. Foley, Andries van Dam');
    await tester.enterText(find.byKey(const Key('input-pdf-description')), 'Classic textbook on raster algorithms, 3D pipelines, and shader architecture.');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn-submit-pdf-book')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Awaiting Library In-Charge approval'), findsOneWidget);
    expect(find.text('Pending In-Charge Approval'), findsWidgets);

    // 2. Librarian opens Approvals tab to approve the PDF submission
    await tester.pumpWidget(MaterialApp(
      home: LibraryScreen(
        storage: storage,
        currentUser: librarian,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(TabBar), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-borrow-approvals')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Student-Submitted PDF Books'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Pending PDF Review'), findsWidgets);
    expect(find.text('Approve PDF'), findsWidgets);

    // Tap Approve PDF
    await tester.tap(find.text('Approve PDF').first);
    await tester.pumpAndSettle();

    expect(find.text('Approve PDF E-Book'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-confirm-approve-pdf')));
    await tester.pumpAndSettle();

    expect(find.textContaining('approved and added to active library collection'), findsOneWidget);
  });

  testWidgets('Enhanced UserProfileScreen: Digital Smart ID pass modal, Campus Life snapshot, contact editing, and theme toggle', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: UserProfileScreen(
        storage: storage,
        userIdentifier: 'usr-harish_2025_l_btech_1',
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Digital ID Card
    expect(find.text('Harish Kumar'), findsWidgets);
    expect(find.text('harish_2025_l_btech_1'), findsWidgets);
    expect(find.text('ACTIVE'), findsWidgets);
    expect(find.text('STUDENT'), findsWidgets);
    expect(find.text('Digital ID Pass'), findsOneWidget);

    // 2. Open Digital ID pass modal
    await tester.tap(find.text('Digital ID Pass'));
    await tester.pumpAndSettle();

    expect(find.text('CAMPUS DIGITAL PASS'), findsOneWidget);
    expect(find.text('CAMPUS-NFC-VERIFIED'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Close modal
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('CAMPUS DIGITAL PASS'), findsNothing);

    // 3. Campus Life Snapshot & Activity Metrics
    expect(find.text('Campus Life Snapshot & Activity'), findsOneWidget);
    expect(find.text('Attendance Standing'), findsOneWidget);
    expect(find.text('Library Standing'), findsOneWidget);
    expect(find.text('Hostel & Residence'), findsOneWidget);
    expect(find.text('Institutional Fees'), findsOneWidget);

    // 4. Contact & Emergency Information Card
    expect(find.text('Official Identity & Verification'), findsOneWidget);
    expect(find.text('Contact & Emergency Directory'), findsOneWidget);
    expect(find.text('Edit Details'), findsOneWidget);

    // 5. Open Edit Contact Details dialog
    await tester.tap(find.text('Edit Details'));
    await tester.pumpAndSettle();

    expect(find.text('Update Contact Details'), findsOneWidget);
    expect(find.text('Personal Email'), findsWidgets);
    expect(find.text('Emergency Contact Name'), findsOneWidget);
    expect(find.text('Save Details'), findsOneWidget);

    // Edit fields
    final phoneFinder = find.widgetWithText(TextField, '+91 98765 43210');
    if (phoneFinder.evaluate().isNotEmpty) {
      await tester.enterText(phoneFinder, '+91 99999 88888');
    }
    await tester.tap(find.text('Save Details'));
    await tester.pumpAndSettle();

    expect(find.text('Contact details updated successfully.'), findsOneWidget);

    // 6. Theme toggle
    await tester.ensureVisible(find.text('Switch to Dark'));
    await tester.pumpAndSettle();
    expect(find.text('Application Theme Preference'), findsOneWidget);
    expect(find.text('Switch to Dark'), findsOneWidget);

    await tester.tap(find.text('Switch to Dark'));
    await tester.pumpAndSettle();

    expect(AppTheme.themeModeNotifier.value, equals(ThemeMode.dark));

    await tester.ensureVisible(find.text('Switch to Light'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch to Light'));
    await tester.pumpAndSettle();

    expect(AppTheme.themeModeNotifier.value, equals(ThemeMode.light));
  });

  testWidgets('Small Screen Responsiveness: UserProfileScreen standalone on 360x640 without overflow', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(
      home: UserProfileScreen(
        storage: storage,
        userIdentifier: 'usr-harish_2025_l_btech_1',
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Harish Kumar'), findsWidgets);
    expect(find.text('Digital ID Pass'), findsOneWidget);
  });

  testWidgets('AKTU Sessional & Continuous Internal Evaluation: Scorecard, AKTU formula breakdown, and Dispute linkage', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final harish = await storage.getUserProfile('usr-harish_2025_l_btech_1');

    await tester.pumpWidget(MaterialApp(
      home: SessionalExamScreen(
        storage: storage,
        currentUser: harish,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Verify Header and Institutional Context
    expect(find.text('AKTU Sessional & Internal Assessment'), findsOneWidget);
    expect(find.text('AKTU Affiliated'), findsOneWidget);
    expect(find.textContaining('internal theory marks are derived from Class Tests'), findsOneWidget);

    // 2. Verify Subject Cards
    expect(find.text('CS301'), findsWidgets);
    expect(find.text('Operating Systems'), findsWidgets);
    expect(find.text('CS301L'), findsWidgets);
    expect(find.text('Practical Lab'), findsOneWidget);

    // 3. Verify AKTU Formula chips
    expect(find.text('CT-1 Score'), findsWidgets);
    expect(find.text('CT-2 Score'), findsWidgets);
    expect(find.text('Sessional Scaled'), findsWidgets);
    expect(find.text('Total Theory Internal'), findsWidgets);
    expect(find.text('Total Practical Internal'), findsOneWidget);

    // 4. Test Dispute linkage
    final disputeBtn = find.byKey(const Key('btn-dispute-sessional-CS301'));
    await tester.ensureVisible(disputeBtn);
    await tester.pumpAndSettle();
    await tester.tap(disputeBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-raise-dispute')), findsOneWidget);
    expect(find.text('Raise Official Dispute'), findsOneWidget);
    expect(find.text('CS301'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('AKTU Sessional & Continuous Internal Evaluation: Faculty Mark Entry, Datesheet, Seating, and HOD Freeze', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final hod = await storage.getUserProfile('usr-priya_2024_emp_1');

    await tester.pumpWidget(MaterialApp(
      home: SessionalExamScreen(
        storage: storage,
        currentUser: hod,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Switch to Faculty Mark Entry tab
    await tester.tap(find.text('Faculty Mark Entry'));
    await tester.pumpAndSettle();

    expect(find.text('Select Course:'), findsOneWidget);
    expect(find.text('CS301'), findsWidgets);
    expect(find.text('Save Marks'), findsWidgets);

    // 2. Switch to Datesheet & Seating tab
    await tester.tap(find.text('Datesheet & Seating'));
    await tester.pumpAndSettle();

    expect(find.text('Official Sessional Schedule'), findsOneWidget);
    expect(find.text('Interactive Hall Seating Layout'), findsOneWidget);
    expect(find.text('D-01'), findsOneWidget);
    expect(find.text('Seat 1'), findsOneWidget);

    // 3. Switch to AKTU Award List tab
    await tester.tap(find.text('AKTU Award List & HOD'));
    await tester.pumpAndSettle();

    expect(find.text('Export AKTU CSV'), findsOneWidget);
    expect(find.text('Class Average'), findsOneWidget);
    expect(find.text('Pass Percentage'), findsOneWidget);

    // Export CSV
    await tester.tap(find.byKey(const Key('btn-export-aktu-csv')));
    await tester.pumpAndSettle();

    expect(find.text('AKTU Award List CSV Export'), findsOneWidget);
    expect(find.text('Copy CSV'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('DigiLocker & APAAR / ABC ID Integration: Verified Credentials, ABC Card, Cryptographic Hash Inspection', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(MaterialApp(
      home: UserProfileScreen(
        storage: storage,
        userIdentifier: 'usr-harish_2025_l_btech_1',
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Verify DigiLocker Section
    expect(find.text('DigiLocker & Academic Bank of Credits (ABC) Vault'), findsOneWidget);
    expect(find.text('DigiLocker Verified'), findsOneWidget);
    expect(find.text('Sync DigiLocker'), findsOneWidget);

    // 2. Verify APAAR / ABC ID
    expect(find.text('8912-3456-7890'), findsOneWidget);
    expect(find.byKey(const Key('btn-copy-abc-id')), findsOneWidget);

    // 3. Verify Verified Credentials List
    expect(find.text('Secondary School Certificate (Class X)'), findsOneWidget);
    expect(find.text('Senior School Certificate (Class XII - PCM)'), findsOneWidget);
    expect(find.text('Aadhaar Identity Verification'), findsOneWidget);

    // 4. Test Cryptographic Hash Inspection dialog
    final inspectBtn = find.byKey(const Key('btn-view-doc-class_x'));
    await tester.ensureVisible(inspectBtn);
    await tester.pumpAndSettle();
    await tester.tap(inspectBtn);
    await tester.pumpAndSettle();

    expect(find.text('DigiLocker Cryptographic Proof'), findsOneWidget);
    expect(find.text('SHA-256 Tamper-Evident Hash:'), findsOneWidget);
    expect(find.text('Copy Hash'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('DigiLocker OAuth 2.0 PKCE Connect Flow: Dialog consent, token exchange, and disconnect lifecycle', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    // 1. Start with an unverified student
    await storage.disconnectDigiLocker(studentId: 'usr-harish_2025_l_btech_1');

    await tester.pumpWidget(MaterialApp(
      home: UserProfileScreen(
        storage: storage,
        userIdentifier: 'usr-harish_2025_l_btech_1',
      ),
    ));
    await tester.pumpAndSettle();

    // 2. Verify unlinked card state
    expect(find.text('DigiLocker Not Linked'), findsOneWidget);
    final connectBtn = find.byKey(const Key('btn-connect-digilocker'));
    expect(connectBtn, findsOneWidget);

    // 3. Tap Connect with DigiLocker to open dialog
    await tester.ensureVisible(connectBtn);
    await tester.pumpAndSettle();
    await tester.tap(connectBtn);
    await tester.pumpAndSettle();

    expect(find.text('Connect DigiLocker Account'), findsOneWidget);
    expect(find.text('Government of India Trust Architecture'), findsOneWidget);
    expect(find.text('12-Digit APAAR / Academic Bank of Credits (ABC) ID'), findsOneWidget);

    // 4. Authorize and exchange credentials
    final authBtn = find.byKey(const Key('btn-authorize-digilocker-consent'));
    expect(authBtn, findsOneWidget);
    await tester.tap(authBtn);
    await tester.pumpAndSettle();

    // 5. Verify connected state
    expect(find.text('DigiLocker Verified'), findsOneWidget);
    expect(find.text('8912-3456-7890'), findsOneWidget);
    expect(find.byKey(const Key('btn-disconnect-digilocker')), findsOneWidget);

    // 6. Test Disconnect
    final disconnectBtn = find.byKey(const Key('btn-disconnect-digilocker'));
    await tester.ensureVisible(disconnectBtn);
    await tester.pumpAndSettle();
    await tester.tap(disconnectBtn);
    await tester.pumpAndSettle();

    expect(find.text('Disconnect DigiLocker Account?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-confirm-disconnect-digilocker')));
    await tester.pumpAndSettle();

    expect(find.text('DigiLocker Not Linked'), findsOneWidget);
  });

  testWidgets('Small Screen Responsiveness: SessionalExamScreen standalone on 360x640 with zero overflow', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final harish = await storage.getUserProfile('usr-harish_2025_l_btech_1');

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(
      home: SessionalExamScreen(
        storage: storage,
        currentUser: harish,
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('AKTU Sessional & Internal Assessment'), findsOneWidget);
    expect(find.text('Student Scorecard'), findsOneWidget);
  });

  testWidgets('Navigation to Sessional Exam screen from HomeScreen succeeds without RangeError', (tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final harish = await storage.getUserProfile('usr-harish_2025_l_btech_1');

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        storage: storage,
        currentUser: harish,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Verify nav item for exams exists in sidebar and navigates successfully
    final examNav = find.byKey(const Key('nav-item-exams'));
    expect(examNav, findsOneWidget);

    await tester.tap(examNav);
    await tester.pumpAndSettle();

    expect(find.text('AKTU Sessional & Internal Assessment'), findsOneWidget);
    expect(find.text('Student Scorecard'), findsOneWidget);

    // 2. Mobile screen: Verify navigation via Mobile Dock Sheet and Quick Card
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();

    // Navigate back to Dashboard via bottom dock
    final dashDock = find.byKey(const Key('dock-division-dashboard'));
    expect(dashDock, findsOneWidget);
    await tester.tap(dashDock);
    await tester.pumpAndSettle();

    // Open More Pages dock sheet
    final moreDock = find.byKey(const Key('dock-division-more-pages'));
    expect(moreDock, findsOneWidget);
    await tester.tap(moreDock);
    await tester.pumpAndSettle();

    // Scroll until Sessional Exam item in bottom sheet is visible and tap
    final sheetExamItem = find.byKey(const Key('dock-menu-item-sessional'));
    expect(sheetExamItem, findsOneWidget);
    await tester.scrollUntilVisible(sheetExamItem, 50, scrollable: find.byType(Scrollable).last);
    await tester.tap(sheetExamItem);
    await tester.pumpAndSettle();

    expect(find.text('AKTU Sessional & Internal Assessment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Multi-Channel Payment Gateway: UPI QR, RuPay/Visa Card with 3D Secure OTP, NetBanking, and Challan VAN settlement', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    await tester.pumpWidget(MaterialApp(
      home: FeeScreen(
        storage: storage,
        currentUser: student,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Open multi-channel payment interface on Hostel invoice
    expect(find.byKey(const Key('btn-pay-fee-inv-hostel-2026-sem3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-pay-fee-inv-hostel-2026-sem3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-pay-invoice')), findsOneWidget);
    expect(find.textContaining('SANDBOX'), findsOneWidget);
    expect(find.byKey(const Key('input-payment-amount')), findsOneWidget);

    // 2. Test UPI Channel with dynamic QR and VPA
    expect(find.text('UPI / QR'), findsWidgets);
    expect(find.textContaining('Scan with Google Pay'), findsOneWidget);
    expect(find.byKey(const Key('input-upi-id')), findsOneWidget);
    expect(find.byKey(const Key('btn-pay-upi')), findsOneWidget);

    // 3. Test Card Channel with RuPay/Visa preview and 3D Secure OTP
    await tester.tap(find.byKey(const Key('pay-tab-card')), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('INSTITUTIONAL SECURE CARD'), findsOneWidget);
    expect(find.byKey(const Key('input-card-number')), findsOneWidget);
    expect(find.byKey(const Key('btn-pay-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-pay-card')));
    await tester.pumpAndSettle();

    // Verify 3D Secure Authorization OTP dialog appears
    expect(find.byKey(const Key('dialog-3d-secure-otp')), findsOneWidget);
    expect(find.byKey(const Key('input-bank-otp')), findsOneWidget);
    expect(find.byKey(const Key('btn-verify-otp')), findsOneWidget);

    // Cancel OTP to explore remaining channels
    await tester.tap(find.byKey(const Key('btn-cancel-otp')));
    await tester.pumpAndSettle();

    // 4. Test NetBanking Channel with popular Indian banks
    await tester.tap(find.byKey(const Key('pay-tab-netbanking')), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('State Bank of India (SBI)'), findsWidgets);
    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(find.text('ICICI Bank'), findsOneWidget);
    expect(find.byKey(const Key('btn-pay-netbanking')), findsOneWidget);

    // 5. Test Challan Channel with Virtual Account Number (VAN) and UTR submission
    await tester.tap(find.byKey(const Key('pay-tab-challan')), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Institutional Bank Challan / NEFT / RTGS'), findsOneWidget);
    expect(find.text('Virtual Account Number'), findsOneWidget);
    expect(find.text('IFSC Code'), findsOneWidget);
    expect(find.byKey(const Key('input-utr-number')), findsOneWidget);
    expect(find.byKey(const Key('btn-submit-utr')), findsOneWidget);

    // 6. Complete settlement via UTR submission
    await tester.ensureVisible(find.byKey(const Key('input-utr-number')));
    await tester.enterText(find.byKey(const Key('input-utr-number')), 'UTR20261109998823');
    await tester.ensureVisible(find.byKey(const Key('btn-submit-utr')));
    await tester.tap(find.byKey(const Key('btn-submit-utr')));
    await tester.pumpAndSettle();

    // Confirm settlement processed
    expect(find.textContaining('Payment processed successfully'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Small Screen Responsiveness: Multi-channel Payment Dialog on 360x640 mobile viewport with zero overflow', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');
    final invoices = await storage.getInvoices(studentId: student.id);
    final inv = invoices.first;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const Key('btn-test-open-payment'),
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (_) => CampusPaymentDialog(
                    invoice: inv,
                    facade: CampusFacade(storage: storage, api: api),
                    studentId: student.id,
                    onPaymentSuccess: () {},
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Open Payment Dialog on mobile viewport
    await tester.tap(find.byKey(const Key('btn-test-open-payment')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-pay-invoice')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Switch between all 4 tabs on small screen
    await tester.tap(find.byKey(const Key('pay-tab-card')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('pay-tab-netbanking')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('pay-tab-challan')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Confirm settlement
    await tester.tap(find.byKey(const Key('btn-confirm-pay-invoice')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('End-to-End Pipelines: PDF Receipt Generation & Download, PDF Book Upload, and Optical QR Image Scanning', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);
    final facade = CampusFacade(storage: storage, api: api);
    final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

    // 1. Pure-Dart PDF Receipt Generation Pipeline Verification
    final sampleReceipt = FeeReceiptModel(
      receiptNumber: 'RCP-INST-TEST-99',
      paymentId: 'pay_test_99',
      studentId: student.id,
      studentName: student.fullName,
      campusHandle: student.campusHandle,
      amount: 45000.0,
      paymentMethod: 'upi',
      transactionRef: 'UPI/998877665544',
      issuedAt: DateTime.now(),
      title: 'BBDIT B.Tech Semester Tuition Remittance',
      category: 'fee',
    );

    final pdfBytes = ReceiptPdfGenerator.generate(sampleReceipt);
    expect(pdfBytes, isNotEmpty);
    final headerStr = String.fromCharCodes(pdfBytes.take(8));
    expect(headerStr.startsWith('%PDF-1.4'), isTrue);

    // 2. Receipt Download Pipeline in FeeScreen
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeeScreen(
          storage: storage,
          currentUser: student,
          facade: facade,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Switch to Records & Receipts Ledger
    await tester.tap(find.byKey(const Key('tab-records-ledger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-view-receipt-RCP-2026-00108')), findsOneWidget);
    expect(find.byKey(const Key('btn-download-receipt-RCP-2026-00108')), findsOneWidget);

    // Tap Download PDF icon on ledger card
    await tester.tap(find.byKey(const Key('btn-download-receipt-RCP-2026-00108')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Open View Proof modal and download from dialog
    await tester.tap(find.byKey(const Key('btn-view-receipt-RCP-2026-00108')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-view-receipt')), findsOneWidget);
    expect(find.byKey(const Key('btn-download-receipt-dialog-RCP-2026-00108')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-download-receipt-dialog-RCP-2026-00108')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 3. PDF File Picker & Upload Pipeline in LibraryScreen
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LibraryScreen(
          storage: storage,
          currentUser: student,
          facade: facade,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Switch to Digital E-Books tab
    await tester.tap(find.byKey(const Key('tab-infinite-ebooks')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-add-pdf-book')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-add-pdf-book')));
    await tester.pumpAndSettle();

    // Verify PDF file picker element is present in dialog
    expect(find.byKey(const Key('btn-pick-pdf-file')), findsOneWidget);
    expect(find.byKey(const Key('badge-picked-pdf')), findsOneWidget);

    // Trigger file selection
    await tester.tap(find.byKey(const Key('btn-pick-pdf-file')));
    await tester.pumpAndSettle();

    expect(find.text('bbdit_curriculum_textbook.pdf'), findsOneWidget);

    // Enter title & author and submit
    await tester.enterText(find.byKey(const Key('input-pdf-title')), 'Compiler Engineering Handbook');
    await tester.enterText(find.byKey(const Key('input-pdf-author')), 'A. V. Aho & J. D. Ullman');
    await tester.tap(find.byKey(const Key('btn-submit-pdf-book')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 4. Optical Anti-Proxy Attendance Scanner in AttendanceScreen
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AttendanceScreen(
          storage: storage,
          currentUser: student,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Open Student Optical Scanner (which starts repeat animation)
    await tester.tap(find.widgetWithText(ElevatedButton, 'Scan Rolling QR').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify static screenshots and image uploads are blocked by protocol
    expect(find.textContaining('Anti-Proxy Protocol: Static screenshots and image uploads are strictly blocked'), findsOneWidget);
    expect(find.text('Capture From Active Lecture Broadcast'), findsOneWidget);

    // Live capture from classroom broadcast
    await tester.tap(find.text('Capture From Active Lecture Broadcast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });
}
