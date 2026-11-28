import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/digilocker.dart';
import 'package:campus_client/models/payment_order.dart';
import 'package:campus_client/models/sessional.dart';
import 'package:campus_client/utils/app_error_catalog.dart';

void main() {
  group('AppErrorCatalog 100% coverage', () {
    test('allErrors and findByCode work for known and unknown codes', () {
      expect(AppErrorCatalog.allErrors, isNotEmpty);
      for (final err in AppErrorCatalog.allErrors) {
        final found = AppErrorCatalog.findByCode(err.code.toLowerCase());
        expect(found.code, err.code);
        expect(err.toString(), contains(err.code));
      }
      final fallback = AppErrorCatalog.findByCode('NON-EXISTENT-999');
      expect(fallback.code, AppErrorCatalog.systemUnexpected.code);
    });

    test('resolveException maps all exception categories', () {
      expect(AppErrorCatalog.resolveException(null).code, AppErrorCatalog.systemUnexpected.code);
      expect(AppErrorCatalog.resolveException('SocketException: refused').code, AppErrorCatalog.networkOffline.code);
      expect(AppErrorCatalog.resolveException('TimeoutException: timed out').code, AppErrorCatalog.networkTimeout.code);
      expect(AppErrorCatalog.resolveException('HTTP 503 Service Unavailable').code, AppErrorCatalog.serverMaintenance.code);
      expect(AppErrorCatalog.resolveException('HTTP 401 Unauthorized').code, AppErrorCatalog.authCredentialsMismatch.code);
      expect(AppErrorCatalog.resolveException('HTTP 403 Forbidden').code, AppErrorCatalog.authPermissionDenied.code);
      expect(AppErrorCatalog.resolveException('Device or resource busy').code, AppErrorCatalog.cameraInUse.code);
      expect(AppErrorCatalog.resolveException('Cannot open /dev/video0').code, AppErrorCatalog.cameraNotFound.code);
      expect(AppErrorCatalog.resolveException('Storage permission denied').code, AppErrorCatalog.storageAccessRestricted.code);
      expect(AppErrorCatalog.resolveException('Unknown random error').code, AppErrorCatalog.systemUnexpected.code);
    });

    test('resolveMobileScannerError maps all mobile scanner codes', () {
      expect(AppErrorCatalog.resolveMobileScannerError('permissionDenied').code, AppErrorCatalog.cameraPermissionDenied.code);
      expect(AppErrorCatalog.resolveMobileScannerError('no_camera').code, AppErrorCatalog.cameraNotFound.code);
      expect(AppErrorCatalog.resolveMobileScannerError('already_in_use').code, AppErrorCatalog.cameraInUse.code);
      expect(AppErrorCatalog.resolveMobileScannerError('other').code, AppErrorCatalog.cameraStreamInterrupted.code);
      expect(AppErrorCatalog.resolveMobileScannerError(null).code, AppErrorCatalog.cameraStreamInterrupted.code);
    });
  });

  group('DigiLocker models 100% coverage', () {
    test('DigiLockerAuthResponse and DigiLockerStatusModel roundtrip', () {
      final auth = DigiLockerAuthResponse.fromJson({
        'auth_url': 'https://dl.example/auth',
        'state': 'st1',
        'code_verifier': 'cv1',
        'environment': 'production',
      });
      expect(auth.toJson()['state'], 'st1');

      final status = DigiLockerStatusModel.fromJson({
        'student_id': 'u1',
        'is_connected': true,
        'abc_id': '123456789012',
        'verified_at': '2026-11-28T10:00:00.000Z',
        'documents_count': 1,
        'documents': [
          {
            'document_type': 'class_x',
            'document_title': 'Class X',
            'issuer': 'CBSE',
            'doc_ref_masked': 'XXXX1234',
            'issued_year': 2020,
            'is_verified': true,
            'verification_hash': 'abc',
            'verified_at': '2026-11-28T10:00:00Z',
            'status': 'verified',
          }
        ],
        'environment_mode': 'sandbox',
      });
      expect(status.isConnected, isTrue);
      expect(status.documents.length, 1);
      expect(status.toJson()['abc_id'], '123456789012');
    });
  });

  group('PaymentOrder models 100% coverage', () {
    test('VirtualAccountModel, PaymentGatewayConfigModel, PaymentOrderModel roundtrip', () {
      final cfg = PaymentGatewayConfigModel.fromJson({
        'provider': 'razorpay',
        'key_id': 'rzp_1',
        'merchant_name': 'BBDIT',
        'merchant_vpa': 'bbdit@sbi',
        'environment': 'sandbox',
        'supported_methods': ['upi', 'net_banking'],
        'virtual_account': {
          'beneficiary_name': 'BBDIT',
          'bank_name': 'SBI',
          'account_number': '12345',
          'ifsc_code': 'SBIN0001',
          'branch_name': 'Main',
          'reference_van': 'VAN1',
        },
      });
      expect(cfg.isSandbox, isTrue);
      expect(cfg.toJson()['provider'], 'razorpay');

      final order = PaymentOrderModel.fromJson({
        'order_id': 'ord_1',
        'entity_type': 'invoice',
        'entity_id': 'inv_1',
        'student_id': 'u1',
        'student_name': 'Harish',
        'amount': 5000,
        'currency': 'INR',
        'status': 'created',
        'gateway_provider': 'sandbox',
        'gateway_order_id': 'gw_1',
        'gateway_key_id': 'key_1',
        'upi_link': 'upi://pay',
        'virtual_account': cfg.virtualAccount!.toJson(),
        'notes': 'Tuition',
        'expires_at': '2026-11-28T12:00:00.000Z',
      });
      expect(order.amount, 5000.0);
      expect(order.toJson()['order_id'], 'ord_1');
    });
  });

  group('Sessional models 100% coverage', () {
    test('InternalAssessmentModel, SessionalScheduleModel, DeskSeatingModel, AKTUInternalAwardListModel roundtrip', () {
      final rec = InternalAssessmentModel.fromJson({
        'id': 'rec_1',
        'student_id': 'u1',
        'student_name': 'Harish',
        'university_roll_no': '210097',
        'subject_code': 'CS301',
        'subject_name': 'OS',
        'semester_number': 5,
        'section': 'Section B',
        'is_practical': false,
        'ct1_score': 24,
        'ct2_score': 27,
        'put_score': 80,
        'ta_score': 9,
        'lab_continuous_score': 0,
        'lab_viva_score': 0,
        'lab_attendance_score': 0,
        'calculated_sessional': 17,
        'total_internal_marks': 26,
        'max_internal_marks': 30,
        'formula_used': 'AKTU',
        'is_frozen': true,
        'frozen_by': 'hod_1',
        'frozen_at': '2026-11-28T10:00:00Z',
        'status': 'frozen',
        'remarks': 'Verified',
      });
      final copied = rec.copyWith(ct1Score: 28, isFrozen: false);
      expect(copied.ct1Score, 28.0);
      expect(copied.toJson()['subject_code'], 'CS301');

      final sched = SessionalScheduleModel.fromJson({
        'id': 'sch_1',
        'exam_type': 'CT-1',
        'subject_code': 'CS301',
        'subject_name': 'OS',
        'semester_number': 5,
        'exam_date': '2026-11-30',
        'time_slot': '10:00 AM',
        'hall_number': 'LT-101',
        'total_capacity': 60,
        'invigilator_name': 'Prof. Sharma',
        'roll_range': '1-60',
      });
      expect(sched.toJson()['hall_number'], 'LT-101');

      final desk = DeskSeatingModel.fromJson({
        'desk_number': 'D-01',
        'hall_number': 'LT-101',
        'seat_index': 1,
        'student_roll_no': '210097',
        'student_name': 'Harish',
        'subject_code': 'CS301',
        'subject_name': 'OS',
        'exam_type': 'CT-1',
      });
      expect(desk.toJson()['desk_number'], 'D-01');

      final award = AKTUInternalAwardListModel.fromJson({
        'department_code': 'CSE',
        'department_name': 'Computer Science',
        'program_name': 'B.Tech',
        'semester_number': 5,
        'subject_code': 'CS301',
        'subject_name': 'OS',
        'academic_session': '2026-27',
        'is_practical': false,
        'max_internal_marks': 30,
        'total_students': 1,
        'pass_count': 1,
        'fail_count': 0,
        'pass_percentage': 100,
        'average_marks': 26,
        'highest_marks': 26,
        'lowest_marks': 26,
        'deficit_count': 0,
        'is_frozen': true,
        'frozen_by': 'hod_1',
        'frozen_at': '2026-11-28T10:00:00Z',
        'digital_signature': 'sig123',
        'records': [rec.toJson()],
      });
      expect(award.records.length, 1);
      expect(award.toJson()['digital_signature'], 'sig123');
    });
  });
}
