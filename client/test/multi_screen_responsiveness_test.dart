import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/screens/attendance_screen.dart';
import 'package:campus_client/screens/complaints_screen.dart';
import 'package:campus_client/screens/department_management_screen.dart';
import 'package:campus_client/screens/fee_screen.dart';
import 'package:campus_client/screens/home_screen.dart';
import 'package:campus_client/screens/hostel_screen.dart';
import 'package:campus_client/screens/library_screen.dart';
import 'package:campus_client/screens/login_screen.dart';
import 'package:campus_client/screens/mess_screen.dart';
import 'package:campus_client/screens/notices_screen.dart';
import 'package:campus_client/screens/sessional_exam_screen.dart';
import 'package:campus_client/screens/timetable_screen.dart';
import 'package:campus_client/screens/user_management_screen.dart';
import 'package:campus_client/screens/user_profile_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/app_cache.dart';
import 'package:campus_client/services/offline_storage_service.dart';

void main() {
  final viewports = [
    const Size(320, 568),  // Extra small mobile
    const Size(360, 640),  // Standard mobile
    const Size(412, 915),  // Large mobile
    const Size(768, 1024), // Tablet portrait
    const Size(1024, 768), // Tablet landscape
    const Size(1280, 800), // Laptop
    const Size(1920, 1080),// Full HD Desktop
    const Size(2560, 1440),// 2K / Ultrawide
  ];

  late OfflineStorageService storage;
  late ApiService api;

  setUpAll(() {
    api = ApiService(baseUrl: 'http://localhost:8080');
    storage = OfflineStorageService(api: api);
    AppCache.instance.init();
  });

  for (final vp in viewports) {
    testWidgets('Multi-screen responsiveness at ${vp.width.toInt()}x${vp.height.toInt()}', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      tester.view.physicalSize = vp;
      tester.view.devicePixelRatio = 1.0;

      final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');
      final admin = OfflineStorageService.getMockUserForHandle('campus_admin');

      void checkNoOverflow(String screenName) {
        final err = tester.takeException();
        expect(err, isNull, reason: '$screenName overflowed at $vp');
      }

      // 1. LoginScreen
      await tester.pumpWidget(MaterialApp(home: LoginScreen(storage: storage, onLoginSuccess: (_) {})));
      await tester.pumpAndSettle();
      checkNoOverflow('LoginScreen');

      // 2. HomeScreen with student persona
      await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage, currentUser: student)));
      await tester.pumpAndSettle();
      checkNoOverflow('HomeScreen (student)');

      // 3. HomeScreen with admin persona
      await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage, currentUser: admin)));
      await tester.pumpAndSettle();
      checkNoOverflow('HomeScreen (admin)');

      // 4. TimetableScreen
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TimetableScreen(storage: storage, activeScope: 'sec:cse-3a', currentUser: student)),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('TimetableScreen');

      // 5. AttendanceScreen
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AttendanceScreen(storage: storage, currentUser: student)),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('AttendanceScreen');

      // 6. NoticesScreen
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NoticesScreen(storage: storage, userScopes: student.activeScopes)),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('NoticesScreen');

      // 7. HostelScreen
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HostelScreen(storage: storage, currentUser: student)),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('HostelScreen');

      // 8. MessScreen
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MessScreen(storage: storage, currentUser: student)),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('MessScreen');

      // 9. FeeScreen
      await tester.pumpWidget(MaterialApp(
        home: FeeScreen(storage: storage, currentUser: student),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('FeeScreen');

      // 10. LibraryScreen
      await tester.pumpWidget(MaterialApp(
        home: LibraryScreen(storage: storage, currentUser: student),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('LibraryScreen');

      // 11. ComplaintsScreen
      await tester.pumpWidget(MaterialApp(
        home: ComplaintsScreen(storage: storage, currentUser: student),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('ComplaintsScreen');

      // 12. UserProfileScreen
      await tester.pumpWidget(MaterialApp(
        home: UserProfileScreen(storage: storage, userIdentifier: student.id, initialUser: student, showAppBar: false),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('UserProfileScreen');

      // 13. SessionalExamScreen
      await tester.pumpWidget(MaterialApp(
        home: SessionalExamScreen(storage: storage, currentUser: student),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('SessionalExamScreen');

      // 14. UserManagementScreen (Admin)
      await tester.pumpWidget(MaterialApp(
        home: UserManagementScreen(storage: storage, currentUser: admin),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('UserManagementScreen');

      // 15. DepartmentManagementScreen (Admin)
      await tester.pumpWidget(MaterialApp(
        home: DepartmentManagementScreen(storage: storage, currentUser: admin),
      ));
      await tester.pumpAndSettle();
      checkNoOverflow('DepartmentManagementScreen');
    });
  }
}
