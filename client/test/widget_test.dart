import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:campus_client/main.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/screens/home_screen.dart';
import 'package:campus_client/screens/login_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
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

    // Verify Persona dropdown opens cleanly
    final personaSwitcher = find.byTooltip('Switch Active Persona');
    expect(personaSwitcher, findsOneWidget);
    await tester.tap(personaSwitcher);
    await tester.pumpAndSettle();
    expect(find.textContaining('Dr. Priya Nair'), findsWidgets);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

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

  testWidgets('Cross-program section flow: Admin inspects Section B with multi-program enrollment (CSE, AI/ML, DS) and creates a shared section',
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
    expect(find.text('Participating Degree Programs (Many-to-Many)'), findsOneWidget);

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
    await tester.tap(find.text('Faculty'));
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
    await tester.tap(find.text('Faculty'));
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
    await tester.tap(find.text('Student'));
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

  testWidgets('Timetable: 9 AM to 5 PM 1-hour blocks, Rectangle consecutive grouping, Square units, and Free vs Off distinction', (tester) async {
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
    expect(find.textContaining('Free Periods'), findsWidgets);
    expect(find.textContaining('Declared Off'), findsWidgets);

    // 3. Verify Geometry categorization:
    // Consecutive occupied blocks (09:00 CS301 + 10:00 CS302) are rendered as RECTANGLE
    expect(find.text('RECTANGLE'), findsWidgets);
    expect(find.text('CONSECUTIVE PERIODS'), findsWidgets);

    // Standalone occupied, free, and off blocks are rendered as SQUARE
    expect(find.text('SQUARE'), findsWidgets);

    // 4. Verify Free is distinct from Off:
    // Both statuses exist simultaneously on the schedule and have distinct branding
    expect(find.text('FREE PERIOD'), findsWidgets);
    expect(find.textContaining('Declared Off'), findsWidgets);
    expect(find.text('Operating Systems'), findsWidgets);

    // 5. Test Week Matrix Toggle
    final switchModeBtn = find.byTooltip('Switch to Week Matrix View');
    expect(switchModeBtn, findsOneWidget);
    await tester.tap(switchModeBtn);
    await tester.pumpAndSettle();

    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('09:00'), findsWidgets);
    expect(find.text('16:00'), findsWidgets);

    // Toggle back to Day Timeline View
    final switchTimelineBtn = find.byTooltip('Switch to Day Timeline View');
    expect(switchTimelineBtn, findsOneWidget);
    await tester.tap(switchTimelineBtn);
    await tester.pumpAndSettle();

    // 6. Test Saturday half-day behavior (classes in morning, free period, afternoon declared off)
    await tester.tap(find.text('Sat'));
    await tester.pumpAndSettle();

    expect(find.text('SEM301'), findsWidgets);
    expect(find.text('FREE PERIOD'), findsWidgets);
    expect(find.text('DECLARED OFF'), findsWidgets);

    // 7. Test Block Configuration Sheet
    // Tap a block to open configuration
    await tester.tap(find.text('FREE PERIOD').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Configure Schedule Block'), findsOneWidget);
    expect(find.text('BLOCK TYPE'), findsOneWidget);
    expect(find.text('Free Period (Campus Open)'), findsOneWidget);

    // Switch type to Declared Off inside editor
    await tester.tap(find.text('Declared Off').first);
    await tester.pumpAndSettle();

    expect(find.text('Declared Off (Campus Hours Closed)'), findsOneWidget);

    // Save block
    await tester.tap(find.text('Save Block Configuration'));
    await tester.pumpAndSettle();

    expect(find.text('DECLARED OFF'), findsWidgets);
  });
}
