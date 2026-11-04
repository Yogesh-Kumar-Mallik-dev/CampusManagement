import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/main.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/widgets/app_logo.dart';

void main() {
  testWidgets('Campus app renders home dashboard with logo and navigation',
      (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:8080');
    final storage = OfflineStorageService(api: api);

    await tester.pumpWidget(CampusManagementApp(storage: storage));
    await tester.pump();

    // Verify high-definition logo and dashboard cards render
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Academic Operations'), findsOneWidget);
    expect(find.text('Timetable'), findsWidgets);
    expect(find.text('Attendance'), findsWidgets);
    expect(find.text('Targeted Notices'), findsWidgets);
  });
}
