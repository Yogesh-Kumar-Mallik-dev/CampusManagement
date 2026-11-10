import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/di/service_locator.dart';
import 'package:campus_client/screens/home_screen.dart';
import 'package:campus_client/screens/timetable_screen.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/app_cache.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/theme/app_theme.dart';

void main() {
  group('AppCache Application-Level Cache Service Tests', () {
    late AppCache cache;

    setUp(() {
      cache = AppCache.instance;
      cache.reset();
      cache.init();
    });

    tearDown(() {
      cache.reset();
    });

    test('Cache initializes and supports generic key-value types', () {
      expect(cache.isInitialized, isTrue);
      expect(cache.size, equals(0));

      // String
      cache.setString('test.str', 'hello world');
      expect(cache.getString('test.str'), equals('hello world'));
      expect(cache.containsKey('test.str'), isTrue);

      // Int
      cache.setInt('test.int', 42);
      expect(cache.getInt('test.int'), equals(42));

      // Bool
      cache.setBool('test.bool', true);
      expect(cache.getBool('test.bool'), isTrue);

      // Double
      cache.setDouble('test.double', 99.5);
      expect(cache.getDouble('test.double'), equals(99.5));

      // Map
      cache.setMap('test.map', {'a': 1, 'b': 'two'});
      final retrievedMap = cache.getMap('test.map');
      expect(retrievedMap, isNotNull);
      expect(retrievedMap!['a'], equals(1));
      expect(retrievedMap['b'], equals('two'));

      // List
      cache.setList('test.list', [10, 20, 30]);
      final retrievedList = cache.getList('test.list');
      expect(retrievedList, equals([10, 20, 30]));

      // Removal & Clear
      cache.remove('test.str');
      expect(cache.containsKey('test.str'), isFalse);
      expect(cache.getString('test.str'), isNull);

      cache.clear();
      expect(cache.size, equals(0));
    });

    test('Cache persists and restores preferred ThemeMode', () {
      expect(cache.getPreferredThemeMode(), isNull);

      cache.setPreferredThemeMode(ThemeMode.dark);
      expect(cache.getPreferredThemeMode(), equals(ThemeMode.dark));

      cache.setPreferredThemeMode(ThemeMode.light);
      expect(cache.getPreferredThemeMode(), equals(ThemeMode.light));

      cache.setPreferredThemeMode(ThemeMode.system);
      expect(cache.getPreferredThemeMode(), equals(ThemeMode.system));

      // Verify AppTheme synchronization
      AppTheme.setTheme(ThemeMode.dark);
      expect(AppTheme.themeModeNotifier.value, equals(ThemeMode.dark));
      expect(cache.getPreferredThemeMode(), equals(ThemeMode.dark));

      AppTheme.setTheme(ThemeMode.light);
      expect(AppTheme.themeModeNotifier.value, equals(ThemeMode.light));
      expect(cache.getPreferredThemeMode(), equals(ThemeMode.light));

      AppTheme.toggleTheme();
      expect(AppTheme.themeModeNotifier.value, equals(ThemeMode.dark));
      expect(cache.getPreferredThemeMode(), equals(ThemeMode.dark));

      // Reset theme back to light
      AppTheme.setTheme(ThemeMode.light);
    });

    test('Cache remembers personal navigation tabs and dock slot index per user handle', () {
      const studentHandle = 'harish_2025_l_btech_1';
      const facultyHandle = 'priya_2024_emp_1';

      expect(cache.getLastActiveNavIndex(userHandle: studentHandle), isNull);
      expect(cache.getLastActiveNavIndex(userHandle: facultyHandle), isNull);

      // Student navigates to Attendance (index 2)
      cache.setLastActiveNavIndex(2, userHandle: studentHandle);
      cache.setSlot3PageIndex(2, userHandle: studentHandle);

      // Faculty navigates to Department Management (index 5)
      cache.setLastActiveNavIndex(5, userHandle: facultyHandle);
      cache.setSlot3PageIndex(5, userHandle: facultyHandle);

      // Verify scoping integrity
      expect(cache.getLastActiveNavIndex(userHandle: studentHandle), equals(2));
      expect(cache.getSlot3PageIndex(userHandle: studentHandle), equals(2));

      expect(cache.getLastActiveNavIndex(userHandle: facultyHandle), equals(5));
      expect(cache.getSlot3PageIndex(userHandle: facultyHandle), equals(5));
    });

    test('Cache remembers subsystem tabs (Fee, Library, Payment, Hostel, Mess, Complaints)', () {
      const userHandle = 'harish_2025_l_btech_1';

      // Fee Portal tab (e.g. 2: Records & Receipts)
      cache.setLastFeeTab(2, userHandle: userHandle);
      expect(cache.getLastFeeTab(userHandle: userHandle), equals(2));

      // Library Portal tab (e.g. 1: Physical Catalog)
      cache.setLastLibraryTab(1, userHandle: userHandle);
      expect(cache.getLastLibraryTab(userHandle: userHandle), equals(1));

      // Preferred payment method
      cache.setPreferredPaymentMethod('netbanking');
      expect(cache.getPreferredPaymentMethod(), equals('netbanking'));

      cache.setPreferredPaymentMethod('UPI');
      expect(cache.getPreferredPaymentMethod(), equals('upi'));

      // Hostel floor
      cache.setLastHostelFloor(3, userHandle: userHandle);
      expect(cache.getLastHostelFloor(userHandle: userHandle), equals(3));

      // Mess day (e.g. 5: Friday)
      cache.setLastMessDay(5, userHandle: userHandle);
      expect(cache.getLastMessDay(userHandle: userHandle), equals(5));

      // Complaints filter
      cache.setLastComplaintsFilter('resolved', userHandle: userHandle);
      expect(cache.getLastComplaintsFilter(userHandle: userHandle), equals('resolved'));

      // Remembered user handle
      cache.setRememberedUserHandle(userHandle);
      expect(cache.getRememberedUserHandle(), equals(userHandle));
      cache.clearRememberedUserHandle();
      expect(cache.getRememberedUserHandle(), isNull);
    });

    test('Cache fires changeNotifier on any mutation', () {
      int notifications = 0;
      void listener() => notifications++;
      cache.changeNotifier.addListener(listener);

      cache.setString('notify.test', 'val1');
      cache.setInt('notify.test2', 123);
      cache.remove('notify.test');
      cache.clear();

      expect(notifications, equals(4));
      cache.changeNotifier.removeListener(listener);
    });

    test('CampusDI registers AppCache singleton in setup()', () {
      final di = CampusDI.setup();
      expect(di.isRegistered<AppCache>(), isTrue);
      expect(di.get<AppCache>(), isA<AppCache>());
    });

    testWidgets('HomeScreen restores cached last active tab when restoreCachedTab is true', (tester) async {
      final api = ApiService(baseUrl: 'http://localhost:8080');
      final storage = OfflineStorageService(api: api);
      final student = OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1');

      // Pre-seed cache with Timetable (index 1)
      cache.setLastActiveNavIndex(1, userHandle: student.campusHandle);
      cache.setSlot3PageIndex(1, userHandle: student.campusHandle);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          storage: storage,
          currentUser: student,
          restoreCachedTab: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Should automatically land on Timetable tab instead of default Dashboard
      expect(find.byType(TimetableScreen), findsOneWidget);
    });
  });
}
