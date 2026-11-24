import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/academic.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/assign_role_dialog.dart';
import 'user_profile_screen.dart';

class UserManagementScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;

  const UserManagementScreen({
    super.key,
    required this.storage,
    this.currentUser,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserModel> _users = [];
  PageLoadState _loadState = PageLoadState.pending;
  String? _errorMessage;
  String _selectedFilter = 'all'; // 'all', 'student', 'employee', 'external', 'inactive'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _loadGeneration = 0; // stale-response guard
  int _activeCount = 0;
  int _contractorCount = 0;
  int _discontinuedCount = 0;

  void _recomputeCounts() {
    int active = 0;
    int contractor = 0;
    int discontinued = 0;
    for (final u in _users) {
      if (u.isActive) {
        active++;
      } else {
        discontinued++;
      }
      if (u.isContractor) {
        contractor++;
      }
    }
    _activeCount = active;
    _contractorCount = contractor;
    _discontinuedCount = discontinued;
  }

  @override
  void initState() {
    super.initState();
    final cached = widget.storage.cachedUsers;
    if (cached.isNotEmpty) {
      _users = List.from(cached);
      _recomputeCounts();
      _loadState = PageLoadState.success;
    }
    _loadUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final gen = ++_loadGeneration;
    if (_users.isEmpty) {
      setState(() {
        _loadState = PageLoadState.pending;
        _errorMessage = null;
      });
    }
    try {
      final list = await widget.storage.getUsers(
        archetype: _selectedFilter == 'student' || _selectedFilter == 'employee' || _selectedFilter == 'external'
            ? _selectedFilter
            : null,
        status: _selectedFilter == 'inactive' ? 'inactive' : null,
        search: _searchQuery,
      );
      if (mounted && gen == _loadGeneration) {
        setState(() {
          _users = list;
          _recomputeCounts();
          _loadState = PageLoadState.success;
          _errorMessage = null;
        });
      }
    } catch (_) {
      if (mounted && gen == _loadGeneration) {
        setState(() {
          if (_users.isEmpty) {
            _loadState = PageLoadState.failed;
            _errorMessage = 'Failed to load user directory. Check connection.';
          }
        });
      }
    }
  }

  void _onFilterChanged(String filter) {
    setState(() => _selectedFilter = filter);
    _loadUsers();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _loadUsers);
  }

  void _openCreateUserDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UserCreationDialog(
        storage: widget.storage,
        onUserCreated: (newUser) {
          _loadUsers();
          _showCredentialsDialog(newUser);
        },
      ),
    );
  }

  void _showCredentialsDialog(UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UserCredentialsDialog(user: user),
    );
  }

  void _openUserProfile(UserModel user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          storage: widget.storage,
          userIdentifier: user.id.isNotEmpty ? user.id : user.campusHandle,
          initialUser: user,
          currentAdminUser: widget.currentUser,
          onUserUpdated: _loadUsers,
        ),
      ),
    );
  }

  void _openAssignRoleDialog(UserModel user) {
    AssignRoleDialog.show(
      context,
      user: user,
      storage: widget.storage,
      onAssigned: (_) => _loadUsers(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalCount = _users.length;
    final activeCount = _activeCount;
    final contractorCount = _contractorCount;
    final discontinuedCount = _discontinuedCount;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & Actions Strip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Campus Directory & Identity Management',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Canonical handle generation, scoped permissions, and institutional lifecycle governance.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.wineRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 16, color: Colors.white),
                  label: const Text('Onboard User', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openCreateUserDialog,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Metrics Bar
            _buildMetricsBar(isDark, totalCount, activeCount, contractorCount, discontinuedCount),
            const SizedBox(height: 20),

            // 3. Search and Segmented Filter Bar
            _buildSearchAndFilterBar(isDark),
            const SizedBox(height: 20),

            // 4. Users Grid / List
            if (_loadState == PageLoadState.pending)
              _buildUserSkeletons(isDark)
            else if (_loadState == PageLoadState.failed)
              InlineStateError(
                message: _errorMessage ?? 'Failed to load user directory.',
                onRetry: _loadUsers,
              )
            else if (_users.isEmpty)
              _buildEmptyState(isDark)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  final itemWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: _users.map((u) {
                      return SizedBox(
                        width: itemWidth,
                        child: _UserDirectoryCard(
                          user: u,
                          onTap: () => _openUserProfile(u),
                          onAssignRole: () => _openAssignRoleDialog(u),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsBar(bool isDark, int total, int active, int contractors, int discontinued) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 740;
        final items = [
          _buildMetricItem('Total Identities', '$total', isDark, AppColors.wineRed),
          _buildMetricItem('Active Credentials', '$active', isDark, AppColors.githubGreen),
          _buildMetricItem('Contractors & External', '$contractors', isDark, AppColors.statusYellow),
          _buildMetricItem('Discontinued / Exited', '$discontinued', isDark, AppColors.statusRed),
        ];

        if (isNarrow) {
          return Column(
            children: [
              Row(children: [items[0], const SizedBox(width: 10), items[1]]),
              const SizedBox(height: 10),
              Row(children: [items[2], const SizedBox(width: 10), items[3]]),
            ],
          );
        }

        return Row(
          children: [
            items[0],
            const SizedBox(width: 10),
            items[1],
            const SizedBox(width: 10),
            items[2],
            const SizedBox(width: 10),
            items[3],
          ],
        );
      },
    );
  }

  Widget _buildMetricItem(String label, String value, bool isDark, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(bool isDark) {
    final filters = [
      ('all', 'All Users'),
      ('student', 'Students'),
      ('employee', 'Faculty & Staff'),
      ('external', 'Contractors & Vendors'),
      ('inactive', 'Discontinued'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 960;

        final searchField = SizedBox(
          height: 38,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by handle, name, roll no, or email...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                child: AppSvgIcon(
                  svgString: AppSvgIcon.search,
                  size: 13,
                  strokeWidth: 1.5,
                  color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                ),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 12),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
          ),
        );

        final filterChips = Wrap(
          spacing: 6,
          runSpacing: 6,
          children: filters.map((f) {
            final isSelected = _selectedFilter == f.$1;
            return InkWell(
              onTap: () => _onFilterChanged(f.$1),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.wineRedDarkSubtle : AppColors.wineRedSubtle)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? AppColors.wineRedDarkBorder : AppColors.wineRedBorder)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: 1,
                  ),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? AppColors.wineRedDarkText : AppColors.wineRed)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ),
            );
          }).toList(),
        );

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    filterChips,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    filterChips,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildUserSkeletons(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final itemWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(6, (index) {
            return Container(
              width: itemWidth,
              padding: const EdgeInsets.all(16),
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
                    children: [
                      const AppSkeleton(width: 40, height: 40, borderRadius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            AppSkeleton(width: 120, height: 14, borderRadius: 4),
                            SizedBox(height: 6),
                            AppSkeleton(width: 80, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      const AppSkeleton(width: 60, height: 20, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      AppSkeleton(width: 140, height: 11, borderRadius: 4),
                      Spacer(),
                      AppSkeleton(width: 50, height: 11, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          AppSvgIcon(
            svgString: AppSvgIcon.user,
            size: 36,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'No matching campus identities found',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search criteria or filter.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserDirectoryCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback onTap;
  final VoidCallback onAssignRole;

  const _UserDirectoryCard({
    required this.user,
    required this.onTap,
    required this.onAssignRole,
  });

  @override
  State<_UserDirectoryCard> createState() => _UserDirectoryCardState();
}

class _UserDirectoryCardState extends State<_UserDirectoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final u = widget.user;

    final roleBadge = u.archetype == 'student'
        ? AppColors.primaryBadge(isDark)
        : (u.isContractor ? AppColors.yellowBadge(isDark) : AppColors.blueBadge(isDark));

    BadgeStyle statusBadge;
    switch (u.status.toLowerCase()) {
      case 'active':
        statusBadge = AppColors.greenBadge(isDark);
        break;
      case 'graduated':
        statusBadge = AppColors.blueBadge(isDark);
        break;
      case 'suspended':
      case 'discontinued':
        statusBadge = AppColors.redBadge(isDark);
        break;
      default:
        statusBadge = AppColors.neutralBadge(isDark);
    }

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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: u.isActive
                          ? AppColors.wineRed
                          : (isDark ? AppColors.darkBorder : Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      u.firstName.isNotEmpty ? u.firstName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.fullName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusBadge.background,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: statusBadge.border, width: 1),
                              ),
                              child: Text(
                                u.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: statusBadge.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Canonical Handle Monospace Badge
                        Text(
                          u.campusHandle,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleBadge.background,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: roleBadge.border, width: 1),
                      ),
                      child: Text(
                        u.isContractor
                            ? (u.vendorOrganization != null && u.vendorOrganization!.isNotEmpty
                                ? 'CONTRACTOR • ${u.vendorOrganization}'
                                : 'CONTRACTOR')
                            : u.archetype.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: roleBadge.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      u.isContractor && u.gatePassId != null && u.gatePassId!.isNotEmpty
                          ? u.gatePassId!
                          : (u.universityRollNo != null && u.universityRollNo!.isNotEmpty
                              ? u.universityRollNo!
                              : u.email),
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: (u.isContractor && u.gatePassId != null && u.gatePassId!.isNotEmpty) ||
                                (u.universityRollNo != null && u.universityRollNo!.isNotEmpty)
                            ? 'monospace'
                            : null,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              if (u.assignedRoles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: u.assignedRoles.map((r) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBg : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.wineRed.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        r.roleName.isNotEmpty ? r.roleName : r.roleCode,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.wineRed,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    key: Key('btn-card-assign-role-${u.campusHandle}'),
                    onTap: widget.onAssignRole,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          AppSvgIcon(svgString: AppSvgIcon.shield, size: 12, color: AppColors.wineRed),
                          SizedBox(width: 4),
                          Text(
                            'Assign Role',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.wineRed),
                          ),
                        ],
                      ),
                    ),
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

class _UserCreationDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final ValueChanged<UserModel> onUserCreated;

  const _UserCreationDialog({
    required this.storage,
    required this.onUserCreated,
  });

  @override
  State<_UserCreationDialog> createState() => _UserCreationDialogState();
}

class _UserCreationDialogState extends State<_UserCreationDialog> {
  int _selectedTab = 0; // 0: Student, 1: Employee, 2: Contractor / Vendor
  bool _isSubmitting = false;
  String? _errorMessage;

  // Dynamic program & department options
  List<ProgramModel> _availablePrograms = [];
  List<DepartmentModel> _availableDepartments = [];
  String? _stuBranch;

  // Student Form Controllers
  final _stuFirst = TextEditingController();
  final _stuLast = TextEditingController();
  final _stuAcademicName = TextEditingController();
  String _stuGender = 'not_specified';
  final _stuEmail = TextEditingController();
  final _stuPersonalEmail = TextEditingController();
  final _stuPhone = TextEditingController();
  final _stuAppNo = TextEditingController();
  final _stuRollNo = TextEditingController();
  final _stuRegNo = TextEditingController();
  final _stuSection = TextEditingController();
  final _stuAdvisor = TextEditingController();
  int _stuAdmissionYear = DateTime.now().year;
  String _stuEntryType = 'regular'; // 'regular', 'lateral', 'transfer'
  String? _stuProgram; // dynamic code or id

  // Employee Form Controllers
  final _empFirst = TextEditingController();
  final _empLast = TextEditingController();
  String _empGender = 'not_specified';
  final _empEmail = TextEditingController();
  final _empPersonalEmail = TextEditingController();
  final _empPhone = TextEditingController();
  final _empCode = TextEditingController();
  int _empJoiningYear = DateTime.now().year;
  String _empType = 'permanent'; // 'permanent', 'contract', 'visiting'

  // Academic track options
  bool _empIsAcademic = true;
  String _empAcademicRank = 'Assistant Professor';
  final _empCabin = TextEditingController();
  String? _empDept; // dynamic code or id

  // Administrative track options
  bool _empIsAdmin = false;
  String _empAdminUnit = 'unit:student_affairs';
  final _empDesignation = TextEditingController();
  final _empOffice = TextEditingController();

  // Contractor / External Form Controllers
  final _extFirst = TextEditingController();
  final _extLast = TextEditingController();
  String _extGender = 'not_specified';
  final _extEmail = TextEditingController();
  final _extPersonalEmail = TextEditingController();
  final _extPhone = TextEditingController();
  int _extOnboardingYear = DateTime.now().year;
  final _extVendorOrg = TextEditingController();
  String _extServiceType = 'canteen';
  final _extGatePass = TextEditingController();
  final _extSupervisorName = TextEditingController();
  final _extSupervisorPhone = TextEditingController();
  final _extScopes = TextEditingController();

  // Credential setup options
  final _initialPasswordController = TextEditingController();
  bool _autoGeneratePassword = true;
  bool _obscureInitialPassword = true;
  late String _generatedPassword;

  String _makeSecureTempPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    final suffix = List.generate(4, (i) => chars[(rand >> (i * 5)) % chars.length]).join();
    return 'Campus#${DateTime.now().year}$suffix';
  }

  @override
  void initState() {
    super.initState();
    _generatedPassword = _makeSecureTempPassword();
    _loadAcademicOptions();
  }

  Future<void> _loadAcademicOptions() async {
    try {
      final progs = await widget.storage.getPrograms();
      final depts = await widget.storage.getDepartments();
      if (mounted) {
        setState(() {
          _availablePrograms = progs.where((p) => !p.isRetired).toList();
          _availableDepartments = depts;
          if (_availablePrograms.isNotEmpty) {
            final firstProg = _availablePrograms.first;
            _stuProgram = firstProg.code.isNotEmpty ? firstProg.code : firstProg.id;
            final activeBranches = firstProg.branches.where((b) => !b.isRetired).toList();
            if (activeBranches.isNotEmpty) {
              _stuBranch = activeBranches.first.code.isNotEmpty ? activeBranches.first.code : activeBranches.first.name;
            } else {
              _stuBranch = null;
            }
          } else {
            _stuProgram = null;
            _stuBranch = null;
          }
          if (_availableDepartments.isNotEmpty) {
            final firstDept = _availableDepartments.first;
            _empDept = firstDept.code.isNotEmpty ? 'dept:${firstDept.code.toLowerCase()}' : firstDept.id;
          } else {
            _empDept = null;
          }
        });
      }
    } catch (_) {}
  }

  List<String> _getAdmissionYears() {
    final now = DateTime.now().year;
    return [
      (now - 3).toString(),
      (now - 2).toString(),
      (now - 1).toString(),
      now.toString(),
      (now + 1).toString(),
    ];
  }

  List<String> _getJoiningYears() {
    final now = DateTime.now().year;
    return List.generate(7, (i) => (now - 5 + i).toString());
  }

  List<String> _getOnboardingYears() {
    final now = DateTime.now().year;
    return List.generate(5, (i) => (now - 2 + i).toString());
  }

  @override
  void dispose() {
    _stuFirst.dispose();
    _stuLast.dispose();
    _stuAcademicName.dispose();
    _stuEmail.dispose();
    _stuPersonalEmail.dispose();
    _stuPhone.dispose();
    _stuAppNo.dispose();
    _stuRollNo.dispose();
    _stuRegNo.dispose();
    _stuSection.dispose();
    _stuAdvisor.dispose();

    _empFirst.dispose();
    _empLast.dispose();
    _empEmail.dispose();
    _empPersonalEmail.dispose();
    _empPhone.dispose();
    _empCode.dispose();
    _empCabin.dispose();
    _empDesignation.dispose();
    _empOffice.dispose();

    _extFirst.dispose();
    _extLast.dispose();
    _extEmail.dispose();
    _extPersonalEmail.dispose();
    _extPhone.dispose();
    _extVendorOrg.dispose();
    _extGatePass.dispose();
    _extSupervisorName.dispose();
    _extSupervisorPhone.dispose();
    _extScopes.dispose();
    _initialPasswordController.dispose();
    super.dispose();
  }

  String _generateStudentHandlePreview() {
    final name = _stuFirst.text.trim().toLowerCase();
    final cleanName = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final prefixName = cleanName.isEmpty ? 'name' : cleanName;
    final entryCode = _stuEntryType == 'regular' ? 'r' : (_stuEntryType == 'lateral' ? 'l' : 't');
    final progVal = (_stuProgram != null && _stuProgram!.isNotEmpty) ? _stuProgram! : 'prog';
    final progPart = (_stuBranch != null && _stuBranch!.isNotEmpty)
        ? '${progVal}_${_stuBranch!}'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')
        : progVal.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${prefixName}_${_stuAdmissionYear}_${entryCode}_${progPart}_#';
  }

  String _generateEmployeeHandlePreview() {
    final name = _empFirst.text.trim().toLowerCase();
    final cleanName = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final prefixName = cleanName.isEmpty ? 'name' : cleanName;
    return '${prefixName}_${_empJoiningYear}_emp_#';
  }

  String _generateContractorHandlePreview() {
    final name = _extFirst.text.trim().toLowerCase();
    final cleanName = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final prefixName = cleanName.isEmpty ? 'name' : cleanName;
    return '${prefixName}_${_extOnboardingYear}_ext_#';
  }

  String _getCurrentHandlePreview() {
    if (_selectedTab == 0) return _generateStudentHandlePreview();
    if (_selectedTab == 1) return _generateEmployeeHandlePreview();
    return _generateContractorHandlePreview();
  }

  Future<void> _submitStudent() async {
    final first = _stuFirst.text.trim();
    final last = _stuLast.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _errorMessage = 'First name and last name are required.');
      return;
    }

    if (_availablePrograms.isEmpty || _stuProgram == null || _stuProgram!.isEmpty) {
      setState(() => _errorMessage = 'Cannot admit student: No degree programs configured. Please configure at least one degree program in Academic Management first.');
      return;
    }

    final initialPass = _autoGeneratePassword
        ? _generatedPassword
        : _initialPasswordController.text.trim();
    if (!_autoGeneratePassword && initialPass.length < 6) {
      setState(() => _errorMessage = 'Initial password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final email = _stuEmail.text.trim().isNotEmpty
        ? _stuEmail.text.trim()
        : '${first.toLowerCase()}_$_stuAdmissionYear@campus.edu';

    try {
      final user = await widget.storage.createStudent({
        'first_name': first,
        'last_name': last,
        'email': email,
        'personal_email': _stuPersonalEmail.text.trim(),
        'phone': _stuPhone.text.trim(),
        'gender': _stuGender != 'not_specified' ? _stuGender : null,
        'academic_name': _stuAcademicName.text.trim().isNotEmpty ? _stuAcademicName.text.trim() : null,
        'admission_year': _stuAdmissionYear,
        'entry_type': _stuEntryType,
        'program': _stuProgram!,
        if (_stuBranch != null && _stuBranch!.isNotEmpty) 'branch': _stuBranch,
        'admission_application_no': _stuAppNo.text.trim(),
        'university_roll_no': _stuRollNo.text.trim(),
        'university_reg_no': _stuRegNo.text.trim(),
        'section_scope': _stuSection.text.trim(),
        'advisor_name': _stuAdvisor.text.trim(),
        'initial_password': initialPass,
      });
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUserCreated(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitEmployee() async {
    final first = _empFirst.text.trim();
    final last = _empLast.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _errorMessage = 'First name and last name are required.');
      return;
    }

    if (!_empIsAcademic && !_empIsAdmin) {
      setState(() => _errorMessage = 'Employee must be affiliated with Academic track, Administrative track, or both.');
      return;
    }

    if (_empIsAcademic && (_availableDepartments.isEmpty || _empDept == null || _empDept!.isEmpty)) {
      setState(() => _errorMessage = 'Cannot affiliate academic employee: No academic departments configured. Please configure departments in Academic Management first.');
      return;
    }

    final initialPass = _autoGeneratePassword
        ? _generatedPassword
        : _initialPasswordController.text.trim();
    if (!_autoGeneratePassword && initialPass.length < 6) {
      setState(() => _errorMessage = 'Initial password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final email = _empEmail.text.trim().isNotEmpty
        ? _empEmail.text.trim()
        : '${first.toLowerCase()}_${_empJoiningYear}_emp@campus.edu';

    try {
      final user = await widget.storage.createEmployee({
        'first_name': first,
        'last_name': last,
        'email': email,
        'personal_email': _empPersonalEmail.text.trim(),
        'phone': _empPhone.text.trim(),
        'gender': _empGender != 'not_specified' ? _empGender : null,
        'joining_year': _empJoiningYear,
        'employment_type': _empType,
        'employee_code': _empCode.text.trim(),
        'is_academic': _empIsAcademic,
        'academic_rank': _empAcademicRank,
        'cabin_location': _empCabin.text.trim(),
        'department_affiliations': (_empDept != null && _empDept!.isNotEmpty) ? [_empDept!] : <String>[],
        'is_administrative': _empIsAdmin,
        'primary_unit': _empAdminUnit,
        'designation': _empDesignation.text.trim().isNotEmpty ? _empDesignation.text.trim() : '',
        'office_location': _empOffice.text.trim(),
        'initial_password': initialPass,
      });
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUserCreated(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitContractor() async {
    final first = _extFirst.text.trim();
    final last = _extLast.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _errorMessage = 'First name and last name are required.');
      return;
    }
    final vendor = _extVendorOrg.text.trim();
    if (vendor.isEmpty) {
      setState(() => _errorMessage = 'Vendor organization is required.');
      return;
    }

    final initialPass = _autoGeneratePassword
        ? _generatedPassword
        : _initialPasswordController.text.trim();
    if (!_autoGeneratePassword && initialPass.length < 6) {
      setState(() => _errorMessage = 'Initial password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final email = _extEmail.text.trim().isNotEmpty
        ? _extEmail.text.trim()
        : '${first.toLowerCase()}_${_extOnboardingYear}_ext@campus.edu';

    final scopes = _extScopes.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      final user = await widget.storage.createContractor({
        'first_name': first,
        'last_name': last,
        'email': email,
        'personal_email': _extPersonalEmail.text.trim(),
        'phone': _extPhone.text.trim(),
        'gender': _extGender != 'not_specified' ? _extGender : null,
        'onboarding_year': _extOnboardingYear,
        'vendor_organization': vendor,
        'service_type': _extServiceType,
        'gate_pass_id': _extGatePass.text.trim(),
        'supervisor_name': _extSupervisorName.text.trim(),
        'supervisor_phone': _extSupervisorPhone.text.trim(),
        'permitted_scopes': scopes,
        'initial_password': initialPass,
      });
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUserCreated(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Onboard New Campus Identity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Archetype Selector Tabs
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? AppColors.wineRed
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Student Admission',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 0
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? AppColors.wineRed
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Employee Onboarding',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 1
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTab = 2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 2
                                ? AppColors.wineRed
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Contractor / Vendor',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 2
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Dynamic Handle Preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.wineRedDarkSubtle : AppColors.wineRedSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.wineRedDarkBorder : AppColors.wineRedBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const AppSvgIcon(
                      svgString: AppSvgIcon.shield,
                      size: 14,
                      color: AppColors.wineRed,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Handle: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                      ),
                    ),
                    Flexible(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([_stuFirst, _empFirst, _extFirst]),
                        builder: (context, _) => Text(
                          _getCurrentHandlePreview(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Form fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _selectedTab == 0
                          ? _buildStudentForm(isDark)
                          : (_selectedTab == 1 ? _buildEmployeeForm(isDark) : _buildContractorForm(isDark)),
                      const SizedBox(height: 16),
                      _buildCredentialSetupSection(isDark),
                    ],
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: AppColors.statusRed),
                ),
              ],
              const SizedBox(height: 14),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wineRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : (_selectedTab == 0
                            ? _submitStudent
                            : (_selectedTab == 1 ? _submitEmployee : _submitContractor)),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_selectedTab == 0
                            ? 'Admit Student'
                            : (_selectedTab == 1 ? 'Onboard Employee' : 'Onboard Contractor')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField('First Name *', _stuFirst, 'Enter first name', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField('Last Name *', _stuLast, 'Enter last name', isDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                'Gender',
                _stuGender,
                ['not_specified', 'male', 'female', 'other', 'prefer_not_to_say'],
                (val) => setState(() => _stuGender = val!),
                isDark,
                itemLabels: const {
                  'not_specified': 'Select Gender (Optional)',
                  'male': 'Male',
                  'female': 'Female',
                  'other': 'Other',
                  'prefer_not_to_say': 'Prefer not to say',
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Academic Name (10th Record)',
                _stuAcademicName,
                'Official certificate name if different',
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField('Institutional Email (Optional)', _stuEmail, 'Auto-generated if empty', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField('Personal Email', _stuPersonalEmail, 'name@example.com', isDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField('Phone Number', _stuPhone, '+91 XXXXX XXXXX', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField('Admission Application No', _stuAppNo, 'Application reference no', isDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                'Admission Year',
                _stuAdmissionYear.toString(),
                _getAdmissionYears(),
                (val) => setState(() => _stuAdmissionYear = int.parse(val!)),
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                'Entry Type',
                _stuEntryType,
                ['regular', 'lateral', 'transfer'],
                (val) => setState(() => _stuEntryType = val!),
                isDark,
              ),
            ),
            if (_availablePrograms.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  'Degree Program',
                  _stuProgram ?? (_availablePrograms.first.code.isNotEmpty ? _availablePrograms.first.code : _availablePrograms.first.id),
                  _availablePrograms.map((p) => p.code.isNotEmpty ? p.code : p.id).toList(),
                  (val) {
                    if (val == null) return;
                    setState(() {
                      _stuProgram = val;
                      final pMatch = _availablePrograms.cast<ProgramModel?>().firstWhere(
                        (p) => p != null && (p.code.toLowerCase() == val.toLowerCase() || p.id.toLowerCase() == val.toLowerCase()),
                        orElse: () => null,
                      );
                      if (pMatch != null && pMatch.hasBranches && pMatch.branches.isNotEmpty) {
                        final act = pMatch.branches.where((b) => !b.isRetired).toList();
                        _stuBranch = act.isNotEmpty ? (act.first.code.isNotEmpty ? act.first.code : act.first.name) : null;
                      } else {
                        _stuBranch = null;
                      }
                    });
                  },
                  isDark,
                  itemLabels: {
                    for (final p in _availablePrograms)
                      (p.code.isNotEmpty ? p.code : p.id): '${p.name} (${p.code})',
                  },
                ),
              ),
            ],
          ],
        ),
        if (_availablePrograms.isEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF261E14) : const Color(0xFFFFF8E6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF7D5A1E) : const Color(0xFFF1D592),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSvgIcon(
                  svgString: AppSvgIcon.alertTriangle,
                  size: 20,
                  color: isDark ? const Color(0xFFE3B341) : const Color(0xFF9E6A03),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Degree Programs Configured',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFE3B341) : const Color(0xFF9E6A03),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No degree programs have been created yet. You must configure at least one degree program in Academic Management before admitting students.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_availablePrograms.isNotEmpty && _stuProgram != null) ...[
          () {
            final pMatch = _availablePrograms.cast<ProgramModel?>().firstWhere(
              (p) => p != null && (p.code.toLowerCase() == _stuProgram!.toLowerCase() || p.id.toLowerCase() == _stuProgram!.toLowerCase()),
              orElse: () => null,
            );
            if (pMatch != null && pMatch.hasBranches) {
              final act = pMatch.branches.where((b) => !b.isRetired).toList();
              if (act.isNotEmpty) {
                final currentBranch = _stuBranch ?? (act.first.code.isNotEmpty ? act.first.code : act.first.name);
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildDropdown(
                    'Branch / Discipline',
                    currentBranch,
                    act.map((b) => b.code.isNotEmpty ? b.code : b.name).toList(),
                    (val) => setState(() => _stuBranch = val),
                    isDark,
                    itemLabels: {
                      for (final b in act)
                        (b.code.isNotEmpty ? b.code : b.name): '${b.name} (${b.code})',
                    },
                  ),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No branches configured for this program. Student will be enrolled in core track.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                );
              }
            }
            return const SizedBox.shrink();
          }(),
        ],
      ],
    );
  }

  Widget _buildEmployeeForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField('First Name *', _empFirst, 'Enter first name', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField('Last Name *', _empLast, 'Enter last name', isDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField('Official Email (Optional)', _empEmail, 'Auto-generated if empty', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField('Personal Email', _empPersonalEmail, 'name@example.com', isDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField('Phone Number', _empPhone, '+91 XXXXX XXXXX', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                'Gender',
                _empGender,
                ['not_specified', 'male', 'female', 'other', 'prefer_not_to_say'],
                (val) => setState(() => _empGender = val!),
                isDark,
                itemLabels: const {
                  'not_specified': 'Select Gender (Optional)',
                  'male': 'Male',
                  'female': 'Female',
                  'other': 'Other',
                  'prefer_not_to_say': 'Prefer not to say',
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                'Joining Year',
                _empJoiningYear.toString(),
                _getJoiningYears(),
                (val) => setState(() => _empJoiningYear = int.parse(val!)),
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                'Employment Type',
                _empType,
                ['permanent', 'contract', 'visiting'],
                (val) => setState(() => _empType = val!),
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Dual Track Selectors
        const Text(
          'Institutional Tracks (Single or Dual-Track Appointment)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Academic Track Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F242C) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Academic Track (Teaching & Research duties)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enables academic rank and faculty course assignments',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('switch-employee-academic-track'),
                value: _empIsAcademic,
                activeThumbColor: const Color(0xFF0969DA),
                onChanged: (val) => setState(() => _empIsAcademic = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_empIsAcademic) ...[
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_availableDepartments.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF261E14) : const Color(0xFFFFF8E6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF7D5A1E) : const Color(0xFFF1D592),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSvgIcon(
                          svgString: AppSvgIcon.alertTriangle,
                          size: 20,
                          color: isDark ? const Color(0xFFE3B341) : const Color(0xFF9E6A03),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Academic Departments Configured',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFE3B341) : const Color(0xFF9E6A03),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No academic departments have been created yet. Please create a department in Academic Management before affiliating faculty members.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    if (_availableDepartments.isNotEmpty) ...[
                      Expanded(
                        child: _buildDropdown(
                          'Department Affiliation',
                          _empDept ?? (_availableDepartments.first.code.isNotEmpty ? 'dept:${_availableDepartments.first.code.toLowerCase()}' : _availableDepartments.first.id),
                          _availableDepartments.map((d) => d.code.isNotEmpty ? 'dept:${d.code.toLowerCase()}' : d.id).toList(),
                          (val) => setState(() => _empDept = val!),
                          isDark,
                          itemLabels: {
                            for (final d in _availableDepartments)
                              (d.code.isNotEmpty ? 'dept:${d.code.toLowerCase()}' : d.id): '${d.name} (${d.code})',
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _buildDropdown(
                        'Academic Rank',
                        _empAcademicRank,
                        [
                          'Assistant Professor',
                          'Associate Professor',
                          'Professor',
                          'Lecturer',
                          'Head of Department (HOD)',
                          'Dean / Director',
                        ],
                        (val) => setState(() => _empAcademicRank = val!),
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTextField('Cabin Location', _empCabin, 'Cabin / Room number', isDark),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Administrative Track Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F242C) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Administrative Track (Operations & Governance duties)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enables administrative unit, designation, and governance roles',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('switch-employee-admin-track'),
                value: _empIsAdmin,
                activeThumbColor: const Color(0xFF0969DA),
                onChanged: (val) => setState(() => _empIsAdmin = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_empIsAdmin) ...[
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'Primary Administrative Unit',
                        _empAdminUnit,
                        [
                          'unit:student_affairs',
                          'unit:security',
                          'unit:registrar',
                          'unit:library',
                          'unit:it_center',
                          'unit:finance',
                          'unit:examination',
                          'unit:estate_maintenance',
                        ],
                        (val) => setState(() => _empAdminUnit = val!),
                        isDark,
                        itemLabels: const {
                          'unit:student_affairs': 'Student Affairs',
                          'unit:security': 'Security & Safety Office',
                          'unit:registrar': 'Registrar & Academic Secretariat',
                          'unit:library': 'Central University Library',
                          'unit:it_center': 'Information Technology & Computing',
                          'unit:finance': 'Finance & Accounts Office',
                          'unit:examination': 'Examination & Evaluation Cell',
                          'unit:estate_maintenance': 'Estate & Campus Maintenance',
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField('Designation', _empDesignation, 'Administrative designation', isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTextField('Office Location', _empOffice, 'Office room location', isDark),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContractorForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField('First Name *', _extFirst, 'Enter first name', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField('Last Name *', _extLast, 'Enter last name', isDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'Gender',
          _extGender,
          ['not_specified', 'male', 'female', 'other', 'prefer_not_to_say'],
          (val) => setState(() => _extGender = val!),
          isDark,
          itemLabels: const {
            'not_specified': 'Select Gender (Optional)',
            'male': 'Male',
            'female': 'Female',
            'other': 'Other',
            'prefer_not_to_say': 'Prefer not to say',
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField('Vendor Organization / Firm *', _extVendorOrg, 'Organization / Agency name', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                'Service Category',
                _extServiceType,
                ['canteen', 'mess', 'cleaning', 'security', 'transport', 'maintenance', 'lab_vendor'],
                (val) => setState(() => _extServiceType = val!),
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField('Gate Pass / Security Badge ID', _extGatePass, 'Badge ID (Auto if empty)', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                'Onboarding Year',
                _extOnboardingYear.toString(),
                _getOnboardingYears(),
                (val) => setState(() => _extOnboardingYear = int.parse(val!)),
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField('Contact Phone', _extPhone, '+91 XXXXX XXXXX', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField('Official / Vendor Email', _extEmail, 'Auto-generated if empty', isDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField('Site Supervisor Name', _extSupervisorName, 'Supervisor name', isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField('Supervisor Phone', _extSupervisorPhone, '+91 XXXXX XXXXX', isDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField('Permitted Access Zones / Gate Scopes', _extScopes, 'e.g. gate:main, building:admin', isDark),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.1),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder, letterSpacing: -0.1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
    bool isDark, {
    Map<String, String>? itemLabels,
  }) {
    final effectiveValue = options.contains(value) ? value : (options.isNotEmpty ? options.first : value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        AppDropdown<String>(
          value: effectiveValue,
          items: options.map((opt) {
            return AppDropdownItem<String>(
              value: opt,
              label: itemLabels?[opt] ?? opt.toUpperCase(),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildCredentialSetupSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(6),
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
            runSpacing: 4,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSvgIcon(
                    svgString: AppSvgIcon.shield,
                    size: 14,
                    color: AppColors.wineRed,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Initial Account Credentials',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.wineRedDarkSubtle : AppColors.wineRedSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? AppColors.wineRedDarkBorder : AppColors.wineRedBorder,
                  ),
                ),
                child: const Text(
                  'Password Change Mandatory',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.wineRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _autoGeneratePassword,
                  activeColor: AppColors.wineRed,
                  onChanged: (val) {
                    setState(() {
                      _autoGeneratePassword = val ?? true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _autoGeneratePassword = !_autoGeneratePassword;
                    });
                  },
                  child: const Text(
                    'Auto-generate secure temporary password',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_autoGeneratePassword) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _generatedPassword,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _generatedPassword = _makeSecureTempPassword();
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppSvgIcon(
                            svgString: AppSvgIcon.refresh,
                            size: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Regenerate',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Custom Initial Password *',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _initialPasswordController,
                    obscureText: _obscureInitialPassword,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter temporary password (min 6 chars)',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: AppSvgIcon(
                          svgString: _obscureInitialPassword ? AppSvgIcon.eye : AppSvgIcon.eyeOff,
                          size: 14,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureInitialPassword = !_obscureInitialPassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'The created user will use this temporary password to log in once, and will be required to choose a new password immediately.',
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCredentialsDialog extends StatefulWidget {
  final UserModel user;

  const _UserCredentialsDialog({
    required this.user,
  });

  @override
  State<_UserCredentialsDialog> createState() => _UserCredentialsDialogState();
}

class _UserCredentialsDialogState extends State<_UserCredentialsDialog> {
  bool _obscurePassword = true;

  String get _effectivePassword =>
      widget.user.initialPassword ?? widget.user.campusHandle;

  void _copyToClipboard(BuildContext context, String label, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.githubGreen,
      ),
    );
  }

  void _copyAllCredentials(BuildContext context) {
    final buffer = StringBuffer()
      ..writeln('Institutional Campus Management Credentials')
      ..writeln('===========================================')
      ..writeln('Full Name: ${widget.user.fullName}')
      ..writeln('Archetype: ${widget.user.archetype.toUpperCase()}')
      ..writeln('Username (Campus Handle): ${widget.user.campusHandle}')
      ..writeln('Institutional Email: ${widget.user.email}')
      ..writeln('Temporary Password: $_effectivePassword')
      ..writeln('===========================================')
      ..writeln('Note: Password change is strictly required upon first login.');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All credentials copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.githubGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.githubGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const AppSvgIcon(
                      svgString: AppSvgIcon.check,
                      size: 18,
                      color: AppColors.githubGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Created Successfully',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Credentials have been generated for ${widget.user.fullName}.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Mandatory Password Notice Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.wineRedDarkSubtle : AppColors.wineRedSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.wineRedDarkBorder : AppColors.wineRedBorder,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSvgIcon(
                      svgString: AppSvgIcon.shield,
                      size: 16,
                      color: AppColors.wineRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mandatory First-Login Password Change',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.wineRed,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'The user will be required to establish their own permanent, secure password immediately upon first sign-in before accessing institutional tools.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Credentials Table
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    _buildCredentialRow(
                      context,
                      label: 'Campus Handle (Username)',
                      value: widget.user.campusHandle,
                      isMonospace: true,
                      isDark: isDark,
                      onCopy: () => _copyToClipboard(context, 'Campus Handle', widget.user.campusHandle),
                    ),
                    Divider(height: 1, thickness: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    _buildCredentialRow(
                      context,
                      label: 'Institutional Email',
                      value: widget.user.email,
                      isDark: isDark,
                      onCopy: () => _copyToClipboard(context, 'Email', widget.user.email),
                    ),
                    Divider(height: 1, thickness: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    _buildCredentialRow(
                      context,
                      label: 'Temporary Password',
                      value: _effectivePassword,
                      isMonospace: true,
                      isPassword: true,
                      obscured: _obscurePassword,
                      onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                      isDark: isDark,
                      onCopy: () => _copyToClipboard(context, 'Temporary Password', _effectivePassword),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const AppSvgIcon(svgString: AppSvgIcon.copy, size: 13),
                    label: const Text('Copy All Credentials', style: TextStyle(fontSize: 12)),
                    onPressed: () => _copyAllCredentials(context),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wineRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isMonospace = false,
    bool isPassword = false,
    bool obscured = false,
    VoidCallback? onToggleObscure,
    required bool isDark,
    required VoidCallback onCopy,
  }) {
    final displayValue = isPassword && obscured ? '••••••••••••' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: isMonospace ? 'monospace' : null,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isPassword && onToggleObscure != null) ...[
            IconButton(
              tooltip: obscured ? 'Show password' : 'Hide password',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: AppSvgIcon(
                svgString: obscured ? AppSvgIcon.eye : AppSvgIcon.eyeOff,
                size: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              onPressed: onToggleObscure,
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: 'Copy $label',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: AppSvgIcon(
              svgString: AppSvgIcon.copy,
              size: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
