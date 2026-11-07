import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'models/user.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/offline_storage_service.dart';
import 'theme/app_theme.dart';
import 'theme/svg_icons.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppSvgIcon.prewarmCoreIcons();
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
    AppSvgIcon.prewarmCoreIcons();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      initTheme: AppTheme.lightTheme,
      duration: const Duration(milliseconds: 350),
      builder: (context, myTheme) {
        return MaterialApp(
          title: 'CampusOS',
          debugShowCheckedModeBanner: false,
          theme: myTheme,
          builder: (context, child) {
            return ThemeSwitchingArea(
              child: child ?? const SizedBox(),
            );
          },
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
      },
    );
  }
}
