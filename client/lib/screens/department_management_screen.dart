import 'dart:async';
import 'package:flutter/material.dart';
import '../models/academic.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/app_skeleton.dart';

class DepartmentManagementScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;

  const DepartmentManagementScreen({
    super.key,
    required this.storage,
    this.currentUser,
  });

  @override
  State<DepartmentManagementScreen> createState() => _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState extends State<DepartmentManagementScreen> {
  List<DepartmentModel> _departments = [];
  List<SectionModel> _sections = [];
  List<ProgramModel> _programs = [];
  List<SubjectModel> _subjects = [];
  List<SemesterModel> _semesters = [];
  List<UserModel> _teachers = [];

  List<DepartmentModel> _cachedFilteredDepts = [];
  List<SectionModel> _cachedFilteredSecs = [];
  List<SubjectModel> _cachedFilteredSubs = [];
  int _aliasedSubjectsCount = 0;
  int _activeSyllabusCount = 0;
  Timer? _searchDebounce;

  PageLoadState _loadState = PageLoadState.pending;
  String? _errorMessage;
  String _searchQuery = '';
  int _selectedTab = 0; // 0 = Departments, 1 = Cross-Program Sections

  void _recomputeMetrics() {
    int aliased = 0;
    int syllabus = 0;
    for (final s in _subjects) {
      if ((s.oddSemCode != null && s.oddSemCode!.isNotEmpty) || (s.evenSemCode != null && s.evenSemCode!.isNotEmpty)) {
        aliased++;
      }
      if (s.activeSyllabus != null) {
        syllabus++;
      }
    }
    _aliasedSubjectsCount = aliased;
    _activeSyllabusCount = syllabus;
  }

  void _recomputeFilteredLists() {
    if (_searchQuery.trim().isEmpty) {
      _cachedFilteredDepts = _departments;
      _cachedFilteredSecs = _sections;
      _cachedFilteredSubs = _subjects;
      return;
    }
    final q = _searchQuery.toLowerCase().trim();
    _cachedFilteredDepts = _departments.where((d) {
      return d.name.toLowerCase().contains(q) ||
          d.code.toLowerCase().contains(q) ||
          (d.hodName != null && d.hodName!.toLowerCase().contains(q));
    }).toList();
    _cachedFilteredSecs = _sections.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.displayName.toLowerCase().contains(q) ||
          s.programNames.any((p) => p.toLowerCase().contains(q));
    }).toList();
    _cachedFilteredSubs = _subjects.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q) ||
          (s.oddSemCode != null && s.oddSemCode!.toLowerCase().contains(q)) ||
          (s.evenSemCode != null && s.evenSemCode!.toLowerCase().contains(q));
    }).toList();
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _searchQuery = val;
          _recomputeFilteredLists();
        });
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = '';
      _recomputeFilteredLists();
    });
  }

  @override
  void initState() {
    super.initState();
    final cachedDepts = widget.storage.cachedDepartments;
    if (cachedDepts.isNotEmpty) {
      _departments = List.from(cachedDepts);
      _sections = List.from(widget.storage.cachedSections);
      _programs = List.from(widget.storage.cachedPrograms);
      _subjects = List.from(widget.storage.cachedSubjects);
      _semesters = List.from(widget.storage.cachedSemesters);
      final users = widget.storage.cachedUsers;
      _teachers = users.where((u) => u.archetype == 'employee').toList();
      _recomputeMetrics();
      _recomputeFilteredLists();
      _loadState = PageLoadState.success;
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_departments.isEmpty) {
      setState(() {
        _loadState = PageLoadState.pending;
        _errorMessage = null;
      });
    }
    try {
      final depts = await widget.storage.getDepartments(forceRefresh: true);
      final secs = await widget.storage.getSections();
      final progs = await widget.storage.getPrograms();
      final subs = await widget.storage.getSubjects();
      final sems = await widget.storage.getSemesters();

      final users = widget.storage.cachedUsers;
      final faculty = users.where((u) => u.archetype == 'employee').toList();

      if (mounted) {
        setState(() {
          _departments = depts;
          _sections = secs;
          _programs = progs;
          _subjects = subs;
          _semesters = sems;
          _teachers = faculty;
          _recomputeMetrics();
          _recomputeFilteredLists();
          _loadState = PageLoadState.success;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_departments.isEmpty) {
            _loadState = PageLoadState.failed;
            _errorMessage = 'Failed to load department structure. Check network connection.';
          }
        });
      }
    }
  }

  List<DepartmentModel> get _filteredDepartments => _cachedFilteredDepts;
  List<SectionModel> get _filteredSections => _cachedFilteredSecs;
  List<SubjectModel> get _filteredSubjects => _cachedFilteredSubs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.wineRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Bar with Title and Primary Action (Always mounted)
              _buildHeader(isDark),
              const SizedBox(height: 18),

              // View Toggle (Departments vs Cross-Program Sections)
              _buildViewToggle(isDark),
              const SizedBox(height: 20),

              // Academic Metrics Strip
              _buildMetricsRow(isDark),
              const SizedBox(height: 24),

              // Search Bar
              _buildSearchBar(isDark),
              const SizedBox(height: 20),

              // Active Content: Skeleton / Error / Live Data
              if (_loadState == PageLoadState.pending) ...[
                _buildDepartmentSkeletons(isDark),
              ] else if (_loadState == PageLoadState.failed) ...[
                InlineStateError(
                  message: _errorMessage ?? 'Failed to load department management records.',
                  onRetry: _loadData,
                ),
              ] else ...[
                if (_selectedTab == 0) ...[
                  if (_filteredDepartments.isEmpty)
                    _buildEmptyState(isDark)
                  else
                    _buildDepartmentsGrid(isDark),
                ] else if (_selectedTab == 1) ...[
                  if (_filteredSections.isEmpty)
                    _buildEmptySectionState(isDark)
                  else
                    _buildSectionsGrid(isDark),
                ] else ...[
                  if (_filteredSubjects.isEmpty)
                    _buildEmptySubjectState(isDark)
                  else
                    _buildSubjectsGrid(isDark),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final String title;
    final String subtitle;
    final String icon;
    final Color color;
    final String buttonLabel;
    final VoidCallback buttonAction;

    if (_selectedTab == 0) {
      title = 'Academic Departments & Structure';
      subtitle = 'Manage departments, associated courses, faculty allocations, and degree cohorts';
      icon = AppSvgIcon.building;
      color = AppColors.wineRed;
      buttonLabel = 'Add Department';
      buttonAction = _openAddDepartmentDialog;
    } else if (_selectedTab == 1) {
      title = 'Cross-Program Sections & Cohorts';
      subtitle = 'Manage shared semester divisions with multi-program student cohorts and common curricula';
      icon = AppSvgIcon.layers;
      color = const Color(0xFF8250DF);
      buttonLabel = 'Add Shared Section';
      buttonAction = _openAddSectionDialog;
    } else {
      title = 'Curriculum Subjects & Syllabus Audit';
      subtitle = 'Odd/even term code aliasing (e.g. BCA 102/202) and immutable BoS accreditation audit trail';
      icon = AppSvgIcon.book;
      color = AppColors.githubGreen;
      buttonLabel = 'Add Academic Subject';
      buttonAction = _openAddSubjectDialog;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        final titleCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppSvgIcon(
                  svgString: icon,
                  size: 24,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

        final actionButtons = Row(
          mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (_selectedTab == 1) ...[
              OutlinedButton.icon(
                key: const Key('btn-faculty-workload-header'),
                onPressed: _openFacultyWorkloadDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const AppSvgIcon(svgString: AppSvgIcon.clock, size: 16, color: Color(0xFF8250DF)),
                label: const Text(
                  'Workload',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
            ],
            isNarrow
                ? Expanded(
                    child: ElevatedButton.icon(
                      onPressed: buttonAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 16, color: Colors.white),
                      label: Text(
                        buttonLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: buttonAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 16, color: Colors.white),
                    label: Text(
                      buttonLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleCol,
              const SizedBox(height: 12),
              actionButtons,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: titleCol),
            const SizedBox(width: 16),
            actionButtons,
          ],
        );
      },
    );
  }

  Widget _buildViewToggle(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _buildToggleButton(
            title: 'Academic Departments (${_departments.length})',
            icon: AppSvgIcon.building,
            isSelected: _selectedTab == 0,
            activeColor: AppColors.wineRed,
            isDark: isDark,
            onTap: () {
              setState(() => _selectedTab = 0);
              _clearSearch();
            },
          ),
          _buildToggleButton(
            title: 'Cross-Program Sections (${_sections.length})',
            icon: AppSvgIcon.layers,
            isSelected: _selectedTab == 1,
            activeColor: const Color(0xFF8250DF),
            isDark: isDark,
            onTap: () {
              setState(() => _selectedTab = 1);
              _clearSearch();
            },
          ),
          _buildToggleButton(
            title: 'Subjects & Syllabi (${_subjects.length})',
            icon: AppSvgIcon.book,
            isSelected: _selectedTab == 2,
            activeColor: AppColors.githubGreen,
            isDark: isDark,
            onTap: () {
              setState(() => _selectedTab = 2);
              _clearSearch();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required String icon,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? activeColor.withValues(alpha: 0.22) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: activeColor, width: 1)
              : null,
          boxShadow: (isSelected && !isDark)
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSvgIcon(
              svgString: icon,
              size: 15,
              color: isSelected
                  ? activeColor
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : activeColor)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(bool isDark) {
    final totalSubjects = _subjects.length;
    final totalTeachers = _teachers.length;
    final totalSemesters = _semesters.length;
    final totalSections = _sections.length;
    final aliasedSubjectsCount = _aliasedSubjectsCount;
    final activeSyllabusCount = _activeSyllabusCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final Widget card1;
        final Widget card2;
        final Widget card3;
        final Widget card4;

        if (_selectedTab == 0) {
          card1 = _buildMetricCard(
            title: 'Departments',
            count: _departments.length.toString(),
            subtitle: '${_programs.length} degree programs',
            icon: AppSvgIcon.building,
            color: AppColors.wineRed,
            isDark: isDark,
          );
          card2 = _buildMetricCard(
            title: 'Course Subjects',
            count: totalSubjects.toString(),
            subtitle: 'Catalog course modules',
            icon: AppSvgIcon.book,
            color: AppColors.githubGreen,
            isDark: isDark,
          );
          card3 = _buildMetricCard(
            title: 'Faculty Members',
            count: totalTeachers.toString(),
            subtitle: 'Teaching affiliations',
            icon: AppSvgIcon.user,
            color: const Color(0xFF0969DA),
            isDark: isDark,
          );
          card4 = _buildMetricCard(
            title: 'Academic Semesters',
            count: totalSemesters.toString(),
            subtitle: 'Active program cohorts',
            icon: AppSvgIcon.layers,
            color: const Color(0xFF8250DF),
            isDark: isDark,
          );
        } else if (_selectedTab == 1) {
          card1 = _buildMetricCard(
            title: 'Shared Sections',
            count: totalSections.toString(),
            subtitle: 'Multi-program cohorts',
            icon: AppSvgIcon.layers,
            color: const Color(0xFF8250DF),
            isDark: isDark,
          );
          card2 = _buildMetricCard(
            title: 'Degree Programs',
            count: _programs.length.toString(),
            subtitle: 'Degree specializations',
            icon: AppSvgIcon.userCheck,
            color: AppColors.githubGreen,
            isDark: isDark,
          );
          card3 = _buildMetricCard(
            title: 'Faculty Members',
            count: totalTeachers.toString(),
            subtitle: 'Cross-disciplinary faculty',
            icon: AppSvgIcon.user,
            color: const Color(0xFF0969DA),
            isDark: isDark,
          );
          card4 = _buildMetricCard(
            title: 'Core Curriculum',
            count: totalSubjects.toString(),
            subtitle: 'Shared & elective courses',
            icon: AppSvgIcon.book,
            color: AppColors.wineRed,
            isDark: isDark,
          );
        } else {
          card1 = _buildMetricCard(
            title: 'Curriculum Subjects',
            count: totalSubjects.toString(),
            subtitle: 'Catalog course modules',
            icon: AppSvgIcon.book,
            color: AppColors.githubGreen,
            isDark: isDark,
          );
          card2 = _buildMetricCard(
            title: 'Odd/Even Aliased',
            count: aliasedSubjectsCount.toString(),
            subtitle: 'e.g. BCA 102 / 202',
            icon: AppSvgIcon.refresh,
            color: const Color(0xFF0969DA),
            isDark: isDark,
          );
          card3 = _buildMetricCard(
            title: 'Active Curricula',
            count: activeSyllabusCount.toString(),
            subtitle: 'Current BoS schemes',
            icon: AppSvgIcon.shield,
            color: AppColors.wineRed,
            isDark: isDark,
          );
          card4 = _buildMetricCard(
            title: 'Historical Archive',
            count: 'Immutable',
            subtitle: 'NAAC / NBA Audit Trail',
            icon: AppSvgIcon.clock,
            color: const Color(0xFF8250DF),
            isDark: isDark,
          );
        }

        if (isWide) {
          return Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 12),
              Expanded(child: card2),
              const SizedBox(width: 12),
              Expanded(child: card3),
              const SizedBox(width: 12),
              Expanded(child: card4),
            ],
          );
        }

        final halfWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: halfWidth, child: card1),
            SizedBox(width: halfWidth, child: card2),
            SizedBox(width: halfWidth, child: card3),
            SizedBox(width: halfWidth, child: card4),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required String subtitle,
    required String icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
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
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AppSvgIcon(svgString: icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    String hintText;
    if (_selectedTab == 0) {
      hintText = 'Search department by name, code (e.g. CSE, ECE) or HOD...';
    } else if (_selectedTab == 1) {
      hintText = 'Search section by name (e.g. Section B), cohort, or degree program...';
    } else {
      hintText = 'Search subjects by code (e.g. BCA 102/202, CS301), odd/even code, or title...';
    }

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: TextField(
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 13,
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
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildDepartmentsGrid(bool isDark) {
    final depts = _filteredDepartments;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1100 ? 3 : (constraints.maxWidth > 640 ? 2 : 1);
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: depts.map((dept) {
            return SizedBox(
              width: itemWidth,
              child: _buildDepartmentCard(dept, isDark),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDepartmentCard(DepartmentModel dept, bool isDark) {
    final primaryBadge = AppColors.primaryBadge(isDark);
    final greenBadge = AppColors.greenBadge(isDark);
    final neutralBadge = AppColors.neutralBadge(isDark);

    return Container(
      padding: const EdgeInsets.all(18),
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
          // Header with Code badge & HOD
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryBadge.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: primaryBadge.border, width: 1),
                ),
                child: Text(
                  dept.code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryBadge.text,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (dept.hodName != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const AppSvgIcon(svgString: AppSvgIcon.userCheck, size: 12, color: AppColors.githubGreen),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'HOD: ${dept.hodName}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Department Name
          Text(
            dept.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            dept.description.isNotEmpty ? dept.description : 'Academic discipline offering multidisciplinary courses and faculty research.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Many-to-Many Quantitative Indicators
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildCountChip(
                label: '${dept.subjectCount} Subjects',
                icon: AppSvgIcon.book,
                style: greenBadge,
              ),
              _buildCountChip(
                label: '${dept.teacherCount} Faculty',
                icon: AppSvgIcon.user,
                style: neutralBadge,
              ),
              _buildCountChip(
                label: '${dept.semesterCount} Semesters',
                icon: AppSvgIcon.layers,
                style: primaryBadge,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Manage & Hierarchy inspector button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openDepartmentDetails(dept),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 9),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const AppSvgIcon(svgString: AppSvgIcon.info, size: 13),
              label: const Text('View Hierarchy & Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip({
    required String label,
    required String icon,
    required BadgeStyle style,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: style.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSvgIcon(svgString: icon, size: 11, color: style.text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: style.text),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentSkeletons(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(crossAxisCount * 2, (index) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: const EdgeInsets.all(18),
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
                      children: const [
                        AppSkeleton(width: 50, height: 18, borderRadius: 4),
                        Spacer(),
                        AppSkeleton(width: 80, height: 14, borderRadius: 4),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const AppSkeleton(width: 160, height: 16, borderRadius: 4),
                    const SizedBox(height: 8),
                    const AppSkeleton.rect(height: 12, borderRadius: 4),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        AppSkeleton(width: 70, height: 22, borderRadius: 4),
                        SizedBox(width: 8),
                        AppSkeleton(width: 70, height: 22, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const AppSvgIcon(svgString: AppSvgIcon.building, size: 40, color: AppColors.lightTextMuted),
            const SizedBox(height: 12),
            Text(
              'No matching departments found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search query or add a new department',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySectionState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const AppSvgIcon(svgString: AppSvgIcon.layers, size: 40, color: Color(0xFF8250DF)),
            const SizedBox(height: 12),
            Text(
              'No matching shared sections found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search query or add a cross-program section cohort',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionsGrid(bool isDark) {
    final secs = _filteredSections;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: secs.map((sec) {
            return SizedBox(
              width: itemWidth,
              child: _buildSectionCard(sec, isDark),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSectionCard(SectionModel sec, bool isDark) {
    final purpleBadge = BadgeStyle(
      background: const Color(0xFF8250DF).withValues(alpha: 0.12),
      border: const Color(0xFF8250DF).withValues(alpha: 0.4),
      text: const Color(0xFF8250DF),
    );
    final primaryBadge = AppColors.primaryBadge(isDark);
    final greenBadge = AppColors.greenBadge(isDark);
    final neutralBadge = AppColors.neutralBadge(isDark);

    return Container(
      padding: const EdgeInsets.all(18),
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
          // Header with Section Name and Semester badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: purpleBadge.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: purpleBadge.border, width: 1),
                ),
                child: Text(
                  sec.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: purpleBadge.text,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppSvgIcon(svgString: AppSvgIcon.layers, size: 12, color: Color(0xFF8250DF)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Sem ${sec.semesterNumber} (${sec.academicYear})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title & Cross-Program Description
          Text(
            sec.displayName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'Cross-program cohort: Students share classroom division & common core subjects.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Cross-Program Badges (e.g. CSE, AIML, DS)
          const Text(
            'ENROLLED DEGREE PROGRAMS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF8250DF)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sec.programNames.map((pName) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF8250DF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF8250DF).withValues(alpha: 0.3)),
                ),
                child: Text(
                  pName,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8250DF)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Counts Row: Subjects, Faculty, Students
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCountChip(
                label: '${sec.subjectIds.length} Subjects',
                icon: AppSvgIcon.book,
                style: greenBadge,
              ),
              _buildCountChip(
                label: '${sec.teacherIds.length} Faculty',
                icon: AppSvgIcon.user,
                style: neutralBadge,
              ),
              _buildCountChip(
                label: '${sec.studentCount} Students',
                icon: AppSvgIcon.userCheck,
                style: primaryBadge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openSectionDetails(sec),
              icon: const AppSvgIcon(svgString: AppSvgIcon.layers, size: 14, color: Color(0xFF8250DF)),
              label: const Text(
                'Inspect Section Cohort',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8250DF),
                side: const BorderSide(color: Color(0xFF8250DF), width: 1),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ADD DEPARTMENT DIALOG (WITH M:N MULTI-SELECT CHIPS)
  // ---------------------------------------------------------------------------

  void _openAddDepartmentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddDepartmentDialog(
        storage: widget.storage,
        subjects: _subjects,
        semesters: _semesters,
        teachers: _teachers,
        onCreated: (dept) {
          setState(() {
            _departments.removeWhere((d) => d.id == dept.id);
            _departments.insert(0, dept);
          });
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ADD SECTION DIALOG (WITH MULTI-PROGRAM SELECTION)
  // ---------------------------------------------------------------------------

  void _openAddSectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddSectionDialog(
        storage: widget.storage,
        programs: _programs,
        subjects: _subjects,
        teachers: _teachers,
        onCreated: (sec) {
          setState(() {
            _sections.removeWhere((s) => s.id == sec.id);
            _sections.insert(0, sec);
          });
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DEPARTMENT DETAILS INSPECTOR (SHOWS M:N RELATIONS & ENROLLED STUDENTS)
  // ---------------------------------------------------------------------------

  void _openDepartmentDetails(DepartmentModel dept) async {
    showDialog(
      context: context,
      builder: (ctx) => _DepartmentDetailDialog(
        storage: widget.storage,
        department: dept,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION DETAILS INSPECTOR (SHOWS MULTI-PROGRAM COHORT & CURRICULUM ALLOCATION)
  // ---------------------------------------------------------------------------

  void _openSectionDetails(SectionModel sec) {
    showDialog(
      context: context,
      builder: (ctx) => _SectionDetailDialog(
        storage: widget.storage,
        section: sec,
      ),
    );
  }

  void _openFacultyWorkloadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _FacultyWorkloadDialog(
        storage: widget.storage,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUBJECTS & SYLLABUS AUDIT ACTIONS & GRIDS
  // ---------------------------------------------------------------------------

  void _openAddSubjectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddSubjectDialog(
        storage: widget.storage,
        onCreated: (sub) {
          setState(() {
            _subjects.removeWhere((s) => s.id == sub.id);
            _subjects.insert(0, sub);
          });
        },
      ),
    );
  }

  void _openSyllabusAuditDialog(SubjectModel subject) {
    showDialog(
      context: context,
      builder: (ctx) => _SyllabusAuditDialog(
        storage: widget.storage,
        subject: subject,
        onRevised: _loadData,
      ),
    );
  }

  void _openReviseSyllabusDialog(SubjectModel subject) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ReviseSyllabusDialog(
        storage: widget.storage,
        subject: subject,
        onRevised: _loadData,
      ),
    );
  }

  Widget _buildEmptySubjectState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.githubGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const AppSvgIcon(
              svgString: AppSvgIcon.book,
              size: 32,
              color: AppColors.githubGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No subjects matching "$_searchQuery"' : 'No academic subjects registered',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try searching by a different term code, subject name, or semester aliasing.'
                : 'Register academic subjects, configure odd/even semester codes, and archive syllabi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openAddSubjectDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.githubGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 14, color: Colors.white),
              label: const Text('Add Academic Subject'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectsGrid(bool isDark) {
    final subs = _filteredSubjects;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: subs.map((sub) {
            return SizedBox(
              width: itemWidth,
              child: _buildSubjectCard(sub, isDark),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSubjectCard(SubjectModel sub, bool isDark) {
    final hasOddEven = (sub.oddSemCode != null && sub.oddSemCode!.isNotEmpty) ||
        (sub.evenSemCode != null && sub.evenSemCode!.isNotEmpty);

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.githubGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const AppSvgIcon(
                        svgString: AppSvgIcon.book,
                        size: 16,
                        color: AppColors.githubGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.code,
                            key: ValueKey('subject_code_${sub.id}'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            sub.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.wineRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${sub.credits} Credits',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.wineRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cycle Aliasing Badges (Odd vs Even Semesters)
          if (hasOddEven) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppSvgIcon(svgString: AppSvgIcon.refresh, size: 12, color: Color(0xFF0969DA)),
                      const SizedBox(width: 6),
                      const Text(
                        'Semester Cycle Aliasing',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0969DA)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (sub.oddSemCode != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0969DA).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Odd Sem (1,3,5): ${sub.oddSemCode}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0969DA)),
                          ),
                        ),
                      if (sub.evenSemCode != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8250DF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Even Sem (2,4,6): ${sub.evenSemCode}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF8250DF)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Active Syllabus Summary
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const AppSvgIcon(svgString: AppSvgIcon.shield, size: 13, color: AppColors.githubGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sub.activeSyllabus != null
                        ? 'Scheme: ${sub.activeSyllabus!.revisionCode} (Eff. ${sub.activeSyllabus!.effectiveFromYear})'
                        : 'Curriculum Scheme: Standard BoS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Actions Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openSyllabusAuditDialog(sub),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const AppSvgIcon(svgString: AppSvgIcon.book, size: 14),
                  label: const Text('Syllabus Audit & History', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openReviseSyllabusDialog(sub),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.githubGreen,
                  side: const BorderSide(color: AppColors.githubGreen),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 14, color: AppColors.githubGreen),
                label: const Text('Revise', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ADD DEPARTMENT DIALOG IMPLEMENTATION
// -----------------------------------------------------------------------------

class _AddDepartmentDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final List<SubjectModel> subjects;
  final List<SemesterModel> semesters;
  final List<UserModel> teachers;
  final ValueChanged<DepartmentModel> onCreated;

  const _AddDepartmentDialog({
    required this.storage,
    required this.subjects,
    required this.semesters,
    required this.teachers,
    required this.onCreated,
  });

  @override
  State<_AddDepartmentDialog> createState() => _AddDepartmentDialogState();
}

class _AddDepartmentDialogState extends State<_AddDepartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedHODId;
  final Set<String> _selectedSubjectIds = {};
  final Set<String> _selectedTeacherIds = {};
  final Set<String> _selectedSemesterIds = {};

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'code': _codeController.text.trim().toUpperCase(),
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'hod_id': _selectedHODId,
        'subject_ids': _selectedSubjectIds.toList(),
        'teacher_ids': _selectedTeacherIds.toList(),
        'semester_ids': _selectedSemesterIds.toList(),
      };

      final created = await widget.storage.addDepartment(payload);
      widget.onCreated(created);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const AppSvgIcon(svgString: AppSvgIcon.building, size: 20, color: AppColors.wineRed),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Add Academic Department',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.statusRedSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.statusRed, width: 1),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: AppColors.statusRed, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Code & Name
                        Row(
                          children: [
                            SizedBox(
                              width: 140,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Code *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _codeController,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: const InputDecoration(hintText: 'e.g. CSE'),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Department Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(hintText: 'e.g. Computer Science & Engineering'),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Description
                        const Text('Overview / Mission', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _descController,
                          maxLines: 2,
                          decoration: const InputDecoration(hintText: 'Discipline scope, research labs, or department purpose...'),
                        ),
                        const SizedBox(height: 14),

                        // Head of Department
                        const Text('Head of Department (HOD)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        AppDropdown<String?>(
                          value: _selectedHODId,
                          hint: 'No HOD assigned yet',
                          items: [
                            const AppDropdownItem<String?>(
                              value: null,
                              label: 'No HOD assigned yet',
                            ),
                            ...widget.teachers.map((t) => AppDropdownItem<String?>(
                                  value: t.id,
                                  label: '${t.fullName} (${t.campusHandle})',
                                )),
                          ],
                          onChanged: (v) => setState(() => _selectedHODId = v),
                        ),
                        const SizedBox(height: 16),

                        // Multi-Select: Subjects
                        _buildSectionHeader('Associated Subjects', AppSvgIcon.book),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.subjects.map((s) {
                            final isSelected = _selectedSubjectIds.contains(s.id);
                            return FilterChip(
                              label: Text('${s.code} - ${s.name}', style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              selectedColor: AppColors.wineRed.withValues(alpha: 0.15),
                              checkmarkColor: AppColors.wineRed,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedSubjectIds.add(s.id);
                                  } else {
                                    _selectedSubjectIds.remove(s.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Multi-Select: Faculty / Teachers
                        _buildSectionHeader('Affiliated Teachers / Faculty', AppSvgIcon.user),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.teachers.map((t) {
                            final isSelected = _selectedTeacherIds.contains(t.id);
                            return FilterChip(
                              label: Text(t.fullName, style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              selectedColor: AppColors.githubGreen.withValues(alpha: 0.15),
                              checkmarkColor: AppColors.githubGreen,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedTeacherIds.add(t.id);
                                  } else {
                                    _selectedTeacherIds.remove(t.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Multi-Select: Program Semesters
                        _buildSectionHeader('Program Semesters', AppSvgIcon.layers),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.semesters.map((sem) {
                            final isSelected = _selectedSemesterIds.contains(sem.id);
                            return FilterChip(
                              label: Text(sem.displayName, style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              selectedColor: const Color(0xFF8250DF).withValues(alpha: 0.15),
                              checkmarkColor: const Color(0xFF8250DF),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedSemesterIds.add(sem.id);
                                  } else {
                                    _selectedSemesterIds.remove(sem.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.wineRed,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Create Department'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String icon) {
    return Row(
      children: [
        AppSvgIcon(svgString: icon, size: 14, color: AppColors.wineRed),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// DEPARTMENT DETAIL & HIERARCHY INSPECTOR
// -----------------------------------------------------------------------------

class _DepartmentDetailDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final DepartmentModel department;

  const _DepartmentDetailDialog({
    required this.storage,
    required this.department,
  });

  @override
  State<_DepartmentDetailDialog> createState() => _DepartmentDetailDialogState();
}

class _DepartmentDetailDialogState extends State<_DepartmentDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DepartmentDetailModel? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final res = await widget.storage.getDepartmentDetail(widget.department.id);
    if (mounted) {
      setState(() {
        _detail = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.wineRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.wineRed, width: 1),
                          ),
                          child: Text(
                            widget.department.code,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.wineRed,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.department.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.department.description.isNotEmpty
                    ? widget.department.description
                    : 'Academic department managing multidisciplinary curricula, faculty cohorts, and degree semesters.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 14),

              // Tab Bar
              TabBar(
                controller: _tabController,
                labelColor: AppColors.wineRed,
                indicatorColor: AppColors.wineRed,
                tabs: [
                  Tab(text: 'Subjects (${_detail?.subjects.length ?? widget.department.subjectCount})'),
                  Tab(text: 'Teachers (${_detail?.teachers.length ?? widget.department.teacherCount})'),
                  Tab(text: 'Semesters (${_detail?.semesters.length ?? widget.department.semesterCount})'),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.wineRed))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSubjectsList(isDark),
                          _buildTeachersList(isDark),
                          _buildSemestersList(isDark),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectsList(bool isDark) {
    final subjects = _detail?.subjects ?? [];
    if (subjects.isEmpty) {
      return const Center(child: Text('No subjects linked to this department yet.'));
    }

    return ListView.separated(
      itemCount: subjects.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final sub = subjects[idx];
        final hasOddEven = (sub.oddSemCode != null && sub.oddSemCode!.isNotEmpty) ||
            (sub.evenSemCode != null && sub.evenSemCode!.isNotEmpty);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              const AppSvgIcon(svgString: AppSvgIcon.book, size: 18, color: AppColors.wineRed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${sub.code} - ${sub.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasOddEven) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0969DA).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'Odd: ${sub.oddSemCode ?? sub.code} | Even: ${sub.evenSemCode ?? sub.code}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0969DA)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Credits: ${sub.credits}  |  ${sub.activeSyllabus != null ? "Active Scheme: ${sub.activeSyllabus!.revisionCode}" : "Curriculum Configured"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => _SyllabusAuditDialog(
                      storage: widget.storage,
                      subject: sub,
                      onRevised: _loadDetail,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const AppSvgIcon(svgString: AppSvgIcon.shield, size: 12),
                label: const Text('Audit', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeachersList(bool isDark) {
    final teachers = _detail?.teachers ?? [];
    if (teachers.isEmpty) {
      return const Center(child: Text('No faculty members assigned to this department yet.'));
    }

    return ListView.separated(
      itemCount: teachers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final t = teachers[idx];
        final isHOD = widget.department.hodId == t.id;

        return ListTile(
          dense: true,
          leading: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isHOD ? AppColors.wineRed : AppColors.githubGreen,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              t.firstName[0],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Row(
            children: [
              Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (isHOD) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.wineRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('HOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.wineRed)),
                ),
              ],
            ],
          ),
          subtitle: Text('${t.campusHandle}  |  ${t.email}', style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }

  Widget _buildSemestersList(bool isDark) {
    final semesters = _detail?.semesters ?? [];
    if (semesters.isEmpty) {
      return const Center(child: Text('No program semesters associated with this department yet.'));
    }

    return ListView.separated(
      itemCount: semesters.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final sem = semesters[idx];
        return ListTile(
          dense: true,
          leading: const AppSvgIcon(svgString: AppSvgIcon.layers, size: 18, color: Color(0xFF8250DF)),
          title: Text(sem.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(
            '${sem.subjectIds.length} Subjects  |  ${sem.teacherIds.length} Teachers  |  ${sem.studentCount} Students (Many-to-One)',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: OutlinedButton(
            onPressed: () => _openSemesterDetail(sem),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Inspect Roster', style: TextStyle(fontSize: 11)),
          ),
        );
      },
    );
  }

  void _openSemesterDetail(SemesterModel sem) {
    showDialog(
      context: context,
      builder: (ctx) => _SemesterRosterDialog(
        storage: widget.storage,
        semester: sem,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SEMESTER ROSTER DIALOG (STUDENT N:1 RELATIONSHIP INSPECTOR)
// -----------------------------------------------------------------------------

class _SemesterRosterDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final SemesterModel semester;

  const _SemesterRosterDialog({
    required this.storage,
    required this.semester,
  });

  @override
  State<_SemesterRosterDialog> createState() => _SemesterRosterDialogState();
}

class _SemesterRosterDialogState extends State<_SemesterRosterDialog> {
  SemesterDetailModel? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSemesterDetail();
  }

  Future<void> _loadSemesterDetail() async {
    final res = await widget.storage.getSemesterDetail(widget.semester.id);
    if (mounted) {
      setState(() {
        _detail = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = _detail?.students ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const AppSvgIcon(svgString: AppSvgIcon.layers, size: 18, color: Color(0xFF8250DF)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.semester.displayName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Institutional relationship note clarifying students are linked to semester (not department)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2230) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const AppSvgIcon(svgString: AppSvgIcon.info, size: 14, color: AppColors.wineRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Students enroll directly in their active Semester cohort. Department affiliation is automatically derived through the semester curriculum.',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text('Enrolled Student Roster (${students.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.wineRed))
                    : students.isEmpty
                        ? const Center(child: Text('No students currently enrolled in this semester cohort.'))
                        : ListView.separated(
                            itemCount: students.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final st = students[idx];
                              return ListTile(
                                dense: true,
                                leading: Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.wineRed.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    st.firstName[0],
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.wineRed),
                                  ),
                                ),
                                title: Text(st.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                subtitle: Text('${st.campusHandle}  |  ${st.email}', style: const TextStyle(fontSize: 11)),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ADD CROSS-PROGRAM SECTION DIALOG
// -----------------------------------------------------------------------------

class _AddSectionDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final List<ProgramModel> programs;
  final List<SubjectModel> subjects;
  final List<UserModel> teachers;
  final ValueChanged<SectionModel> onCreated;

  const _AddSectionDialog({
    required this.storage,
    required this.programs,
    required this.subjects,
    required this.teachers,
    required this.onCreated,
  });

  @override
  State<_AddSectionDialog> createState() => _AddSectionDialogState();
}

class _AddSectionDialogState extends State<_AddSectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Section B');
  final _yearController = TextEditingController(text: '2025-2026');
  int _semesterNumber = 3;

  final Set<String> _selectedProgramIds = {};
  final Set<String> _selectedSubjectIds = {};
  final Set<String> _selectedTeacherIds = {};

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default select first two programs if available (e.g. CSE & AI/ML)
    if (widget.programs.isNotEmpty) {
      _selectedProgramIds.add(widget.programs.first.id);
      if (widget.programs.length > 1) {
        _selectedProgramIds.add(widget.programs[1].id);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProgramIds.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one degree program for this shared section');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'name': _nameController.text.trim(),
        'semester_number': _semesterNumber,
        'academic_year': _yearController.text.trim(),
        'program_ids': _selectedProgramIds.toList(),
        'subject_ids': _selectedSubjectIds.toList(),
        'teacher_ids': _selectedTeacherIds.toList(),
      };

      final created = await widget.storage.addSection(payload);
      widget.onCreated(created);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const AppSvgIcon(svgString: AppSvgIcon.layers, size: 20, color: Color(0xFF8250DF)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Add Shared Section Cohort',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.statusRedSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.statusRed, width: 1),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: AppColors.statusRed, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name & Semester Number
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Section Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(hintText: 'e.g. Section B'),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 110,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Semester *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  AppDropdown<int>(
                                    value: _semesterNumber,
                                    items: List.generate(8, (i) => i + 1).map((s) {
                                      return AppDropdownItem<int>(value: s, label: 'Sem $s');
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _semesterNumber = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Academic Year *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _yearController,
                                    decoration: const InputDecoration(hintText: '2025-2026'),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Cross-Program Selection
                        _buildSectionHeader('Participating Degree Programs', AppSvgIcon.userCheck, const Color(0xFF8250DF)),
                        const SizedBox(height: 4),
                        Text(
                          'Select all degree programs that attend this shared section classroom division',
                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.programs.map((p) {
                            final isSelected = _selectedProgramIds.contains(p.id);
                            return FilterChip(
                              label: Text('${p.code} - ${p.name}', style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              selectedColor: const Color(0xFF8250DF).withValues(alpha: 0.18),
                              checkmarkColor: const Color(0xFF8250DF),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedProgramIds.add(p.id);
                                  } else {
                                    _selectedProgramIds.remove(p.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Associated Subjects
                        _buildSectionHeader('Curriculum Subjects', AppSvgIcon.book, AppColors.wineRed),
                        const SizedBox(height: 4),
                        Text(
                          'Common core and specialized courses scheduled for this cohort',
                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.subjects.map((s) {
                            final isSelected = _selectedSubjectIds.contains(s.id);
                            return FilterChip(
                              label: Text('${s.code} - ${s.name}', style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              selectedColor: AppColors.wineRed.withValues(alpha: 0.15),
                              checkmarkColor: AppColors.wineRed,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedSubjectIds.add(s.id);
                                  } else {
                                    _selectedSubjectIds.remove(s.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Associated Faculty
                        _buildSectionHeader('Affiliated Teachers / Faculty', AppSvgIcon.user, AppColors.githubGreen),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.teachers.map((t) {
                            final isSelected = _selectedTeacherIds.contains(t.id);
                            return FilterChip(
                              label: Text(t.fullName, style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              selectedColor: AppColors.githubGreen.withValues(alpha: 0.15),
                              checkmarkColor: AppColors.githubGreen,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedTeacherIds.add(t.id);
                                  } else {
                                    _selectedTeacherIds.remove(t.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8250DF),
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Create Shared Section'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String icon, Color color) {
    return Row(
      children: [
        AppSvgIcon(svgString: icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SECTION DETAIL & HIERARCHY INSPECTOR
// -----------------------------------------------------------------------------

class _SectionDetailDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final SectionModel section;

  const _SectionDetailDialog({
    required this.storage,
    required this.section,
  });

  @override
  State<_SectionDetailDialog> createState() => _SectionDetailDialogState();
}

class _SectionDetailDialogState extends State<_SectionDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SectionDetailModel? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final res = await widget.storage.getSectionDetail(widget.section.id);
    if (mounted) {
      setState(() {
        _detail = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8250DF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF8250DF), width: 1),
                          ),
                          child: Text(
                            widget.section.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8250DF),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Semester ${widget.section.semesterNumber} - ${widget.section.name}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Explanatory cross-program cohort banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2230) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF8250DF).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const AppSvgIcon(svgString: AppSvgIcon.info, size: 14, color: Color(0xFF8250DF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Shared Cross-Program Cohort: Students from multiple degree programs share classroom lectures and common curriculum.',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Participating Programs breakdown
              if (_detail != null && _detail!.programs.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _detail!.programs.map((p) {
                    final studentCount = _detail!.programBreakdown[p.code] ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8250DF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF8250DF).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${p.code} ($studentCount enrolled)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8250DF)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // TabBar
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF8250DF),
                indicatorColor: const Color(0xFF8250DF),
                tabs: [
                  Tab(text: 'Curriculum (${_detail?.subjects.length ?? widget.section.subjectIds.length})'),
                  Tab(text: 'Allocations (${_detail?.facultyAllocations.length ?? 0})'),
                  Tab(text: 'Lab Batches (${_detail?.labBatches.length ?? 0})'),
                  Tab(text: 'Enrolled Cohort (${_detail?.students.length ?? widget.section.studentCount})'),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF8250DF)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCurriculumList(isDark),
                          _buildAllocationsTab(isDark),
                          _buildLabBatchesTab(isDark),
                          _buildStudentsList(isDark),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurriculumList(bool isDark) {
    final allocs = _detail?.subjectAllocations ?? [];
    if (allocs.isEmpty) {
      return const Center(child: Text('No courses allocated to this section.'));
    }

    return ListView.separated(
      itemCount: allocs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final alloc = allocs[idx];
        final isCore = alloc.isSharedCore;

        return ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isCore
                  ? AppColors.githubGreen.withValues(alpha: 0.12)
                  : const Color(0xFF8250DF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              alloc.subjectCode,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: isCore ? AppColors.githubGreen : const Color(0xFF8250DF),
              ),
            ),
          ),
          title: Text(alloc.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('${alloc.credits} Credits', style: const TextStyle(fontSize: 11)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isCore
                  ? AppColors.githubGreen.withValues(alpha: 0.12)
                  : const Color(0xFF8250DF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCore
                    ? AppColors.githubGreen.withValues(alpha: 0.4)
                    : const Color(0xFF8250DF).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              isCore ? 'Shared Common Core' : 'Program Elective (${alloc.programCode})',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isCore ? AppColors.githubGreen : const Color(0xFF8250DF),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllocationsTab(bool isDark) {
    final allocs = _detail?.facultyAllocations ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Bar for Faculty Allocations
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Faculty Subject Allocations (${allocs.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('btn-view-workload-dialog'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => _FacultyWorkloadDialog(storage: widget.storage),
                    );
                  },
                  icon: const AppSvgIcon(svgString: AppSvgIcon.clock, size: 12, color: Color(0xFF8250DF)),
                  label: const Text('Workload Overview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8250DF),
                    side: const BorderSide(color: Color(0xFF8250DF), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                ElevatedButton.icon(
                  key: const Key('btn-assign-faculty-allocation'),
                  onPressed: _openAssignFacultyDialog,
                  icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 12, color: Colors.white),
                  label: const Text('Assign Faculty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8250DF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: allocs.isEmpty
              ? const Center(child: Text('No faculty allocations configured for this section.'))
              : ListView.separated(
                  itemCount: allocs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final a = allocs[idx];
                    final isPractical = a.componentType.toLowerCase() == 'practical';
                    final isTheory = a.componentType.toLowerCase() == 'theory';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPractical
                                  ? const Color(0xFF8250DF).withValues(alpha: 0.12)
                                  : AppColors.githubGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              a.subjectCode ?? a.subjectId,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: isPractical ? const Color(0xFF8250DF) : AppColors.githubGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.subjectName ?? a.subjectCode ?? a.subjectId,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Instructor: ${a.teacherName ?? a.teacherId}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isPractical
                                            ? const Color(0xFF8250DF).withValues(alpha: 0.1)
                                            : AppColors.githubGreen.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(
                                          color: isPractical
                                              ? const Color(0xFF8250DF).withValues(alpha: 0.3)
                                              : AppColors.githubGreen.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        isPractical
                                            ? 'Practical [${a.batchName ?? "All Batches"}]'
                                            : (isTheory ? 'Theory (Cohort)' : a.componentType.toUpperCase()),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isPractical ? const Color(0xFF8250DF) : AppColors.githubGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            child: Text(
                              '${a.weeklyHours} hrs/wk',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            key: Key('btn-remove-alloc-${a.id}'),
                            icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 14, color: AppColors.statusRed),
                            tooltip: 'Remove Allocation',
                            onPressed: () async {
                              await widget.storage.removeFacultyAllocation(a.id, widget.section.id);
                              _loadDetail();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLabBatchesTab(bool isDark) {
    final batches = _detail?.labBatches ?? [];
    final students = _detail?.students ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Practical Lab Batches (${batches.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('btn-create-lab-batch'),
                  onPressed: _openCreateBatchDialog,
                  icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 12, color: Color(0xFF8250DF)),
                  label: const Text('Add Batch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8250DF),
                    side: const BorderSide(color: Color(0xFF8250DF), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                ElevatedButton.icon(
                  key: const Key('btn-auto-partition-batches'),
                  onPressed: _openAutoPartitionDialog,
                  icon: const AppSvgIcon(svgString: AppSvgIcon.layers, size: 12, color: Colors.white),
                  label: const Text('Auto-Partition', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8250DF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: batches.isEmpty
              ? const Center(child: Text('No practical lab batches created for this section.'))
              : ListView.separated(
                  itemCount: batches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final batch = batches[idx];
                    final batchIdSet = batch.studentIds.toSet();
                    final batchStudents = students.where((s) => batchIdSet.contains(s.id)).toList();

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8250DF).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      batch.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8250DF),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${batch.studentIds.length} students assigned',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (batchStudents.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                            ...batchStudents.map((st) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const AppSvgIcon(svgString: AppSvgIcon.user, size: 12, color: Color(0xFF8250DF)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${st.fullName} (${st.campusHandle})',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (batches.length > 1)
                                      InkWell(
                                        key: Key('btn-reassign-${st.id}'),
                                        onTap: () => _openReassignBatchDialog(st, batch, batches),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Text(
                                            'Move Batch',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF8250DF),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ] else ...[
                            const SizedBox(height: 6),
                            Text(
                              'No students currently in this batch.',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStudentsList(bool isDark) {
    final students = _detail?.students ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Bar for Cohort Mobility
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Enrolled Student Roster (${students.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (students.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _openMergeCohortDialog,
                icon: const AppSvgIcon(svgString: AppSvgIcon.layers, size: 12, color: Color(0xFF8250DF)),
                label: const Text('Consolidate Cohort', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8250DF),
                  side: const BorderSide(color: Color(0xFF8250DF), width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        Expanded(
          child: students.isEmpty
              ? const Center(child: Text('No students currently assigned to this section cohort.'))
              : ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final st = students[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8250DF).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              st.firstName.isNotEmpty ? st.firstName[0] : 'S',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8250DF)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(st.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  '${st.campusHandle}  |  ${st.email}',
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openTransferStudentDialog(st),
                            icon: const AppSvgIcon(svgString: AppSvgIcon.userCheck, size: 12, color: Color(0xFF8250DF)),
                            label: const Text('Move Section', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8250DF),
                              side: const BorderSide(color: Color(0xFF8250DF), width: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _openTransferStudentDialog(UserModel student) {
    showDialog(
      context: context,
      builder: (ctx) => _TransferStudentDialog(
        storage: widget.storage,
        student: student,
        currentSection: widget.section,
        onTransferred: () {
          _loadDetail();
        },
      ),
    );
  }

  void _openMergeCohortDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _MergeCohortDialog(
        storage: widget.storage,
        sourceSection: widget.section,
        onMerged: () {
          _loadDetail();
        },
      ),
    );
  }

  void _openAssignFacultyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AssignFacultyAllocationDialog(
        storage: widget.storage,
        section: widget.section,
        subjects: _detail?.subjects ?? widget.storage.cachedSubjects,
        teachers: widget.storage.cachedUsers.where((u) => u.archetype == 'employee').toList(),
        batches: _detail?.labBatches ?? [],
        onAssigned: () {
          _loadDetail();
        },
      ),
    );
  }

  void _openAutoPartitionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AutoPartitionBatchesDialog(
        storage: widget.storage,
        section: widget.section,
        studentCount: _detail?.students.length ?? widget.section.studentCount,
        onPartitioned: () {
          _loadDetail();
        },
      ),
    );
  }

  void _openCreateBatchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _CreateLabBatchDialog(
        storage: widget.storage,
        section: widget.section,
        onCreated: () {
          _loadDetail();
        },
      ),
    );
  }

  void _openReassignBatchDialog(UserModel student, LabBatchModel currentBatch, List<LabBatchModel> batches) {
    showDialog(
      context: context,
      builder: (ctx) => _ReassignBatchDialog(
        storage: widget.storage,
        student: student,
        currentBatch: currentBatch,
        batches: batches,
        onReassigned: () {
          _loadDetail();
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TRANSFER STUDENT TO ANOTHER SECTION DIALOG
// -----------------------------------------------------------------------------

class _TransferStudentDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel student;
  final SectionModel currentSection;
  final VoidCallback onTransferred;

  const _TransferStudentDialog({
    required this.storage,
    required this.student,
    required this.currentSection,
    required this.onTransferred,
  });

  @override
  State<_TransferStudentDialog> createState() => _TransferStudentDialogState();
}

class _TransferStudentDialogState extends State<_TransferStudentDialog> {
  String? _targetSectionId;
  bool _isSubmitting = false;
  String? _errorMessage;
  late final List<SectionModel> _otherSections;

  @override
  void initState() {
    super.initState();
    _otherSections = widget.storage.cachedSections
        .where((s) => s.id != widget.currentSection.id)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherSections = _otherSections;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const AppSvgIcon(svgString: AppSvgIcon.userCheck, size: 18, color: Color(0xFF8250DF)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Move Student Section',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              Text(
                'Student: ${widget.student.fullName} (${widget.student.campusHandle})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Current Section: ${widget.currentSection.displayName}',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 16),

              const Text('Select Target Section Division *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (otherSections.isEmpty)
                const Text('No other sections available. Create a new section first.', style: TextStyle(fontSize: 12, color: AppColors.statusRed))
              else
                AppDropdown<String>(
                  value: _targetSectionId,
                  hint: 'Choose destination section...',
                  items: otherSections.map((s) {
                    return AppDropdownItem<String>(
                      value: s.id,
                      label: '${s.name} - Sem ${s.semesterNumber} (${s.programNames.join(", ")})',
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _targetSectionId = val),
                ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                const SizedBox(height: 10),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_isSubmitting || _targetSectionId == null)
                        ? null
                        : () async {
                            setState(() {
                              _isSubmitting = true;
                              _errorMessage = null;
                            });
                            try {
                              await widget.storage.transferStudentSection(
                                studentId: widget.student.id,
                                targetSectionId: _targetSectionId!,
                              );
                              widget.onTransferred();
                              if (context.mounted) Navigator.of(context).pop();
                            } catch (e) {
                              setState(() {
                                _errorMessage = e.toString().replaceFirst('Exception: ', '');
                                _isSubmitting = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8250DF),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Move'),
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

// -----------------------------------------------------------------------------
// CONSOLIDATE / MERGE SECTION COHORTS DIALOG
// -----------------------------------------------------------------------------

class _MergeCohortDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final SectionModel sourceSection;
  final VoidCallback onMerged;

  const _MergeCohortDialog({
    required this.storage,
    required this.sourceSection,
    required this.onMerged,
  });

  @override
  State<_MergeCohortDialog> createState() => _MergeCohortDialogState();
}

class _MergeCohortDialogState extends State<_MergeCohortDialog> {
  String? _targetSectionId;
  bool _isSubmitting = false;
  String? _errorMessage;
  late final List<SectionModel> _otherSections;

  @override
  void initState() {
    super.initState();
    _otherSections = widget.storage.cachedSections
        .where((s) => s.id != widget.sourceSection.id)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherSections = _otherSections;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const AppSvgIcon(svgString: AppSvgIcon.layers, size: 18, color: Color(0xFF8250DF)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Consolidate Cohort / Merge Sections',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              Text(
                'Source Section: ${widget.sourceSection.displayName}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Migrate all students in this division into a single combined section (e.g. when sections are reduced in succeeding semesters).',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 16),

              const Text('Select Destination Combined Section *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (otherSections.isEmpty)
                const Text('No other sections available to merge into.', style: TextStyle(fontSize: 12, color: AppColors.statusRed))
              else
                AppDropdown<String>(
                  value: _targetSectionId,
                  hint: 'Choose destination combined section...',
                  items: otherSections.map((s) {
                    return AppDropdownItem<String>(
                      value: s.id,
                      label: '${s.name} - Sem ${s.semesterNumber} (${s.programNames.join(", ")})',
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _targetSectionId = val),
                ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                const SizedBox(height: 10),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_isSubmitting || _targetSectionId == null)
                        ? null
                        : () async {
                            setState(() {
                              _isSubmitting = true;
                              _errorMessage = null;
                            });
                            try {
                              await widget.storage.mergeSectionCohorts(
                                sourceSectionId: widget.sourceSection.id,
                                targetSectionId: _targetSectionId!,
                              );
                              widget.onMerged();
                              if (context.mounted) Navigator.of(context).pop();
                            } catch (e) {
                              setState(() {
                                _errorMessage = e.toString().replaceFirst('Exception: ', '');
                                _isSubmitting = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8250DF),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Consolidation'),
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

// -----------------------------------------------------------------------------
// ASSIGN FACULTY ALLOCATION DIALOG
// -----------------------------------------------------------------------------

class _AssignFacultyAllocationDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final SectionModel section;
  final List<SubjectModel> subjects;
  final List<UserModel> teachers;
  final List<LabBatchModel> batches;
  final VoidCallback onAssigned;

  const _AssignFacultyAllocationDialog({
    required this.storage,
    required this.section,
    required this.subjects,
    required this.teachers,
    required this.batches,
    required this.onAssigned,
  });

  @override
  State<_AssignFacultyAllocationDialog> createState() => _AssignFacultyAllocationDialogState();
}

class _AssignFacultyAllocationDialogState extends State<_AssignFacultyAllocationDialog> {
  String? _selectedSubjectId;
  String? _selectedTeacherId;
  String _componentType = 'theory';
  String? _selectedBatchId;
  late TextEditingController _hoursController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController(text: '3');
    if (widget.subjects.isNotEmpty) {
      _selectedSubjectId = widget.subjects.first.id;
    }
    if (widget.teachers.isNotEmpty) {
      _selectedTeacherId = widget.teachers.first.id;
    }
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  void _onComponentChanged(String? val) {
    if (val == null) return;
    setState(() {
      _componentType = val;
      if (val == 'practical') {
        _hoursController.text = '2';
        if (widget.batches.isNotEmpty && _selectedBatchId == null) {
          _selectedBatchId = widget.batches.first.id;
        }
      } else {
        _hoursController.text = '3';
        _selectedBatchId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const AppSvgIcon(svgString: AppSvgIcon.book, size: 18, color: Color(0xFF8250DF)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Assign Faculty to Section',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Subject selection
              const Text('Select Academic Subject *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              AppDropdown<String>(
                key: const Key('dropdown-allocation-subject'),
                value: _selectedSubjectId,
                hint: 'Select subject...',
                items: widget.subjects.map((sub) {
                  return AppDropdownItem<String>(
                    value: sub.id,
                    label: '${sub.code} - ${sub.name}',
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSubjectId = val),
              ),
              const SizedBox(height: 14),

              // Teacher selection
              const Text('Assign Instructor / Teacher *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              AppDropdown<String>(
                key: const Key('dropdown-allocation-teacher'),
                value: _selectedTeacherId,
                hint: 'Select teacher...',
                items: widget.teachers.map((t) {
                  return AppDropdownItem<String>(
                    value: t.id,
                    label: '${t.fullName} (${t.campusHandle})',
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedTeacherId = val),
              ),
              const SizedBox(height: 14),

              // Component type selection
              const Text('Teaching Component Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              AppDropdown<String>(
                key: const Key('dropdown-allocation-component'),
                value: _componentType,
                items: const [
                  AppDropdownItem(value: 'theory', label: 'Theory Lecture (Full Cohort)'),
                  AppDropdownItem(value: 'practical', label: 'Practical Lab (Batch Sub-division)'),
                  AppDropdownItem(value: 'tutorial', label: 'Tutorial Class'),
                ],
                onChanged: (val) {
                  if (val != null) _onComponentChanged(val);
                },
              ),
              const SizedBox(height: 14),

              // Batch selection if practical
              if (_componentType == 'practical') ...[
                const Text('Assign to Practical Lab Batch *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                AppDropdown<String?>(
                  key: const Key('dropdown-allocation-batch'),
                  value: _selectedBatchId,
                  hint: 'All Batches (Section Cohort)',
                  items: [
                    const AppDropdownItem<String?>(
                      value: null,
                      label: 'All Batches (Section Cohort)',
                    ),
                    ...widget.batches.map((b) => AppDropdownItem<String?>(
                          value: b.id,
                          label: '${b.name} (${b.studentIds.length} students)',
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedBatchId = val),
                ),
                const SizedBox(height: 14),
              ],

              // Weekly Hours
              const Text('Weekly Contact Hours *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('input-allocation-hours'),
                controller: _hoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'e.g. 4 (Theory: 3-4 hrs, Practical: 2 hrs)',
                ),
              ),
              const SizedBox(height: 14),

              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                const SizedBox(height: 10),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('btn-submit-allocation'),
                    onPressed: (_isSubmitting || _selectedSubjectId == null || _selectedTeacherId == null)
                        ? null
                        : () async {
                            final hours = int.tryParse(_hoursController.text.trim()) ?? 3;
                            setState(() {
                              _isSubmitting = true;
                              _errorMessage = null;
                            });
                            try {
                              await widget.storage.assignFacultyAllocation({
                                'section_id': widget.section.id,
                                'subject_id': _selectedSubjectId!,
                                'teacher_id': _selectedTeacherId!,
                                'component_type': _componentType,
                                'batch_id': _selectedBatchId,
                                'weekly_hours': hours,
                              });
                              widget.onAssigned();
                              if (context.mounted) Navigator.of(context).pop();
                            } catch (e) {
                              setState(() {
                                _errorMessage = e.toString().replaceFirst('Exception: ', '');
                                _isSubmitting = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8250DF),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Assign Faculty'),
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

// -----------------------------------------------------------------------------
// AUTO-PARTITION PRACTICAL BATCHES DIALOG
// -----------------------------------------------------------------------------

class _AutoPartitionBatchesDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final SectionModel section;
  final int studentCount;
  final VoidCallback onPartitioned;

  const _AutoPartitionBatchesDialog({
    required this.storage,
    required this.section,
    required this.studentCount,
    required this.onPartitioned,
  });

  @override
  State<_AutoPartitionBatchesDialog> createState() => _AutoPartitionBatchesDialogState();
}

class _AutoPartitionBatchesDialogState extends State<_AutoPartitionBatchesDialog> {
  int _batchCount = 2;
  late TextEditingController _prefixController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prefixController = TextEditingController(text: 'Batch');
  }

  @override
  void dispose() {
    _prefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const AppSvgIcon(svgString: AppSvgIcon.layers, size: 18, color: Color(0xFF8250DF)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Auto-Partition Practical Batches',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              Text(
                'Section: ${widget.section.displayName} (${widget.studentCount} enrolled)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              const Text('Number of Practical Batches *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              AppDropdown<int>(
                key: const Key('dropdown-batch-count'),
                value: _batchCount,
                items: const [
                  AppDropdownItem(value: 2, label: '2 Batches (e.g. Batch 1, Batch 2)'),
                  AppDropdownItem(value: 3, label: '3 Batches (e.g. Batch 1, Batch 2, Batch 3)'),
                  AppDropdownItem(value: 4, label: '4 Batches (e.g. Batch 1, Batch 2, Batch 3, Batch 4)'),
                ],
                onChanged: (val) => setState(() => _batchCount = val ?? 2),
              ),
              const SizedBox(height: 14),

              const Text('Batch Name Prefix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('input-batch-prefix'),
                controller: _prefixController,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'e.g. Batch (generates Batch 1, Batch 2)',
                ),
              ),
              const SizedBox(height: 14),

              // Preview box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2230) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF8250DF).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const AppSvgIcon(svgString: AppSvgIcon.info, size: 14, color: Color(0xFF8250DF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Evenly distributes all ${widget.studentCount} enrolled students across $_batchCount practical batches with deterministic sorting.',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                const SizedBox(height: 10),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('btn-submit-auto-partition'),
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            setState(() {
                              _isSubmitting = true;
                              _errorMessage = null;
                            });
                            try {
                              final prefix = _prefixController.text.trim().isNotEmpty
                                  ? _prefixController.text.trim()
                                  : 'Batch';
                              await widget.storage.autoPartitionBatches({
                                'section_id': widget.section.id,
                                'batch_count': _batchCount,
                                'prefix': prefix,
                              });
                              widget.onPartitioned();
                              if (context.mounted) Navigator.of(context).pop();
                            } catch (e) {
                              setState(() {
                                _errorMessage = e.toString().replaceFirst('Exception: ', '');
                                _isSubmitting = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8250DF),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Auto-Partition'),
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

// -----------------------------------------------------------------------------
// CREATE LAB BATCH DIALOG
// -----------------------------------------------------------------------------

class _CreateLabBatchDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final SectionModel section;
  final VoidCallback onCreated;

  const _CreateLabBatchDialog({
    required this.storage,
    required this.section,
    required this.onCreated,
  });

  @override
  State<_CreateLabBatchDialog> createState() => _CreateLabBatchDialogState();
}

class _CreateLabBatchDialogState extends State<_CreateLabBatchDialog> {
  late TextEditingController _nameController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const AppSvgIcon(svgString: AppSvgIcon.plus, size: 18, color: Color(0xFF8250DF)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Create Lab Batch',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              const Text('Batch Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('input-batch-name'),
                controller: _nameController,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'e.g. Batch B3 or Practical Group A',
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                const SizedBox(height: 10),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('btn-submit-create-batch'),
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            final name = _nameController.text.trim();
                            if (name.isEmpty) return;
                            setState(() {
                              _isSubmitting = true;
                              _errorMessage = null;
                            });
                            try {
                              await widget.storage.createLabBatch({
                                'section_id': widget.section.id,
                                'name': name,
                              });
                              widget.onCreated();
                              if (context.mounted) Navigator.of(context).pop();
                            } catch (e) {
                              setState(() {
                                _errorMessage = e.toString().replaceFirst('Exception: ', '');
                                _isSubmitting = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8250DF),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Batch'),
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

// -----------------------------------------------------------------------------
// REASSIGN STUDENT LAB BATCH DIALOG
// -----------------------------------------------------------------------------

class _ReassignBatchDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel student;
  final LabBatchModel currentBatch;
  final List<LabBatchModel> batches;
  final VoidCallback onReassigned;

  const _ReassignBatchDialog({
    required this.storage,
    required this.student,
    required this.currentBatch,
    required this.batches,
    required this.onReassigned,
  });

  @override
  State<_ReassignBatchDialog> createState() => _ReassignBatchDialogState();
}

class _ReassignBatchDialogState extends State<_ReassignBatchDialog> {
  String? _targetBatchId;
  bool _isSubmitting = false;
  String? _errorMessage;
  late final List<LabBatchModel> _otherBatches;

  @override
  void initState() {
    super.initState();
    _otherBatches = widget.batches.where((b) => b.id != widget.currentBatch.id).toList();
    if (_otherBatches.isNotEmpty) {
      _targetBatchId = _otherBatches.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherBatches = _otherBatches;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const AppSvgIcon(svgString: AppSvgIcon.layers, size: 18, color: Color(0xFF8250DF)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Reassign Student Lab Batch',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              Text(
                'Student: ${widget.student.fullName} (${widget.student.campusHandle})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Current Batch: ${widget.currentBatch.name}',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 14),

              const Text('Select Target Lab Batch *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              AppDropdown<String>(
                key: const Key('dropdown-target-batch'),
                value: _targetBatchId,
                hint: 'Select target batch...',
                items: otherBatches.map((b) {
                  return AppDropdownItem<String>(
                    value: b.id,
                    label: '${b.name} (${b.studentIds.length} students)',
                  );
                }).toList(),
                onChanged: (val) => setState(() => _targetBatchId = val),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                const SizedBox(height: 10),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('btn-submit-reassign-batch'),
                    onPressed: (_isSubmitting || _targetBatchId == null)
                        ? null
                        : () async {
                            setState(() {
                              _isSubmitting = true;
                              _errorMessage = null;
                            });
                            try {
                              await widget.storage.assignStudentBatch(
                                batchId: _targetBatchId!,
                                studentId: widget.student.id,
                              );
                              widget.onReassigned();
                              if (context.mounted) Navigator.of(context).pop();
                            } catch (e) {
                              setState(() {
                                _errorMessage = e.toString().replaceFirst('Exception: ', '');
                                _isSubmitting = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8250DF),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Reassign Batch'),
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

// -----------------------------------------------------------------------------
// FACULTY WORKLOAD OVERVIEW DIALOG
// -----------------------------------------------------------------------------

class _FacultyWorkloadDialog extends StatefulWidget {
  final OfflineStorageService storage;

  const _FacultyWorkloadDialog({required this.storage});

  @override
  State<_FacultyWorkloadDialog> createState() => _FacultyWorkloadDialogState();
}

class _FacultyWorkloadDialogState extends State<_FacultyWorkloadDialog> {
  List<FacultyWorkloadSummaryModel> _summaries = [];
  bool _isLoading = true;
  int _overloadedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final list = await widget.storage.getFacultyWorkloadSummaries();
    if (mounted) {
      setState(() {
        _summaries = list;
        _overloadedCount = list.where((s) => s.isOverloaded).length;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overloadedCount = _overloadedCount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const AppSvgIcon(svgString: AppSvgIcon.clock, size: 20, color: Color(0xFF8250DF)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Faculty Teaching Workload & Contact Hours',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 6),
              // Explanatory Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2230) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF8250DF).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const AppSvgIcon(svgString: AppSvgIcon.info, size: 14, color: Color(0xFF8250DF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Standard recommended workload limit: 16 contact hours/week per faculty. Overload warnings are triggered when allocations exceed 16 hrs.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    if (overloadedCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.statusRed, width: 1),
                        ),
                        child: Text(
                          '$overloadedCount OVERLOADED',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusRed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF8250DF)))
                    : _summaries.isEmpty
                        ? const Center(child: Text('No faculty members found.'))
                        : ListView.separated(
                            itemCount: _summaries.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final item = _summaries[idx];
                              final ratio = (item.totalWeeklyHours / item.maxRecommendedHours).clamp(0.0, 1.0);
                              final isOver = item.isOverloaded;

                              return Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isOver
                                        ? AppColors.statusRed.withValues(alpha: 0.5)
                                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: (isOver ? AppColors.statusRed : AppColors.githubGreen)
                                                    .withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.teacherName.isNotEmpty ? item.teacherName[0] : 'T',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isOver ? AppColors.statusRed : AppColors.githubGreen,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              item.teacherName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            if (isOver) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.statusRed.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: AppColors.statusRed),
                                                ),
                                                child: const Text(
                                                  'OVERLOAD (> 16 hrs)',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.statusRed,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Text(
                                              '${item.totalWeeklyHours} / ${item.maxRecommendedHours} hrs/wk',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isOver ? AppColors.statusRed : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 6,
                                        backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isOver ? AppColors.statusRed : AppColors.githubGreen,
                                        ),
                                      ),
                                    ),
                                    if (item.allocations.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: item.allocations.map((a) {
                                          final isPrac = a.componentType.toLowerCase() == 'practical';
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF21262D) : Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                              ),
                                            ),
                                            child: Text(
                                              '${a.sectionName ?? "Section"}: ${a.subjectCode ?? a.subjectId} (${isPrac ? "Lab ${a.batchName ?? ''}" : "Theory"}) - ${a.weeklyHours}h',
                                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SYLLABUS AUDIT TRAIL & CYCLE ALIASING DIALOG (ACCREDITATION ARCHIVE)
// -----------------------------------------------------------------------------

class _SyllabusAuditDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final SubjectModel subject;
  final VoidCallback? onRevised;

  const _SyllabusAuditDialog({
    required this.storage,
    required this.subject,
    this.onRevised,
  });

  @override
  State<_SyllabusAuditDialog> createState() => _SyllabusAuditDialogState();
}

class _SyllabusAuditDialogState extends State<_SyllabusAuditDialog> {
  List<SyllabusVersionModel> _auditTrail = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _simulatedSemester = 1;
  final Set<String> _expandedContentIds = {};

  @override
  void initState() {
    super.initState();
    _loadAuditTrail();
  }

  Future<void> _loadAuditTrail() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.storage.getSubjectSyllabusAudit(widget.subject.id);
      if (mounted) {
        setState(() {
          _auditTrail = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _openReviseModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ReviseSyllabusDialog(
        storage: widget.storage,
        subject: widget.subject,
        onRevised: () {
          _loadAuditTrail();
          widget.onRevised?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = widget.subject;
    final hasOddEven = (sub.oddSemCode != null && sub.oddSemCode!.isNotEmpty) ||
        (sub.evenSemCode != null && sub.evenSemCode!.isNotEmpty);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.githubGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const AppSvgIcon(svgString: AppSvgIcon.book, size: 20, color: AppColors.githubGreen),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${sub.code} - ${sub.name}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Curriculum Syllabus Audit & Semester Term Aliasing',
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
                  IconButton(
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.wineRed))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                              const SizedBox(height: 12),
                            ],

                            // 1. Cycle / Term Code Aliasing Resolver
                            _buildCycleResolverSection(sub, hasOddEven, isDark),
                            const SizedBox(height: 20),

                            // 2. Active Scheme Curriculum
                            _buildActiveSchemeSection(isDark),
                            const SizedBox(height: 20),

                            // 3. Immutable Historical Revisions Vault (NAAC/NBA/UGC)
                            _buildAuditTrailSection(isDark),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openReviseModal,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.githubGreen,
                      side: const BorderSide(color: AppColors.githubGreen),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 14, color: AppColors.githubGreen),
                    label: const Text('Revise Syllabus (BoS Scheme Update)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA),
                      foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
                      elevation: 0,
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCycleResolverSection(SubjectModel sub, bool hasOddEven, bool isDark) {
    final resolvedCode = sub.resolveCode(_simulatedSemester);
    final isOdd = _simulatedSemester % 2 == 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppSvgIcon(svgString: AppSvgIcon.refresh, size: 14, color: Color(0xFF0969DA)),
              const SizedBox(width: 8),
              const Text(
                'SEMESTER CYCLE CODE RESOLVER (ODD / EVEN ALIASING)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF0969DA)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasOddEven
                ? 'Subject code dynamically resolves across semester cohorts independent of degree programs.'
                : 'Canonical single-code subject. Configure odd/even semester aliasing if offered across cycles.',
            style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 12),

          // Code mapping chips
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _buildAliasPill(
                label: 'Canonical Code',
                code: sub.code,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                bgColor: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
              ),
              if (sub.oddSemCode != null)
                _buildAliasPill(
                  label: 'Odd Semesters (1, 3, 5, 7)',
                  code: sub.oddSemCode!,
                  color: const Color(0xFF0969DA),
                  bgColor: const Color(0xFF0969DA).withValues(alpha: 0.12),
                ),
              if (sub.evenSemCode != null)
                _buildAliasPill(
                  label: 'Even Semesters (2, 4, 6, 8)',
                  code: sub.evenSemCode!,
                  color: const Color(0xFF8250DF),
                  bgColor: const Color(0xFF8250DF).withValues(alpha: 0.12),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Interactive Cycle Simulator
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Simulate Term Offering:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOdd
                            ? const Color(0xFF0969DA).withValues(alpha: 0.15)
                            : const Color(0xFF8250DF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Resolved: $resolvedCode (${isOdd ? "Odd" : "Even"})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOdd ? const Color(0xFF0969DA) : const Color(0xFF8250DF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: List.generate(6, (index) {
                    final semNum = index + 1;
                    final isSelected = _simulatedSemester == semNum;
                    return InkWell(
                      onTap: () => setState(() => _simulatedSemester = semNum),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (semNum % 2 == 1 ? const Color(0xFF0969DA) : const Color(0xFF8250DF))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                        child: Text(
                          'Sem $semNum',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAliasPill({
    required String label,
    required String code,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 10, color: color)),
          Text(code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildActiveSchemeSection(bool isDark) {
    final active = _auditTrail.firstWhere((v) => v.isActive, orElse: () {
      return SyllabusVersionModel(
        id: 'fallback-syl',
        subjectId: widget.subject.id,
        revisionCode: widget.subject.activeSyllabus?.revisionCode ?? 'Scheme-Default',
        effectiveFromYear: widget.subject.activeSyllabus?.effectiveFromYear ?? '2024-2025',
        isActive: true,
        content: widget.subject.activeSyllabus?.content ?? 'Syllabus content active and ratified by BoS.',
        changeSummary: widget.subject.activeSyllabus?.changeSummary,
        approvedBy: widget.subject.activeSyllabus?.approvedBy ?? 'Board of Studies (BoS)',
      );
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.githubGreen.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const AppSvgIcon(svgString: AppSvgIcon.shield, size: 16, color: AppColors.githubGreen),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'ACTIVE CURRICULUM SCHEME (${active.revisionCode})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.githubGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.githubGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CURRENTLY ACTIVE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.githubGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            'Effective Academic Years: ${active.effectiveFromYear} - Present  |  Ratified by: ${active.approvedBy ?? "Academic BoS Council"}',
            style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          if (active.changeSummary != null && active.changeSummary!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Change Justification: ${active.changeSummary}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.wineRed),
            ),
          ],
          const SizedBox(height: 12),

          // Content Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
            ),
            child: Text(
              active.content,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTrailSection(bool isDark) {
    final pastVersions = _auditTrail.where((v) => !v.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppSvgIcon(svgString: AppSvgIcon.clock, size: 14, color: Color(0xFF8250DF)),
            const SizedBox(width: 8),
            Text(
              'ACCREDITATION AUDIT VAULT (${pastVersions.length} HISTORICAL REVISIONS)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Color(0xFF8250DF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'All past syllabi are immutably archived for UGC, NBA, and NAAC retrospective cohort verification.',
          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
        const SizedBox(height: 12),

        if (pastVersions.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: const Center(
              child: Text(
                'No past syllabus schemes archived yet. When new curriculum revisions are published, prior copies are automatically locked here.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pastVersions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final v = pastVersions[idx];
              final isExpanded = _expandedContentIds.contains(v.id);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  v.revisionCode,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.wineRed.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ARCHIVED / RETIRED',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.wineRed),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Taught: ${v.effectiveFromYear} to ${v.effectiveToYear ?? "Replaced"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Approved by: ${v.approvedBy ?? "BoS Committee"}  |  Summary: ${v.changeSummary ?? "Baseline approved syllabus"}',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 8),

                    // Expand/Collapse Toggle
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedContentIds.remove(v.id);
                          } else {
                            _expandedContentIds.add(v.id);
                          }
                        });
                      },
                      child: Row(
                        children: [
                          AppSvgIcon(
                            svgString: isExpanded ? AppSvgIcon.chevronDown : AppSvgIcon.arrowRight,
                            size: 12,
                            color: const Color(0xFF0969DA),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpanded ? 'Hide Archived Syllabus Units' : 'Inspect Archived Syllabus Units',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0969DA)),
                          ),
                        ],
                      ),
                    ),

                    if (isExpanded) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          v.content,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// REVISE SYLLABUS MODAL (PUBLISH NEW BoS REFORM SCHEME)
// -----------------------------------------------------------------------------

class _ReviseSyllabusDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final SubjectModel subject;
  final VoidCallback onRevised;

  const _ReviseSyllabusDialog({
    required this.storage,
    required this.subject,
    required this.onRevised,
  });

  @override
  State<_ReviseSyllabusDialog> createState() => _ReviseSyllabusDialogState();
}

class _ReviseSyllabusDialogState extends State<_ReviseSyllabusDialog> {
  final _revisionController = TextEditingController(text: 'Reg-2025');
  final _effectiveYearController = TextEditingController(text: '2025-2026');
  final _approvedByController = TextEditingController(text: 'Board of Studies (BoS) Computing & Academic Council');
  final _changeSummaryController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.subject.activeSyllabus != null) {
      _contentController.text = widget.subject.activeSyllabus!.content;
    }
  }

  @override
  void dispose() {
    _revisionController.dispose();
    _effectiveYearController.dispose();
    _approvedByController.dispose();
    _changeSummaryController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rev = _revisionController.text.trim();
    final content = _contentController.text.trim();
    if (rev.isEmpty) {
      setState(() => _errorMessage = 'Revision code is required (e.g. Reg-2025)');
      return;
    }
    if (content.isEmpty) {
      setState(() => _errorMessage = 'Syllabus content cannot be empty');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.storage.reviseSubjectSyllabus({
        'subject_id': widget.subject.id,
        'revision_code': rev,
        'effective_from_year': _effectiveYearController.text.trim(),
        'approved_by': _approvedByController.text.trim(),
        'change_summary': _changeSummaryController.text.trim(),
        'content': content,
      });
      widget.onRevised();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const AppSvgIcon(svgString: AppSvgIcon.book, size: 18, color: AppColors.githubGreen),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Revise Syllabus: ${widget.subject.code}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 14),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Publishing a new scheme immutably archives the current syllabus with effective cohort bounds for accreditation audits.',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _revisionController,
                        decoration: const InputDecoration(
                          labelText: 'Revision Code *',
                          hintText: 'e.g. Reg-2025, Scheme-2025',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _effectiveYearController,
                        decoration: const InputDecoration(
                          labelText: 'Effective Academic Year *',
                          hintText: 'e.g. 2025-2026',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _approvedByController,
                  decoration: const InputDecoration(
                    labelText: 'Approving Authority (BoS / Council)',
                    hintText: 'e.g. Board of Studies (BoS) Computing',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _changeSummaryController,
                  decoration: const InputDecoration(
                    labelText: 'Change Justification / Summary',
                    hintText: 'e.g. Added Unit 5 Modern Systems and POSIX Concurrency',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Modular Syllabus Units & Reference Texts *',
                    hintText: 'Unit 1: Introduction...\nUnit 2: Core Concepts...\nUnit 3: Case Studies...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                  const SizedBox(height: 10),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.githubGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Publish & Archive Previous'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ADD ACADEMIC SUBJECT DIALOG
// -----------------------------------------------------------------------------

class _AddSubjectDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final ValueChanged<SubjectModel> onCreated;

  const _AddSubjectDialog({
    required this.storage,
    required this.onCreated,
  });

  @override
  State<_AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends State<_AddSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _oddCodeController = TextEditingController();
  final _evenCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _creditsController = TextEditingController(text: '4');
  final _revisionController = TextEditingController(text: 'Scheme-2025');
  final _effectiveYearController = TextEditingController(text: '2025-2026');
  final _contentController = TextEditingController(text: 'Unit 1: Foundational Principles & Architecture.\nUnit 2: Applied Modular Systems.\nUnit 3: Case Studies and Laboratory Practice.');

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _oddCodeController.dispose();
    _evenCodeController.dispose();
    _nameController.dispose();
    _creditsController.dispose();
    _revisionController.dispose();
    _effectiveYearController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final credits = int.tryParse(_creditsController.text.trim()) ?? 4;
      final oddCode = _oddCodeController.text.trim().toUpperCase();
      final evenCode = _evenCodeController.text.trim().toUpperCase();
      var code = _codeController.text.trim().toUpperCase();

      if (code.isEmpty) {
        if (oddCode.isNotEmpty && evenCode.isNotEmpty) {
          code = '$oddCode / $evenCode';
        } else if (oddCode.isNotEmpty) {
          code = oddCode;
        } else if (evenCode.isNotEmpty) {
          code = evenCode;
        } else {
          code = 'SUBJ-${DateTime.now().millisecondsSinceEpoch % 1000}';
        }
      }

      final payload = {
        'code': code,
        'odd_sem_code': oddCode.isNotEmpty ? oddCode : null,
        'even_sem_code': evenCode.isNotEmpty ? evenCode : null,
        'name': _nameController.text.trim(),
        'credits': credits,
        'active_syllabus': {
          'revision_code': _revisionController.text.trim(),
          'effective_from_year': _effectiveYearController.text.trim(),
          'is_active': true,
          'content': _contentController.text.trim(),
          'change_summary': 'Initial ratified curriculum scheme',
          'approved_by': 'Board of Studies (BoS) Computing',
        },
      };

      final created = await widget.storage.createSubject(payload);
      widget.onCreated(created);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const AppSvgIcon(svgString: AppSvgIcon.book, size: 18, color: AppColors.githubGreen),
                          const SizedBox(width: 8),
                          Text(
                            'Add Academic Subject',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 14),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configure subject code aliasing (e.g. BCA-102 in odd sems, BCA-202 in even sems) and initial ratified syllabus.',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Subject Name *',
                      hintText: 'e.g. Computer Fundamentals & Programming',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Subject name is required' : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _oddCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Odd Sem Code (Optional)',
                            hintText: 'e.g. BCA-102',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _evenCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Even Sem Code (Optional)',
                            hintText: 'e.g. BCA-202',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          controller: _creditsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Credits',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Canonical Display Code (Optional)',
                      hintText: 'e.g. BCA 102 / 202 or CS301 (Auto-derived if empty)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'INITIAL SYLLABUS SCHEME',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppColors.githubGreen),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _revisionController,
                          decoration: const InputDecoration(
                            labelText: 'Revision Code',
                            hintText: 'e.g. Scheme-2025',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _effectiveYearController,
                          decoration: const InputDecoration(
                            labelText: 'Effective Year',
                            hintText: 'e.g. 2025-2026',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Curriculum Units & Content',
                      hintText: 'Unit 1: Primitive Data Structures\nUnit 2: Stacks and Queues...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                    const SizedBox(height: 10),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.githubGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Create Subject'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


