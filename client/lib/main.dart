import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/offline_storage_service.dart';

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
    return MaterialApp(
      title: 'CampusOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E40AF), // Institutional Navy
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: HomeScreen(storage: storage),
    );
  }
}
