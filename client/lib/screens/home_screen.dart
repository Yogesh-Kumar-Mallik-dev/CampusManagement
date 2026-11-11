import 'package:flutter/material.dart';
import '../models/academic.dart';
import '../models/complaint.dart';
import '../models/hostel.dart';
import '../models/mess.dart';
import '../models/user.dart';
import '../services/app_cache.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_logo.dart';
import '../widgets/smooth_theme_toggle.dart';
import 'attendance_screen.dart';
import 'complaints_screen.dart';
import 'department_management_screen.dart';
import 'fee_screen.dart';
import 'hostel_screen.dart';
import 'library_screen.dart';
import 'mess_screen.dart';
import 'notices_screen.dart';
import 'sessional_exam_screen.dart';
import 'timetable_screen.dart';
import 'user_management_screen.dart';
import 'user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;
  final VoidCallback? onLogout;
  final Set<int> maintenancePages;
  final Set<int> showcasePages;
  final int? initialTab;
  final bool restoreCachedTab;

  const HomeScreen({
    super.key,
    required this.storage,
    this.currentUser,
    this.onLogout,
    this.maintenancePages = const {},
    this.showcasePages = const {},
    this.initialTab,
    this.restoreCachedTab = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _slot3PageIndex = 1; // Default to Timetable in dock division 3
  final Set<int> _loadedTabs = {0};
  final Map<int, Widget> _tabWidgetCache = {};

  late Set<int> _maintenancePages;
  late Set<int> _showcasePages;

  late List<UserModel> _personas;
  late UserModel _currentUser;

  int _userCount = 0;
  List<DepartmentModel> _departmentsList = [];
  int _departmentCount = 0;
  List<ComplaintModel> _complaintsList = [];
  int _complaintCount = 0;
  int _pendingComplaintCount = 0;
  int _investigatingComplaintCount = 0;
  int _resolvedComplaintCount = 0;
  int _hostelRoomCount = 0;
  int _hostelOccupiedCount = 0;
  int _hostelTotalAssets = 0;
  String _studentRoomInfo = 'Not Allotted';
  String _studentRoomSubtitle = 'No hostel room assigned';
  double? _studentAttendancePercentage;
  int _studentTotalClassesHeld = 0;
  int _studentTotalClassesAttended = 0;
  List<TimetableSlotModel> _todaySlots = [];
  List<MessMealModel> _todayMeals = [];
  int _messMealCount = 0;
  double _messAverageRating = 0.0;
  int _messRatingCount = 0;

  bool _isPageInMaintenance(int index) => _maintenancePages.contains(index);
  bool _isPageInShowcase(int index) => _showcasePages.contains(index);

  bool _isPageAccessible(int index) {
    if (index == 4) return _currentUser.canManageUsers;
    if (index == 5) return _currentUser.canManageDepartments;
    return true;
  }

  void _onDestinationSelected(int index) {
    if ((index >= 1 && index <= 10) || index == 12) {
      _slot3PageIndex = index;
      AppCache.instance.setSlot3PageIndex(index, userHandle: _currentUser.campusHandle);
    }
    AppCache.instance.setLastActiveNavIndex(index, userHandle: _currentUser.campusHandle);
    if (_currentIndex == index) return;
    if (index == 0) {
      _loadDashboardData();
    }
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
      if (_isPageInMaintenance(index)) {
        final info = _getMaintenanceInfo(index);
        return _buildMaintenanceView(
          moduleName: info.$1,
          maintenanceWindow: info.$2,
          reason: info.$3,
        );
      }
      if (_isPageInShowcase(index)) {
        final info = _getShowcaseInfo(index);
        return _buildFeatureShowcaseView(
          moduleName: info.$1,
          previewTag: info.$2,
          description: info.$3,
        );
      }

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
          return FeeScreen(
            key: ValueKey('tab-fees-${_currentUser.id}'),
            storage: widget.storage,
            currentUser: _currentUser,
            restoreCachedTab: widget.restoreCachedTab,
          );
        case 10:
          return LibraryScreen(
            key: ValueKey('tab-library-${_currentUser.id}'),
            storage: widget.storage,
            currentUser: _currentUser,
            restoreCachedTab: widget.restoreCachedTab,
            onNavigateToTab: _onDestinationSelected,
          );
        case 11:
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
        case 12:
          return SessionalExamScreen(
            key: ValueKey('tab-sessional-${_currentUser.id}'),
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

  Widget _buildMaintenanceView({
    required String moduleName,
    required String maintenanceWindow,
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
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD97706).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const AppSvgIcon(
                      svgString: AppSvgIcon.lock,
                      size: 22,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Module Under Maintenance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'MAINTENANCE TAKEDOWN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
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
                          'Maintenance Window: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            maintenanceWindow,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Reason: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Preservation: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            'All offline records, submissions, and queued transactions remain preserved locally.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('btn-maintenance-back-dashboard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _onDestinationSelected(0),
                icon: const AppSvgIcon(svgString: AppSvgIcon.dashboard, size: 14),
                label: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureShowcaseView({
    required String moduleName,
    required String previewTag,
    required String description,
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
                      color: const Color(0xFF0969DA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF0969DA).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const AppSvgIcon(
                      svgString: AppSvgIcon.lock,
                      size: 22,
                      color: Color(0xFF0969DA),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Upcoming Feature Preview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0969DA).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF0969DA).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                previewTag,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0969DA),
                                ),
                              ),
                            ),
                          ],
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
                          'Showcase Overview: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Release Channel: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Expanded(
                          child: Text(
                            'Institutional preview channel. Scheduled for upcoming academic rollout.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('btn-showcase-back-dashboard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _onDestinationSelected(0),
                icon: const AppSvgIcon(svgString: AppSvgIcon.dashboard, size: 14),
                label: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, String, String) _getMaintenanceInfo(int index) {
    switch (index) {
      case 1:
        return ('Academic Timetable', '22:00 - 01:00 IST', 'Term schedule re-indexing and room slot synchronization.');
      case 2:
        return ('Attendance Ledger & Studio', '23:30 - 01:00 IST', 'Rolling cryptographic QR token generator service upgrade.');
      case 3:
        return ('Institutional Notices', '01:00 - 02:30 IST', 'Notice distribution queue indexing and multicast channel optimization.');
      case 4:
        return ('Campus Directory & Identity Management', '23:00 - 02:00 IST', 'Directory administration indexing and cryptographic identity sync.');
      case 5:
        return ('Academic Departments & Structure', '22:00 - 01:00 IST', 'Curriculum database migration and syllabus archive indexing.');
      case 6:
        return ('Hostel Room Management', '00:00 - 03:00 IST', 'Room inventory database maintenance and serial tracking sync.');
      case 7:
        return ('Hostel Mess & Feedback', '21:30 - 23:00 IST', 'Dining feedback aggregation system maintenance and menu sync.');
      case 8:
        return ('Grievances & Complaints Redressal', '01:00 - 03:00 IST', 'Ticket dispatcher and cryptographic anonymity vault upgrade.');
      case 9:
        return ('Institutional Fee & Fine Management', '00:00 - 02:00 IST', 'Payment gateway settlement re-indexing and bank ledger synchronization.');
      case 10:
        return ('Library & Knowledge Portal', '22:30 - 00:30 IST', 'E-book index rebuild and physical inventory sync.');
      case 11:
        return ('User Profile & DigiLocker Vault', '00:00 - 01:30 IST', 'DigiLocker certificate verification and profile sync.');
      case 12:
        return ('AKTU Sessional & Internal Assessment', '23:00 - 01:00 IST', 'Internal award list ledger indexing and SHA-256 seal verification.');
      default:
        return ('Campus Module', '23:00 - 02:00 IST', 'System database re-indexing and maintenance upgrade.');
    }
  }

  (String, String, String) _getShowcaseInfo(int index) {
    switch (index) {
      case 1:
        return ('Academic Timetable', 'UPCOMING MODULE', 'AI-assisted dynamic clash resolution timetable editor.');
      case 2:
        return ('Attendance Ledger & Studio', 'UPCOMING MODULE', 'Facial geo-fenced optical roll-call verification.');
      case 3:
        return ('Institutional Notices', 'UPCOMING MODULE', 'Automated emergency SMS and push broadcast alert system.');
      case 4:
        return ('Campus Directory & Identity Management', 'PREVIEW SHOWCASE', 'Enterprise federated multi-campus directory lookup.');
      case 5:
        return ('Academic Departments & Structure', 'PREVIEW SHOWCASE', 'Autonomous credit-transfer and Board of Studies governance.');
      case 6:
        return ('Hostel Room Management', 'UPCOMING MODULE', 'Smart RFID hostel room access and automated power management.');
      case 7:
        return ('Hostel Mess & Feedback', 'UPCOMING MODULE', 'Digital meal coupon reservation and dietary calorie analyzer.');
      case 8:
        return ('Grievances & Complaints Redressal', 'UPCOMING MODULE', 'AI-prioritized institutional grievance triage and SLA escalation.');
      case 9:
        return ('Institutional Fee & Fine Management', 'UPCOMING MODULE', 'Automated scholarship disbursement and installment e-mandate portal.');
      case 10:
        return ('Library & Knowledge Portal', 'UPCOMING MODULE', 'Federated inter-library loan and AI reading assistant.');
      case 11:
        return ('User Profile & DigiLocker Vault', 'PREVIEW SHOWCASE', 'Decentralized verifiable credentials and academic blockchain passport.');
      case 12:
        return ('AKTU Sessional & Internal Assessment', 'PREVIEW SHOWCASE', 'Automated AKTU exam portal API sync and digital award signing.');
      default:
        return ('Campus Module', 'PREVIEW SHOWCASE', 'Next-generation campus management service in development.');
    }
  }

  @override
  void initState() {
    super.initState();
    _maintenancePages = Set.from(widget.maintenancePages);
    _showcasePages = Set.from(widget.showcasePages);
    final adminUser = OfflineStorageService.getMockUserForHandle('campus_admin');
    final initial = widget.currentUser ?? adminUser;
    _personas = [initial];
    if (initial.campusHandle != adminUser.campusHandle) {
      _personas.add(adminUser);
    }
    _currentUser = initial;
    _loadDirectoryPersonas();
    _loadDashboardData();

    int effectiveIndex = widget.initialTab ?? 0;
    if (widget.initialTab == null && widget.restoreCachedTab) {
      final cached = AppCache.instance.getLastActiveNavIndex(userHandle: _currentUser.campusHandle);
      if (cached != null && _isPageAccessible(cached)) {
        effectiveIndex = cached;
      }
    }
    _currentIndex = effectiveIndex;
    _loadedTabs.add(effectiveIndex);

    if (widget.restoreCachedTab) {
      final cachedSlot3 = AppCache.instance.getSlot3PageIndex(userHandle: _currentUser.campusHandle);
      if (cachedSlot3 != null && _isPageAccessible(cachedSlot3)) {
        _slot3PageIndex = cachedSlot3;
      }
    }

    _checkServer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _loadedTabs.addAll([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        });
      }
    });
  }

  Future<void> _loadDirectoryPersonas() async {
    try {
      final users = await widget.storage.getUsers();
      if (mounted && users.isNotEmpty) {
        setState(() {
          for (final u in users) {
            if (!_personas.any((p) => p.campusHandle == u.campusHandle || p.id == u.id)) {
              _personas.add(u);
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDashboardData() async {
    try {
      final futures = await Future.wait([
        widget.storage.getUsers().catchError((_) => <UserModel>[]),
        widget.storage.getDepartments().catchError((_) => <DepartmentModel>[]),
        widget.storage.getComplaints().catchError((_) => <ComplaintModel>[]),
        widget.storage.getHostelRooms().catchError((_) => <HostelRoomModel>[]),
        widget.storage.getMessTimetable().catchError((_) => <MessMealModel>[]),
        widget.storage.getMessRatingsReport().catchError((_) => const MessReportSummary(
              totalRatings: 0,
              averageScore: 0.0,
              ratingCounts: {},
              recentMessages: [],
              sundayScheduleNote: '',
            )),
      ]);

      if (!mounted) return;

      final users = futures[0] as List<UserModel>;
      final depts = futures[1] as List<DepartmentModel>;
      final complaints = futures[2] as List<ComplaintModel>;
      final rooms = futures[3] as List<HostelRoomModel>;
      final meals = futures[4] as List<MessMealModel>;
      final messReport = futures[5] as MessReportSummary;

      final now = DateTime.now();
      final weekday = now.weekday;
      final daysOfWeekNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final todayName = daysOfWeekNames[weekday - 1];

      final occupiedRooms = rooms.where((r) => r.occupants.isNotEmpty).length;
      int totalAssets = 0;
      HostelRoomModel? studentRoom;
      for (final r in rooms) {
        totalAssets += r.assets.length;
        if (r.occupants.any((o) => o.userId == _currentUser.id || o.campusHandle == _currentUser.campusHandle)) {
          studentRoom = r;
        }
      }

      double? attendancePct;
      int attendedCount = 0;
      int heldCount = 0;
      if (_currentUser.archetype == 'student') {
        try {
          final summaries = await widget.storage.getAttendanceSummary(_currentUser.id);
          for (final s in summaries) {
            heldCount += s.totalSessions;
            attendedCount += s.attended;
          }
          if (heldCount > 0) {
            attendancePct = (attendedCount / heldCount) * 100.0;
          }
        } catch (_) {}
      }

      List<TimetableSlotModel> todaySlotsList = [];
      try {
        final sectionScope = _currentUser.activeScopes.firstWhere(
          (s) => s.startsWith('sec:') || s.startsWith('dept:'),
          orElse: () => '',
        );
        if (sectionScope.isNotEmpty) {
          final allSlots = await widget.storage.getTimetable(sectionScope);
          todaySlotsList = allSlots.where((s) => s.dayOfWeek == weekday).toList();
        }
      } catch (_) {}

      final todayMealsList = meals.where((m) => m.dayOfWeek.toLowerCase() == todayName).toList();

      if (mounted) {
        setState(() {
          _userCount = users.length;
          _departmentsList = depts;
          _departmentCount = depts.length;
          _complaintsList = complaints;
          _complaintCount = complaints.length;
          _pendingComplaintCount = complaints.where((c) => c.status == 'submitted').length;
          _investigatingComplaintCount = complaints.where((c) => c.status == 'in_progress').length;
          _resolvedComplaintCount = complaints.where((c) => c.status == 'resolved').length;
          _hostelRoomCount = rooms.length;
          _hostelOccupiedCount = occupiedRooms;
          _hostelTotalAssets = totalAssets;
          if (studentRoom != null) {
            _studentRoomInfo = 'Room ${studentRoom.roomNumber}';
            _studentRoomSubtitle = '${studentRoom.blockName} • Floor ${studentRoom.floor} • Curfew 22:30 IST';
          } else {
            _studentRoomInfo = 'Not Allotted';
            _studentRoomSubtitle = 'No hostel room assigned';
          }
          _studentAttendancePercentage = attendancePct;
          _studentTotalClassesHeld = heldCount;
          _studentTotalClassesAttended = attendedCount;
          _todaySlots = todaySlotsList;
          _todayMeals = todayMealsList;
          _messMealCount = meals.length;
          _messAverageRating = messReport.averageScore;
          _messRatingCount = messReport.totalRatings;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentUser != null && widget.currentUser != oldWidget.currentUser) {
      _currentUser = widget.currentUser!;
      _tabWidgetCache.clear();
      _checkServer();
    }
    if (widget.maintenancePages != oldWidget.maintenancePages) {
      _maintenancePages = Set.from(widget.maintenancePages);
      _tabWidgetCache.clear();
    }
    if (widget.showcasePages != oldWidget.showcasePages) {
      _showcasePages = Set.from(widget.showcasePages);
      _tabWidgetCache.clear();
    }
  }

  void _checkServer() {
    widget.storage.refreshConnectivityAndSync(_currentUser.id).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrWeb = screenWidth >= 800;
    final isNarrow = screenWidth <= 600;
    final isVeryNarrow = screenWidth < 360;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabStack = IndexedStack(
      index: _currentIndex,
      children: List.generate(13, _buildTab),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isVeryNarrow ? 4 : (isNarrow ? 8 : 16),
        title: AppLogo(height: isVeryNarrow ? 26 : (isNarrow ? 34 : 40)),
        actions: [
          // Connection Status Badge
          Builder(
            builder: (context) {
              final statusBadge = widget.storage.isOnline
                  ? AppColors.greenBadge(isDark)
                  : AppColors.yellowBadge(isDark);
              final isNarrow = MediaQuery.of(context).size.width <= 600;
              final isVeryNarrow = MediaQuery.of(context).size.width < 360;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: EdgeInsets.symmetric(horizontal: isVeryNarrow ? 4 : (isNarrow ? 6 : 10), vertical: 4),
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
          SizedBox(width: isVeryNarrow ? 3 : 8),

          // Grievances & Complaints Direct Shortcut
          IconButton(
            key: const Key('appbar-btn-complaints'),
            tooltip: 'Grievances & Complaints',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(28, 28),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            icon: const AppSvgIcon(
              svgString: AppSvgIcon.alertTriangle,
              size: 18,
            ),
            onPressed: () => _onDestinationSelected(8),
          ),
          const SizedBox(width: 2),

          // Fees & Fine Portal Direct Shortcut
          if (!isVeryNarrow) ...[
            IconButton(
              key: const Key('appbar-btn-fees'),
              tooltip: 'Fees & Fine Portal',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(28, 28),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              icon: const AppSvgIcon(
                svgString: AppSvgIcon.creditCard,
                size: 18,
              ),
              onPressed: () => _onDestinationSelected(9),
            ),
            const SizedBox(width: 2),
          ],

          // Smooth Animated Theme Toggle
          const SmoothThemeToggle(),
          SizedBox(width: isVeryNarrow ? 2 : 4),

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
              _loadDashboardData();
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
          SizedBox(width: isVeryNarrow ? 4 : (isNarrow ? 8 : 16)),
        ],
      ),
      body: isDesktopOrWeb
          ? Row(
              children: [
                _CampusSidebar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  currentUser: _currentUser,
                  maintenancePages: _maintenancePages,
                  showcasePages: _showcasePages,
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
                    isSelected: _currentIndex == 11,
                    isDark: isDark,
                    onTap: () => _onDestinationSelected(11),
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
        return (label: 'Fees', svgIcon: AppSvgIcon.creditCard);
      case 10:
        return (label: 'Library', svgIcon: AppSvgIcon.book);
      case 11:
        return (label: 'Profile', svgIcon: AppSvgIcon.user);
      case 12:
        return (label: 'Sessionals', svgIcon: AppSvgIcon.academicCap);
      default:
        return (label: 'Timetable', svgIcon: AppSvgIcon.calendar);
    }
  }

  void _showOtherPagesSheet(BuildContext context, bool isDark) {
    final allPages = [
      (
        index: 1,
        keyName: 'timetable',
        label: 'Timetable',
        subtitle: 'Lectures, labs & weekly class schedule',
        svgIcon: AppSvgIcon.calendar,
      ),
      (
        index: 2,
        keyName: 'attendance',
        label: 'Attendance',
        subtitle: 'Live optical QR broadcast & attendance ledger',
        svgIcon: AppSvgIcon.attendance,
      ),
      (
        index: 3,
        keyName: 'notices',
        label: 'Notices',
        subtitle: 'Targeted institutional bulletins & circulars',
        svgIcon: AppSvgIcon.bell,
      ),
      (
        index: 4,
        keyName: 'directory',
        label: 'Campus Directory',
        subtitle: 'Student, faculty & staff identity onboarding',
        svgIcon: AppSvgIcon.user,
      ),
      (
        index: 5,
        keyName: 'departments',
        label: 'Academic Departments',
        subtitle: 'Programs, cross-program sections & lab batches',
        svgIcon: AppSvgIcon.building,
      ),
      (
        index: 6,
        keyName: 'hostel',
        label: 'Hostel Management',
        subtitle: 'Room inventory, verified fixtures & occupants',
        svgIcon: AppSvgIcon.bed,
      ),
      (
        index: 7,
        keyName: 'mess',
        label: 'Hostel Mess & Ratings',
        subtitle: 'Weekly menu timetable & feedback reports',
        svgIcon: AppSvgIcon.utensils,
      ),
      (
        index: 8,
        keyName: 'complaints',
        label: 'Grievances & Complaints',
        subtitle: 'Lodge & track verified or anonymous complaints',
        svgIcon: AppSvgIcon.alertTriangle,
      ),
      (
        index: 9,
        keyName: 'fees',
        label: 'Fees & Fine Portal',
        subtitle: 'Semester dues, itemized invoices, fines & receipts',
        svgIcon: AppSvgIcon.creditCard,
      ),
      (
        index: 10,
        keyName: 'library',
        label: 'Library & Knowledge Portal',
        subtitle: 'Borrowed books, return dates, late fines & infinite e-books',
        svgIcon: AppSvgIcon.book,
      ),
      (
        index: 12,
        keyName: 'sessional',
        label: 'Sessional & Internal Exams',
        subtitle: 'AKTU internal marks, datesheet, hall seating & award list',
        svgIcon: AppSvgIcon.academicCap,
      ),
    ];

    final otherPages = <({
      int index,
      String keyName,
      String label,
      String subtitle,
      String svgIcon,
      bool isRestricted,
      String? lockBadgeText,
    })>[];

    for (final page in allPages) {
      final isMaintenance = _isPageInMaintenance(page.index);
      final isShowcase = _isPageInShowcase(page.index);

      if (isMaintenance) {
        otherPages.add((
          index: page.index,
          keyName: page.keyName,
          label: page.label,
          subtitle: 'Module temporarily offline for scheduled maintenance',
          svgIcon: page.svgIcon,
          isRestricted: true,
          lockBadgeText: 'Maintenance',
        ));
        continue;
      }

      if (isShowcase) {
        otherPages.add((
          index: page.index,
          keyName: page.keyName,
          label: page.label,
          subtitle: 'Upcoming module preview (Coming Soon)',
          svgIcon: page.svgIcon,
          isRestricted: true,
          lockBadgeText: 'Preview',
        ));
        continue;
      }

      final isAccessible = _isPageAccessible(page.index);
      if (isAccessible) {
        otherPages.add((
          index: page.index,
          keyName: page.keyName,
          label: page.label,
          subtitle: page.subtitle,
          svgIcon: page.svgIcon,
          isRestricted: false,
          lockBadgeText: null,
        ));
      }
    }

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
                              item.subtitle,
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
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lock_outline, size: 12, color: Color(0xFFD97706)),
                                        if (item.lockBadgeText != null) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            item.lockBadgeText!,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
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
      return 'Campus Residential Services • Chief Hostel Warden';
    }
    if (user.isMessManager) {
      return 'Dining & Catering Operations • Central Campus Canteen & Mess';
    }
    if (user.isFaculty || user.isHOD) {
      final deptScope = user.activeScopes.firstWhere(
        (s) => s.startsWith('dept:'),
        orElse: () => '',
      );
      final deptName = deptScope.isNotEmpty ? deptScope.replaceFirst('dept:', '').toUpperCase() : '';
      final title = user.isHOD ? 'Head of Department' : 'Faculty Member';
      return deptName.isNotEmpty ? 'Department of $deptName • $title' : title;
    }
    if (user.isStudent) {
      final parts = <String>[];
      if (user.currentSemester != null) {
        parts.add('Semester ${user.currentSemester}');
      }
      final secScope = user.sectionScope ??
          user.activeScopes.where((s) => s.startsWith('sec:')).firstOrNull;
      if (secScope != null) {
        parts.add('Section ${secScope.replaceFirst('sec:', '').toUpperCase()}');
      }
      if (user.universityRollNo != null && user.universityRollNo!.isNotEmpty) {
        parts.add('Roll: ${user.universityRollNo}');
      }
      return parts.isNotEmpty ? parts.join(' • ') : 'Enrolled Student • ${user.email}';
    }
    if (user.isContractor) {
      final org = user.vendorOrganization ?? 'Contractor Services';
      final pass = user.gatePassId != null ? 'Gate Pass: ${user.gatePassId}' : 'Authorized Contractor';
      return '$org • $pass';
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
          badgeText: _todaySlots.isNotEmpty ? 'UPCOMING LECTURE' : 'SCHEDULE CLEAR',
          badgeColor: _todaySlots.isNotEmpty ? AppColors.wineRed : AppColors.githubGreen,
          actionLabel: 'Open Timetable',
          onAction: () => _onDestinationSelected(1),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _todaySlots.isNotEmpty
                    ? '${_todaySlots.first.courseName} (${_todaySlots.first.startTime} - ${_todaySlots.first.endTime})'
                    : 'No Upcoming Lectures Today',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _todaySlots.isNotEmpty
                    ? 'Venue: ${_todaySlots.first.roomNumber} • Faculty: ${_todaySlots.first.instructorName.isNotEmpty ? _todaySlots.first.instructorName : "Assigned Faculty"}'
                    : 'No lectures or practical labs scheduled on today\'s timetable.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _todaySlots.isNotEmpty
                    ? 'Optical QR token session will be broadcast at start of lecture for roll-call verification.'
                    : 'Check your full weekly timetable for upcoming course sessions.',
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
          badgeText: _studentRoomInfo,
          badgeColor: const Color(0xFFD97706),
          actionLabel: 'Rate Recent Meal',
          onAction: () => _onDestinationSelected(7),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _studentRoomInfo != 'Not Allotted'
                    ? 'Campus Hostel • $_studentRoomSubtitle'
                    : 'Campus Hostel • Room Not Allotted',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _todayMeals.isNotEmpty
                    ? 'Dining Today: ${_todayMeals.map((m) => '${m.title} (${m.startTime}-${m.endTime})').join(' • ')}'
                    : 'No mess meals scheduled for today.',
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
              Text(
                _todaySlots.isNotEmpty
                    ? 'Course: ${_todaySlots.first.courseCode} ${_todaySlots.first.courseName}'
                    : 'Optical Attendance Studio Ready',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _todaySlots.isNotEmpty
                    ? 'Venue: ${_todaySlots.first.roomNumber}'
                    : 'Select a course section to launch live attendance ledger.',
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
          badgeText: '${_todaySlots.length} SESSIONS',
          badgeColor: AppColors.wineRed,
          actionLabel: 'View Timetable',
          onAction: () => _onDestinationSelected(1),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_todaySlots.isNotEmpty)
                ..._todaySlots.take(3).map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${s.startTime} - ${s.endTime} • ${s.courseCode} ${s.courseName} (${s.roomNumber})',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
              else
                const Text(
                  'No lectures or practical labs scheduled on today\'s timetable.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        );
        break;

      case 'warden':
        final hostelTickets = _complaintsList.where((c) => c.category == 'hostel').toList();
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
          badgeText: '${hostelTickets.length} OPEN TICKETS',
          badgeColor: const Color(0xFFD97706),
          actionLabel: 'Manage Maintenance',
          onAction: () => _onDestinationSelected(8),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hostelTickets.isNotEmpty)
                ...hostelTickets.take(3).map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${t.title} - ${t.status.toUpperCase()}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
              else
                const Text(
                  'No open hostel maintenance tickets recorded.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 4),
              Text(
                'All $_hostelTotalAssets room assets tagged with 14-char institutional serial numbers.',
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
              if (_todayMeals.isNotEmpty)
                ..._todayMeals.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${m.title} (${m.startTime} - ${m.endTime}): ${m.menuSummary}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
              else
                const Text(
                  'No meals scheduled for today.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        );
        panel2 = _buildDashboardPanel(
          context: context,
          isDark: isDark,
          title: 'Food Quality Meter & Feedback',
          badgeText: _messRatingCount > 0 ? '${_messAverageRating.toStringAsFixed(1)} / 5.0' : 'NO RATINGS',
          badgeColor: const Color(0xFF0969DA),
          actionLabel: 'Inspect Rating Reports',
          onAction: () => _onDestinationSelected(7),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _messRatingCount > 0
                    ? 'Student Satisfaction: ${_messAverageRating.toStringAsFixed(1)} / 5.0 Stars ($_messRatingCount reviews)'
                    : 'No student feedback ratings submitted yet.',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
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
                'Authorized Building Scopes: Campus Facilities & Main Gate Turnstiles.',
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
          badgeText: 'SYSTEM HEALTH',
          badgeColor: _complaintCount > 0 ? AppColors.statusRed : AppColors.githubGreen,
          actionLabel: 'Open Redressal Center',
          onAction: () => _onDestinationSelected(8),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _complaintCount > 0
                    ? 'Triage: $_pendingComplaintCount Pending Review • $_investigatingComplaintCount Under Investigation • $_resolvedComplaintCount Resolved'
                    : 'No complaints or grievances recorded in the institutional ledger.',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Categories: Hostel (${_complaintsList.where((c) => c.category == 'hostel').length}) • Academic (${_complaintsList.where((c) => c.category == 'academic').length}) • Canteen (${_complaintsList.where((c) => c.category == 'canteen').length}) • Campus (${_complaintsList.where((c) => c.category == 'campus').length})',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SLA Compliance: Mandatory 24-hour institutional resolution policy enforced across all units.',
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
          badgeText: '$_departmentCount DEPTS ACTIVE',
          badgeColor: const Color(0xFF0969DA),
          actionLabel: 'Manage Departments',
          onAction: () => _onDestinationSelected(5),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_departmentsList.isNotEmpty)
                ..._departmentsList.take(3).map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${d.code.toUpperCase()}: ${d.name}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
              else
                const Text(
                  '0 academic departments configured. Use Department Management to configure degree programs.',
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
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
            value: _studentAttendancePercentage != null
                ? '${_studentAttendancePercentage!.toStringAsFixed(1)}%'
                : 'No Records',
            subtitle: _studentTotalClassesHeld > 0
                ? '$_studentTotalClassesAttended / $_studentTotalClassesHeld Classes Attended'
                : '0 attendance sessions recorded',
            iconSvg: AppSvgIcon.attendance,
            color: _studentAttendancePercentage != null && _studentAttendancePercentage! >= 75
                ? AppColors.githubGreen
                : (_studentAttendancePercentage != null && _studentAttendancePercentage! >= 40
                    ? const Color(0xFFD97706)
                    : AppColors.statusRed),
            onTap: () => _onDestinationSelected(2),
          ),
          _DashboardMetricCard(
            title: "Today's Schedule",
            value: _todaySlots.isNotEmpty ? '${_todaySlots.length} Sessions' : '0 Classes Today',
            subtitle: _todaySlots.isNotEmpty
                ? _todaySlots.map((s) => s.courseCode).take(2).join(', ')
                : 'No classes scheduled today',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(1),
          ),
          _DashboardMetricCard(
            title: 'Hostel Residence',
            value: _studentRoomInfo,
            subtitle: _studentRoomSubtitle,
            iconSvg: AppSvgIcon.bed,
            color: const Color(0xFFD97706),
            onTap: () => _onDestinationSelected(6),
          ),
          _DashboardMetricCard(
            title: 'Mess Schedule',
            value: _todayMeals.isNotEmpty ? '${_todayMeals.length} Meals Today' : 'No Menu',
            subtitle: _todayMeals.isNotEmpty
                ? _todayMeals.map((m) => m.title).take(2).join(', ')
                : 'No meals configured for today',
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
            value: _todaySlots.isNotEmpty ? '${_todaySlots.length} Classes Today' : '0 Classes Today',
            subtitle: _todaySlots.isNotEmpty
                ? '${_todaySlots.first.courseCode} (${_todaySlots.first.startTime})'
                : 'No sessions scheduled today',
            iconSvg: AppSvgIcon.calendar,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(1),
          ),
          _DashboardMetricCard(
            title: 'Optical Attendance',
            value: 'Session Broadcaster',
            subtitle: 'Launch rolling QR token code',
            iconSvg: AppSvgIcon.attendance,
            color: AppColors.githubGreen,
            onTap: () => _onDestinationSelected(2),
          ),
          _DashboardMetricCard(
            title: 'Department Stats',
            value: _departmentCount > 0 ? '$_departmentCount Department${_departmentCount == 1 ? '' : 's'}' : '0 Departments',
            subtitle: _departmentsList.isNotEmpty ? _departmentsList.first.name : 'No departments configured',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(5),
          ),
          _DashboardMetricCard(
            title: 'Student Grievances',
            value: _complaintCount > 0 ? '$_complaintCount Grievances' : '0 Grievances',
            subtitle: _complaintCount > 0 ? '$_pendingComplaintCount pending review' : 'No unresolved complaints',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
        ];
        break;

      case 'warden':
        final occupancyPct = _hostelRoomCount > 0 ? ((_hostelOccupiedCount / _hostelRoomCount) * 100).toInt() : 0;
        final hostelComplaintCount = _complaintsList.where((c) => c.category == 'hostel').length;
        metrics = [
          _DashboardMetricCard(
            title: 'Hostel Occupancy',
            value: '$occupancyPct% Occupancy',
            subtitle: '$_hostelOccupiedCount / $_hostelRoomCount Rooms Allotted',
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
            value: '$_hostelTotalAssets Items Monitored',
            subtitle: '14-Char Serial Asset Tracking',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(6),
          ),
          _DashboardMetricCard(
            title: 'Hostel Redressal',
            value: hostelComplaintCount > 0 ? '$hostelComplaintCount Tickets' : '0 Open Tickets',
            subtitle: 'Maintenance and fixture issues',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
        ];
        break;

      case 'mess':
        final canteenComplaintCount = _complaintsList.where((c) => c.category == 'canteen').length;
        metrics = [
          _DashboardMetricCard(
            title: 'Meal Timetable',
            value: _messMealCount > 0 ? '$_messMealCount Scheduled Meals' : '0 Meals',
            subtitle: _todayMeals.isNotEmpty ? '${_todayMeals.length} meals scheduled today' : 'No meals scheduled for today',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
          _DashboardMetricCard(
            title: 'Average Rating',
            value: _messRatingCount > 0 ? '${_messAverageRating.toStringAsFixed(1)} / 5.0 Stars' : 'No Ratings',
            subtitle: _messRatingCount > 0 ? '$_messRatingCount student ratings' : '0 student ratings submitted',
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
            value: canteenComplaintCount > 0 ? '$canteenComplaintCount Feedback Records' : '0 Feedback Records',
            subtitle: 'Hygiene and meal feedback',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
        ];
        break;

      case 'contractor':
        final vendorComplaintCount = _complaintsList.where((c) => c.category == 'campus' || c.category == 'canteen').length;
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
            subtitle: 'Campus buildings & facilities',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(9),
          ),
          _DashboardMetricCard(
            title: 'Mess Schedule',
            value: 'Canteen Access',
            subtitle: 'Dining timetable & menu access',
            iconSvg: AppSvgIcon.utensils,
            color: const Color(0xFF2DA44E),
            onTap: () => _onDestinationSelected(7),
          ),
          _DashboardMetricCard(
            title: 'Vendor Redressal',
            value: vendorComplaintCount > 0 ? '$vendorComplaintCount Tickets' : '0 Tickets',
            subtitle: 'Facility & billing inquiries',
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
            value: _userCount > 0 ? '$_userCount Identit${_userCount == 1 ? 'y' : 'ies'}' : '0 Identities',
            subtitle: 'Students, Staff & Administrators',
            iconSvg: AppSvgIcon.user,
            color: AppColors.wineRed,
            onTap: () => _onDestinationSelected(4),
          ),
          _DashboardMetricCard(
            title: 'Academic Structure',
            value: _departmentCount > 0 ? '$_departmentCount Department${_departmentCount == 1 ? '' : 's'}' : '0 Departments',
            subtitle: _departmentCount > 0 ? 'Active academic departments' : 'No departments configured',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(5),
          ),
          _DashboardMetricCard(
            title: 'Institutional Redressal',
            value: _complaintCount > 0 ? '$_complaintCount Complaint${_complaintCount == 1 ? '' : 's'}' : '0 Complaints',
            subtitle: _complaintCount > 0 ? '$_pendingComplaintCount pending review' : 'No complaints recorded',
            iconSvg: AppSvgIcon.alertTriangle,
            color: AppColors.statusRed,
            onTap: () => _onDestinationSelected(8),
          ),
          _DashboardMetricCard(
            title: 'Offline Sync Engine',
            value: widget.storage.isOnline ? 'Online Connected' : 'Offline Mode',
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
            subtitle: 'Targeted scope circulars & bulletins',
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
            subtitle: 'Department curriculum, syllabus & course outlines',
            iconSvg: AppSvgIcon.building,
            color: const Color(0xFF0969DA),
            onTap: () => _onDestinationSelected(5),
          ),
          _buildOperationCard(
            title: 'Hostel Rooms',
            subtitle: 'Hostel room allotment & verified asset inventory',
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
          _buildOperationCard(
            key: const Key('card-quick-fees'),
            title: 'Fees & Fine Portal',
            subtitle: 'Semester dues, itemized invoices, fines & receipts',
            iconSvg: AppSvgIcon.creditCard,
            color: const Color(0xFF0D9488),
            onTap: () => _onDestinationSelected(9),
          ),
          _buildOperationCard(
            key: const Key('card-quick-library'),
            title: 'Library & Knowledge Portal',
            subtitle: 'Borrowed books, return dates, late fines & infinite e-books',
            iconSvg: AppSvgIcon.book,
            color: const Color(0xFF2563EB),
            onTap: () => _onDestinationSelected(10),
          ),
          _buildOperationCard(
            key: const Key('card-quick-sessional'),
            title: 'AKTU Sessional & Internal Exams',
            subtitle: 'Continuous assessment scorecards, datesheet, seating & award list',
            iconSvg: AppSvgIcon.academicCap,
            color: const Color(0xFF7C3AED),
            onTap: () => _onDestinationSelected(12),
          ),
        ];
        break;

      case 'faculty':
        personaLabel = 'Academic & Instructional Governance';
        cards = [
          _buildOperationCard(
            title: 'Attendance Ledger',
            subtitle: 'Launch rotating QR broadcast for course sections',
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
          _buildOperationCard(
            title: 'Fees & Fine Portal',
            subtitle: 'Institutional billing, student fee receipts & fines',
            iconSvg: AppSvgIcon.creditCard,
            color: const Color(0xFF0D9488),
            onTap: () => _onDestinationSelected(9),
          ),
          _buildOperationCard(
            title: 'Library & Knowledge Portal',
            subtitle: 'Course reserve textbooks, catalog search & e-books',
            iconSvg: AppSvgIcon.book,
            color: const Color(0xFF2563EB),
            onTap: () => _onDestinationSelected(10),
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
          _buildOperationCard(
            key: const Key('card-quick-fees'),
            title: 'Fees & Fine Portal',
            subtitle: 'Semester dues, itemized invoices, fines & receipts',
            iconSvg: AppSvgIcon.creditCard,
            color: const Color(0xFF0D9488),
            onTap: () => _onDestinationSelected(9),
          ),
          _buildOperationCard(
            key: const Key('card-quick-library'),
            title: 'Library & Knowledge Portal',
            subtitle: 'Physical catalog, book loans, late fines & e-books',
            iconSvg: AppSvgIcon.book,
            color: const Color(0xFF2563EB),
            onTap: () => _onDestinationSelected(10),
          ),
          _buildOperationCard(
            key: const Key('card-quick-sessional-student'),
            title: 'AKTU Sessional & Internal Exams',
            subtitle: 'Class test scores, lab viva, datesheet & internal marks breakdown',
            iconSvg: AppSvgIcon.academicCap,
            color: const Color(0xFF7C3AED),
            onTap: () => _onDestinationSelected(12),
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
  final Set<int> maintenancePages;
  final Set<int> showcasePages;

  const _CampusSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.currentUser,
    this.maintenancePages = const {},
    this.showcasePages = const {},
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

    final allItems = const [
      (index: 0, svg: AppSvgIcon.dashboard, label: 'Dashboard'),
      (index: 1, svg: AppSvgIcon.calendar, label: 'Timetable'),
      (index: 2, svg: AppSvgIcon.attendance, label: 'Attendance'),
      (index: 3, svg: AppSvgIcon.bell, label: 'Notices'),
      (index: 4, svg: AppSvgIcon.user, label: 'Directory'),
      (index: 5, svg: AppSvgIcon.building, label: 'Depts'),
      (index: 6, svg: AppSvgIcon.bed, label: 'Hostel'),
      (index: 7, svg: AppSvgIcon.utensils, label: 'Mess'),
      (index: 10, svg: AppSvgIcon.book, label: 'Library'),
      (index: 12, svg: AppSvgIcon.academicCap, label: 'Exams'),
      (index: 11, svg: AppSvgIcon.user, label: 'Profile'),
    ];

    final visibleItems = <({
      int index,
      String svg,
      String label,
      bool isLocked,
      String? lockBadgeText,
    })>[];

    for (final item in allItems) {
      final isMaintenance = widget.maintenancePages.contains(item.index);
      final isShowcase = widget.showcasePages.contains(item.index);

      if (isMaintenance) {
        visibleItems.add((
          index: item.index,
          svg: item.svg,
          label: item.label,
          isLocked: true,
          lockBadgeText: 'Maintenance',
        ));
        continue;
      }

      if (isShowcase) {
        visibleItems.add((
          index: item.index,
          svg: item.svg,
          label: item.label,
          isLocked: true,
          lockBadgeText: 'Preview',
        ));
        continue;
      }

      final isAccessible = (item.index == 4 && widget.currentUser.canManageUsers) ||
          (item.index == 5 && widget.currentUser.canManageDepartments) ||
          (item.index != 4 && item.index != 5);

      if (isAccessible) {
        visibleItems.add((
          index: item.index,
          svg: item.svg,
          label: item.label,
          isLocked: false,
          lockBadgeText: null,
        ));
      }
    }

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
          final idealItemHeight = availableHeight / (visibleItems.isEmpty ? 1 : visibleItems.length);
          final itemHeight = idealItemHeight.clamp(35.0, 66.0);

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
                  children: List.generate(visibleItems.length, (idx) {
                    final item = visibleItems[idx];
                    final isSelected = widget.selectedIndex == item.index;

                    return _SidebarDestinationItem(
                      key: Key('nav-item-${item.label.toLowerCase()}'),
                      svg: item.svg,
                      label: item.label,
                      isSelected: isSelected,
                      isLocked: item.isLocked,
                      lockBadgeText: item.lockBadgeText,
                      itemHeight: itemHeight,
                      onTap: () => widget.onDestinationSelected(item.index),
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
  final String? lockBadgeText;
  final double itemHeight;
  final VoidCallback onTap;

  const _SidebarDestinationItem({
    super.key,
    required this.svg,
    required this.label,
    required this.isSelected,
    this.isLocked = false,
    this.lockBadgeText,
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

    final double iconBoxWidth = (h >= 58) ? 52.0 : (h >= 48 ? 46.0 : (h >= 40 ? 40.0 : 36.0));
    final double iconBoxHeight = (h >= 58) ? 30.0 : (h >= 48 ? 26.0 : (h >= 40 ? 22.0 : 18.0));
    final double iconSize = (h >= 58) ? 18.0 : (h >= 48 ? 16.0 : (h >= 40 ? 14.0 : 12.0));
    final double spacing = (h >= 56) ? 3.0 : (h >= 42 ? 2.0 : 1.0);
    final double fontSize = (h >= 58) ? 11.0 : (h >= 48 ? 10.0 : (h >= 42 ? 9.0 : 8.0));

    return Tooltip(
      message: widget.isLocked
          ? '${widget.label} (${widget.lockBadgeText ?? 'Restricted'})'
          : widget.label,
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
            padding: EdgeInsets.symmetric(vertical: h < 42 ? 0.0 : 2.0),
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
