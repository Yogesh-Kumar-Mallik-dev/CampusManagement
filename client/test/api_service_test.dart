import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/models/complaint.dart';
import 'package:campus_client/models/library.dart';
import 'package:campus_client/services/api_service.dart';

Map<String, dynamic> _sampleUserJson() => {
      'id': 'usr-1',
      'campus_handle': 'harish_2025_l_btech_1',
      'first_name': 'Harish',
      'last_name': 'Kumar',
      'email': 'harish@campus.edu',
      'archetype': 'student',
      'is_active': true,
      'status': 'active',
      'must_change_password': false,
      'is_first_login': false,
    };

void main() {
  group('ApiService MockClient comprehensive coverage', () {
    test('Auth, OTP, and Password Recovery endpoints', () async {
      final client = MockClient((req) async {
        final p = req.url.path;
        if (p == '/api/v1/auth/login') {
          return http.Response(
            jsonEncode({
              'user': _sampleUserJson(),
              'scopes': ['global'],
              'permissions': ['read'],
              'assigned_roles': [],
              'student_profile': {
                'user_id': 'usr-1',
                'admission_year': 2025,
                'entry_type': 'regular',
                'program': 'B.Tech',
                'current_semester': 3,
                'batch_year': 2025,
              },
            }),
            200,
          );
        }
        if (p == '/api/v1/auth/change-password' ||
            p == '/api/v1/auth/first-login/verify-and-set-password' ||
            p == '/api/v1/auth/reset-password/verify-otp-and-question' ||
            p == '/api/v1/auth/reset-password/verify-otp-and-admin-token') {
          return http.Response(jsonEncode({'user': _sampleUserJson()}), 200);
        }
        if (p == '/api/v1/auth/first-login/request-otp' ||
            p == '/api/v1/auth/reset-password/request-otp') {
          return http.Response(
            jsonEncode({'status': 'sent', 'target_phone_masked': '+91****10'}),
            200,
          );
        }
        if (p == '/api/v1/auth/reset-password/security-question') {
          return http.Response(
            jsonEncode({'security_question': 'First school?'}),
            200,
          );
        }
        if (p == '/api/v1/auth/reset-password/escalate-to-admin') {
          return http.Response(
            jsonEncode({
              'ticket': {
                'id': 'esc-1',
                'ticket_number': 'ESC-RESET-1',
                'user_id': 'usr-1',
                'campus_handle': 'harish_2025_l_btech_1',
                'full_name': 'Harish Kumar',
                'whatsapp_phone': '+919876543210',
                'status': 'pending',
                'escalation_reason': 'Forgot',
              }
            }),
            200,
          );
        }
        if (p == '/api/v1/auth/reset-password/escalations') {
          return http.Response(
            jsonEncode({
              'tickets': [
                {
                  'id': 'esc-1',
                  'ticket_number': 'ESC-RESET-1',
                  'user_id': 'usr-1',
                  'campus_handle': 'harish_2025_l_btech_1',
                  'full_name': 'Harish Kumar',
                  'whatsapp_phone': '+919876543210',
                  'status': 'pending',
                  'escalation_reason': 'Forgot',
                }
              ]
            }),
            200,
          );
        }
        if (p == '/api/v1/auth/reset-password/admin-resolve-escalation') {
          return http.Response(
            jsonEncode({
              'status': 'approved',
              'admin_token': '654321',
              'ticket': {
                'id': 'esc-1',
                'ticket_number': 'ESC-RESET-1',
                'user_id': 'usr-1',
                'campus_handle': 'harish_2025_l_btech_1',
                'full_name': 'Harish Kumar',
                'whatsapp_phone': '+919876543210',
                'status': 'approved',
                'escalation_reason': 'Forgot',
              }
            }),
            200,
          );
        }
        if (p == '/api/health') {
          return http.Response('ok', 200);
        }
        return http.Response(jsonEncode({'error': 'not found'}), 404);
      });

      final api = ApiService(baseUrl: 'http://mock.local', client: client);
      expect(await api.checkHealth(), isTrue);

      final u = await api.login('harish_2025_l_btech_1', 'pass');
      expect(u.campusHandle, 'harish_2025_l_btech_1');

      await api.changePassword(
        identifier: 'harish_2025_l_btech_1',
        currentPassword: 'old',
        newPassword: 'new',
      );
      await api.requestFirstLoginOtp('harish_2025_l_btech_1');
      await api.verifyFirstLoginAndSetPassword(
        identifier: 'harish_2025_l_btech_1',
        otpCode: '123456',
        newPassword: 'new',
        securityQuestion: 'School?',
        securityAnswer: 'St Mary',
      );
      await api.requestResetPasswordOtp('harish_2025_l_btech_1');
      await api.getSecurityQuestionPrompt('harish_2025_l_btech_1');
      await api.resetPasswordWithSecurityQuestion(
        identifier: 'harish_2025_l_btech_1',
        otpCode: '123456',
        securityAnswer: 'St Mary',
        newPassword: 'new',
      );
      await api.createResetAdminEscalation(
        identifier: 'harish_2025_l_btech_1',
        otpCode: '123456',
        reason: 'Forgot',
      );
      final list = await api.listResetEscalations();
      expect(list.length, 1);
      final resolved = await api.adminResolveResetEscalation(
        ticketNumber: 'ESC-RESET-1',
        action: 'approve',
        adminUserId: 'usr-admin',
      );
      expect(resolved.adminToken, '654321');
      await api.resetPasswordWithAdminToken(
        identifier: 'harish_2025_l_btech_1',
        otpCode: '123456',
        adminToken: '654321',
        newPassword: 'new',
      );
    });

    test('Academics, Timetable, Notices, Attendance, and Users endpoints', () async {
      final client = MockClient((req) async {
        final p = req.url.path;
        if (p == '/api/v1/academics/courses') {
          return http.Response(
            jsonEncode([
              {'id': 'c1', 'code': 'CS101', 'name': 'Intro CS', 'credits': 4, 'semester': 1}
            ]),
            200,
          );
        }
        if (p == '/api/v1/academics/timetable') {
          if (req.method == 'GET') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'ts1',
                  'course_id': 'c1',
                  'course_code': 'CS101',
                  'course_name': 'Intro CS',
                  'scope_id': 'sec:1',
                  'instructor_id': 'u-prof',
                  'instructor_name': 'Prof',
                  'day_of_week': 1,
                  'start_time': '09:00',
                  'end_time': '10:00',
                  'room_number': 'LH-1',
                  'slot_type': 'lecture',
                }
              ]),
              200,
            );
          }
          if (req.method == 'POST') {
            return http.Response(
              jsonEncode({
                'id': 'ts1',
                'course_id': 'c1',
                'scope_id': 'sec:1',
                'day_of_week': 1,
                'start_time': '09:00',
                'end_time': '10:00',
                'room_number': 'LH-1',
                'slot_type': 'lecture',
              }),
              201,
            );
          }
          return http.Response('{}', 200);
        }
        if (p == '/api/v1/academics/timetable/conflict') {
          return http.Response(jsonEncode({'has_conflict': false, 'conflicts': []}), 200);
        }
        if (p == '/api/v1/academics/timetable/day-off' ||
            p == '/api/v1/academics/timetable/restore-day') {
          return http.Response('{}', 200);
        }
        if (p == '/api/v1/notices') {
          if (req.method == 'GET') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'n1',
                  'title': 'Notice',
                  'content': 'Body',
                  'category': 'academic',
                  'priority': 'normal',
                  'publisher_id': 'u1',
                  'publisher_name': 'Admin',
                  'target_scope_id': 'global',
                  'published_at': '2026-11-28T10:00:00Z',
                }
              ]),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'n2',
              'title': 'New',
              'content': 'Body',
              'category': 'academic',
              'priority': 'normal',
              'publisher_id': 'u1',
              'publisher_name': 'Admin',
              'target_scope_id': 'global',
              'published_at': '2026-11-28T10:00:00Z',
            }),
            201,
          );
        }
        if (p == '/api/v1/attendance/summary') {
          return http.Response(
            jsonEncode([
              {
                'course_id': 'c1',
                'course_code': 'CS101',
                'course_name': 'Intro CS',
                'total_classes': 10,
                'attended': 8,
                'percentage': 80.0,
              }
            ]),
            200,
          );
        }
        if (p == '/api/v1/academics/attendance/session' ||
            p == '/api/v1/attendance/sync') {
          return http.Response('{}', 200);
        }
        if (p == '/api/v1/users') {
          return http.Response(jsonEncode([_sampleUserJson()]), 200);
        }
        if (p == '/api/v1/users/profile') {
          return http.Response(jsonEncode({'user': _sampleUserJson()}), 200);
        }
        if (p == '/api/v1/users/profile/update' ||
            p == '/api/v1/users/verify-class-x-pdf' ||
            p == '/api/v1/users/discontinue' ||
            p == '/api/v1/users/reactivate') {
          return http.Response(jsonEncode({'user': _sampleUserJson()}), 200);
        }
        if (p == '/api/v1/users/student' ||
            p == '/api/v1/users/employee' ||
            p == '/api/v1/users/contractor') {
          return http.Response(jsonEncode({'user': _sampleUserJson()}), 201);
        }
        if (p == '/api/v1/users/roles') {
          return http.Response('{}', 200);
        }
        return http.Response('{}', 200);
      });

      final api = ApiService(baseUrl: 'http://mock.local', client: client);
      expect((await api.fetchCourses()).length, 1);
      final slots = await api.fetchTimetable('sec:1');
      expect(slots.length, 1);
      await api.saveTimetableSlot(slots.first);
      expect(await api.deleteTimetableSlot('ts1'), isTrue);
      expect(await api.checkTimetableConflict(slots.first), isEmpty);
      expect(await api.declareDayOffBackend(scopeCode: 'sec:1', dayOfWeek: 1, reason: 'Holiday'), isTrue);
      expect(await api.restoreDayScheduleBackend(scopeCode: 'sec:1', dayOfWeek: 1), isTrue);
      expect((await api.fetchNotices(['global'])).length, 1);
      await api.publishNotice({'title': 'T'});
      expect((await api.fetchAttendanceSummary('usr-1')).length, 1);
      expect(await api.pushAttendanceBatch('prof-1', []), isTrue);
      expect((await api.fetchUsers()).length, 1);
      await api.fetchUserProfile('usr-1');
      await api.updateUserProfile(userId: 'usr-1', phone: '9999999999');
      await api.verifyClassXWithPdf(userId: 'usr-1', academicName: 'Harish', fileName: 'x.pdf', fileBytes: [37, 80, 68, 70]);
      await api.createStudent({'first_name': 'A'});
      await api.createEmployee({'first_name': 'B'});
      await api.createContractor({'first_name': 'C'});
      await api.discontinueUser(userId: 'usr-1', status: 'graduated', reason: 'Graduated', discontinuedBy: 'admin');
      await api.reactivateUser('usr-1');
      expect(await api.assignUserRole(userId: 'usr-1', roleCode: 'student', scopeCode: 'global'), isTrue);
    });

    test('Hostel, Mess, Complaints, Fees, Payments, Library, Sessional, DigiLocker & Assignments', () async {
      final client = MockClient((req) async {
        final p = req.url.path;
        if (p == '/api/v1/hostel/rooms') {
          if (req.method == 'GET') {
            return http.Response(
              jsonEncode([
                {'id': 'hr1', 'room_number': 101, 'block_name': 'Block 1', 'floor': 0}
              ]),
              200,
            );
          }
          return http.Response(
            jsonEncode({'id': 'hr1', 'room_number': 101, 'block_name': 'Block 1', 'floor': 0}),
            req.method == 'PUT' ? 200 : 201,
          );
        }
        if (p == '/api/v1/hostel/rooms/assets') {
          if (req.method == 'DELETE') return http.Response('{}', 200);
          return http.Response(
            jsonEncode({
              'id': 'ha1',
              'room_number': 101,
              'asset_type': 'bed',
              'serial_number': 'BED01',
              'condition': 'operational',
              'installed_at': '2026-11-28T10:00:00Z',
            }),
            req.method == 'PUT' ? 200 : 201,
          );
        }
        if (p == '/api/v1/hostel/rooms/occupants') {
          if (req.method == 'DELETE') return http.Response('{}', 200);
          return http.Response(
            jsonEncode({
              'user_id': 'u1',
              'room_number': 101,
              'campus_handle': 'h1',
              'name': 'Harish',
              'allotted_at': '2026-11-28T10:00:00Z',
            }),
            201,
          );
        }
        if (p == '/api/v1/mess/timetable') {
          if (req.method == 'GET') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'm1',
                  'day_of_week': 'monday',
                  'meal_type': 'breakfast',
                  'start_time': '08:00',
                  'end_time': '09:30',
                  'title': 'Breakfast',
                  'menu_summary': 'Poha',
                }
              ]),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'm1',
              'day_of_week': 'monday',
              'meal_type': 'breakfast',
              'start_time': '08:00',
              'end_time': '09:30',
              'title': 'Breakfast',
              'menu_summary': 'Poha',
            }),
            200,
          );
        }
        if (p == '/api/v1/mess/ratings') {
          if (req.method == 'GET') {
            return http.Response(
              jsonEncode({'total_ratings': 1, 'rating_breakdown': {'good': 1}, 'recent_feedbacks': []}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'r1',
              'meal_id': 'm1',
              'day_of_week': 'monday',
              'meal_type': 'breakfast',
              'user_id': 'u1',
              'user_name': 'Harish',
              'campus_handle': 'h1',
              'rating': 'good',
              'message': 'Nice',
              'created_at': '2026-11-28T10:00:00Z',
            }),
            201,
          );
        }
        if (p == '/api/v1/complaints' || p == '/api/v1/complaints/status') {
          final cmp = {
            'id': 'cmp1',
            'submitted_by': 'u1',
            'title': 'Fan',
            'description': 'Broken',
            'category': 'hostel',
            'urgency': 'low',
            'status': 'open',
            'is_anonymous': false,
            'created_at': '2026-11-28T10:00:00Z',
          };
          if (req.method == 'GET') return http.Response(jsonEncode([cmp]), 200);
          return http.Response(jsonEncode(cmp), req.method == 'PUT' ? 200 : 201);
        }
        if (p == '/api/v1/fees/summary') {
          return http.Response(
            jsonEncode({'total_dues': 0, 'total_paid': 1000, 'pending_fines': 0, 'overdue_invoices': 0}),
            200,
          );
        }
        if (p == '/api/v1/fees/invoices') {
          return http.Response(jsonEncode([]), 200);
        }
        if (p == '/api/v1/fees/fines') {
          return http.Response(jsonEncode([]), 200);
        }
        if (p == '/api/v1/fees/payments') {
          return http.Response(jsonEncode([]), 200);
        }
        if (p == '/api/v1/payments/config') {
          return http.Response(jsonEncode({'provider': 'sandbox'}), 200);
        }
        if (p == '/api/v1/payments/order') {
          return http.Response(jsonEncode({'order_id': 'ord_1', 'amount': 100}), 201);
        }
        if (p == '/api/v1/payments/verify') {
          return http.Response(jsonEncode({'success': true}), 200);
        }
        if (p == '/api/v1/library/summary') {
          return http.Response(jsonEncode({'active_loans': 0, 'overdue_loans': 0, 'total_fines': 0}), 200);
        }
        if (p == '/api/v1/library/books') {
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          if (req.method == 'DELETE') return http.Response('{}', 200);
          return http.Response(
            jsonEncode({
              'id': 'b1',
              'isbn': '123',
              'title': 'Book',
              'author': 'Auth',
              'category': 'CS',
              'total_copies': 1,
              'available_copies': 1,
            }),
            201,
          );
        }
        if (p == '/api/v1/library/ebooks') {
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          if (req.method == 'DELETE') return http.Response('{}', 200);
          return http.Response(
            jsonEncode({'id': 'eb1', 'title': 'EB', 'author': 'A', 'category': 'CS', 'format': 'PDF'}),
            201,
          );
        }
        if (p == '/api/v1/upload/pdf') {
          return http.Response(jsonEncode({'id': 'file-1', 'url': '/api/v1/uploads?id=file-1'}), 201);
        }
        if (p == '/api/v1/uploads' || p.endsWith('/pdf') || p.endsWith('/download')) {
          return http.Response.bytes([37, 80, 68, 70], 200);
        }
        if (p == '/api/v1/sessional/records' || p == '/api/v1/sessional/schedule' || p == '/api/v1/sessional/seating') {
          return http.Response(jsonEncode([]), 200);
        }
        if (p == '/api/v1/sessional/award-list' || p == '/api/v1/sessional/freeze') {
          return http.Response(jsonEncode({'subject_code': 'CS301', 'records': []}), 200);
        }
        if (p == '/api/v1/digilocker/auth-url') {
          return http.Response(jsonEncode({'auth_url': 'https://dl', 'state': 's', 'code_verifier': 'c'}), 200);
        }
        if (p == '/api/v1/digilocker/status') {
          return http.Response(jsonEncode({'student_id': 'u1', 'is_connected': false}), 200);
        }
        if (p == '/api/v1/digilocker/exchange' || p == '/api/v1/digilocker/disconnect' || p == '/api/v1/users/sync-digilocker' || p == '/api/v1/users/profile') {
          return http.Response(jsonEncode({'user': _sampleUserJson()}), 200);
        }
        if (p == '/api/v1/academics/assignments' || p == '/api/v1/academics/assignments/submissions') {
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          return http.Response(
            jsonEncode({
              'id': 'a1',
              'title': 'HW1',
              'section_id': 'sec1',
              'subject_id': 'sub1',
              'assignment_id': 'a1',
              'student_id': 'u1',
              'max_marks': 100,
              'created_at': '2026-11-28T10:00:00Z',
              'submitted_at': '2026-11-28T10:00:00Z',
            }),
            201,
          );
        }
        return http.Response('{}', 200);
      });

      final api = ApiService(baseUrl: 'http://mock.local', client: client);
      await api.fetchHostelRooms();
      await api.createHostelRoom(101, 'Block 1');
      await api.updateHostelRoom(originalRoomNumber: 101, newRoomNumber: 102, blockName: 'Block 1');
      await api.addHostelAsset(101, 'bed', 'BED01', 'operational');
      await api.updateHostelAsset(roomNumber: 101, assetId: 'ha1', serialNumber: 'BED01', condition: 'operational');
      await api.removeHostelAsset(101, 'ha1');
      await api.assignHostelOccupant(101, 'u1', 'h1', 'Harish');
      await api.removeHostelOccupant(101, 'u1');

      final meals = await api.fetchMessTimetable();
      await api.updateMessMeal(meals.first);
      await api.fetchMessRatingsReport();
      await api.submitMessRating(
        mealId: 'm1',
        userId: 'u1',
        userName: 'Harish',
        campusHandle: 'h1',
        rating: 'good',
        message: 'Great',
      );

      await api.fetchComplaints();
      await api.createComplaint(ComplaintModel(
        id: 'c1',
        submittedBy: 'u1',
        submitterName: 'Harish',
        submitterHandle: 'h1',
        submitterRole: 'student',
        title: 'T',
        description: 'D',
        category: 'hostel',
        urgency: 'low',
        status: 'open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await api.updateComplaintStatus(complaintId: 'c1', status: 'resolved', remarks: 'Fixed', resolvedBy: 'admin');

      await api.getFeeSummary('u1');
      await api.getInvoices(studentId: 'u1');
      await api.getFines(studentId: 'u1');
      await api.getFeePayments('u1');
      await api.downloadInvoicePdf('inv1');
      await api.downloadReceiptPdf('rcp1');
      await api.getPaymentConfig();
      await api.createPaymentOrder(entityType: 'invoice', entityId: 'inv1', studentId: 'u1', amount: 100);
      await api.verifyPaymentOrder(orderId: 'ord_1', paymentId: 'p1', paymentMethod: 'upi');

      await api.getLibrarySummary('u1');
      await api.getPhysicalBooks();
      await api.getEBooks();
      await api.createPhysicalBook(PhysicalBookModel(
        id: 'b1',
        isbn: '123',
        title: 'Book',
        author: 'Auth',
        publisher: 'Pub',
        edition: '1st',
        category: 'CS',
        departmentId: 'd1',
        totalCopies: 1,
        availableCopies: 1,
        shelfLocation: 'A1',
        replacementCost: 500,
      ));
      await api.deletePhysicalBook('b1');
      await api.uploadPdfDocument(bytes: [37, 80, 68, 70], filename: 'test.pdf');
      await api.downloadPdfDocument('file-1');
      await api.downloadEBookPdf('eb1');
      await api.createEBook(EBookModel(
        id: 'eb1',
        title: 'EB',
        author: 'A',
        category: 'CS',
        publisher: 'P',
        format: 'PDF',
        fileSize: '1 MB',
        downloadUrl: '',
        readUrl: '',
        description: '',
      ));
      await api.deleteEBook('eb1');

      await api.fetchSessionalRecords();
      await api.fetchSessionalSchedules();
      await api.fetchSeatingLayout();
      await api.fetchAwardList(subjectCode: 'CS301', semester: 5);

      await api.getDigiLockerAuthUrl(studentId: 'u1');
      await api.getDigiLockerStatus(studentId: 'u1');
      await api.exchangeDigiLockerToken(studentId: 'u1', code: 'c', state: 'st', codeVerifier: 'cv');
      await api.disconnectDigiLocker(studentId: 'u1');
      await api.syncDigiLocker('u1');

      await api.getAssignments();
      await api.createAssignment({'title': 'HW1'});
      await api.getSubmissions('a1');
      await api.submitAssignment({'assignment_id': 'a1', 'student_id': 'u1'});
    });

    test('Departments, Programs, Subjects, Sections, Batches, Optical, Library Loans & Error paths', () async {
      final client = MockClient((req) async {
        final p = req.url.path;
        if (p == '/api/v1/attendance/optical/start') {
          return http.Response(
            jsonEncode({
              'id': 'opt-1',
              'course_id': 'c1',
              'course_code': 'CS101',
              'course_name': 'CS',
              'room_number': 'LH-1',
              'scope_code': 'sec:1',
              'marked_by_user_id': 'p1',
              'marked_by_name': 'Prof',
              'refresh_interval_ms': 1500,
              'session_secret': 'sec',
              'expires_at': '2026-11-28T12:00:00Z',
            }),
            201,
          );
        }
        if (p == '/api/v1/attendance/optical/verify') {
          return http.Response(jsonEncode({'verified': true, 'message': 'ok'}), 200);
        }
        if (p == '/api/v1/attendance/optical/roster') {
          return http.Response(jsonEncode([]), 200);
        }
        if (p == '/api/v1/attendance/optical/manual-record') {
          if (req.method == 'DELETE') return http.Response('{}', 200);
          return http.Response(
            jsonEncode({
              'id': 'rec-1',
              'session_id': 'opt-1',
              'student_id': 'u1',
              'student_name': 'Harish',
              'status': 'present',
            }),
            201,
          );
        }
        if (p == '/api/v1/attendance/optical/end') {
          return http.Response('{}', 200);
        }
        if (p == '/api/v1/departments') {
          if (req.url.queryParameters.containsKey('id')) {
            return http.Response(
              jsonEncode({
                'department': {'id': 'd1', 'code': 'CSE', 'name': 'CSE'},
                'subjects': [],
                'teachers': [],
                'semesters': [],
              }),
              200,
            );
          }
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          return http.Response(jsonEncode({'id': 'd1', 'code': 'CSE', 'name': 'CSE'}), 201);
        }
        if (p == '/api/v1/academics/programs') {
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          return http.Response(
            jsonEncode({'id': 'p1', 'code': 'BTECH', 'name': 'B.Tech', 'degree_level': 'undergraduate', 'total_semesters': 8}),
            req.method == 'PUT' ? 200 : 201,
          );
        }
        if (p == '/api/v1/academics/subjects') {
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          return http.Response(jsonEncode({'id': 's1', 'code': 'CS101', 'name': 'CS', 'credits': 4}), 201);
        }
        if (p == '/api/v1/academics/subjects/syllabus') {
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          return http.Response(
            jsonEncode({
              'id': 'sy1',
              'subject_id': 's1',
              'revision_code': 'R1',
              'effective_from_year': '2026',
              'is_active': true,
              'content': 'Syllabus',
            }),
            201,
          );
        }
        if (p == '/api/v1/academics/semesters') {
          if (req.url.queryParameters.containsKey('id')) {
            return http.Response(
              jsonEncode({
                'semester': {'id': 'sem1', 'program_id': 'p1', 'semester_number': 1, 'academic_year': '2026', 'section': 'A', 'display_name': 'Sem 1'},
                'subjects': [],
                'teachers': [],
              }),
              200,
            );
          }
          return http.Response(jsonEncode([]), 200);
        }
        if (p == '/api/v1/academics/teachers' || p == '/api/v1/academics/allocations' || p == '/api/v1/academics/faculty/workload') {
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          if (req.method == 'DELETE') return http.Response('{}', 200);
          return http.Response(
            jsonEncode({
              'id': 'fa1',
              'section_id': 'sec1',
              'subject_id': 's1',
              'teacher_id': 't1',
              'component_type': 'theory',
              'weekly_hours': 3,
            }),
            201,
          );
        }
        if (p == '/api/v1/academics/sections') {
          if (req.url.queryParameters.containsKey('id')) {
            return http.Response(
              jsonEncode({
                'section': {'id': 'sec1', 'name': 'A', 'semester_number': 1, 'academic_year': '2026', 'display_name': 'Sec A'},
                'programs': [],
                'subjects': [],
                'teachers': [],
                'students': [],
              }),
              200,
            );
          }
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          return http.Response(
            jsonEncode({'id': 'sec1', 'name': 'A', 'semester_number': 1, 'academic_year': '2026', 'display_name': 'Sec A'}),
            201,
          );
        }
        if (p == '/api/v1/academics/sections/merge') {
          return http.Response(jsonEncode({'reassigned_students': 5}), 200);
        }
        if (p == '/api/v1/academics/sections/batches') {
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          return http.Response(jsonEncode({'id': 'lb1', 'section_id': 'sec1', 'name': 'B1', 'student_ids': []}), 201);
        }
        if (p == '/api/v1/academics/sections/batches/auto-partition') {
          return http.Response(jsonEncode([]), 201);
        }
        if (p == '/api/v1/library/books') {
          return http.Response(
            jsonEncode({
              'id': 'b1',
              'isbn': '123',
              'title': 'Book',
              'author': 'Auth',
              'category': 'CS',
              'total_copies': 1,
              'available_copies': 1,
            }),
            200,
          );
        }
        if (p == '/api/v1/library/borrows') {
          return http.Response(jsonEncode([]), 200);
        }
        if (p.startsWith('/api/v1/library/borrow') ||
            p.startsWith('/api/v1/library/return') ||
            p.startsWith('/api/v1/library/renew')) {
          return http.Response(
            jsonEncode({
              'id': 'br1',
              'book_id': 'b1',
              'book_title': 'Book',
              'student_id': 'u1',
              'student_name': 'Harish',
              'campus_handle': 'h1',
              'borrow_date': '2026-11-01T00:00:00Z',
              'due_date': '2026-11-15T00:00:00Z',
              'status': 'active',
            }),
            p == '/api/v1/library/borrow' ? 201 : 200,
          );
        }
        if (p == '/api/v1/library/ebooks/approve' || p == '/api/v1/library/ebooks/reject') {
          return http.Response(jsonEncode({'id': 'eb1', 'title': 'EB', 'author': 'A', 'category': 'CS', 'format': 'PDF'}), 200);
        }
        if (p == '/api/v1/fees/invoices') {
          return http.Response(
            jsonEncode({
              'id': 'inv1',
              'student_id': 'u1',
              'student_name': 'Harish',
              'campus_handle': 'h1',
              'academic_year': '2026',
              'semester_number': 1,
              'fee_type': 'tuition',
              'title': 'Tuition',
              'total_amount': 1000,
              'paid_amount': 0,
              'due_amount': 1000,
              'due_date': '2026-12-01T00:00:00Z',
              'status': 'pending',
            }),
            200,
          );
        }
        if (p == '/api/v1/fees/fines/appeal' || p == '/api/v1/fees/fines/waive') {
          return http.Response(
            jsonEncode({
              'id': 'f1',
              'student_id': 'u1',
              'student_name': 'Harish',
              'campus_handle': 'h1',
              'category': 'library',
              'reason': 'Late',
              'amount': 50,
              'status': 'waived',
            }),
            200,
          );
        }
        if (p == '/api/v1/fees/receipts') {
          return http.Response(
            jsonEncode({
              'receipt_number': 'RCP-1',
              'payment_id': 'p1',
              'student_id': 'u1',
              'student_name': 'Harish',
              'campus_handle': 'h1',
              'amount': 1000,
              'payment_method': 'upi',
              'transaction_ref': 'TX1',
              'issued_at': '2026-11-28T10:00:00Z',
              'title': 'Fee',
              'category': 'fee',
            }),
            200,
          );
        }
        if (p == '/api/v1/sessional/marks') {
          return http.Response(
            jsonEncode({
              'id': 's1',
              'student_id': 'u1',
              'student_name': 'Harish',
              'university_roll_no': '1',
              'subject_code': 'CS301',
              'subject_name': 'OS',
              'semester_number': 5,
            }),
            200,
          );
        }
        if (p == '/api/v1/sessional/freeze') {
          return http.Response(jsonEncode({'subject_code': 'CS301', 'records': []}), 200);
        }
        if (p == '/api/v1/academics/assignments/grade') {
          return http.Response(
            jsonEncode({
              'id': 'sub1',
              'assignment_id': 'a1',
              'student_id': 'u1',
              'submitted_at': '2026-11-28T10:00:00Z',
              'marks_awarded': 90,
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final api = ApiService(baseUrl: 'http://mock.local', client: client);
      await api.startOpticalSession({'course_id': 'c1'});
      await api.verifyOpticalAttendance({'session_id': 'opt-1'});
      await api.fetchOpticalSessionRoster('opt-1');
      await api.addManualOpticalRecord({'session_id': 'opt-1'});
      await api.removeManualOpticalRecord('opt-1', 'rec-1');
      await api.endOpticalSession('opt-1');

      await api.fetchDepartments();
      await api.createDepartment({'code': 'CSE', 'name': 'CSE'});
      await api.fetchDepartmentDetail('d1');
      await api.fetchPrograms();
      final prog = await api.createProgram(ProgramModel(id: 'p1', code: 'BTECH', name: 'B.Tech', degreeLevel: 'undergraduate', totalSemesters: 8));
      await api.updateProgram(prog);
      await api.fetchSubjects();
      await api.createSubject({'code': 'CS101', 'name': 'CS'});
      await api.fetchSyllabusAudit('s1');
      await api.reviseSyllabus({'subject_id': 's1'});
      await api.fetchSemesters();
      await api.fetchSemesterDetail('sem1');
      await api.fetchTeachers();
      await api.fetchSections();
      await api.createSection({'name': 'A'});
      await api.fetchSectionDetail('sec1');
      await api.assignStudentToSection(studentId: 'u1', sectionId: 'sec1', programId: 'p1');
      await api.transferStudentSection(studentId: 'u1', targetSectionId: 'sec2');
      await api.mergeSectionCohorts(sourceSectionId: 'sec1', targetSectionId: 'sec2');
      await api.fetchSectionBatches('sec1');
      await api.createLabBatch({'section_id': 'sec1', 'name': 'B1'});
      await api.autoPartitionBatches({'section_id': 'sec1', 'batch_count': 2});
      await api.assignStudentBatch(studentId: 'u1', batchId: 'lb1');
      await api.fetchFacultyAllocations('sec1');
      await api.assignFacultyAllocation({'section_id': 'sec1'});
      await api.removeFacultyAllocation('fa1');
      await api.fetchFacultyWorkload();

      await api.getBookById('b1');
      await api.getBorrowRecords();
      await api.borrowBook(bookId: 'b1', studentId: 'u1');
      await api.approveBorrowRequest(borrowId: 'br1', approvedBy: 'lib', approvedByName: 'Lib');
      await api.rejectBorrowRequest(borrowId: 'br1', rejectedBy: 'lib', rejectionReason: 'No');
      await api.returnBook(borrowId: 'br1', studentId: 'u1');
      await api.approveReturnRequest(borrowId: 'br1', approvedBy: 'lib', approvedByName: 'Lib');
      await api.rejectReturnRequest(borrowId: 'br1', rejectedBy: 'lib', rejectionReason: 'Damaged');
      await api.renewBook(borrowId: 'br1', studentId: 'u1');
      await api.approveRenewalRequest(borrowId: 'br1', approvedBy: 'lib', approvedByName: 'Lib');
      await api.rejectRenewalRequest(borrowId: 'br1', rejectedBy: 'lib', rejectionReason: 'Overdue');
      await api.approveEBook(ebookId: 'eb1', approvedBy: 'lib', approvedByName: 'Lib');
      await api.rejectEBook(ebookId: 'eb1', rejectedBy: 'lib', rejectionReason: 'Incomplete');

      await api.getInvoiceById('inv1');
      await api.payInvoice(invoiceId: 'inv1', studentId: 'u1', amount: 1000, paymentMethod: 'upi');
      await api.payFine(fineId: 'f1', studentId: 'u1', paymentMethod: 'upi');
      await api.appealFine(fineId: 'f1', reason: 'Error');
      await api.waiveFine(fineId: 'f1', waivedBy: 'admin');
      await api.fetchReceipt('RCP-1');
      await api.updateSessionalMarks({'record_id': 's1'});
      await api.freezeSessionalMarks({'subject_code': 'CS301'});
      await api.gradeSubmission(submissionId: 'sub1', marks: 90, feedback: 'Good', gradedBy: 'prof');

      // Error status verification
      final errApi = ApiService(
        baseUrl: 'http://mock.local',
        client: MockClient((_) async => http.Response('{"error":"server error"}', 500)),
      );
      await expectLater(errApi.login('u', 'p'), throwsException);
      await expectLater(errApi.fetchCourses(), throwsException);
      await expectLater(errApi.fetchUsers(), throwsException);
      await expectLater(errApi.checkHealth(), completion(isFalse));
    });
  });
}
