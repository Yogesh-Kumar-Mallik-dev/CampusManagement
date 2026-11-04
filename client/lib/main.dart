import 'package:flutter/material.dart';
import 'models/user.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/offline_storage_service.dart';
import 'theme/app_theme.dart';

// Global Theme Mode notifier for smooth animated toggle
final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiService(baseUrl: 'http://localhost:8080');
  final storage = OfflineStorageService(api: api);

  runApp(CampusManagementApp(storage: storage));
}

class CampusManagementApp extends StatefulWidget {
  final OfflineStorageService storage;

  const CampusManagementApp({super.key, required this.storage});

  @override
  State<CampusManagementApp> createState() => _CampusManagementAppState();
}

class _CampusManagementAppState extends State<CampusManagementApp> {
  UserModel? _loggedInUser;

  @override
  void initState() {
    super.initState();
    appThemeModeNotifier.addListener(_onThemeModeChanged);
  }

  @override
  void dispose() {
    appThemeModeNotifier.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  void _onThemeModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appThemeModeNotifier.value,
      themeAnimationDuration: AppTheme.themeAnimationDuration,
      themeAnimationCurve: AppTheme.themeAnimationCurve,
      home: _loggedInUser == null
          ? LoginScreen(
              storage: widget.storage,
              onLoginSuccess: (user) {
                setState(() => _loggedInUser = user);
              },
            )
          : HomeScreen(
              storage: widget.storage,
              currentUser: _loggedInUser,
              onLogout: () {
                setState(() => _loggedInUser = null);
              },
            ),
    );
  }
}
