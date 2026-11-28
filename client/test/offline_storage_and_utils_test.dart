import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/utils/file_downloader_io.dart';
import 'package:campus_client/utils/native_file_storage_io.dart';

Map<String, dynamic> _userJson(String handle) => {
      'id': 'usr-$handle',
      'campus_handle': handle,
      'first_name': 'Test',
      'last_name': 'User',
      'email': '$handle@campus.edu',
      'archetype': 'student',
      'is_active': true,
      'status': 'active',
      'must_change_password': false,
      'is_first_login': false,
    };

void main() {
  group('OfflineStorageService online pass-through & error branches', () {
    late ApiService onlineApi;
    late OfflineStorageService storage;

    setUp(() {
      final client = MockClient((req) async {
        final p = req.url.path;
        if (p == '/api/health') return http.Response('ok', 200);
        if (p == '/api/v1/auth/login' ||
            p == '/api/v1/auth/change-password' ||
            p == '/api/v1/auth/first-login/verify-and-set-password' ||
            p == '/api/v1/auth/reset-password/verify-otp-and-question' ||
            p == '/api/v1/auth/reset-password/verify-otp-and-admin-token' ||
            p == '/api/v1/users/profile' ||
            p == '/api/v1/users/profile/update' ||
            p == '/api/v1/users/student' ||
            p == '/api/v1/users/employee' ||
            p == '/api/v1/users/contractor') {
          return http.Response(
            jsonEncode({'user': _userJson('online_stu_1')}),
            (p.endsWith('student') || p.endsWith('employee') || p.endsWith('contractor')) ? 201 : 200,
          );
        }
        if (p == '/api/v1/auth/first-login/request-otp' ||
            p == '/api/v1/auth/reset-password/request-otp') {
          return http.Response(jsonEncode({'status': 'sent', 'target_phone_masked': '+91****99'}), 200);
        }
        if (p == '/api/v1/auth/reset-password/security-question') {
          return http.Response(jsonEncode({'security_question': 'Pet name?'}), 200);
        }
        if (p == '/api/v1/auth/reset-password/escalate-to-admin') {
          return http.Response(
            jsonEncode({
              'ticket': {
                'id': 'esc-1',
                'ticket_number': 'ESC-ONLINE-1',
                'user_id': 'usr-1',
                'campus_handle': 'online_stu_1',
                'full_name': 'Test User',
                'whatsapp_phone': '+919876543210',
                'status': 'pending',
                'escalation_reason': 'Forgot',
              }
            }),
            200,
          );
        }
        if (p == '/api/v1/auth/reset-password/escalations') {
          return http.Response(jsonEncode({'tickets': []}), 200);
        }
        if (p == '/api/v1/auth/reset-password/admin-resolve-escalation') {
          return http.Response(
            jsonEncode({
              'status': 'approved',
              'admin_token': '654321',
              'ticket': {
                'id': 'esc-1',
                'ticket_number': 'ESC-ONLINE-1',
                'user_id': 'usr-1',
                'campus_handle': 'online_stu_1',
                'full_name': 'Test User',
                'whatsapp_phone': '+919876543210',
                'status': 'approved',
                'escalation_reason': 'Forgot',
              }
            }),
            200,
          );
        }
        if (p == '/api/v1/users') {
          return http.Response(jsonEncode([_userJson('online_stu_1')]), 200);
        }
        return http.Response('{}', 200);
      });

      onlineApi = ApiService(baseUrl: 'http://mock.local', client: client);
      storage = OfflineStorageService(api: onlineApi, enableMockSeeding: true);
    });

    test('online connectivity routes auth, OTP, and user APIs through ApiService', () async {
      storage.isOnline = true;
      expect(await storage.checkConnectivity(force: true), isTrue);

      final u = await storage.authenticate('online_stu_1', 'pass123');
      expect(u.campusHandle, 'online_stu_1');

      await storage.changePassword(
        identifier: 'online_stu_1',
        currentPassword: 'old',
        newPassword: 'new',
      );
      await storage.requestFirstLoginOtp('online_stu_1');
      await storage.verifyFirstLoginAndSetPassword(
        identifier: 'online_stu_1',
        otpCode: '123456',
        newPassword: 'new',
        securityQuestion: 'Pet?',
        securityAnswer: 'Rex',
      );
      await storage.requestResetPasswordOtp('online_stu_1');
      await storage.getSecurityQuestionPrompt('online_stu_1');
      await storage.resetPasswordWithSecurityQuestion(
        identifier: 'online_stu_1',
        otpCode: '123456',
        securityAnswer: 'Rex',
        newPassword: 'new',
      );
      await storage.createResetAdminEscalation(
        identifier: 'online_stu_1',
        otpCode: '123456',
        reason: 'Forgot',
      );
      await storage.listResetEscalations();
      await storage.adminResolveResetEscalation(
        ticketNumber: 'ESC-ONLINE-1',
        action: 'approve',
        adminUserId: 'usr-admin',
      );
      await storage.resetPasswordWithAdminToken(
        identifier: 'online_stu_1',
        otpCode: '123456',
        adminToken: '654321',
        newPassword: 'new',
      );

      final users = await storage.getUsers(forceRefresh: true);
      expect(users, isNotEmpty);
      await storage.getUserProfile('online_stu_1');
      await storage.updateUserProfile(userId: 'usr-online_stu_1', phone: '+919876543210');
      await storage.createStudent({'first_name': 'S'});
      await storage.createEmployee({'first_name': 'E'});
      await storage.createContractor({'first_name': 'C'});
    });

    test('offline error branches throw cleanly on invalid OTP/question/token', () async {
      final offlineApi = ApiService(
        baseUrl: 'http://offline.local',
        client: MockClient((_) async => throw const SocketException('offline')),
      );
      final offStorage = OfflineStorageService(api: offlineApi, enableMockSeeding: true);
      expect(await offStorage.checkConnectivity(force: true), isFalse);

      await expectLater(
        offStorage.verifyFirstLoginAndSetPassword(
          identifier: 'harish_2025_l_btech_1',
          otpCode: '000000',
          newPassword: 'NewPass1!',
          securityQuestion: 'Q?',
          securityAnswer: 'Ans',
        ),
        throwsException,
      );
      await expectLater(
        offStorage.resetPasswordWithSecurityQuestion(
          identifier: 'harish_2025_l_btech_1',
          otpCode: '000000',
          securityAnswer: 'Ans',
          newPassword: 'NewPass1!',
        ),
        throwsException,
      );
      final noSeedStorage = OfflineStorageService(api: offlineApi, enableMockSeeding: false);
      await expectLater(
        noSeedStorage.createResetAdminEscalation(
          identifier: 'unknown_nobody',
          otpCode: '000000',
        ),
        throwsException,
      );
      await expectLater(
        offStorage.resetPasswordWithAdminToken(
          identifier: 'harish_2025_l_btech_1',
          otpCode: '000000',
          adminToken: '999999',
          newPassword: 'NewPass1!',
        ),
        throwsException,
      );
    });
  });

  group('NativeFileStorage IO & FileDownloader IO', () {
    test('readUploadedPdf, getUploadedPdfDiskPath, persistUploadedPdf & triggerPdfDownload', () async {
      final home = Platform.environment['HOME'] ?? '.';
      final dir = Directory('$home/.campus_management/uploads');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final testId = 'test_cov_${DateTime.now().millisecondsSinceEpoch}';
      final idFile = File('${dir.path}/$testId.pdf');
      final namedFile = File('${dir.path}/${testId}_alt_doc.pdf');

      try {
        await idFile.writeAsBytes([37, 80, 68, 70]);
        final bytes = await readUploadedPdf(testId);
        expect(bytes, [37, 80, 68, 70]);
        final diskPath = await getUploadedPdfDiskPath(testId);
        expect(diskPath, idFile.path);

        // Remove exact idFile and test fallback scan for namedFile
        await idFile.delete();
        await namedFile.writeAsBytes([37, 80, 68, 70, 45]);
        final bytes2 = await readUploadedPdf(testId);
        expect(bytes2, [37, 80, 68, 70, 45]);
        final diskPath2 = await getUploadedPdfDiskPath(testId);
        expect(diskPath2, namedFile.path);

        // Missing file returns null
        expect(await readUploadedPdf('nonexistent_$testId'), isNull);
        expect(await getUploadedPdfDiskPath('nonexistent_$testId'), isNull);

        await persistUploadedPdf(testId, 'doc.pdf', [1, 2, 3]);
        expect(await triggerPdfDownload(filename: 'test.pdf', bytes: [37, 80, 68, 70]), isTrue);
      } finally {
        if (await idFile.exists()) await idFile.delete();
        if (await namedFile.exists()) await namedFile.delete();
      }
    });
  });
}
