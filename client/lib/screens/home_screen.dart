import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import 'attendance_screen.dart';
import 'notices_screen.dart';
import 'timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  final OfflineStorageService storage;

  const HomeScreen({super.key, required this.storage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Mock persona switcher to test Multi-role & Scoped permissions live
  late List<UserModel> _personas;
  late UserModel _currentUser;

  @override
  void initState() {
    super.initState();
    _personas = [
      UserModel(
        id: 'usr-harish_2025_l_btech_1',
        campusHandle: 'harish_2025_l_btech_1',
        firstName: 'Harish',
        lastName: 'Kumar',
        email: 'harish_2025_l_btech_1@campus.edu',
        archetype: 'student',
        activeScopes: ['global', 'sec:cse-3a', 'club:robotics'],
      ),
      UserModel(
        id: 'usr-priya_2024_emp_1',
        campusHandle: 'priya_2024_emp_1',
        firstName: 'Dr. Priya',
        lastName: 'Nair',
        email: 'priya_2024_emp_1@campus.edu',
        archetype: 'employee',
        activeScopes: ['global', 'dept:cse', 'sec:cse-3a', 'unit:student_affairs'],
      ),
      UserModel(
        id: 'usr-ramesh_2023_emp_1',
        campusHandle: 'ramesh_2023_emp_1',
        firstName: 'Ramesh',
        lastName: 'Singh',
        email: 'ramesh_2023_emp_1@campus.edu',
        archetype: 'employee',
        activeScopes: ['global', 'unit:security', 'facility:gate-1'],
      ),
    ];
    _currentUser = _personas.first;
    _checkServer();
  }

  Future<void> _checkServer() async {
    await widget.storage.refreshConnectivityAndSync(_currentUser.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrWeb = MediaQuery.of(context).size.width >= 800;

    final pages = [
      _buildDashboardView(),
      TimetableScreen(
        storage: widget.storage,
        activeScope: _currentUser.activeScopes.contains('sec:cse-3a') ? 'sec:cse-3a' : 'global',
      ),
      AttendanceScreen(
        storage: widget.storage,
        currentUser: _currentUser,
      ),
      NoticesScreen(
        storage: widget.storage,
        userScopes: _currentUser.activeScopes,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('CampusOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // Online/Offline pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: widget.storage.isOnline ? Colors.green.shade100 : Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.storage.isOnline ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: widget.storage.isOnline ? Colors.green.shade800 : Colors.amber.shade900,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.storage.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.storage.isOnline ? Colors.green.shade800 : Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Persona Switcher
          DropdownButtonHideUnderline(
            child: DropdownButton<UserModel>(
              value: _currentUser,
              icon: const Icon(Icons.arrow_drop_down),
              items: _personas.map((u) {
                return DropdownMenuItem<UserModel>(
                  value: u,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: u.archetype == 'student' ? Colors.blue : Colors.purple,
                        child: Text(
                          u.firstName[0],
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(u.firstName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (UserModel? newUser) {
                if (newUser != null) {
                  setState(() => _currentUser = newUser);
                  _checkServer();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: isDesktopOrWeb
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) => setState(() => _currentIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: Text('Timetable')),
                    NavigationRailDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: Text('Attendance')),
                    NavigationRailDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: Text('Notices')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: pages[_currentIndex]),
              ],
            )
          : pages[_currentIndex],
      bottomNavigationBar: isDesktopOrWeb
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Timetable'),
                BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), label: 'Attendance'),
                BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Notices'),
              ],
            ),
    );
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      _currentUser.firstName[0],
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser.fullName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Handle: ${_currentUser.campusHandle}',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: _currentUser.activeScopes.map((scope) {
                            return Chip(
                              label: Text(scope, style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Action Cards
          const Text(
            'Phase 1 Core Modules',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width >= 800 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildModuleCard(
                title: 'Timetable',
                subtitle: 'Lectures & Labs',
                icon: Icons.calendar_month,
                color: Colors.blue,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _buildModuleCard(
                title: 'Attendance',
                subtitle: 'Offline Sync & Outbox',
                icon: Icons.fact_check,
                color: Colors.teal,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _buildModuleCard(
                title: 'Targeted Notices',
                subtitle: 'Department & Section',
                icon: Icons.notifications_active,
                color: Colors.amber.shade900,
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Offline Engine Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueGrey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Offline-First Sync Engine Active',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All classes, timetables, and notices are cached locally. You can take attendance anywhere on campus without internet connectivity; it queues in your local outbox and syncs safely to the Go backend.',
                        style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
