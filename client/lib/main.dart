import 'package:flutter/material.dart';
import 'di/service_locator.dart';
import 'facade/campus_facade.dart';
import 'models/user.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_cache.dart';
import 'services/offline_storage_service.dart';
import 'theme/app_theme.dart';
import 'theme/svg_icons.dart';
import 'widgets/circular_theme_reveal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppSvgIcon.prewarmCoreIcons();

  // Initialize application-level cache and restore preferred theme
  AppCache.instance.init();
  AppTheme.initFromCache();

  // Initialize unified IoC container and decoupled dependencies
  final di = CampusDI.setup(defaultBaseUrl: 'http://localhost:8080');
  final storage = di.get<OfflineStorageService>();
  final facade = di.get<ICampusFacade>();

  runApp(
    CampusScope(
      facade: facade,
      storage: storage,
      child: CampusManagementApp(
        storage: storage,
        restoreCachedTab: true,
      ),
    ),
  );
}

class CampusManagementApp extends StatefulWidget {
  final OfflineStorageService storage;
  final bool restoreCachedTab;

  const CampusManagementApp({
    super.key,
    required this.storage,
    this.restoreCachedTab = false,
  });

  @override
  State<CampusManagementApp> createState() => _CampusManagementAppState();
}

class _CampusManagementAppState extends State<CampusManagementApp> {
  UserModel? _loggedInUser;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'BBDIT & BBDIT College of Pharmacy',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          themeAnimationDuration: Duration.zero,
          builder: (context, child) {
            return CircularThemeReveal(
              child: child ?? const SizedBox.shrink(),
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
                  restoreCachedTab: widget.restoreCachedTab,
                  onLogout: () {
                    setState(() => _loggedInUser = null);
                  },
                ),
        );
      },
    );
  }
}
