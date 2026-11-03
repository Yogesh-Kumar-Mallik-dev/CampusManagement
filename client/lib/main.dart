import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/offline_storage_service.dart';
import 'theme/app_theme.dart';

// Global Theme Mode notifier for instant toggle
final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiService(baseUrl: 'http://localhost:8080');
  final storage = OfflineStorageService(api: api);

  runApp(CampusManagementApp(storage: storage));
}

class CampusManagementApp extends StatelessWidget {
  final OfflineStorageService storage;

  const CampusManagementApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'CampusOS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: HomeScreen(storage: storage),
        );
      },
    );
  }
}
