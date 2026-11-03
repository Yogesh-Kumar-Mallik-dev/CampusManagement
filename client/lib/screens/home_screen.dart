import 'package:flutter/material.dart';
import '../main.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/svg_icons.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: AppColors.wineRed,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              child: const AppSvgIcon(
                svgString: AppSvgIcon.academicCap,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'CampusOS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Connection Status Badge
          AnimatedContainer(
            duration: AppTheme.themeAnimationDuration,
            curve: AppTheme.themeAnimationCurve,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.storage.isOnline
                  ? (isDark ? const Color(0xFF1B4725) : AppColors.githubGreenSubtle)
                  : (isDark ? const Color(0xFF3B2A10) : AppColors.statusYellowSubtle),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.storage.isOnline
                    ? (isDark ? AppColors.githubGreen : AppColors.githubGreenBorder)
                    : (isDark ? AppColors.statusYellow : AppColors.statusYellowBorder),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvgIcon(
                  svgString: widget.storage.isOnline ? AppSvgIcon.cloudCheck : AppSvgIcon.cloudOff,
                  size: 13,
                  color: widget.storage.isOnline ? AppColors.githubGreenText : AppColors.statusYellow,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.storage.isOnline ? 'Online Sync' : 'Offline Cache',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.storage.isOnline ? AppColors.githubGreenText : AppColors.statusYellow,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Theme Toggle
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            onPressed: () {
              appThemeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          const SizedBox(width: 4),

          // User Persona Switcher
          DropdownButtonHideUnderline(
            child: DropdownButton<UserModel>(
              value: _currentUser,
              icon: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: AppSvgIcon(svgString: AppSvgIcon.chevronDown, size: 14),
              ),
              items: _personas.map((u) {
                return DropdownMenuItem<UserModel>(
                  value: u,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: u.archetype == 'student'
                              ? AppColors.wineRed.withValues(alpha: 0.15)
                              : AppColors.githubGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: u.archetype == 'student'
                                ? AppColors.wineRed
                                : AppColors.githubGreen,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          u.firstName[0],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: u.archetype == 'student'
                                ? AppColors.wineRed
                                : AppColors.githubGreenText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        u.fullName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
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
          const SizedBox(width: 16),
        ],
      ),
      body: isDesktopOrWeb
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) => setState(() => _currentIndex = i),
                  labelType: NavigationRailLabelType.all,
                  minWidth: 76,
                  destinations: const [
                    NavigationRailDestination(
                      icon: AppSvgIcon(svgString: AppSvgIcon.dashboard),
                      selectedIcon: AppSvgIcon(svgString: AppSvgIcon.dashboard, color: AppColors.wineRed),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: AppSvgIcon(svgString: AppSvgIcon.calendar),
                      selectedIcon: AppSvgIcon(svgString: AppSvgIcon.calendar, color: AppColors.wineRed),
                      label: Text('Timetable'),
                    ),
                    NavigationRailDestination(
                      icon: AppSvgIcon(svgString: AppSvgIcon.attendance),
                      selectedIcon: AppSvgIcon(svgString: AppSvgIcon.attendance, color: AppColors.wineRed),
                      label: Text('Attendance'),
                    ),
                    NavigationRailDestination(
                      icon: AppSvgIcon(svgString: AppSvgIcon.bell),
                      selectedIcon: AppSvgIcon(svgString: AppSvgIcon.bell, color: AppColors.wineRed),
                      label: Text('Notices'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
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
                BottomNavigationBarItem(
                  icon: AppSvgIcon(svgString: AppSvgIcon.dashboard),
                  activeIcon: AppSvgIcon(svgString: AppSvgIcon.dashboard, color: AppColors.wineRed),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: AppSvgIcon(svgString: AppSvgIcon.calendar),
                  activeIcon: AppSvgIcon(svgString: AppSvgIcon.calendar, color: AppColors.wineRed),
                  label: 'Timetable',
                ),
                BottomNavigationBarItem(
                  icon: AppSvgIcon(svgString: AppSvgIcon.attendance),
                  activeIcon: AppSvgIcon(svgString: AppSvgIcon.attendance, color: AppColors.wineRed),
                  label: 'Attendance',
                ),
                BottomNavigationBarItem(
                  icon: AppSvgIcon(svgString: AppSvgIcon.bell),
                  activeIcon: AppSvgIcon(svgString: AppSvgIcon.bell, color: AppColors.wineRed),
                  label: 'Notices',
                ),
              ],
            ),
    );
  }

  Widget _buildDashboardView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enterprise User Identity Strip
          AnimatedContainer(
            duration: AppTheme.themeAnimationDuration,
            curve: AppTheme.themeAnimationCurve,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.wineRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _currentUser.firstName[0],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _currentUser.fullName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _currentUser.archetype == 'student'
                                  ? AppColors.wineRedSubtle
                                  : AppColors.githubGreenSubtle,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _currentUser.archetype == 'student'
                                    ? AppColors.wineRedBorder
                                    : AppColors.githubGreenBorder,
                              ),
                            ),
                            child: Text(
                              _currentUser.archetype.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _currentUser.archetype == 'student'
                                    ? AppColors.wineRed
                                    : AppColors.githubGreenText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Canonical Handle: ${_currentUser.campusHandle}  |  ${_currentUser.email}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _currentUser.activeScopes.map((scope) {
                          return AnimatedContainer(
                            duration: AppTheme.themeAnimationDuration,
                            curve: AppTheme.themeAnimationCurve,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Text(
                              scope,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Operational Navigation Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Academic Operations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Phase 1 Baseline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final cards = [
                _buildOperationCard(
                  title: 'Academic Timetable',
                  subtitle: 'Daily schedule, lecture slots, and labs',
                  iconSvg: AppSvgIcon.calendar,
                  color: AppColors.wineRed,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _buildOperationCard(
                  title: 'Attendance Ledger',
                  subtitle: 'Offline outbox with idempotent sync',
                  iconSvg: AppSvgIcon.attendance,
                  color: AppColors.githubGreen,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _buildOperationCard(
                  title: 'Targeted Notices',
                  subtitle: 'Scoped department announcements',
                  iconSvg: AppSvgIcon.bell,
                  color: AppColors.statusYellow,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[2]),
                  ],
                );
              }
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 10),
                  cards[1],
                  const SizedBox(height: 10),
                  cards[2],
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Institutional System Specs
          AnimatedContainer(
            duration: AppTheme.themeAnimationDuration,
            curve: AppTheme.themeAnimationCurve,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: AppSvgIcon(
                    svgString: AppSvgIcon.shield,
                    size: 20,
                    color: AppColors.wineRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Offline-First Replication & Scoped RBAC Engine Active',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All attendance, course structures, and schedules cache locally on this device. When offline, all transactions append to the local outbox and sync with cryptographic safety to the Go backend when network reconnects.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          height: 1.4,
                        ),
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

  Widget _buildOperationCard({
    required String title,
    required String subtitle,
    required String iconSvg,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: AppTheme.themeAnimationDuration,
        curve: AppTheme.themeAnimationCurve,
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AppSvgIcon(svgString: iconSvg, size: 16, color: color),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
