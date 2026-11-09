import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_logo.dart';
import '../widgets/smooth_theme_toggle.dart';
import 'attendance_screen.dart';
import 'complaints_screen.dart';
import 'department_management_screen.dart';
import 'hostel_screen.dart';
import 'mess_screen.dart';
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
  int _slot3PageIndex = 1; // Default to Timetable in dock division 3
  final Set<int> _loadedTabs = {0};
  final Map<int, Widget> _tabWidgetCache = {};

  late List<UserModel> _personas;
  late UserModel _currentUser;

  void _onDestinationSelected(int index) {
    if (index >= 1 && index <= 8) {
      _slot3PageIndex = index;
    }
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
        case 6:
          return HostelScreen(
            key: ValueKey('tab-hostel-${_currentUser.id}'),
            storage: widget.storage,
            currentUser: _currentUser,
          );
        case 7:
          return MessScreen(
            key: ValueKey('tab-mess-${_currentUser.id}'),
            storage: widget.storage,
            currentUser: _currentUser,
          );
        case 8:
          return ComplaintsScreen(
            key: ValueKey('tab-complaints-${_currentUser.id}'),
            storage: widget.storage,
            currentUser: _currentUser,
          );
        case 9:
          return UserProfileScreen(
            key: ValueKey('tab-profile-${_currentUser.id}'),
            storage: widget.storage,
            userIdentifier: _currentUser.id,
            initialUser: _currentUser,
            currentAdminUser: _currentUser,
            showAppBar: false,
            onUserUpdated: () async {
              final updated = await widget.storage.getUserProfile(_currentUser.id);
              if (mounted) {
                setState(() {
                  _currentUser = updated;
                });
              }
            },
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
                        _loadedTabs.addAll([0, 1, 2, 3, 4, 5, 6]);
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
          _loadedTabs.addAll([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        });
      }
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentUser != null && widget.currentUser != oldWidget.currentUser) {
      _currentUser = widget.currentUser!;
      _tabWidgetCache.clear();
      _checkServer();
    }
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
      children: List.generate(10, _buildTab),
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
              final isNarrow = MediaQuery.of(context).size.width <= 600;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 10, vertical: 4),
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
                    if (!isNarrow) ...[
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
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Grievances & Complaints Direct Shortcut
          IconButton(
            key: const Key('appbar-btn-complaints'),
            tooltip: 'Grievances & Complaints',
            icon: const AppSvgIcon(
              svgString: AppSvgIcon.alertTriangle,
              size: 18,
            ),
            onPressed: () => _onDestinationSelected(8),
          ),
          const SizedBox(width: 4),

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
                _loadedTabs.addAll([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
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
                  if (MediaQuery.of(context).size.width > 560) ...[
                    const SizedBox(width: 8),
                    Text(
                      _currentUser.fullName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
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
          : _buildBottomDock(context, isDark),
    );
  }

  // ----------------------------------------------------
  // REDESIGNED 4-DIVISION BOTTOM DOCK
  // 1 = Dashboard (Mandatory)
  // 2 = Profile (Mandatory)
  // 3 = Currently Active Page (Replaced dynamically from 4)
  // 4 = List of Other Pages (3 horizontal lines icon)
  // ----------------------------------------------------

  Widget _buildBottomDock(BuildContext context, bool isDark) {
    final activeSlot3 = _getDockItemForIndex(_slot3PageIndex);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 680),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Division 1: Dashboard (Mandatory)
                Expanded(
                  child: _buildDockDivisionItem(
                    key: const Key('dock-division-dashboard'),
                    label: 'Dashboard',
                    svgIcon: AppSvgIcon.dashboard,
                    isSelected: _currentIndex == 0,
                    isDark: isDark,
                    onTap: () => _onDestinationSelected(0),
                  ),
                ),

                // Division 2: Profile (Mandatory)
                Expanded(
                  child: _buildDockDivisionItem(
                    key: const Key('dock-division-profile'),
                    label: 'Profile',
                    svgIcon: AppSvgIcon.user,
                    isSelected: _currentIndex == 9,
                    isDark: isDark,
                    onTap: () => _onDestinationSelected(9),
                  ),
                ),

                // Division 3: Currently Active Page (Dynamic)
                Expanded(
                  child: _buildDockDivisionItem(
                    key: const Key('dock-division-active-page'),
                    label: activeSlot3.label,
                    svgIcon: activeSlot3.svgIcon,
                    isSelected: _currentIndex == _slot3PageIndex,
                    isDark: isDark,
                    onTap: () => _onDestinationSelected(_slot3PageIndex),
                  ),
                ),

                // Division 4: List of Other Pages (3 horizontal lines)
                Expanded(
                  child: _buildDockDivisionItem(
                    key: const Key('dock-division-more-pages'),
                    label: 'Pages',
                    svgIcon: AppSvgIcon.menu,
                    isSelected: false,
                    isDark: isDark,
                    onTap: () => _showOtherPagesSheet(context, isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDockDivisionItem({
    required Key key,
    required String label,
    required String svgIcon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final inactiveColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 48,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.wineRed : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AppSvgIcon(
                svgString: svgIcon,
                size: 18,
                color: isSelected ? Colors.white : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? (isDark ? Colors.white : AppColors.wineRed) : inactiveColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  ({String label, String svgIcon}) _getDockItemForIndex(int index) {
    switch (index) {
      case 1:
        return (label: 'Timetable', svgIcon: AppSvgIcon.calendar);
      case 2:
        return (label: 'Attendance', svgIcon: AppSvgIcon.attendance);
      case 3:
        return (label: 'Notices', svgIcon: AppSvgIcon.bell);
      case 4:
        return (label: 'Directory', svgIcon: AppSvgIcon.user);
      case 5:
        return (label: 'Depts', svgIcon: AppSvgIcon.building);
      case 6:
        return (label: 'Hostel', svgIcon: AppSvgIcon.bed);
      case 7:
        return (label: 'Mess', svgIcon: AppSvgIcon.utensils);
      case 8:
        return (label: 'Complaints', svgIcon: AppSvgIcon.alertTriangle);
      case 9:
        return (label: 'Profile', svgIcon: AppSvgIcon.user);
      default:
        return (label: 'Timetable', svgIcon: AppSvgIcon.calendar);
    }
  }

  void _showOtherPagesSheet(BuildContext context, bool isDark) {
    final otherPages = [
      (
        index: 1,
        keyName: 'timetable',
        label: 'Timetable',
        subtitle: 'Lectures, labs & weekly class schedule',
        svgIcon: AppSvgIcon.calendar,
        isRestricted: false,
        restrictedRole: null,
      ),
      (
        index: 2,
        keyName: 'attendance',
        label: 'Attendance',
        subtitle: 'Live optical QR broadcast & attendance ledger',
        svgIcon: AppSvgIcon.attendance,
        isRestricted: false,
        restrictedRole: null,
      ),
      (
        index: 3,
        keyName: 'notices',
        label: 'Notices',
        subtitle: 'Targeted institutional bulletins & circulars',
        svgIcon: AppSvgIcon.bell,
        isRestricted: false,
        restrictedRole: null,
      ),
      (
        index: 4,
        keyName: 'directory',
        label: 'Campus Directory',
        subtitle: 'Student, faculty & staff identity onboarding',
        svgIcon: AppSvgIcon.user,
        isRestricted: !_currentUser.canManageUsers,
        restrictedRole: 'Campus Administrator',
      ),
      (
        index: 5,
        keyName: 'departments',
        label: 'Academic Departments',
        subtitle: 'Programs, cross-program sections & lab batches',
        svgIcon: AppSvgIcon.building,
        isRestricted: !_currentUser.canManageDepartments,
        restrictedRole: 'HOD / Admin',
      ),
      (
        index: 6,
        keyName: 'hostel',
        label: 'Hostel Management',
        subtitle: 'Room inventory, verified fixtures & occupants',
        svgIcon: AppSvgIcon.bed,
        isRestricted: false,
        restrictedRole: null,
      ),
      (
        index: 7,
        keyName: 'mess',
        label: 'Hostel Mess & Ratings',
        subtitle: 'Weekly menu timetable & feedback reports',
        svgIcon: AppSvgIcon.utensils,
        isRestricted: false,
        restrictedRole: null,
      ),
      (
        index: 8,
        keyName: 'complaints',
        label: 'Grievances & Complaints',
        subtitle: 'Lodge & track verified or anonymous complaints',
        svgIcon: AppSvgIcon.alertTriangle,
        isRestricted: false,
        restrictedRole: null,
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              maxWidth: 620,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.wineRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const AppSvgIcon(
                          svgString: AppSvgIcon.menu,
                          size: 16,
                          color: AppColors.wineRed,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Campus Pages & Modules',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Select a page to open and replace in dock division 3',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: otherPages.map((item) {
                        final isCurrentInSlot3 = _slot3PageIndex == item.index;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: ListTile(
                            key: Key('dock-menu-item-${item.keyName}'),
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            tileColor: isCurrentInSlot3
                                ? (isDark ? const Color(0xFF261D1D) : const Color(0xFFFFF0F2))
                                : null,
                            leading: Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isCurrentInSlot3
                                    ? AppColors.wineRed
                                    : (isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AppSvgIcon(
                                svgString: item.svgIcon,
                                size: 15,
                                color: isCurrentInSlot3
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                            ),
                            title: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isCurrentInSlot3 ? FontWeight.bold : FontWeight.w600,
                                color: isCurrentInSlot3 ? AppColors.wineRed : null,
                              ),
                            ),
                            subtitle: Text(
                              item.isRestricted && item.restrictedRole != null
                                  ? 'Requires ${item.restrictedRole}'
                                  : item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: item.isRestricted
                                    ? const Color(0xFFD97706)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.isRestricted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF3B2616) : const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFFD97706) : const Color(0xFFFDBA74),
                                      ),
                                    ),
                                    child: const Icon(Icons.lock_outline, size: 12, color: Color(0xFFD97706)),
                                  )
                                else if (isCurrentInSlot3)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.wineRed.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.wineRed,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _slot3PageIndex = item.index;
                              });
                              _onDestinationSelected(item.index);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getPersonaCategory(UserModel user) {
    if (user.isAdmin) return 'admin';
    if (user.isWarden) return 'warden';
    if (user.isMessManager) return 'mess';
    if (user.isFaculty || user.isHOD) return 'faculty';
    if (user.isStudent) return 'student';
    if (user.isContractor) return 'contractor';
    return 'student';
  }

  String _getPersonalizedBannerSubtitle(UserModel user) {
    if (user.isAdmin) {
      return 'Institutional Operations & Leadership • Campus Director';
    }
    if (user.isWarden) {
      return 'Campus Residential Services • Chief Hostel Warden • Gate 1 Office';
    }
    if (user.isMessManager) {
      return 'Dining & Catering Operations • Central Campus Canteen & Mess';
    }
    if (user.isFaculty || user.isHOD) {
      final deptScope = user.activeScopes.firstWhere(
        (s) => s.startsWith('dept:'),
        orElse: () => 'dept:cse',
      );
      final deptName = deptScope.replaceFirst('dept:', '').toUpperCase();
      final title = user.isHOD ? 'Head of Department & Faculty' : 'Faculty Member';
      return 'Department of $deptName • $title • Cabin: CS-304';
    }
    if (user.isStudent) {
      final secScope = user.sectionScope ??
          user.activeScopes.firstWhere((s) => s.startsWith('sec:'), orElse: () => 'sec:cse-3a');
      final secName = secScope.replaceFirst('sec:', '').toUpperCase();
      final sem = user.currentSemester ?? 3;
      final roll = (user.universityRollNo?.isNotEmpty == true) ? user.universityRollNo! : '2025-CS-042';
      return 'B.Tech Computer Science • Semester $sem • Section $secName • Roll: $roll';
    }
    if (user.isContractor) {
      final org = user.vendorOrganization ?? 'External Contractor Services';
      final pass = user.gatePassId ?? 'GP-2025-0891';
      return '$org • Gate Pass: $pass • Authorized Contractor';
    }
    return user.email;
  }

  String _getMetricHeaderTitle(String persona) {
    switch (persona) {
      case 'student':
        return 'Student Academic Vitals';
      case 'faculty':
        return 'Instructional & Department Vitals';
      case 'warden':
        return 'Housing & Residential Vitals';
      case 'mess':
        return 'Dining & Food Service Vitals';
      case 'contractor':
        return 'Facility Access & Vendor Vitals';
      case 'admin':
      default:
        return 'Institutional Vital Indicators';
    }
  }

  String _getMetricHeaderBadge(String persona) {
    switch (persona) {
      case 'student':
        return 'Active Semester CSE-3A';
      case 'faculty':
        return 'Faculty & Department Chair';
      case 'warden':
        return 'Hostel Residential Oversight';
      case 'mess':
        return 'Central Canteen Operations';
      case 'contractor':
        return 'Authorized Vendor Service';
      case 'admin':
      default:
        return 'Campus Executive Governance';
    }
  }

  Widget _buildDashboardView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final persona = _getPersonaCategory(_currentUser);
    final greeting = _getTimeGreeting();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enterprise User Identity Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 560;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.wineRed,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            _currentUser.firstName.isNotEmpty ? _currentUser.firstName[0] : '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                    '$greeting, ${_currentUser.firstName}!',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: roleBadge.text,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getPersonalizedBannerSubtitle(_currentUser),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${_currentUser.campusHandle} • ${_currentUser.email}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (!isNarrow) ...[
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
                                      if (mounted) {
                                        setState(() {
                                          _currentUser = fresh;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    if (_currentUser.activeScopes.isNotEmpty) ...[
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
                                fontSize: 10,
                                color: scopeBadge.text,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ----------------------------------------------------
          // LIVE PERSONALIZED ROLE METRICS (4 CARDS)
          // ----------------------------------------------------
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                _getMetricHeaderTitle(persona),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                _getMetricHeaderBadge(persona),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          _buildPersonalizedMetrics(context, isDark, persona),

          const SizedBox(height: 16),

          // ----------------------------------------------------
          // PERSONALIZED OPERATIONS CARDS (Academic Operations)
          // ----------------------------------------------------
          _buildPersonalizedOperations(context, isDark, persona),

          const SizedBox(height: 16),

          // ----------------------------------------------------
          // ROLE-SPECIFIC SPECIALIZED PANELS
          // ----------------------------------------------------
          _buildPersonalizedPanels(context, isDark, persona),

          const SizedBox(height: 16),

          // Institutional System Specs & Sync Health
          _buildSystemSpecsBanner(context, isDark, persona),
        ],
      ),
    );
  }

  Widget _buildSystemSpecsBanner(BuildContext context, bool isDark, String persona) {
    final String title;
    final String description;
    final String iconSvg;
    final Color iconColor;

    switch (persona) {
      case 'student':
        title = 'Student Campus Support & Offline Ledger';
        description = 'All timetables, attendance sync outbox, and room information cache offline on this device. Campus Emergency: Ext 1001 (Dial 108) • Biometric Gate 1 Curfew 22:30 IST.';
        iconSvg = AppSvgIcon.shield;
        iconColor = AppColors.wineRed;
        break;

      case 'faculty':
        title = 'Academic Integrity & Offline Ledger Synchronization';
        description = 'All optical QR broadcast sessions, attendance ledgers, and department curriculum cache locally. Student scan confirmations append to local outbox and synchronize automatically.';
        iconSvg = AppSvgIcon.attendance;
        iconColor = AppColors.githubGreen;
        break;

      case 'warden':
        title = 'Residential Security & Caretaker Emergency Desk';
        description = 'Turnstile entry records, resident room allocations, and fixture audits synchronize with Go backend. Chief Warden Office: Ext 2401 • Campus Health Center: Ext 1001 • Gate 1 Biometrics Active.';
        iconSvg = AppSvgIcon.shield;
        iconColor = AppColors.wineRed;
        break;

      case 'mess':
        title = 'Food Hygiene & Kitchen Quality Compliance';
        description = 'Central campus catering operates under standard hygiene protocols. Central RO + UV cooler station verified. Compulsory student feedback required on all ratings under 3 stars.';
        iconSvg = AppSvgIcon.utensils;
        iconColor = const Color(0xFF2DA44E);
        break;

      case 'admin':
      default:
        title = 'Offline-First Replication & Scoped RBAC Engine Active';
        description = 'All attendance records, course structures, and schedules cache locally on this device. When offline, all transactions append to the local outbox and sync with cryptographic safety to the Go backend when network reconnects.';
        iconSvg = AppSvgIcon.shield;
        iconColor = AppColors.wineRed;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppSvgIcon(
              svgString: iconSvg,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedPanels(BuildContext context, bool isDark, String persona) {
    final Widget panel1;
    final Widget panel2;

    switch (persona) {
      case 'student':
        panel1 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Upcoming Academic Session',
          badgeText: 'UPCOMING LECTURE',
          badgeColor: AppColors.wineRed,
          actionLabel: 'Open Timetable',
          onAction: () => _onDestinationSelected(1),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CS301: Operating Systems (09:00 - 10:00 AM)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Lecture Hall LH-101 • Faculty: Dr. Priya Nair',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Optical QR token session will be broadcast at start of lecture for roll-call verification.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        );
        panel2 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Residential Hall & Dining',
          badgeText: 'ROOM 108',
          badgeColor: const Color(0xFFD97706),
          actionLabel: 'Rate Recent Meal',
          onAction: () => _onDestinationSelected(7),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aryabhatta Hall • Floor 1 • Curfew 22:30 IST Gate 1',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Central Mess Dinner: Paneer Butter Masala, Dal Makhani, Tandoori Roti (20:00 - 21:30)',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sunday Schedule: Brunch (10:00 - 12:30) and Dinner (20:00 - 21:30) only.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        );
        break;

      case 'faculty':
        panel1 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Optical Attendance Studio',
          badgeText: 'OPTICAL ATTENDANCE STUDIO',
          badgeColor: AppColors.githubGreen,
          actionLabel: 'Launch Attendance',
          onAction: () => _onDestinationSelected(2),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Course: CS301 Operating Systems • Section CSE-3A',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '64 Registered Students • Venue: Lecture Hall LH-101',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Optical rotating QR code refreshes every 4s with rolling cryptographic signatures preventing proxy check-ins.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        );
        panel2 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: "Today's Teaching Schedule",
          badgeText: '3 SESSIONS',
          badgeColor: AppColors.wineRed,
          actionLabel: 'View Timetable',
          onAction: () => _onDestinationSelected(1),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '09:00 - 10:00 AM • CS301 Operating Systems (LH-101)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              const Text(
                '11:00 - 12:00 PM • CS302 Database Systems (LH-102)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              const Text(
                '02:00 - 04:00 PM • CS303 OS Practical Lab (Lab 2 - Batches A1, A2)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
        break;

      case 'warden':
        panel1 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Residential Curfew Protocol',
          badgeText: 'RESIDENTIAL PROTOCOL',
          badgeColor: AppColors.wineRed,
          actionLabel: 'Inspect Rooms',
          onAction: () => _onDestinationSelected(6),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gate 1 Biometric Verification & Turnstile Protocol',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'All resident students must scan through Gate 1 turnstiles by 22:30 IST sharp.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Night Out Passes require portal submission 6 hours prior to departure. Quiet hours: 23:00 - 06:00 across all wings.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        );
        panel2 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Hostel Maintenance Queue',
          badgeText: '3 OPEN TICKETS',
          badgeColor: const Color(0xFFD97706),
          actionLabel: 'Manage Maintenance',
          onAction: () => _onDestinationSelected(8),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Room 108: Tubelight flickering (SN: TL-108-01) - Inspected',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              const Text(
                'Room 204: Low water pressure on Floor 2 central cooler - Work ordered',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              const Text(
                'Room 312: Steel locker key replacement request - Pending inspection',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'All 16 room assets tagged with 14-char institutional serial numbers.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        );
        break;

      case 'mess':
        panel1 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: "Today's Complete Meal Menu",
          badgeText: 'CENTRAL MESS BOARD',
          badgeColor: const Color(0xFF2DA44E),
          actionLabel: 'Edit Weekly Menu',
          onAction: () => _onDestinationSelected(7),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Breakfast (07:30 - 09:00): Idli Sambar, Upma, Coconut Chutney, Tea/Coffee',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              const Text(
                'Lunch (12:30 - 14:00): Rajma Masala, Steamed Rice, Phulka, Curd, Salad',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              const Text(
                'Snacks (17:00 - 18:30): Crispy Veg Cutlet, Green Mint Chutney, Masala Chai',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              const Text(
                'Dinner (20:00 - 21:30): Paneer Butter Masala, Dal Makhani, Roti, Gulab Jamun',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
        panel2 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Food Quality Meter & Feedback',
          badgeText: 'SUNDAY TIMETABLE CONSTRAINT',
          badgeColor: const Color(0xFF0969DA),
          actionLabel: 'Inspect Rating Reports',
          onAction: () => _onDestinationSelected(7),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Student Satisfaction: 68% 5-Star • 22% 4-Star • 10% Sub-3-Star',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Compulsory Explanation Rule: Any student rating under 3 stars must provide detailed corrective remarks.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sunday Schedule: Brunch (10:00 - 12:30) & Dinner (20:00 - 21:30) only. Breakfast and Lunch are not scheduled on Sundays.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        );
        break;

      case 'contractor':
        panel1 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Gate Pass Verification & Facility Access',
          badgeText: 'AUTHORIZED VENDOR',
          badgeColor: AppColors.githubGreen,
          actionLabel: 'View Profile',
          onAction: () => _onDestinationSelected(9),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active Biometric Gate Pass • Main Gate & Gate 1 Authorization',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Authorized Building Scopes: Canteen Building, Kitchen Facilities & Main Gate Turnstiles.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        );
        panel2 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Campus Facility Maintenance Windows',
          badgeText: 'SERVICE HOURS',
          badgeColor: const Color(0xFF2DA44E),
          actionLabel: 'Mess Timetable',
          onAction: () => _onDestinationSelected(7),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Morning Service Window: 06:00 - 08:30 (Pre-Lecture Servicing)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              const Text(
                'Evening Service Window: 17:30 - 20:00 (Post-Lecture Maintenance)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
        break;

      case 'admin':
      default:
        panel1 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Institutional Redressal & Grievances SLA',
          badgeText: 'DISTRIBUTED SYSTEM HEALTH',
          badgeColor: AppColors.statusRed,
          actionLabel: 'Open Redressal Center',
          onAction: () => _onDestinationSelected(8),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Triage: 3 Pending Review • 5 Under Investigation • 6 Resolved',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Categories: Hostel (5) • Student Welfare (4) • Canteen (3) • Campus Facilities (2)',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SLA Compliance: 88% resolved within mandated 24-hour institutional resolution policy.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        );
        panel2 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Academic Structure & Department Chairs',
          badgeText: '6 DEPTS ACTIVE',
          badgeColor: const Color(0xFF0969DA),
          actionLabel: 'Manage Departments',
          onAction: () => _onDestinationSelected(5),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CSE: 28 Faculty • 4 Degree Programs • HOD: Dr. Priya Nair',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              const Text(
                'ECE: 22 Faculty • 3 Degree Programs • 480 Students',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              const Text(
                'Mechanical: 18 Faculty • 3 Degree Programs • 360 Students',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 750) {
          final cardWidth = (constraints.maxWidth - 16) / 2;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: cardWidth, child: panel1),
              const SizedBox(width: 16),
              SizedBox(width: cardWidth, child: panel2),
            ],
          );
        }
        return Column(
          children: [
            panel1,
            const SizedBox(height: 12),
            panel2,
          ],
        );
      },
    );
  }

  Widget _buildDashboardPanel({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Widget content,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          content,
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: badgeColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.arrow_forward, size: 13),
                label: Text(actionLabel, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalizedMetrics(BuildContext context, bool isDark, String persona) {
    final List<_DashboardMetricCard> metrics;

    switch (persona) {
      case 'student':
        metrics = [
          _DashboardMetricCard(
            title: 'Attendance Health',
            value: '82.4%',
            subtitle: 'Safe • >75% Mandatory Margin',
            iconSvg: AppSvgIcon.attendance,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(2),
          ),
          _DashboardMetricCard(
            title: "Today's Schedule",
            value: '5 Sessions',
            subtitle: '4 Lectures & 1 Practical Lab',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(1),
          ),
          _DashboardMetricCard(
            title: 'Hostel Residence',
            value: 'Room 108',
            subtitle: 'Floor 1 • Curfew 22:30 IST',
            iconSvg: AppSvgIcon.bed,
            color: const Color(0xFFD97706),
            onTap: () => _onDestinationSelected(6),
          ),
          _DashboardMetricCard(
            title: 'Mess Schedule',
            value: 'Active Menu',
            subtitle: '6 Days + Sunday Brunch (10:00-12:30)',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
        ];
        break;

      case 'faculty':
        metrics = [
          _DashboardMetricCard(
            title: 'Teaching Load',
            value: '3 Classes Today',
            subtitle: 'CS301 (09:00), CS302 Lab (14:00)',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(1),
          ),
          _DashboardMetricCard(
            title: 'Optical Attendance',
            value: 'Ready to Roll',
            subtitle: '1-Tap Rolling QR Broadcast',
            iconSvg: AppSvgIcon.attendance,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(2),
          ),
          _DashboardMetricCard(
            title: 'Department Stats',
            value: '28 Faculty',
            subtitle: '4 Degree Programs • CSE Dept',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(5),
          ),
          _DashboardMetricCard(
            title: 'Student Grievances',
            value: 'Academic Inbox',
            subtitle: 'Course & Practical Inquiries',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
        ];
        break;

      case 'warden':
        metrics = [
          _DashboardMetricCard(
            title: 'Hostel Occupancy',
            value: '94% Occupancy',
            subtitle: '142 / 150 Rooms Allotted',
            iconSvg: AppSvgIcon.bed,
            color: const Color(0xFFD97706),
            onTap: () => _onDestinationSelected(6),
          ),
          _DashboardMetricCard(
            title: 'Night Curfew',
            value: '22:30 IST',
            subtitle: 'Gate 1 Biometric Verification',
            iconSvg: AppSvgIcon.shield,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(6),
          ),
          _DashboardMetricCard(
            title: 'Fixture Inventory',
            value: '16 Items Monitored',
            subtitle: '14-Char Serial Asset Tracking',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(6),
          ),
          _DashboardMetricCard(
            title: 'Hostel Redressal',
            value: 'Maintenance Queue',
            subtitle: 'Plumbing, Electric & Fixtures',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
        ];
        break;

      case 'mess':
        metrics = [
          _DashboardMetricCard(
            title: 'Meal Timetable',
            value: '6 Days + Sunday',
            subtitle: 'Sunday Brunch (10:00 - 12:30)',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
          _DashboardMetricCard(
            title: 'Average Rating',
            value: '4.2 / 5.0 Stars',
            subtitle: 'Mandatory Reviews < 3 Stars',
            iconSvg: AppSvgIcon.attendance,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(7),
          ),
          _DashboardMetricCard(
            title: 'Service Schedule',
            value: 'Standard Timetable',
            subtitle: 'Breakfast, Lunch, Snacks, Dinner',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(7),
          ),
          _DashboardMetricCard(
            title: 'Catering Feedback',
            value: 'Quality Redressal',
            subtitle: 'Hygiene & Meal Feedback',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
        ];
        break;

      case 'contractor':
        metrics = [
          _DashboardMetricCard(
            title: 'Gate Pass Status',
            value: 'Active Verified',
            subtitle: 'Gate 1 & Main Gate Authorized',
            iconSvg: AppSvgIcon.shield,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(9),
          ),
          _DashboardMetricCard(
            title: 'Facility Scopes',
            value: 'Assigned Areas',
            subtitle: 'Canteen & Main Campus Buildings',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(9),
          ),
          _DashboardMetricCard(
            title: 'Mess Schedule',
            value: 'Canteen Access',
            subtitle: 'Dining Timetable & Menu Access',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
          _DashboardMetricCard(
            title: 'Vendor Redressal',
            value: 'Contractor Issues',
            subtitle: 'Facility & Billing Inquiries',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
        ];
        break;

      case 'admin':
      default:
        metrics = [
          _DashboardMetricCard(
            title: 'Campus Directory',
            value: '1,420 Identities',
            subtitle: 'Students, Staff & Contractors',
            iconSvg: AppSvgIcon.user,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(4),
          ),
          _DashboardMetricCard(
            title: 'Academic Structure',
            value: '6 Departments',
            subtitle: '18 Degree Programs & Sections',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(5),
          ),
          _DashboardMetricCard(
            title: 'Institutional Redressal',
            value: '5 Categories',
            subtitle: 'Student, Staff, Hostel, Campus',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
          _DashboardMetricCard(
            title: 'Offline Sync Engine',
            value: '100% Operational',
            subtitle: 'Cryptographic Outbox Active',
            iconSvg: AppSvgIcon.shield,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(2),
          ),
        ];
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= 620) {
          final cardWidth = (width - 36) / 4;
          return Row(
            children: [
              for (int i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                SizedBox(width: cardWidth, child: metrics[i]),
              ],
            ],
          );
        } else if (width >= 420) {
          final cardWidth = (width - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            children: metrics.map((m) => SizedBox(width: cardWidth, child: m)).toList(),
          );
        } else {
          return Column(
            children: [
              for (int i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                metrics[i],
              ],
            ],
          );
        }
      },
    );
  }

  Widget _buildPersonalizedOperations(BuildContext context, bool isDark, String persona) {
    final String personaLabel;
    final List<Widget> cards;

    switch (persona) {
      case 'student':
        personaLabel = 'Student Campus Hub';
        cards = [
          _buildOperationCard(
            title: 'Academic Timetable',
            subtitle: 'My daily schedule, lecture slots, and lab batches',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(1),
          ),
          _buildOperationCard(
            title: 'Attendance Ledger',
            subtitle: 'Live optical QR roll-call & 30-day course status',
            iconSvg: AppSvgIcon.attendance,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(2),
          ),
          _buildOperationCard(
            title: 'Targeted Notices',
            subtitle: 'Section CSE-3A circulars & club bulletins',
            iconSvg: AppSvgIcon.bell,
            color: AppColors.statusYellow,
            onTap: () => _onDestinationSelected(3),
          ),
          _buildOperationCard(
            title: 'Directory & Identities',
            subtitle: 'Campus directory & faculty advisor contact',
            iconSvg: AppSvgIcon.user,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(4),
          ),
          _buildOperationCard(
            title: 'Departments & Academics',
            subtitle: 'B.Tech CSE curriculum, syllabus & course outlines',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(5),
          ),
          _buildOperationCard(
            title: 'Hostel Rooms',
            subtitle: 'Room 108, roommates & verified asset inventory',
            iconSvg: AppSvgIcon.bed,
            color: const Color(0xFFD97706),
            onTap: () => _onDestinationSelected(6),
          ),
          _buildOperationCard(
            title: 'Hostel Mess & Feedback',
            subtitle: 'Weekly menu, Sunday brunch & meal ratings',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
          _buildOperationCard(
            key: const Key('card-quick-complaints'),
            title: 'Grievances & Redressal',
            subtitle: 'Official complaints, hostel maintenance & anonymous reporting',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
        ];
        break;

      case 'faculty':
        personaLabel = 'Academic & Instructional Governance';
        cards = [
          _buildOperationCard(
            title: 'Attendance Ledger',
            subtitle: 'Launch rotating QR broadcast for Section CSE-3A',
            iconSvg: AppSvgIcon.attendance,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(2),
          ),
          _buildOperationCard(
            title: 'Academic Timetable',
            subtitle: 'My lecture slots, laboratory batches & room assignments',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(1),
          ),
          _buildOperationCard(
            title: 'Departments & Academics',
            subtitle: 'Programs, syllabus audit trail & faculty workload',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(5),
          ),
          _buildOperationCard(
            title: 'Targeted Notices',
            subtitle: 'Scoped department announcements & bulletins',
            iconSvg: AppSvgIcon.bell,
            color: AppColors.statusYellow,
            onTap: () => _onDestinationSelected(3),
          ),
          _buildOperationCard(
            key: const Key('card-quick-complaints'),
            title: 'Grievances & Redressal',
            subtitle: 'Review escalated academic complaints & student feedback',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
          _buildOperationCard(
            title: 'Directory & Identities',
            subtitle: 'Student roll numbers, faculty & staff directory',
            iconSvg: AppSvgIcon.user,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(4),
          ),
          _buildOperationCard(
            title: 'Hostel Rooms',
            subtitle: 'Hostel inventory & student resident information',
            iconSvg: AppSvgIcon.bed,
            color: const Color(0xFFD97706),
            onTap: () => _onDestinationSelected(6),
          ),
          _buildOperationCard(
            title: 'Hostel Mess & Feedback',
            subtitle: 'Weekly dining menu & student food quality ratings',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
        ];
        break;

      case 'warden':
        personaLabel = 'Residential Life & Facility Controls';
        cards = [
          _buildOperationCard(
            title: 'Hostel Rooms',
            subtitle: 'Inspect rooms 100-999, edit fixtures & manage occupants',
            iconSvg: AppSvgIcon.bed,
            color: const Color(0xFFD97706),
            onTap: () => _onDestinationSelected(6),
          ),
          _buildOperationCard(
            key: const Key('card-quick-complaints'),
            title: 'Grievances & Redressal',
            subtitle: 'Address plumbing, electrical & asset maintenance tickets',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
          _buildOperationCard(
            title: 'Hostel Mess & Feedback',
            subtitle: 'Inspect food ratings, weekly menu & Sunday brunch',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
          _buildOperationCard(
            title: 'Targeted Notices',
            subtitle: 'Post curfew advisories, maintenance notices & inspections',
            iconSvg: AppSvgIcon.bell,
            color: AppColors.statusYellow,
            onTap: () => _onDestinationSelected(3),
          ),
          _buildOperationCard(
            title: 'Directory & Identities',
            subtitle: 'Occupant student records, roll numbers & emergency contacts',
            iconSvg: AppSvgIcon.user,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(4),
          ),
          _buildOperationCard(
            title: 'Academic Timetable',
            subtitle: 'Check student class timings for gate pass clearance',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(1),
          ),
          _buildOperationCard(
            title: 'Departments & Academics',
            subtitle: 'Departmental directory & faculty liaison roster',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(5),
          ),
          _buildOperationCard(
            title: 'Attendance Ledger',
            subtitle: 'Campus attendance ledgers & night curfews',
            iconSvg: AppSvgIcon.attendance,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(2),
          ),
        ];
        break;

      case 'mess':
        personaLabel = 'Dining Operations & Quality Assurance';
        cards = [
          _buildOperationCard(
            title: 'Hostel Mess & Feedback',
            subtitle: 'Edit daily breakfast, lunch, snacks & dinner timetable',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
          _buildOperationCard(
            key: const Key('card-quick-complaints'),
            title: 'Grievances & Redressal',
            subtitle: 'Resolve meal quality, hygiene & contractor tickets',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
          _buildOperationCard(
            title: 'Targeted Notices',
            subtitle: 'Publish feast schedules & special menu notices',
            iconSvg: AppSvgIcon.bell,
            color: AppColors.statusYellow,
            onTap: () => _onDestinationSelected(3),
          ),
          _buildOperationCard(
            title: 'Academic Timetable',
            subtitle: 'Monitor lecture timings to prepare meal serving volumes',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(1),
          ),
          _buildOperationCard(
            title: 'Directory & Identities',
            subtitle: 'Staff roster & catering personnel identity directory',
            iconSvg: AppSvgIcon.user,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(4),
          ),
          _buildOperationCard(
            title: 'Hostel Rooms',
            subtitle: 'Resident boarders & meal plan allocations',
            iconSvg: AppSvgIcon.bed,
            color: const Color(0xFFD97706),
            onTap: () => _onDestinationSelected(6),
          ),
          _buildOperationCard(
            title: 'Departments & Academics',
            subtitle: 'Academic calendar & institutional events',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(5),
          ),
          _buildOperationCard(
            title: 'Attendance Ledger',
            subtitle: 'Catering staff logs & attendance ledgers',
            iconSvg: AppSvgIcon.attendance,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(2),
          ),
        ];
        break;

      case 'contractor':
        personaLabel = 'Vendor Operations & Facility Access';
        cards = [
          _buildOperationCard(
            title: 'Hostel Mess & Feedback',
            subtitle: 'Dining timetable & catering operations',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
          _buildOperationCard(
            key: const Key('card-quick-complaints'),
            title: 'Grievances & Redressal',
            subtitle: 'Submit contractor tickets & facility maintenance',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
          _buildOperationCard(
            title: 'Targeted Notices',
            subtitle: 'Gate security alerts & operational updates',
            iconSvg: AppSvgIcon.bell,
            color: AppColors.statusYellow,
            onTap: () => _onDestinationSelected(3),
          ),
          _buildOperationCard(
            title: 'Directory & Identities',
            subtitle: 'Authorized facilities & contract validation',
            iconSvg: AppSvgIcon.user,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(9),
          ),
          _buildOperationCard(
            title: 'Academic Timetable',
            subtitle: 'Campus schedule & building access hours',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(1),
          ),
          _buildOperationCard(
            title: 'Hostel Rooms',
            subtitle: 'Assigned facility maintenance areas',
            iconSvg: AppSvgIcon.bed,
            color: const Color(0xFFD97706),
            onTap: () => _onDestinationSelected(6),
          ),
          _buildOperationCard(
            title: 'Departments & Academics',
            subtitle: 'Campus building structure & departmental wings',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(5),
          ),
          _buildOperationCard(
            title: 'Attendance Ledger',
            subtitle: 'Contractor gate check-in & duty ledger',
            iconSvg: AppSvgIcon.attendance,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(2),
          ),
        ];
        break;

      case 'admin':
      default:
        personaLabel = 'Executive Administration & Governance';
        cards = [
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
          _buildOperationCard(
            key: const Key('card-quick-complaints'),
            title: 'Grievances & Redressal',
            subtitle: 'Official complaints, hostel maintenance & anonymous reporting',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
          _buildOperationCard(
            title: 'Academic Timetable',
            subtitle: 'Daily schedule, lecture slots, and labs',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(1),
          ),
          _buildOperationCard(
            title: 'Hostel Rooms',
            subtitle: 'Rooms 100-999, fixture inventory & allotments',
            iconSvg: AppSvgIcon.bed,
            color: const Color(0xFFD97706),
            onTap: () => _onDestinationSelected(6),
          ),
          _buildOperationCard(
            title: 'Hostel Mess & Feedback',
            subtitle: 'Weekly menu, Sunday brunch & meal ratings',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
          _buildOperationCard(
            title: 'Targeted Notices',
            subtitle: 'Scoped department announcements',
            iconSvg: AppSvgIcon.bell,
            color: AppColors.statusYellow,
            onTap: () => _onDestinationSelected(3),
          ),
          _buildOperationCard(
            title: 'Attendance Ledger',
            subtitle: 'Offline outbox with idempotent sync',
            iconSvg: AppSvgIcon.attendance,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(2),
          ),
        ];
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Text(
              'Academic Operations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              personaLabel,
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
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  cards[i],
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOperationCard({
    Key? key,
    required String title,
    required String subtitle,
    required String iconSvg,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _OperationCard(
      key: key,
      title: title,
      subtitle: subtitle,
      iconSvg: iconSvg,
      color: color,
      onTap: onTap,
    );
  }
}

class _DashboardMetricCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final String iconSvg;
  final Color color;
  final VoidCallback onTap;

  const _DashboardMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.iconSvg,
    required this.color,
    required this.onTap,
  });

  @override
  State<_DashboardMetricCard> createState() => _DashboardMetricCardState();
}

class _DashboardMetricCardState extends State<_DashboardMetricCard> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: AppSvgIcon(
                      svgString: widget.iconSvg,
                      size: 14,
                      color: widget.color,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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

class _CampusSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final UserModel currentUser;

  const _CampusSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.currentUser,
  });

  @override
  State<_CampusSidebar> createState() => _CampusSidebarState();
}

class _CampusSidebarState extends State<_CampusSidebar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      (svg: AppSvgIcon.bed, label: 'Hostel'),
      (svg: AppSvgIcon.utensils, label: 'Mess'),
      (svg: AppSvgIcon.alertTriangle, label: 'Complaints'),
      (svg: AppSvgIcon.user, label: 'Profile'),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;
          final verticalPadding = totalHeight < 560 ? 4.0 : 8.0;
          final availableHeight = totalHeight - (verticalPadding * 2);
          final idealItemHeight = availableHeight / items.length;
          final itemHeight = idealItemHeight.clamp(42.0, 66.0);

          return Scrollbar(
            controller: _scrollController,
            thumbVisibility: false,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: verticalPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(items.length, (idx) {
                    final isSelected = widget.selectedIndex == idx;
                    final item = items[idx];
                    final isLocked = (idx == 4 && !widget.currentUser.canManageUsers) ||
                        (idx == 5 && !widget.currentUser.canManageDepartments);

                    return _SidebarDestinationItem(
                      key: Key('nav-item-${item.label.toLowerCase()}'),
                      svg: item.svg,
                      label: item.label,
                      isSelected: isSelected,
                      isLocked: isLocked,
                      itemHeight: itemHeight,
                      onTap: () => widget.onDestinationSelected(idx),
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SidebarDestinationItem extends StatefulWidget {
  final String svg;
  final String label;
  final bool isSelected;
  final bool isLocked;
  final double itemHeight;
  final VoidCallback onTap;

  const _SidebarDestinationItem({
    super.key,
    required this.svg,
    required this.label,
    required this.isSelected,
    this.isLocked = false,
    this.itemHeight = 66.0,
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
    final h = widget.itemHeight;

    final double iconBoxWidth = (h >= 58) ? 52.0 : (h >= 48 ? 46.0 : 40.0);
    final double iconBoxHeight = (h >= 58) ? 30.0 : (h >= 48 ? 26.0 : 22.0);
    final double iconSize = (h >= 58) ? 18.0 : (h >= 48 ? 16.0 : 14.0);
    final double spacing = (h >= 56) ? 3.0 : 2.0;
    final double fontSize = (h >= 58) ? 11.0 : (h >= 48 ? 10.0 : 9.0);

    return Tooltip(
      message: widget.isLocked ? '${widget.label} (Restricted)' : widget.label,
      waitDuration: const Duration(milliseconds: 350),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 78,
            height: widget.itemHeight,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: iconBoxWidth,
                      height: iconBoxHeight,
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
                        size: iconSize,
                        color: widget.isSelected
                            ? Colors.white
                            : (_isHovered
                                ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      ),
                    ),
                    if (widget.isLocked)
                      Positioned(
                        top: -2,
                        right: -1,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.statusRed.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: AppSvgIcon(
                            svgString: AppSvgIcon.lock,
                            size: h >= 50 ? 9 : 8,
                            color: AppColors.statusRed,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: spacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                        color: widget.isSelected
                            ? (isDark ? Colors.white : AppColors.wineRed)
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
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
    super.key,
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
