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
          Builder(
            builder: (context) {
              final statusBadge = widget.storage.isOnline
                  ? AppColors.greenBadge(isDark)
                  : AppColors.yellowBadge(isDark);
              return AnimatedContainer(
                duration: AppTheme.themeAnimationDuration,
                curve: AppTheme.themeAnimationCurve,
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBadge.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: statusBadge.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSvgIcon(
                      svgString: widget.storage.isOnline ? AppSvgIcon.cloudCheck : AppSvgIcon.cloudOff,
                      size: 13,
                      color: statusBadge.text,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.storage.isOnline ? 'Online Sync' : 'Offline Cache',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusBadge.text,
                      ),
                    ),
                  ],
                ),
              );
            },
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
              dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(8),
              icon: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: AppSvgIcon(svgString: AppSvgIcon.chevronDown, size: 14),
              ),
              items: _personas.map((u) {
                final roleBadge = u.archetype == 'student'
                    ? AppColors.primaryBadge(isDark)
                    : AppColors.greenBadge(isDark);
                return DropdownMenuItem<UserModel>(
                  value: u,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: AppTheme.themeAnimationDuration,
                        curve: AppTheme.themeAnimationCurve,
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: roleBadge.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: roleBadge.border,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          u.firstName[0],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: roleBadge.text,
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
                _CampusSidebar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) => setState(() => _currentIndex = i),
                ),
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
              items: [
                BottomNavigationBarItem(
                  icon: const AppSvgIcon(svgString: AppSvgIcon.dashboard),
                  activeIcon: AppSvgIcon(
                    svgString: AppSvgIcon.dashboard,
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                  ),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: const AppSvgIcon(svgString: AppSvgIcon.calendar),
                  activeIcon: AppSvgIcon(
                    svgString: AppSvgIcon.calendar,
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                  ),
                  label: 'Timetable',
                ),
                BottomNavigationBarItem(
                  icon: const AppSvgIcon(svgString: AppSvgIcon.attendance),
                  activeIcon: AppSvgIcon(
                    svgString: AppSvgIcon.attendance,
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                  ),
                  label: 'Attendance',
                ),
                BottomNavigationBarItem(
                  icon: const AppSvgIcon(svgString: AppSvgIcon.bell),
                  activeIcon: AppSvgIcon(
                    svgString: AppSvgIcon.bell,
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                  ),
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
                          Builder(
                            builder: (context) {
                              final roleBadge = _currentUser.archetype == 'student'
                                  ? AppColors.primaryBadge(isDark)
                                  : AppColors.greenBadge(isDark);
                              return AnimatedContainer(
                                duration: AppTheme.themeAnimationDuration,
                                curve: AppTheme.themeAnimationCurve,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleBadge.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: roleBadge.border,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _currentUser.archetype.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: roleBadge.text,
                                  ),
                                ),
                              );
                            },
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
                          final scopeBadge = AppColors.neutralBadge(isDark);
                          return AnimatedContainer(
                            duration: AppTheme.themeAnimationDuration,
                            curve: AppTheme.themeAnimationCurve,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scopeBadge.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: scopeBadge.border,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              scope,
                              style: TextStyle(
                                fontSize: 11,
                                color: scopeBadge.text,
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
    return _OperationCard(
      title: title,
      subtitle: subtitle,
      iconSvg: iconSvg,
      color: color,
      onTap: onTap,
    );
  }
}

class _CampusSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _CampusSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = const [
      (svg: AppSvgIcon.dashboard, label: 'Dashboard'),
      (svg: AppSvgIcon.calendar, label: 'Timetable'),
      (svg: AppSvgIcon.attendance, label: 'Attendance'),
      (svg: AppSvgIcon.bell, label: 'Notices'),
    ];

    return Container(
      width: 78,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ...List.generate(items.length, (idx) {
            final isSelected = selectedIndex == idx;
            final item = items[idx];

            return _SidebarDestinationItem(
              svg: item.svg,
              label: item.label,
              isSelected: isSelected,
              onTap: () => onDestinationSelected(idx),
            );
          }),
        ],
      ),
    );
  }
}

class _SidebarDestinationItem extends StatefulWidget {
  final String svg;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarDestinationItem({
    required this.svg,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarDestinationItem> createState() => _SidebarDestinationItemState();
}

class _SidebarDestinationItemState extends State<_SidebarDestinationItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fixed outer container for this destination item (78px wide x 66px high)
    // Pre-allocated so active or hover states NEVER push neighboring items!
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 78,
          height: 66,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pill overlay container with rigidly fixed dimensions: 54px x 32px
              AnimatedContainer(
                duration: AppTheme.themeAnimationDuration,
                curve: AppTheme.themeAnimationCurve,
                width: 54,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.wineRed
                      : (_isHovered
                          ? (isDark ? AppColors.darkSurfaceHover : AppColors.lightSurfaceHover)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isSelected
                        ? AppColors.wineRed
                        : (_isHovered
                            ? (isDark ? AppColors.darkBorderHover : AppColors.lightBorderHover)
                            : Colors.transparent),
                    width: 1,
                  ),
                ),
                child: AppSvgIcon(
                  svgString: widget.svg,
                  size: 18,
                  // Within the wine overlay, the icon is PURE BRIGHT WHITE!
                  // When unselected: crisp secondary/muted color
                  color: widget.isSelected
                      ? Colors.white
                      : (_isHovered
                          ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                ),
              ),
              const SizedBox(height: 4),
              // Fixed-height label text
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                  color: widget.isSelected
                      ? (isDark ? Colors.white : AppColors.wineRed)
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String iconSvg;
  final Color color;
  final VoidCallback onTap;

  const _OperationCard({
    required this.title,
    required this.subtitle,
    required this.iconSvg,
    required this.color,
    required this.onTap,
  });

  @override
  State<_OperationCard> createState() => _OperationCardState();
}

class _OperationCardState extends State<_OperationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = _isHovered
        ? (isDark ? AppColors.darkSurfaceHover : AppColors.lightSurfaceHover)
        : (isDark ? AppColors.darkSurface : AppColors.lightSurface);

    final borderColor = _isHovered
        ? (isDark ? AppColors.darkBorderHover : AppColors.lightBorderHover)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.themeAnimationDuration,
          curve: AppTheme.themeAnimationCurve,
          constraints: const BoxConstraints(minHeight: 90),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: 1, // Constant 1px width to prevent layout jitter
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
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: AppSvgIcon(svgString: widget.iconSvg, size: 16, color: widget.color),
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
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
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
      ),
    );
  }
}
