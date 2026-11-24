import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/screens/login_screen.dart';
import 'package:campus_client/screens/user_management_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/widgets/first_login_otp_dialog.dart';
import 'package:campus_client/widgets/password_reset_dialog.dart';

void main() {
  late OfflineStorageService storage;

  setUp(() {
    storage = OfflineStorageService(
      api: ApiService(baseUrl: 'http://localhost:8085'),
      enableMockSeeding: true,
    );
  });

  testWidgets('LoginScreen renders first-time login and forgot password WhatsApp OTP buttons', (tester) async {
    UserModel? loggedInUser;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          storage: storage,
          onLoginSuccess: (u) => loggedInUser = u,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-first-login-otp')), findsOneWidget);
    expect(find.byKey(const Key('btn-forgot-password-otp')), findsOneWidget);
    expect(find.textContaining('First Time Login?'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(loggedInUser, isNull);
  });

  testWidgets('FirstLoginOtpDialog requests OTP, creates password and security question, and activates user', (tester) async {
    UserModel? activatedUser;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                FirstLoginOtpDialog.show(
                  ctx,
                  storage: storage,
                  initialIdentifier: 'rohit_2026_reg_btech_1',
                ).then((u) => activatedUser = u);
              },
              child: const Text('Open First Login Dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Dialog
    await tester.tap(find.text('Open First Login Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Account Activation'), findsOneWidget);
    expect(find.text('First-time login via WhatsApp OTP'), findsOneWidget);

    // Request WhatsApp OTP
    final reqOtpBtn = find.byKey(const Key('btn-request-first-login-otp'));
    await tester.tap(reqOtpBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('WhatsApp verification code sent to'), findsOneWidget);
    expect(find.byKey(const Key('input-first-login-otp')), findsOneWidget);

    // Enter 6-digit OTP
    await tester.enterText(find.byKey(const Key('input-first-login-otp')), '123456');
    await tester.pumpAndSettle();

    // Enter permanent password
    await tester.enterText(find.byKey(const Key('input-first-login-new-pass')), 'SecurePass2026#');
    await tester.enterText(find.byKey(const Key('input-first-login-confirm-pass')), 'SecurePass2026#');
    await tester.pumpAndSettle();

    // Enter security question answer
    await tester.enterText(find.byKey(const Key('input-first-login-security-answer')), 'Delhi Public School');
    await tester.pumpAndSettle();

    // Submit activation
    final submitBtn = find.byKey(const Key('btn-submit-first-login-activation'));
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify dialog closed and user activated
    expect(activatedUser, isNotNull);
    expect(activatedUser!.mustChangePassword, isFalse);
    expect(activatedUser!.isFirstLogin, isFalse);
    expect(activatedUser!.securityQuestion, isNotEmpty);
  });

  testWidgets('PasswordResetDialog Channel A: resets password using WhatsApp OTP + Security Question', (tester) async {
    // Pre-activate user with a known security answer
    await storage.verifyFirstLoginAndSetPassword(
      identifier: 'rohit_2026_reg_btech_1',
      otpCode: '123456',
      newPassword: 'InitialPass2026!',
      securityQuestion: 'What was the name of your first school?',
      securityAnswer: 'DPS RK Puram',
    );

    UserModel? resetUser;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                PasswordResetDialog.show(
                  ctx,
                  storage: storage,
                  initialIdentifier: 'rohit_2026_reg_btech_1',
                ).then((u) => resetUser = u);
              },
              child: const Text('Open Reset Dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Reset Dialog
    await tester.tap(find.text('Open Reset Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Password Recovery'), findsOneWidget);

    // Request reset OTP
    final reqOtpBtn = find.byKey(const Key('btn-request-reset-otp'));
    await tester.tap(reqOtpBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('WhatsApp reset code sent to'), findsOneWidget);
    expect(find.byKey(const Key('input-reset-otp')), findsOneWidget);

    // Enter OTP
    await tester.enterText(find.byKey(const Key('input-reset-otp')), '123456');
    await tester.pumpAndSettle();

    // Channel A: Enter security answer and new password
    await tester.enterText(find.byKey(const Key('input-reset-security-answer')), 'dps rk puram');
    await tester.enterText(find.byKey(const Key('input-reset-new-password')), 'BrandNewPass2027!');
    await tester.pumpAndSettle();

    // Submit reset
    final submitResetBtn = find.byKey(const Key('btn-submit-reset-question'));
    await tester.ensureVisible(submitResetBtn);
    await tester.tap(submitResetBtn);
    await tester.pumpAndSettle();

    // Verify password reset succeeded
    expect(resetUser, isNotNull);

    // Verify user can log in with new password
    final reAuth = await storage.authenticate('rohit_2026_reg_btech_1', 'BrandNewPass2027!');
    expect(reAuth.campusHandle, 'rohit_2026_reg_btech_1');
  });

  testWidgets('PasswordResetDialog Channel B: creates escalation ticket and completes reset via Admin Token', (tester) async {
    UserModel? resetUser;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                PasswordResetDialog.show(
                  ctx,
                  storage: storage,
                  initialIdentifier: 'rohit_2026_reg_btech_1',
                ).then((u) => resetUser = u);
              },
              child: const Text('Open Reset Dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Reset Dialog
    await tester.tap(find.text('Open Reset Dialog'));
    await tester.pumpAndSettle();

    // Request reset OTP
    await tester.tap(find.byKey(const Key('btn-request-reset-otp')));
    await tester.pumpAndSettle();

    // Switch to Channel B (Admin Escalation)
    await tester.tap(find.byKey(const Key('tab-reset-channel-escalation')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cannot answer your security question?'), findsOneWidget);

    // Enter WhatsApp OTP & submit ticket
    await tester.enterText(find.byKey(const Key('input-reset-otp')), '123456');
    await tester.enterText(find.byKey(const Key('input-reset-escalation-reason')), 'Verified in person with HOD');
    await tester.pumpAndSettle();

    final submitEscalationBtn = find.byKey(const Key('btn-submit-reset-escalation'));
    await tester.ensureVisible(submitEscalationBtn);
    await tester.tap(submitEscalationBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Ticket: ESC-RESET-'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);

    // Admin approves the escalation
    final escalations = await storage.listResetEscalations();
    expect(escalations, isNotEmpty);
    final approvedTicket = await storage.adminResolveResetEscalation(
      ticketNumber: escalations.first.ticketNumber,
      action: 'approve',
      adminUserId: 'usr-campus_admin',
    );
    expect(approvedTicket.status, 'approved');
    expect(approvedTicket.adminToken, '654321');

    // User inputs the Admin Token and new password
    await tester.enterText(find.byKey(const Key('input-reset-admin-token')), '654321');
    await tester.enterText(find.byKey(const Key('input-reset-escalation-new-pass')), 'EscalatedPass2027!');
    await tester.pumpAndSettle();

    final submitTokenBtn = find.byKey(const Key('btn-submit-reset-admin-token'));
    await tester.ensureVisible(submitTokenBtn);
    await tester.tap(submitTokenBtn);
    await tester.pumpAndSettle();

    expect(resetUser, isNotNull);

    // Verify user can authenticate with the escalated password
    final reAuth = await storage.authenticate('rohit_2026_reg_btech_1', 'EscalatedPass2027!');
    expect(reAuth.campusHandle, 'rohit_2026_reg_btech_1');
  });

  testWidgets('UserManagementScreen Password Escalations dialog renders and approves tickets', (tester) async {
    // Pre-create an escalation ticket in storage
    await storage.createResetAdminEscalation(
      identifier: 'rohit_2026_reg_btech_1',
      otpCode: '123456',
      reason: 'Physical Smart ID verified at IT desk',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UserManagementScreen(storage: storage),
      ),
    );
    await tester.pumpAndSettle();

    // Verify button exists in header
    final escalationsBtn = find.byKey(const Key('btn-manage-reset-escalations'));
    expect(escalationsBtn, findsOneWidget);

    // Open Escalations Dialog
    await tester.tap(escalationsBtn);
    await tester.pumpAndSettle();

    expect(find.text('Password Reset Escalations'), findsOneWidget);
    expect(find.textContaining('ESC-RESET-'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);

    // Tap Approve
    final approveBtn = find.text('Approve & Generate Token');
    expect(approveBtn, findsOneWidget);
    await tester.tap(approveBtn);
    await tester.pumpAndSettle();

    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.textContaining('Authorization Token: 654321'), findsOneWidget);
  });
}
