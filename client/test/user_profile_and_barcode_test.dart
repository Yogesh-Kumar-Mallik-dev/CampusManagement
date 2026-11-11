import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/user.dart';
import 'package:campus_client/screens/user_profile_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/widgets/real_barcode.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiService api;
  late OfflineStorageService storage;

  setUp(() {
    api = ApiService(baseUrl: 'http://localhost:8080');
    storage = OfflineStorageService(api: api, enableMockSeeding: false);
  });
  group('RealBarcode ISO/IEC 15417 Code 128 Tests', () {
    test('generateCode128Modules generates valid Code 128 Set B with quiet zones and checksum', () {
      const testCode = 'HARISH2025';
      final modules = RealBarcode.generateCode128Modules(testCode);

      // Must be non-empty and start with 10 quiet modules (false)
      expect(modules.isNotEmpty, isTrue);
      expect(modules.take(10).every((b) => b == false), isTrue);
      // Terminal quiet zone (last 10 modules false)
      expect(modules.reversed.take(10).every((b) => b == false), isTrue);

      // Verify Start B symbol (104): pattern '211214' -> 2 bars, 1 space, 1 bar, 2 spaces, 1 bar, 4 spaces
      final startB = modules.skip(10).take(11).toList();
      expect(startB, [true, true, false, true, false, false, true, false, false, false, false]);
    });

    testWidgets('RealBarcode renders CustomPaint without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RealBarcode(
              data: 'ROLL-123456',
              height: 40,
              lineWidth: 1.5,
              showText: true,
            ),
          ),
        ),
      );

      expect(find.byType(RealBarcode), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('*ROLL-123456*'), findsOneWidget);
    });
  });

  group('User Profile Screen Hardcoded Data & Real Barcode Audit', () {
    testWidgets('renders Not specified for unprovided fields and does not fabricate mock data', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create a brand new student user with NO emergency contact, address, or blood group
      final user = UserModel(
        id: 'usr-fresh_student_1',
        campusHandle: 'fresh_student_1',
        firstName: 'Aarav',
        lastName: 'Sharma',
        email: 'aarav@campus.edu',
        archetype: 'student',
        status: 'active',
        mustChangePassword: true,
        activeScopes: ['global'],
        // emergencyContactName, emergencyContactPhone, bloodGroup, address are deliberately null
      );
      storage.registerUser(user);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: UserProfileScreen(
            storage: storage,
            userIdentifier: user.id,
            initialUser: user,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that mock names and addresses are NOT present
      expect(find.text('Suresh Kumar (Father)'), findsNothing);
      expect(find.text('+91 98765 00112'), findsNothing);
      expect(find.text('Room 204, Block 2, BBDIT Hostel'), findsNothing);

      // Verify truthful empty/unspecified states
      expect(find.text('Not specified'), findsWidgets);
      expect(find.text('Not registered'), findsWidgets);
      expect(find.text('Day Scholar / Non-Resident'), findsWidgets);
      expect(find.text('No Sessions Yet'), findsOneWidget);

      // Verify DigiLocker does NOT show fake CBSE / Aadhaar documents when unverified
      expect(find.text('Secondary School Certificate (Class X)'), findsNothing);
      expect(find.text('Senior School Certificate (Class XII - PCM)'), findsNothing);
      expect(find.text('Aadhaar Identity Verification'), findsNothing);
      expect(find.text('Uttar Pradesh State Domicile Certificate'), findsNothing);
      expect(find.text('8912-3456-7890'), findsNothing);
    });

    testWidgets('Digital ID Pass modal renders real QrImageView and RealBarcode', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final user = UserModel(
        id: 'usr-aarav_2025_r_btech_1',
        campusHandle: 'aarav_2025_r_btech_1',
        universityRollNo: '25010042',
        firstName: 'Aarav',
        lastName: 'Sharma',
        email: 'aarav@campus.edu',
        archetype: 'student',
        status: 'active',
      );
      storage.registerUser(user);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: UserProfileScreen(
            storage: storage,
            userIdentifier: user.id,
            initialUser: user,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Digital ID Pass" badge
      final digitalIdBtn = find.text('Digital ID Pass');
      expect(digitalIdBtn, findsOneWidget);
      await tester.tap(digitalIdBtn);
      await tester.pumpAndSettle();

      // Check Digital ID Modal content
      expect(find.text('CAMPUS DIGITAL PASS'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byType(RealBarcode), findsOneWidget);
      expect(find.text('*25010042*'), findsOneWidget);
    });

    testWidgets('OfflineStorageService creates users without auto-populating unprovided fields', (tester) async {
      final createdStudent = await storage.createStudent({
        'first_name': 'Dev',
        'last_name': 'Patel',
        'email': 'dev@campus.edu',
        'admission_year': 2025,
        'entry_type': 'regular',
        'program': 'btech',
      });

      expect(createdStudent.emergencyContactName, isNull);
      expect(createdStudent.emergencyContactPhone, isNull);
      expect(createdStudent.bloodGroup, isNull);
      expect(createdStudent.address, isNull);

      final createdContractor = await storage.createContractor({
        'first_name': 'Ramesh',
        'last_name': 'Kumar',
        'vendor_organization': 'Campus Foods',
      });

      expect(createdContractor.emergencyContactName, isNull);
      expect(createdContractor.emergencyContactPhone, isNull);
      expect(createdContractor.bloodGroup, isNull);
      expect(createdContractor.universityRollNo, isNull);
      expect(createdContractor.contractorProfile?['gate_pass_id'], isNull);
    });
  });
}
