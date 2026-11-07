import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_logo.dart';
import '../widgets/smooth_theme_toggle.dart';
import 'attendance_screen.dart';
import 'department_management_screen.dart';
import 'notices_screen.dart';
import 'timetable_screen.dart';
import 'user_management_screen.dart';
import 'user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;
  final VoidCallback? onLogout;

  const HomeScreen({
    super.key,
    required this.storage,
    this.currentUser,
    this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0};
  final Map<int, Widget> _tabWidgetCache = {};

  late List<UserModel> _personas;
  late UserModel _currentUser;

  void _onDestinationSelected(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
    });
  }

  Widget _buildTab(int index) {
    if (index == _currentIndex) {
      _loadedTabs.add(index);
    }
    if (!_loadedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    if (index == 0) {
      return _buildDashboardView();
    }
    return _tabWidgetCache.putIfAbsent(index, () {
      switch (index) {
        case 1:
          return TimetableScreen(
            key: ValueKey('tab-timetable-${_currentUser.id}'),
            storage: widget.storage,
            activeScope: _currentUser.activeScopes.contains('sec:cse-3a') ? 'sec:cse-3a' : 'global',
            currentUser: _currentUser,
          );
        case 2:
          return AttendanceScreen(
            key: ValueKey('tab-attendance-${_currentUser.id}'),
            storage: widget.storage,
            currentUser: _currentUser,
          );
        case 3:
          return NoticesScreen(
            key: ValueKey('tab-notices-${_currentUser.id}'),
            storage: widget.storage,
            userScopes: _currentUser.activeScopes,
          );
        case 4:
          if (!_currentUser.canManageUsers) {
            return _buildAccessDeniedView(
              moduleName: 'Campus Directory & Identity Management',
              requiredRole: 'Campus Administrator',
              reason: 'Directory administration, identity onboarding, and credential lifecycle revocation require institutional administrator authority.',
            );
          }
          return UserManagementScreen(
            key: ValueKey('tab-users-${_currentUser.id}'),
            storage: widget.storage,
            currentUser: _currentUser,
          );
        case 5:
          if (!_currentUser.canManageDepartments) {
            return _buildAccessDeniedView(
              moduleName: 'Academic Departments & Structure',
              requiredRole: 'Head of Department or Campus Administrator',
              reason: 'Academic structuring, department governance, and faculty workload assignment are restricted to Department Chairs and Institutional Administrators.',
            );
          }
          return DepartmentManagementScreen(
            key: ValueKey('tab-depts-${_currentUser.id}'),
            storage: widget.storage,
            currentUser: _currentUser,
          );
        default:
          return const SizedBox.shrink();
      }
    });
  }

  Widget _buildAccessDeniedView({
    required String moduleName,
    required String requiredRole,
    required String reason,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.statusRedSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.statusRed.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const AppSvgIcon(
                      svgString: AppSvgIcon.lock,
                      size: 22,
                      color: AppColors.statusRed,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Access Restricted',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          moduleName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Persona: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            '${_currentUser.fullName} (${_currentUser.campusHandle})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Required Role: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            requiredRole,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.wineRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      reason,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _onDestinationSelected(0),
                    icon: const AppSvgIcon(svgString: AppSvgIcon.dashboard, size: 14),
                    label: const Text('Back to Dashboard'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    key: const Key('btn-switch-authorized-persona'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wineRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      final target = _personas.firstWhere(
                        (p) => p.isAdmin || (p.isHOD && requiredRole.contains('Head of Department')),
                        orElse: () => _personas.firstWhere((p) => p.isAdmin, orElse: () => _personas.first),
                      );
                      setState(() {
                        _currentUser = target;
                        _tabWidgetCache.clear();
                        _loadedTabs.addAll([0, 1, 2, 3, 4, 5]);
                      });
                      _checkServer();
                    },
                    child: const Text('Switch to Authorized Persona'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _personas = [
      OfflineStorageService.getMockUserForHandle('campus_admin'),
      OfflineStorageService.getMockUserForHandle('priya_2024_emp_1'),
      OfflineStorageService.getMockUserForHandle('harish_2025_l_btech_1'),
      OfflineStorageService.getMockUserForHandle('ramesh_2023_emp_1'),
      OfflineStorageService.getMockUserForHandle('mukesh_2025_ext_1'),
    ];
    final initial = widget.currentUser ??
        _personas.firstWhere(
          (p) => p.campusHandle == 'harish_2025_l_btech_1',
          orElse: () => _personas.first,
        );
    if (!_personas.contains(initial)) {
      _personas.insert(0, initial);
    }
    _currentUser = _personas.firstWhere((p) => p == initial);
    _checkServer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _loadedTabs.addAll([1, 2, 3, 4, 5]);
        });
      }
    });
  }

  void _checkServer() {
    widget.storage.refreshConnectivityAndSync(_currentUser.id).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrWeb = MediaQuery.of(context).size.width >= 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabStack = IndexedStack(
      index: _currentIndex,
      children: List.generate(6, _buildTab),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const AppLogo(height: 40),
        actions: [
          // Connection Status Badge
          Builder(
            builder: (context) {
              final statusBadge = widget.storage.isOnline
                  ? AppColors.greenBadge(isDark)
                  : AppColors.yellowBadge(isDark);
              return Container(
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

          // Smooth Animated Theme Toggle
          const SmoothThemeToggle(),
          const SizedBox(width: 4),

          // User Persona Switcher (Clean Dropdown below anchor)
          PopupMenuButton<UserModel>(
            tooltip: 'Switch Active Persona',
            position: PopupMenuPosition.under,
            offset: const Offset(0, 8),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
            onSelected: (UserModel newUser) {
              setState(() {
                _currentUser = newUser;
                _tabWidgetCache.clear();
                _loadedTabs.addAll([0, 1, 2, 3, 4, 5]);
              });
              _checkServer();
            },
            itemBuilder: (BuildContext context) {
              return _personas.map((u) {
                final isSelected = u.id == _currentUser.id;
                final roleBadge = u.archetype == 'student'
                    ? AppColors.primaryBadge(isDark)
                    : AppColors.greenBadge(isDark);

                return PopupMenuItem<UserModel>(
                  value: u,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? AppColors.wineRedDark.withValues(alpha: 0.25)
                              : AppColors.wineRedSubtle)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: roleBadge.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: roleBadge.border, width: 1),
                          ),
                          child: Text(
                            u.firstName.isNotEmpty ? u.firstName[0] : '?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: roleBadge.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                u.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                '@${u.campusHandle} • ${u.archetype.toUpperCase()}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 10),
                          AppSvgIcon(
                            svgString: AppSvgIcon.check,
                            size: 14,
                            color: isDark ? AppColors.wineRedLight : AppColors.wineRed,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (_currentUser.archetype == 'student'
                              ? AppColors.primaryBadge(isDark)
                              : AppColors.greenBadge(isDark))
                          .background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (_currentUser.archetype == 'student'
                                ? AppColors.primaryBadge(isDark)
                                : AppColors.greenBadge(isDark))
                            .border,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _currentUser.firstName.isNotEmpty ? _currentUser.firstName[0] : '?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (_currentUser.archetype == 'student'
                                ? AppColors.primaryBadge(isDark)
                                : AppColors.greenBadge(isDark))
                            .text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentUser.fullName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  AppSvgIcon(
                    svgString: AppSvgIcon.chevronDown,
                    size: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ],
              ),
            ),
          ),
          if (widget.onLogout != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Sign Out (${_currentUser.campusHandle})',
              icon: const Icon(Icons.logout, size: 18),
              onPressed: () {
                widget.storage.logout();
                widget.onLogout!();
              },
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: isDesktopOrWeb
          ? Row(
              children: [
                _CampusSidebar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  currentUser: _currentUser,
                ),
                Expanded(child: tabStack),
              ],
            )
          : tabStack,
      bottomNavigationBar: isDesktopOrWeb
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onDestinationSelected,
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
                BottomNavigationBarItem(
                  icon: const AppSvgIcon(svgString: AppSvgIcon.user),
                  activeIcon: AppSvgIcon(
                    svgString: AppSvgIcon.user,
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                  ),
                  label: 'Directory',
                ),
                BottomNavigationBarItem(
                  icon: const AppSvgIcon(svgString: AppSvgIcon.building),
                  activeIcon: AppSvgIcon(
                    svgString: AppSvgIcon.building,
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                  ),
                  label: 'Departments',
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
          Container(
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
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            _currentUser.fullName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Builder(
                            builder: (context) {
                              final roleBadge = _currentUser.archetype == 'student'
                                  ? AppColors.primaryBadge(isDark)
                                  : AppColors.greenBadge(isDark);
                              return Container(
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
                          return Container(
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
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                    side: BorderSide(
                      color: isDark ? AppColors.wineRedDarkBorder : AppColors.wineRedBorder,
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const AppSvgIcon(svgString: AppSvgIcon.user, size: 14),
                  label: const Text('View Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          storage: widget.storage,
                          userIdentifier: _currentUser.id,
                          initialUser: _currentUser,
                          currentAdminUser: _currentUser,
                          onUserUpdated: () async {
                            final fresh = await widget.storage.getUserProfile(_currentUser.id);
                            setState(() {
                              _currentUser = fresh;
                              _tabWidgetCache.clear();
                              _loadedTabs.addAll([0, 1, 2, 3, 4, 5]);
                            });
                          },
                        ),
                      ),
                    );
                  },
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
                  onTap: () => _onDestinationSelected(1),
                ),
                _buildOperationCard(
                  title: 'Attendance Ledger',
                  subtitle: 'Offline outbox with idempotent sync',
                  iconSvg: AppSvgIcon.attendance,
                  color: AppColors.githubGreen,
                  onTap: () => _onDestinationSelected(2),
                ),
                _buildOperationCard(
                  title: 'Targeted Notices',
                  subtitle: 'Scoped department announcements',
                  iconSvg: AppSvgIcon.bell,
                  color: AppColors.statusYellow,
                  onTap: () => _onDestinationSelected(3),
                ),
                _buildOperationCard(
                  title: 'Directory & Identities',
                  subtitle: 'Onboarding & lifecycle exit control',
                  iconSvg: AppSvgIcon.user,
                  color: AppColors.wineRed,
                  onTap: () => _onDestinationSelected(4),
                ),
                _buildOperationCard(
                  title: 'Departments & Academics',
                  subtitle: 'Curriculum, faculty allocations, and semesters',
                  iconSvg: AppSvgIcon.building,
                  color: const Color(0xFF0969DA),
                  onTap: () => _onDestinationSelected(5),
                ),
              ];

              if (isWide) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards.map((c) {
                    final cardWidth = (constraints.maxWidth - 36) / 4;
                    return SizedBox(width: cardWidth, child: c);
                  }).toList(),
                );
              }
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 10),
                  cards[1],
                  const SizedBox(height: 10),
                  cards[2],
                  const SizedBox(height: 10),
                  cards[3],
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Institutional System Specs
          Container(
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
  final UserModel currentUser;

  const _CampusSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = const [
      (svg: AppSvgIcon.dashboard, label: 'Dashboard'),
      (svg: AppSvgIcon.calendar, label: 'Timetable'),
      (svg: AppSvgIcon.attendance, label: 'Attendance'),
      (svg: AppSvgIcon.bell, label: 'Notices'),
      (svg: AppSvgIcon.user, label: 'Directory'),
      (svg: AppSvgIcon.building, label: 'Depts'),
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
            final isLocked = (idx == 4 && !currentUser.canManageUsers) ||
                (idx == 5 && !currentUser.canManageDepartments);

            return _SidebarDestinationItem(
              svg: item.svg,
              label: item.label,
              isSelected: isSelected,
              isLocked: isLocked,
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
  final bool isLocked;
  final VoidCallback onTap;

  const _SidebarDestinationItem({
    required this.svg,
    required this.label,
    required this.isSelected,
    this.isLocked = false,
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
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
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
                  if (widget.isLocked)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.statusRed.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: const AppSvgIcon(
                          svgString: AppSvgIcon.lock,
                          size: 9,
                          color: AppColors.statusRed,
                        ),
                      ),
                    ),
                ],
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
        child: Container(
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
