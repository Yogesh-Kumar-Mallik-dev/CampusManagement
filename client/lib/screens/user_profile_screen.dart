import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_logo.dart';

class UserProfileScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final String userIdentifier; // id or campus handle
  final UserModel? initialUser;
  final UserModel? currentAdminUser;
  final VoidCallback? onUserUpdated;

  const UserProfileScreen({
    super.key,
    required this.storage,
    required this.userIdentifier,
    this.initialUser,
    this.currentAdminUser,
    this.onUserUpdated,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late UserModel _user;
  bool _isLoading = false;
  String? _errorMessage;

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
      if (mounted) {
        setState(() {
          _user = profile;
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
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                      ),
                      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      items: options.map((opt) {
                        return DropdownMenuItem(
                          value: opt,
                          child: Text(
                            opt.toUpperCase(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
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
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
      appBar: AppBar(
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
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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

                          // 3. Official Identity Grid
                          _buildSectionHeader('Official Identity & Verification', AppSvgIcon.shield),
                          const SizedBox(height: 10),
                          _buildIdentityGrid(isDark),
                          const SizedBox(height: 24),

                          // 4. Institutional Standing & Roles
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

                          // 5. Scoped Security & Permissions
                          _buildSectionHeader('Scoped RBAC Authority', AppSvgIcon.lock),
                          const SizedBox(height: 10),
                          _buildScopesCard(isDark),
                          const SizedBox(height: 32),

                          // 6. Administrative Lifecycle Actions
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
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
            padding: const EdgeInsets.all(22),
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
                // Badges row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
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
                    ),
                    const SizedBox(width: 8),
                    // Vector ID Code badge
                    Row(
                      children: [
                        AppSvgIcon(
                          svgString: AppSvgIcon.qrCode,
                          size: 16,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'CAMPUS-NFC-VERIFIED',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
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

  Widget _buildIdentityGrid(bool isDark) {
    final fields = [
      (label: 'Institutional Email', value: _user.email, icon: AppSvgIcon.mail),
      (label: 'Personal Email', value: _user.personalEmail ?? 'Not registered', icon: AppSvgIcon.mail),
      (label: 'Phone Number', value: _user.phone ?? 'Not registered', icon: AppSvgIcon.phone),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 550;
          return Wrap(
            spacing: 20,
            runSpacing: 16,
            children: fields.map((f) {
              return SizedBox(
                width: isWide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth,
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
                            maxLines: 1,
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
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildScopesCard(bool isDark) {
    final scopes = _user.activeScopes;

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
        ],
      ),
    );
  }

  Widget _buildAdminActionBar(bool isDark) {
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
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
              ],
            ),
          ),
          const SizedBox(width: 12),
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
      ),
    );
  }
}
