import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../models/library.dart';
import '../models/fee.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/app_logo.dart';

class UserProfileScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final String userIdentifier;
  final UserModel? initialUser;
  final UserModel? currentAdminUser;
  final VoidCallback? onUserUpdated;
  final bool showAppBar;

  const UserProfileScreen({
    super.key,
    required this.storage,
    required this.userIdentifier,
    this.initialUser,
    this.currentAdminUser,
    this.onUserUpdated,
    this.showAppBar = true,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late UserModel _user;
  bool _isLoading = false;
  String? _errorMessage;

  LibrarySummaryModel? _librarySummary;
  FeeSummaryModel? _feeSummary;
  double? _attendancePercentage;

  @override
  void initState() {
    super.initState();
    if (widget.initialUser != null) {
      _user = widget.initialUser!;
    } else {
      _user = UserModel(
        id: widget.userIdentifier,
        campusHandle: widget.userIdentifier,
        firstName: 'Loading...',
        lastName: '',
        email: '',
        archetype: 'student',
      );
    }
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await widget.storage.getUserProfile(widget.userIdentifier);

      LibrarySummaryModel? libSum;
      FeeSummaryModel? feeSum;
      double? attPct;

      if (profile.archetype == 'student') {
        try {
          libSum = await widget.storage.getLibrarySummary(profile.id);
        } catch (_) {}
        try {
          feeSum = await widget.storage.getFeeSummary(profile.id);
        } catch (_) {}
        try {
          final attList = await widget.storage.getAttendanceSummary(profile.id);
          if (attList.isNotEmpty) {
            int totalClasses = 0;
            int attendedClasses = 0;
            for (final a in attList) {
              totalClasses += a.totalSessions;
              attendedClasses += a.attended;
            }
            if (totalClasses > 0) {
              attPct = (attendedClasses / totalClasses) * 100.0;
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _user = profile;
          _librarySummary = libSum;
          _feeSummary = feeSum;
          _attendancePercentage = attPct;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  BadgeStyle _getStatusBadgeStyle(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.greenBadge(isDark);
      case 'graduated':
        return AppColors.blueBadge(isDark);
      case 'suspended':
      case 'discontinued':
        return AppColors.redBadge(isDark);
      case 'resigned':
      case 'retired':
      default:
        return AppColors.neutralBadge(isDark);
    }
  }

  Widget _buildBarcodeVisual(String code, bool isDark) {
    final barPattern = [
      2, 1, 3, 1, 2, 4, 1, 3, 2, 1, 4, 2, 1, 3, 2, 2, 1, 4, 1, 2, 3, 1, 2, 4, 2, 1, 3, 1, 4, 2, 1, 3, 2, 1
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < barPattern.length; i++) ...[
                  Container(
                    width: barPattern[i].toDouble(),
                    color: (i % 2 == 0) ? Colors.black : Colors.transparent,
                  ),
                  const SizedBox(width: 1.5),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '*$code*',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showDigitalIdModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        AppLogo(height: 22),
                        SizedBox(width: 8),
                        Text(
                          'CAMPUS DIGITAL PASS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const AppSvgIcon(svgString: AppSvgIcon.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const AppSvgIcon(
                        svgString: AppSvgIcon.qrCode,
                        size: 140,
                        color: Colors.black,
                      ),
                      const SizedBox(height: 10),
                      _buildBarcodeVisual(_user.universityRollNo ?? _user.campusHandle, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _user.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _user.campusHandle,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.githubGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.githubGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSvgIcon(
                        svgString: AppSvgIcon.check,
                        size: 12,
                        color: AppColors.githubGreen,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'CAMPUS-NFC-VERIFIED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.githubGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditContactDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emailCtrl = TextEditingController(text: _user.personalEmail ?? '');
    final phoneCtrl = TextEditingController(text: _user.phone ?? '');
    final emergNameCtrl = TextEditingController(text: _user.emergencyContactName ?? '');
    final emergPhoneCtrl = TextEditingController(text: _user.emergencyContactPhone ?? '');
    final addressCtrl = TextEditingController(text: _user.address ?? '');
    String selectedBloodGroup = _user.bloodGroup ?? 'O+';
    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    if (!bloodGroups.contains(selectedBloodGroup)) {
      selectedBloodGroup = 'O+';
    }
    String? editError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.wineRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const AppSvgIcon(
                    svgString: AppSvgIcon.user,
                    size: 18,
                    color: AppColors.wineRed,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Update Contact Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Personal Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. personal.name@example.com',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                        ),
                        prefixIcon: const AppSvgIcon(svgString: AppSvgIcon.mail, size: 14),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. +91 98765 43210',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                        ),
                        prefixIcon: const AppSvgIcon(svgString: AppSvgIcon.phone, size: 14),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Emergency Contact Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: emergNameCtrl,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Suresh Kumar (Father)',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                                  ),
                                  prefixIcon: const AppSvgIcon(svgString: AppSvgIcon.user, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Blood Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              AppDropdown<String>(
                                value: selectedBloodGroup,
                                items: bloodGroups.map((bg) => AppDropdownItem<String>(value: bg, label: bg)).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedBloodGroup = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Emergency Contact Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emergPhoneCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. +91 98765 00112',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                        ),
                        prefixIcon: const AppSvgIcon(svgString: AppSvgIcon.phone, size: 14),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Residential / Hostel Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Room 204, Aryabhatta Hostel Block, Campus North',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                        ),
                      ),
                    ),
                    if (editError != null) ...[
                      const SizedBox(height: 8),
                      Text(editError!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () async {
                  final phone = phoneCtrl.text.trim();
                  if (phone.isNotEmpty && phone.length < 8) {
                    setDialogState(() => editError = 'Please enter a valid phone number.');
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(dialogCtx).pop();
                  setState(() => _isLoading = true);

                  try {
                    final updated = await widget.storage.updateUserProfile(
                      userId: _user.id,
                      personalEmail: emailCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      emergencyContactName: emergNameCtrl.text.trim(),
                      emergencyContactPhone: emergPhoneCtrl.text.trim(),
                      bloodGroup: selectedBloodGroup,
                      address: addressCtrl.text.trim(),
                    );
                    if (mounted) {
                      setState(() {
                        _user = updated;
                        _isLoading = false;
                      });
                      widget.onUserUpdated?.call();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Contact details updated successfully.'),
                          backgroundColor: AppColors.githubGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.statusRed),
                      );
                    }
                  }
                },
                child: const Text('Save Details'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDiscontinueDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedStatus = 'graduated';
    if (_user.archetype == 'employee') {
      selectedStatus = 'resigned';
    } else if (_user.isContractor) {
      selectedStatus = 'discontinued';
    }
    final reasonController = TextEditingController();
    final adminHandle = widget.currentAdminUser?.campusHandle ?? 'admin_root';
    String? formError;

    final studentOptions = [
      'graduated',
      'discontinued',
      'suspended',
      'withdrawn',
      'expelled',
    ];

    final employeeOptions = [
      'resigned',
      'retired',
      'discontinued',
      'suspended',
      'terminated',
    ];

    final contractorOptions = [
      'discontinued',
      'suspended',
      'contract_expired',
      'terminated',
    ];

    List<String> options;
    if (_user.archetype == 'student') {
      options = studentOptions;
    } else if (_user.isContractor) {
      options = contractorOptions;
    } else {
      options = employeeOptions;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.statusRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const AppSvgIcon(
                    svgString: AppSvgIcon.userX,
                    size: 18,
                    color: AppColors.statusRed,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Discontinue / Institutional Exit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.statusYellow.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.statusYellow.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppSvgIcon(
                            svgString: AppSvgIcon.alertTriangle,
                            size: 16,
                            color: AppColors.statusYellow,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Discontinuing ${_user.fullName} (${_user.campusHandle}) will revoke all active security scopes and permissions. Academic & historical records remain preserved.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.statusYellowDarkText : AppColors.statusYellow,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Exit Classification',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    AppDropdown<String>(
                      value: selectedStatus,
                      items: options.map((opt) {
                        return AppDropdownItem<String>(
                          value: opt,
                          label: opt.toUpperCase(),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedStatus = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Reason & Justification (Required)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'e.g. Graduated Class of 2025, Resigned for higher studies...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        formError!,
                        style: const TextStyle(fontSize: 12, color: AppColors.statusRed),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Authorizing Administrator: $adminHandle',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    setDialogState(() => formError = 'Please provide an official justification.');
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(dialogCtx).pop();
                  setState(() => _isLoading = true);

                  try {
                    final updated = await widget.storage.discontinueUser(
                      userId: _user.id,
                      status: selectedStatus,
                      reason: reason,
                      discontinuedBy: adminHandle,
                    );
                    if (mounted) {
                      setState(() {
                        _user = updated;
                        _isLoading = false;
                      });
                      widget.onUserUpdated?.call();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('User ${_user.campusHandle} marked as $selectedStatus.'),
                          backgroundColor: AppColors.statusRed,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.statusRed),
                      );
                    }
                  }
                },
                child: const Text('Confirm Discontinuation'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReactivateDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.githubGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const AppSvgIcon(
                svgString: AppSvgIcon.userCheck,
                size: 18,
                color: AppColors.githubGreen,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Reactivate User Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to restore ${_user.fullName} (${_user.campusHandle}) to active standing? This will re-enable institutional logins and access credentials.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.githubGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogCtx).pop();
              setState(() => _isLoading = true);

              try {
                final updated = await widget.storage.reactivateUser(_user.id);
                if (mounted) {
                  setState(() {
                    _user = updated;
                    _isLoading = false;
                  });
                  widget.onUserUpdated?.call();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('User ${_user.campusHandle} successfully reactivated.'),
                      backgroundColor: AppColors.githubGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.statusRed),
                  );
                }
              }
            },
            child: const Text('Confirm Reactivation'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBadge = _getStatusBadgeStyle(_user.status, isDark);
    final roleBadge = _user.archetype == 'student'
        ? AppColors.primaryBadge(isDark)
        : (_user.isContractor ? AppColors.yellowBadge(isDark) : AppColors.blueBadge(isDark));

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              titleSpacing: 0,
              title: Text(
                _user.fullName.isNotEmpty ? _user.fullName : 'User Profile',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh Profile Data',
                  icon: const AppSvgIcon(svgString: AppSvgIcon.refresh, size: 18),
                  onPressed: _loadUserProfile,
                ),
                IconButton(
                  tooltip: 'Copy Canonical Handle',
                  icon: const AppSvgIcon(svgString: AppSvgIcon.info, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _user.campusHandle));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied handle: ${_user.campusHandle}')),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.wineRed),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppSvgIcon(
                        svgString: AppSvgIcon.alertTriangle,
                        size: 32,
                        color: AppColors.statusRed,
                      ),
                      const SizedBox(height: 12),
                      Text('Error loading profile: $_errorMessage'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadUserProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Digital Institutional ID Card
                          _buildDigitalIdCard(isDark, statusBadge, roleBadge),
                          const SizedBox(height: 20),

                          // 2. Discontinuation Banner (if not active)
                          if (!_user.isActive) ...[
                            _buildDiscontinuationBanner(isDark),
                            const SizedBox(height: 20),
                          ],

                          // 3. Campus Life Snapshot & Activity Metrics
                          _buildSectionHeader('Campus Life Snapshot & Activity', AppSvgIcon.chartBar),
                          const SizedBox(height: 10),
                          _buildCampusLifeSnapshot(isDark),
                          const SizedBox(height: 24),

                          // 4. Contact Details & Emergency Information
                          _buildSectionHeader('Official Identity & Verification', AppSvgIcon.shield),
                          const SizedBox(height: 10),
                          _buildContactAndEmergencyCard(isDark),
                          const SizedBox(height: 24),

                          // 5. Institutional Standing & Roles
                          _buildSectionHeader(
                            _user.archetype == 'student'
                                ? 'Academic Enrollment & Progress'
                                : 'Employment Anchor & Duties',
                            _user.archetype == 'student'
                                ? AppSvgIcon.academicCap
                                : AppSvgIcon.briefcase,
                          ),
                          const SizedBox(height: 10),
                          _buildInstitutionalStandingCard(isDark),
                          const SizedBox(height: 24),

                          // 6. Scoped Security, Permissions & Preferences
                          _buildSectionHeader('Scoped RBAC Authority', AppSvgIcon.lock),
                          const SizedBox(height: 10),
                          _buildScopesCard(isDark),
                          const SizedBox(height: 32),

                          // 7. Administrative Lifecycle Actions
                          _buildAdminActionBar(isDark),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, String svgIcon) {
    return Row(
      children: [
        AppSvgIcon(svgString: svgIcon, size: 16, color: AppColors.wineRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDigitalIdCard(bool isDark, BadgeStyle statusBadge, BadgeStyle roleBadge) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Subtly position watermark logo on right
          Positioned(
            right: 16,
            bottom: 12,
            child: Opacity(
              opacity: isDark ? 0.08 : 0.05,
              child: const AppLogo(height: 110),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar box
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _user.isActive ? AppColors.wineRed : (isDark ? AppColors.darkBorder : Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _user.firstName.isNotEmpty ? _user.firstName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
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
                              Flexible(
                                child: Text(
                                  _user.fullName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusBadge.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusBadge.border, width: 1),
                                ),
                                child: Text(
                                  _user.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusBadge.text,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Canonical Monospace Handle
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBg : AppColors.lightBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _user.campusHandle,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _user.email,
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
                const Divider(height: 1),
                const SizedBox(height: 14),
                // Badges and Scannable Actions row
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleBadge.background,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: roleBadge.border, width: 1),
                          ),
                          child: Text(
                            _user.isContractor
                                ? (_user.vendorOrganization != null && _user.vendorOrganization!.isNotEmpty
                                    ? 'CONTRACTOR • ${_user.vendorOrganization}'
                                    : 'CONTRACTOR')
                                : _user.archetype.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: roleBadge.text,
                            ),
                          ),
                        ),
                        if (_user.isContractor && _user.gatePassId != null && _user.gatePassId!.isNotEmpty)
                          Text(
                            'GATE PASS: ${_user.gatePassId}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          )
                        else if (_user.universityRollNo != null && _user.universityRollNo!.isNotEmpty)
                          Text(
                            'ID: ${_user.universityRollNo}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                      ],
                    ),
                    // Scannable ID Modal Action Button
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: _showDigitalIdModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBg : AppColors.lightBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppSvgIcon(
                              svgString: AppSvgIcon.qrCode,
                              size: 15,
                              color: AppColors.wineRed,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Digital ID Pass',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.wineRed,
                              ),
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
        ],
      ),
    );
  }

  Widget _buildCampusLifeSnapshot(bool isDark) {
    final att = _attendancePercentage ?? 84.5;
    final attIsSafe = att >= 75.0;
    final attDiff = (att - 75.0).abs();

    final activeLoans = _librarySummary?.activeBorrowsCount ?? 0;
    final fineDue = _librarySummary?.totalLateFineDue ?? 0.0;

    final totalDues = _feeSummary?.totalDues ?? 0.0;
    final overdueInvoices = _feeSummary?.overdueInvoices ?? 0;

    final addressText = _user.address ?? 'Room 204, Aryabhatta Hostel';
    final roomBrief = addressText.contains('Room') ? addressText.split(',').first : addressText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 550;
        final cardWidth = isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // 1. Attendance KPI
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                isDark: isDark,
                icon: AppSvgIcon.chartBar,
                iconColor: attIsSafe ? AppColors.githubGreen : AppColors.statusRed,
                title: 'Attendance Standing',
                value: '${att.toStringAsFixed(1)}%',
                subtitle: attIsSafe
                    ? 'Safe (${attDiff.toStringAsFixed(1)}% above 75% min)'
                    : 'Low Attendance Alert (${attDiff.toStringAsFixed(1)}% below min)',
                subtitleColor: attIsSafe ? AppColors.githubGreen : AppColors.statusRed,
              ),
            ),
            // 2. Library KPI
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                isDark: isDark,
                icon: AppSvgIcon.book,
                iconColor: AppColors.githubBlue,
                title: 'Library Standing',
                value: '$activeLoans Active Loan${activeLoans == 1 ? '' : 's'}',
                subtitle: fineDue > 0
                    ? 'Late Fine Due: ₹${fineDue.toStringAsFixed(0)}'
                    : 'Borrow Quota Available',
                subtitleColor: fineDue > 0 ? AppColors.statusRed : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
            // 3. Hostel / Accommodation KPI
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                isDark: isDark,
                icon: AppSvgIcon.bed,
                iconColor: AppColors.statusYellow,
                title: 'Hostel & Residence',
                value: roomBrief,
                subtitle: 'Campus Resident Pass Active',
                subtitleColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            // 4. Institutional Fees KPI
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                isDark: isDark,
                icon: AppSvgIcon.creditCard,
                iconColor: totalDues > 0 ? AppColors.statusRed : AppColors.githubGreen,
                title: 'Institutional Fees',
                value: totalDues > 0 ? '₹${totalDues.toStringAsFixed(0)} Due' : 'Clear / Paid',
                subtitle: overdueInvoices > 0
                    ? '$overdueInvoices Overdue Invoice${overdueInvoices == 1 ? '' : 's'}'
                    : 'No Pending Balance',
                subtitleColor: overdueInvoices > 0 ? AppColors.statusRed : AppColors.githubGreen,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required bool isDark,
    required String icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
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
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AppSvgIcon(svgString: icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactAndEmergencyCard(bool isDark) {
    final items = [
      (label: 'Institutional Email', value: _user.email, icon: AppSvgIcon.mail),
      (label: 'Personal Email', value: _user.personalEmail ?? 'Not registered', icon: AppSvgIcon.mail),
      (label: 'Phone Number', value: _user.phone ?? 'Not registered', icon: AppSvgIcon.phone),
      (label: 'Emergency Contact', value: _user.emergencyContactName ?? 'Suresh Kumar (Father)', icon: AppSvgIcon.user),
      (label: 'Emergency Phone', value: _user.emergencyContactPhone ?? '+91 98765 00112', icon: AppSvgIcon.phone),
      (label: 'Blood Group', value: _user.bloodGroup ?? 'O+', icon: AppSvgIcon.shield),
      (label: 'Residential / Room Address', value: _user.address ?? 'Room 204, Aryabhatta Hostel Block, Campus North', icon: AppSvgIcon.mapPin),
      (label: 'University Roll No', value: _user.universityRollNo ?? 'Pending allocation', icon: AppSvgIcon.shield),
      (label: 'Registration / Application', value: _user.admissionApplicationNo ?? _user.universityRegNo ?? 'Verified Direct', icon: AppSvgIcon.info),
      (label: 'System ID Anchor', value: _user.id, icon: AppSvgIcon.qrCode),
    ];

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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Contact & Emergency Directory',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.wineRed,
                  side: const BorderSide(color: AppColors.wineRed, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const AppSvgIcon(svgString: AppSvgIcon.save, size: 12, color: AppColors.wineRed),
                label: const Text('Edit Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _showEditContactDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 550;
              return Wrap(
                spacing: 20,
                runSpacing: 14,
                children: items.map((f) {
                  final isFullWidth = f.label.contains('Address');
                  final width = isFullWidth
                      ? constraints.maxWidth
                      : (isWide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth);
                  return SizedBox(
                    width: width,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: AppSvgIcon(
                            svgString: f.icon,
                            size: 14,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                f.value,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiscontinuationBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.statusRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppSvgIcon(
                svgString: AppSvgIcon.userX,
                size: 16,
                color: AppColors.statusRed,
              ),
              const SizedBox(width: 8),
              Text(
                'Institutional Exit Record: ${_user.status.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.statusRed,
                ),
              ),
            ],
          ),
          if (_user.discontinuationReason != null && _user.discontinuationReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${_user.discontinuationReason}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              if (_user.discontinuedAt != null)
                Text(
                  'Exit Date: ${_user.discontinuedAt!.split('T').first}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              if (_user.discontinuedBy != null && _user.discontinuedBy!.isNotEmpty) ...[
                const SizedBox(width: 14),
                Text(
                  'Authorized By: ${_user.discontinuedBy}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionalStandingCard(bool isDark) {
    if (_user.isContractor) {
      final cp = _user.contractorProfile ?? {};
      final vendor = _user.vendorOrganization ?? 'Campus External Vendor';
      final service = (_user.serviceType ?? 'Services').toUpperCase();
      final gatePass = _user.gatePassId ?? _user.universityRollNo ?? 'GP-ASSIGNED';
      final onboardingYear = cp['onboarding_year'] ?? 2025;
      final supervisor = _user.supervisorName ?? 'Vendor Office';
      final supPhone = _user.supervisorPhone ?? 'N/A';
      final expiry = _user.contractExpiresAt ?? 'Active';
      final zones = _user.permittedScopes.isNotEmpty
          ? _user.permittedScopes.join(', ')
          : 'gate:main, building:canteen';

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
            _buildFactRow('Vendor Organization', vendor, isDark),
            const Divider(height: 16),
            _buildFactRow('Service Classification', service, isDark),
            const Divider(height: 16),
            _buildFactRow('Security Gate Pass ID', gatePass, isDark),
            const Divider(height: 16),
            _buildFactRow('Onboarding Year', '$onboardingYear', isDark),
            const Divider(height: 16),
            _buildFactRow('Site Supervisor', '$supervisor ($supPhone)', isDark),
            const Divider(height: 16),
            _buildFactRow('Authorized Access Zones', zones, isDark),
            const Divider(height: 16),
            _buildFactRow('Contract Expiration', expiry.length > 10 ? expiry.substring(0, 10) : expiry, isDark),
          ],
        ),
      );
    }

    if (_user.archetype == 'student') {
      final p = _user.studentProfile ?? {};
      final admissionYear = p['admission_year'] ?? 2025;
      final entryType = p['entry_type'] ?? 'regular';
      final program = p['program'] ?? 'btech';
      final semester = p['current_semester'] ?? 1;
      final batchYear = p['batch_year'] ?? (admissionYear + 4);
      final section = _user.sectionScope ?? p['section_scope'] ?? 'sec:cse-1a';
      final advisor = _user.advisorName ?? p['advisor_name'] ?? 'Assigned Faculty Advisor';

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
          children: [
            _buildFactRow('Academic Program', program.toString().toUpperCase(), isDark),
            const Divider(height: 16),
            _buildFactRow('Admission Year & Entry', '$admissionYear (${entryType.toString().toUpperCase()})', isDark),
            const Divider(height: 16),
            _buildFactRow('Current Semester', 'Semester $semester', isDark),
            const Divider(height: 16),
            _buildFactRow('Cohort / Section Scope', section, isDark),
            const Divider(height: 16),
            _buildFactRow('Faculty Advisor', advisor, isDark),
            const Divider(height: 16),
            _buildFactRow('Graduation Cohort', 'Class of $batchYear', isDark),
          ],
        ),
      );
    }

    // Employee facts
    final er = _user.employeeRecord ?? {};
    final ap = _user.academicProfile;
    final ad = _user.administrativeProfile;

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
          _buildFactRow('Employment Type', (er['employment_type'] ?? 'permanent').toString().toUpperCase(), isDark),
          if (ap != null) ...[
            const Divider(height: 16),
            _buildFactRow('Academic Track & Rank', ap['academic_rank'] ?? 'Faculty Member', isDark),
            if (ap['cabin_location'] != null) ...[
              const Divider(height: 16),
              _buildFactRow('Cabin Location', ap['cabin_location'].toString(), isDark),
            ],
            if (ap['departments'] != null && (ap['departments'] as List).isNotEmpty) ...[
              const Divider(height: 16),
              _buildFactRow('Department Affiliations', (ap['departments'] as List).join(', '), isDark),
            ],
          ],
          if (ad != null) ...[
            const Divider(height: 16),
            _buildFactRow('Administrative Unit', ad['primary_unit'] ?? 'General Admin', isDark),
            const Divider(height: 16),
            _buildFactRow('Designation', ad['designation'] ?? 'Officer', isDark),
            if (ad['office_location'] != null) ...[
              const Divider(height: 16),
              _buildFactRow('Office Location', ad['office_location'].toString(), isDark),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFactRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildScopesCard(bool isDark) {
    final scopes = _user.activeScopes;
    final roles = _user.assignedRoles;
    final perms = _user.permissions;

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
          // 1. Assigned Roles
          if (roles.isNotEmpty) ...[
            Text(
              'Institutional Roles (${roles.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: roles.map((r) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.wineRed.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const AppSvgIcon(
                        svgString: AppSvgIcon.shield,
                        size: 12,
                        color: AppColors.wineRed,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        r.roleName.isNotEmpty ? r.roleName : r.roleCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (r.scopeCode != null && r.scopeCode!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${r.scopeCode})',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
          ],

          // 2. Scopes
          Text(
            scopes.isNotEmpty
                ? 'Authorized Scope Boundaries (${scopes.length})'
                : 'No active permissions or scopes assigned (Restricted).',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          if (scopes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: scopes.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppSvgIcon(
                        svgString: AppSvgIcon.lock,
                        size: 11,
                        color: AppColors.wineRed,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        s,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // 3. Permissions list
          if (perms.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              'Granted Authority Rights (${perms.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: perms.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    p,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // 4. Application Theme Mode Toggle
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Application Theme Preference',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDark ? 'Dark Mode Active' : 'Light Mode Active',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: AppTheme.themeModeNotifier,
                builder: (context, mode, _) {
                  final isCurrentlyDark = mode == ThemeMode.dark;
                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: AppSvgIcon(
                      svgString: isCurrentlyDark ? AppSvgIcon.eye : AppSvgIcon.eyeOff,
                      size: 14,
                    ),
                    label: Text(
                      isCurrentlyDark ? 'Switch to Light' : 'Switch to Dark',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => AppTheme.toggleTheme(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionBar(bool isDark) {
    final canManage = widget.currentAdminUser?.canManageUsers ?? true;

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
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Identity Governance & Lifecycle Actions',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _user.isActive
                      ? 'Active institutional credential'
                      : 'Discontinued / Inactive standing',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                if (!canManage) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Lifecycle modifications restricted to Campus Administrator.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.wineRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canManage) ...[
            if (_user.isActive)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusRed,
                  side: const BorderSide(color: AppColors.statusRed, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const AppSvgIcon(
                  svgString: AppSvgIcon.userX,
                  size: 14,
                  color: AppColors.statusRed,
                ),
                label: const Text('Discontinue User', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _showDiscontinueDialog,
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.githubGreen,
                  side: const BorderSide(color: AppColors.githubGreen, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const AppSvgIcon(
                  svgString: AppSvgIcon.userCheck,
                  size: 14,
                  color: AppColors.githubGreen,
                ),
                label: const Text('Reactivate User', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _showReactivateDialog,
              ),
          ],
        ],
      ),
    );
  }
}
