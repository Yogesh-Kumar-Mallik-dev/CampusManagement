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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.wineRed,
                            borderRadius: BorderRadius.circular(6),
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
                        const SizedBox(width: 14),
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
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                                '@${_currentUser.campusHandle} • ${_currentUser.email}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                      const SizedBox(height: 10),
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
                                fontSize: 10.5,
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
          const SizedBox(height: 24),

          // Operational Navigation Cards
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
                  key: const Key('card-quick-complaints'),
                  title: 'Grievances & Redressal',
                  subtitle: 'Official complaints, hostel maintenance & anonymous reporting',
                  iconSvg: AppSvgIcon.alertTriangle,
                  color: AppColors.statusRed,
                  onTap: () => _onDestinationSelected(8),
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
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    cards[i],
                  ],
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
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            ...List.generate(items.length, (idx) {
              final isSelected = selectedIndex == idx;
              final item = items[idx];
              final isLocked = (idx == 4 && !currentUser.canManageUsers) ||
                  (idx == 5 && !currentUser.canManageDepartments);

              return _SidebarDestinationItem(
                key: Key('nav-item-${item.label.toLowerCase()}'),
                svg: item.svg,
                label: item.label,
                isSelected: isSelected,
                isLocked: isLocked,
                onTap: () => onDestinationSelected(idx),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
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
    super.key,
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
