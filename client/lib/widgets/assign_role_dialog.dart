import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

class AssignRoleDialog extends StatefulWidget {
  final UserModel user;
  final OfflineStorageService storage;
  final ValueChanged<UserModel> onAssigned;

  const AssignRoleDialog({
    super.key,
    required this.user,
    required this.storage,
    required this.onAssigned,
  });

  static Future<UserModel?> show(
    BuildContext context, {
    required UserModel user,
    required OfflineStorageService storage,
    required ValueChanged<UserModel> onAssigned,
  }) {
    return showDialog<UserModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssignRoleDialog(
        user: user,
        storage: storage,
        onAssigned: onAssigned,
      ),
    );
  }

  @override
  State<AssignRoleDialog> createState() => _AssignRoleDialogState();
}

class _AssignRoleDialogState extends State<AssignRoleDialog> {
  late String _selectedRoleCode;
  late final TextEditingController _roleNameController;
  late final TextEditingController _scopeController;
  late final TextEditingController _clubNameController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final isStudent = widget.user.archetype == 'student';

    if (isStudent) {
      _selectedRoleCode = 'class_representative';
      _roleNameController = TextEditingController(text: 'Class Representative');
      _scopeController = TextEditingController(
        text: widget.user.sectionScope != null && widget.user.sectionScope!.isNotEmpty
            ? widget.user.sectionScope!
            : 'sec:cse-3a',
      );
      _clubNameController = TextEditingController(text: 'Example');
    } else {
      _selectedRoleCode = 'coordinator';
      _roleNameController = TextEditingController(text: 'Section Coordinator');
      _scopeController = TextEditingController(text: 'sec:cse-3a');
      _clubNameController = TextEditingController(text: 'Example');
    }
  }

  @override
  void dispose() {
    _roleNameController.dispose();
    _scopeController.dispose();
    _clubNameController.dispose();
    super.dispose();
  }

  List<(String, String)> _getRoleOptions() {
    if (widget.user.archetype == 'student') {
      return [
        ('class_representative', 'Class Representative (CR)'),
        ('club_president', 'Club President (e.g. Club:Example:president)'),
        ('club_lead', 'Club Lead / Officer'),
        ('custom', 'Custom Student Role'),
      ];
    } else {
      return [
        ('coordinator', 'Section / Academic Coordinator'),
        ('library_incharge', 'Library In-Charge'),
        ('hod', 'Head of Department (HOD)'),
        ('faculty', 'Faculty Member'),
        ('warden', 'Hostel Warden'),
        ('custom', 'Custom Employee Role'),
      ];
    }
  }

  void _onRoleSelected(String roleCode) {
    setState(() {
      _selectedRoleCode = roleCode;
      switch (roleCode) {
        case 'coordinator':
          _roleNameController.text = 'Section Coordinator';
          _scopeController.text = 'sec:cse-3a';
          break;
        case 'library_incharge':
          _roleNameController.text = 'Library In-Charge';
          _scopeController.text = 'global';
          break;
        case 'hod':
          _roleNameController.text = 'Head of Department (HOD)';
          _scopeController.text = 'dept:cse';
          break;
        case 'faculty':
          _roleNameController.text = 'Faculty Member';
          _scopeController.text = 'dept:cse';
          break;
        case 'warden':
          _roleNameController.text = 'Hostel Warden';
          _scopeController.text = 'facility:hostel-1';
          break;
        case 'class_representative':
          _roleNameController.text = 'Class Representative';
          _scopeController.text = widget.user.sectionScope != null && widget.user.sectionScope!.isNotEmpty
              ? widget.user.sectionScope!
              : 'sec:cse-3a';
          break;
        case 'club_president':
          _roleNameController.text = 'Club President';
          final club = _clubNameController.text.trim().isNotEmpty
              ? _clubNameController.text.trim()
              : 'Example';
          _scopeController.text = 'Club:$club:president';
          break;
        case 'club_lead':
          _roleNameController.text = 'Club Lead';
          final club = _clubNameController.text.trim().isNotEmpty
              ? _clubNameController.text.trim()
              : 'example';
          _scopeController.text = 'club:${club.toLowerCase()}';
          break;
        case 'custom':
          _roleNameController.text = 'Delegated Authority';
          _scopeController.text = 'global';
          break;
      }
    });
  }

  void _onClubNameChanged(String val) {
    if (_selectedRoleCode == 'club_president') {
      final club = val.trim().isNotEmpty ? val.trim() : 'Example';
      setState(() {
        _scopeController.text = 'Club:$club:president';
      });
    } else if (_selectedRoleCode == 'club_lead') {
      final club = val.trim().isNotEmpty ? val.trim().toLowerCase() : 'example';
      setState(() {
        _scopeController.text = 'club:$club';
      });
    }
  }

  List<String> _getPermissionsPreview() {
    switch (_selectedRoleCode) {
      case 'coordinator':
        return [
          'timetable:view',
          'timetable:edit',
          'attendance:mark',
          'attendance:broadcast',
          'attendance:view_roster',
          'attendance:set_criteria',
          'notice:section_post',
        ];
      case 'library_incharge':
        return [
          'library:view',
          'library:issue',
          'library:return',
          'library:manage_inventory',
          'library:view_fines',
          'library:approve',
        ];
      case 'hod':
        return [
          'timetable:view',
          'timetable:edit',
          'timetable:declare_off',
          'attendance:mark',
          'attendance:broadcast',
          'attendance:view_roster',
          'attendance:approve',
          'attendance:set_criteria',
          'syllabus:view',
          'syllabus:approve',
          'faculty:assign_workload',
          'department:manage',
          'notice:publish',
        ];
      case 'faculty':
        return [
          'timetable:view',
          'timetable:edit',
          'attendance:mark',
          'attendance:broadcast',
          'attendance:view_roster',
          'syllabus:view',
          'notice:publish',
        ];
      case 'warden':
        return [
          'gatepass:approve',
          'room:inspect',
          'hostel:manage',
          'hostel:edit_room',
          'complaints:hostel',
          'complaints:campus',
        ];
      case 'class_representative':
        return [
          'attendance:mark',
          'notice:section_post',
          'timetable:view',
        ];
      case 'club_president':
        return [
          'club:publish_event',
          'club:spend_budget',
          'club:manage_members',
          'notice:club_post',
        ];
      case 'club_lead':
        return [
          'club:publish_event',
          'club:manage_members',
        ];
      default:
        return ['custom:delegate'];
    }
  }

  Future<void> _submitAssignment() async {
    final roleName = _roleNameController.text.trim();
    final scopeCode = _scopeController.text.trim();

    if (roleName.isEmpty) {
      setState(() => _errorMessage = 'Role name cannot be empty.');
      return;
    }
    if (scopeCode.isEmpty) {
      setState(() => _errorMessage = 'Scope code cannot be empty.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updatedUser = await widget.storage.assignUserRole(
        userId: widget.user.id,
        roleCode: _selectedRoleCode,
        roleName: roleName,
        scopeCode: scopeCode,
        permissions: _getPermissionsPreview(),
      );

      if (mounted) {
        widget.onAssigned(updatedUser);
        Navigator.of(context).pop(updatedUser);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully assigned role "$roleName" with scope "$scopeCode" to ${widget.user.fullName}.',
            ),
            backgroundColor: AppColors.githubGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to assign role: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = _getRoleOptions();
    final permissions = _getPermissionsPreview();

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.wineRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.wineRed.withValues(alpha: 0.3)),
                    ),
                    child: const AppSvgIcon(
                      svgString: AppSvgIcon.shield,
                      size: 20,
                      color: AppColors.wineRed,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Institutional Role & Permissions',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assign delegated permissions to ${widget.user.fullName} (${widget.user.campusHandle})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('btn-close-assign-dialog'),
                    icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 18),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.statusRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const AppSvgIcon(
                        svgString: AppSvgIcon.alertTriangle,
                        size: 14,
                        color: AppColors.statusRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 11, color: AppColors.statusRed),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Role Selector Dropdown / Radios
              Text(
                'Select Role Preset',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const Key('dropdown-role-preset'),
                    value: _selectedRoleCode,
                    isExpanded: true,
                    dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    items: options.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt.$1,
                        child: Text(
                          opt.$2,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _onRoleSelected(val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Club Name input for student club presidents
              if (_selectedRoleCode == 'club_president' || _selectedRoleCode == 'club_lead') ...[
                Text(
                  'Club Name (e.g. Example, Robotics, Coding)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('input-club-name'),
                  controller: _clubNameController,
                  onChanged: _onClubNameChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Example',
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Role Display Name
              Text(
                'Role Name / Title',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('input-role-name'),
                controller: _roleNameController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Section Coordinator or Club President',
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Scope Code
              Text(
                'Scope Code Boundary (e.g. sec:cse-3a, dept:cse, Club:Example:president, global)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('input-role-scope'),
                controller: _scopeController,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'e.g. sec:cse-3a, Club:Example:president',
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Permissions Preview
              Text(
                'Granted Permissions (${permissions.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: permissions.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.wineRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.wineRed.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppColors.wineRed,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('btn-cancel-assign-role'),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    key: const Key('btn-confirm-assign-role'),
                    onPressed: _isSubmitting ? null : _submitAssignment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wineRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const AppSvgIcon(svgString: AppSvgIcon.check, size: 14, color: Colors.white),
                    label: Text(
                      _isSubmitting ? 'Assigning...' : 'Assign Role & Permissions',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
