import 'package:flutter/material.dart';
import '../models/academic.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

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

  bool _isLoading = true;
  String _searchQuery = '';
  int _selectedTab = 0; // 0 = Departments, 1 = Cross-Program Sections

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
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
        _isLoading = false;
      });
    }
  }

  List<DepartmentModel> get _filteredDepartments {
    if (_searchQuery.trim().isEmpty) return _departments;
    final q = _searchQuery.toLowerCase().trim();
    return _departments.where((d) {
      return d.name.toLowerCase().contains(q) ||
          d.code.toLowerCase().contains(q) ||
          (d.hodName != null && d.hodName!.toLowerCase().contains(q));
    }).toList();
  }

  List<SectionModel> get _filteredSections {
    if (_searchQuery.trim().isEmpty) return _sections;
    final q = _searchQuery.toLowerCase().trim();
    return _sections.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.displayName.toLowerCase().contains(q) ||
          s.programNames.any((p) => p.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.wineRed),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.wineRed,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar with Title and Primary Action
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

                    // Active Tab Content
                    if (_selectedTab == 0) ...[
                      if (_filteredDepartments.isEmpty)
                        _buildEmptyState(isDark)
                      else
                        _buildDepartmentsGrid(isDark),
                    ] else ...[
                      if (_filteredSections.isEmpty)
                        _buildEmptySectionState(isDark)
                      else
                        _buildSectionsGrid(isDark),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final isDeptTab = _selectedTab == 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppSvgIcon(
                    svgString: isDeptTab ? AppSvgIcon.building : AppSvgIcon.layers,
                    size: 24,
                    color: isDeptTab ? AppColors.wineRed : const Color(0xFF8250DF),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      isDeptTab ? 'Academic Departments & Structure' : 'Cross-Program Sections & Cohorts',
                      style: TextStyle(
                        fontSize: 20,
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
                isDeptTab
                    ? 'Manage departments with many-to-many subjects, teachers, and degree semesters'
                    : 'Manage shared semester divisions with multi-program student cohorts and common curricula',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: isDeptTab ? _openAddDepartmentDialog : _openAddSectionDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDeptTab ? AppColors.wineRed : const Color(0xFF8250DF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 16, color: Colors.white),
          label: Text(
            isDeptTab ? 'Add Department' : 'Add Shared Section',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
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
            onTap: () => setState(() {
              _selectedTab = 0;
              _searchQuery = '';
            }),
          ),
          _buildToggleButton(
            title: 'Cross-Program Sections (${_sections.length})',
            icon: AppSvgIcon.layers,
            isSelected: _selectedTab == 1,
            activeColor: const Color(0xFF8250DF),
            isDark: isDark,
            onTap: () => setState(() {
              _selectedTab = 1;
              _searchQuery = '';
            }),
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
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final card1 = _selectedTab == 0
            ? _buildMetricCard(
                title: 'Departments',
                count: _departments.length.toString(),
                subtitle: '${_programs.length} degree programs',
                icon: AppSvgIcon.building,
                color: AppColors.wineRed,
                isDark: isDark,
              )
            : _buildMetricCard(
                title: 'Shared Sections',
                count: totalSections.toString(),
                subtitle: 'Multi-program cohorts',
                icon: AppSvgIcon.layers,
                color: const Color(0xFF8250DF),
                isDark: isDark,
              );

        final card2 = _selectedTab == 0
            ? _buildMetricCard(
                title: 'Subjects (M:N)',
                count: totalSubjects.toString(),
                subtitle: 'Catalog course modules',
                icon: AppSvgIcon.book,
                color: AppColors.githubGreen,
                isDark: isDark,
              )
            : _buildMetricCard(
                title: 'Programs (M:N)',
                count: _programs.length.toString(),
                subtitle: 'Degree specializations',
                icon: AppSvgIcon.userCheck,
                color: AppColors.githubGreen,
                isDark: isDark,
              );

        final card3 = _buildMetricCard(
          title: 'Faculty (M:N)',
          count: totalTeachers.toString(),
          subtitle: 'Teaching affiliations',
          icon: AppSvgIcon.user,
          color: const Color(0xFF0969DA),
          isDark: isDark,
        );

        final card4 = _selectedTab == 0
            ? _buildMetricCard(
                title: 'Semesters (M:N)',
                count: totalSemesters.toString(),
                subtitle: 'Active program cohorts',
                icon: AppSvgIcon.layers,
                color: const Color(0xFF8250DF),
                isDark: isDark,
              )
            : _buildMetricCard(
                title: 'Core Curriculum',
                count: totalSubjects.toString(),
                subtitle: 'Shared & elective courses',
                icon: AppSvgIcon.book,
                color: AppColors.wineRed,
                isDark: isDark,
              );

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
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search department by name, code (e.g. CSE, ECE) or HOD...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: AppSvgIcon(
              svgString: AppSvgIcon.search,
              size: 16,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => setState(() => _searchQuery = ''),
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
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              if (dept.hodName != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppSvgIcon(svgString: AppSvgIcon.userCheck, size: 12, color: AppColors.githubGreen),
                    const SizedBox(width: 4),
                    Text(
                      'HOD: ${dept.hodName}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
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
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedHODId,
                          decoration: const InputDecoration(isDense: true),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('No HOD assigned yet', overflow: TextOverflow.ellipsis),
                            ),
                            ...widget.teachers.map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(
                                    '${t.fullName} (${t.campusHandle})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) => setState(() => _selectedHODId = v),
                        ),
                        const SizedBox(height: 16),

                        // Many-to-Many Multi-Select: Subjects
                        _buildSectionHeader('Associated Subjects (Many-to-Many)', AppSvgIcon.book),
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

                        // Many-to-Many Multi-Select: Faculty / Teachers
                        _buildSectionHeader('Affiliated Teachers / Faculty (Many-to-Many)', AppSvgIcon.user),
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

                        // Many-to-Many Multi-Select: Program Semesters
                        _buildSectionHeader('Program Semesters (Many-to-Many)', AppSvgIcon.layers),
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
        return ListTile(
          dense: true,
          leading: const AppSvgIcon(svgString: AppSvgIcon.book, size: 18, color: AppColors.wineRed),
          title: Text('${sub.code} - ${sub.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('Credits: ${sub.credits}  |  Offered in ${sub.departmentIds.length} departments', style: const TextStyle(fontSize: 11)),
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
                        'Students enroll in their active Semester cohort (Many-to-One). They are not directly related to departments; their department relation is derived through this semester.',
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
                                  DropdownButtonFormField<int>(
                                    isExpanded: true,
                                    initialValue: _semesterNumber,
                                    decoration: const InputDecoration(isDense: true),
                                    items: List.generate(8, (i) => i + 1).map((s) {
                                      return DropdownMenuItem(value: s, child: Text('Sem $s', overflow: TextOverflow.ellipsis));
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

                        // Cross-Program Selection (Many-to-Many)
                        _buildSectionHeader('Participating Degree Programs (Many-to-Many)', AppSvgIcon.userCheck, const Color(0xFF8250DF)),
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

                        // Associated Subjects (Many-to-Many)
                        _buildSectionHeader('Curriculum Subjects (Many-to-Many)', AppSvgIcon.book, AppColors.wineRed),
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

                        // Associated Faculty (Many-to-Many)
                        _buildSectionHeader('Affiliated Teachers / Faculty (Many-to-Many)', AppSvgIcon.user, AppColors.githubGreen),
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
    _tabController = TabController(length: 3, vsync: this);
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
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 660),
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
                  Tab(text: 'Faculty (${_detail?.teachers.length ?? widget.section.teacherIds.length})'),
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
                          _buildFacultyList(isDark),
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

  Widget _buildFacultyList(bool isDark) {
    final teachers = _detail?.teachers ?? [];
    if (teachers.isEmpty) {
      return const Center(child: Text('No faculty assigned to this section cohort.'));
    }

    return ListView.separated(
      itemCount: teachers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final t = teachers[idx];
        return ListTile(
          dense: true,
          leading: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.githubGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              t.firstName.isNotEmpty ? t.firstName[0] : 'T',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.githubGreen),
            ),
          ),
          title: Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('${t.campusHandle}  |  ${t.email}', style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }

  Widget _buildStudentsList(bool isDark) {
    final students = _detail?.students ?? [];
    if (students.isEmpty) {
      return const Center(child: Text('No students currently assigned to this section cohort.'));
    }

    return ListView.separated(
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
              color: const Color(0xFF8250DF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              st.firstName.isNotEmpty ? st.firstName[0] : 'S',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8250DF)),
            ),
          ),
          title: Text(st.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('${st.campusHandle}  |  ${st.email}', style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }
}

