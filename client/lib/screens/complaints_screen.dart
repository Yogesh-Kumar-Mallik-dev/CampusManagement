import 'package:flutter/material.dart';
import '../models/complaint.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dropdown.dart';

class ComplaintsScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;

  const ComplaintsScreen({
    super.key,
    required this.storage,
    this.currentUser,
  });

  static Future<ComplaintModel?> showFileComplaintDialog({
    required BuildContext context,
    required OfflineStorageService storage,
    UserModel? currentUser,
    String initialCategory = ComplaintCategory.hostel,
    String? initialTitle,
    String? initialDescription,
    VoidCallback? onSubmitted,
  }) async {
    final titleCtrl = TextEditingController(text: initialTitle ?? '');
    final descCtrl = TextEditingController(text: initialDescription ?? '');
    String category = initialCategory;
    String urgency = ComplaintUrgency.medium;
    bool isAnonymous = false;
    String? validationError;

    return showDialog<ComplaintModel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final supportsAnon = ComplaintCategory.supportsAnonymous(category);

          return AlertDialog(
            key: const Key('dialog-file-complaint'),
            title: const Text(
              'Lodge Grievance / Complaint',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit an official grievance or institutional issue for administrative review and redressal.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Selection
                    AppDropdown<String>(
                      key: const Key('select-complaint-category'),
                      labelText: 'Complaint Domain / Category',
                      value: category,
                      items: ComplaintCategory.all.map((cat) {
                        return AppDropdownItem<String>(
                          value: cat,
                          label: ComplaintCategory.displayName(cat),
                          child: Row(
                            children: [
                              Icon(ComplaintCategory.iconFor(cat), size: 15, color: AppColors.wineRed),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ComplaintCategory.displayName(cat),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            category = val;
                            if (!ComplaintCategory.supportsAnonymous(category)) {
                              isAnonymous = false;
                            }
                            validationError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Urgency Selection
                    AppDropdown<String>(
                      key: const Key('select-complaint-urgency'),
                      labelText: 'Urgency / Severity Level',
                      value: urgency,
                      items: ComplaintUrgency.all.map((urg) {
                        final color = ComplaintUrgency.colorFor(urg);
                        return AppDropdownItem<String>(
                          value: urg,
                          label: ComplaintUrgency.displayName(urg),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                ComplaintUrgency.displayName(urg),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => urgency = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Title
                    TextField(
                      key: const Key('input-complaint-title'),
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Complaint Title / Summary',
                        hintText: 'Brief one-line summary of the issue',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      key: const Key('input-complaint-description'),
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Detailed Explanation',
                        hintText: 'Provide specific locations, dates, timings, or impact of the grievance...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Anonymous Switch & Policy Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: supportsAnon
                              ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                              : const Color(0xFFD97706),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                supportsAnon ? Icons.lock_outline : Icons.info_outline,
                                size: 16,
                                color: supportsAnon ? AppColors.wineRed : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  supportsAnon
                                      ? 'Anonymous Reporting (Supported)'
                                      : 'Anonymous Reporting Not Supported',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: supportsAnon ? null : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                              Switch(
                                key: const Key('switch-complaint-anonymous'),
                                value: isAnonymous,
                                activeThumbColor: AppColors.wineRed,
                                onChanged: supportsAnon
                                    ? (val) => setDialogState(() => isAnonymous = val)
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            supportsAnon
                                ? 'When enabled, your institutional handle, roll number, and name will be strictly masked as "Anonymous Reporter" in administrative rosters.'
                                : 'Institutional policy requires verified identity for ${ComplaintCategory.displayName(category)} complaints to maintain accountability, review academic records, and prevent unsubstantiated disputes.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (validationError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.statusRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.statusRed),
                        ),
                        child: Text(
                          validationError!,
                          style: const TextStyle(fontSize: 11, color: AppColors.statusRed),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const Key('btn-submit-complaint'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final cleanTitle = titleCtrl.text.trim();
                  final cleanDesc = descCtrl.text.trim();

                  if (cleanTitle.isEmpty) {
                    setDialogState(() => validationError = 'Complaint title cannot be empty');
                    return;
                  }
                  if (cleanDesc.isEmpty) {
                    setDialogState(() => validationError = 'Detailed explanation is required');
                    return;
                  }
                  if (isAnonymous && !ComplaintCategory.supportsAnonymous(category)) {
                    setDialogState(() => validationError = 'Anonymous filing is not permitted for ${ComplaintCategory.displayName(category)}');
                    return;
                  }

                  final user = currentUser;
                  final complaint = ComplaintModel(
                    id: '',
                    title: cleanTitle,
                    description: cleanDesc,
                    category: category,
                    urgency: urgency,
                    isAnonymous: isAnonymous,
                    submittedBy: user?.id ?? 'usr-anonymous',
                    submitterName: isAnonymous ? 'Anonymous Reporter' : (user?.fullName ?? 'Campus Member'),
                    submitterHandle: isAnonymous ? 'anonymous' : (user?.campusHandle ?? 'anonymous'),
                    submitterRole: isAnonymous ? 'Anonymous' : (user?.archetype ?? 'student'),
                    status: ComplaintStatus.open,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final created = await storage.createComplaint(complaint);
                    if (ctx.mounted) Navigator.pop(ctx, created);
                    if (onSubmitted != null) {
                      onSubmitted();
                    }
                    messenger.showSnackBar(
                      SnackBar(content: Text('Complaint successfully filed under ${ComplaintCategory.displayName(category)}.')),
                    );
                  } catch (e) {
                    setDialogState(() => validationError = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Submit Complaint'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<ComplaintModel> _complaints = [];
  bool _isLoading = true;

  String _selectedCategory = 'all';
  String _selectedStatus = 'all';

  bool get _hasAdminAccess => widget.currentUser?.hasAnyComplaintManagementPermission ?? false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _hasAdminAccess ? 2 : 1, vsync: this);
    _loadComplaints();
  }

  @override
  void didUpdateWidget(ComplaintsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser?.id != widget.currentUser?.id) {
      final newLength = _hasAdminAccess ? 2 : 1;
      if (_tabController.length != newLength) {
        _tabController.dispose();
        _tabController = TabController(length: newLength, vsync: this);
      }
      _loadComplaints();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.storage.getComplaints(
        viewerId: widget.currentUser?.id,
      );
      if (mounted) {
        setState(() {
          _complaints = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ComplaintModel> get _myComplaints {
    final uid = widget.currentUser?.id ?? '';
    final handle = widget.currentUser?.campusHandle ?? '';
    return _complaints.where((c) {
      final isMine = (uid.isNotEmpty && c.submittedBy == uid) ||
          (handle.isNotEmpty && c.submitterHandle == handle);
      if (!isMine) return false;
      if (_selectedCategory != 'all' && c.category != _selectedCategory) return false;
      if (_selectedStatus != 'all' && c.status != _selectedStatus) return false;
      return true;
    }).toList();
  }

  List<ComplaintModel> get _adminComplaints {
    final user = widget.currentUser;
    if (user == null) return [];

    final allowedCats = user.manageableComplaintCategories;
    final isUnrestricted = user.isAdmin || user.permissions.contains('*') || user.hasPermission('complaints:manage');

    return _complaints.where((c) {
      if (!isUnrestricted && !allowedCats.contains(c.category)) {
        return false;
      }
      if (_selectedCategory != 'all' && c.category != _selectedCategory) return false;
      if (_selectedStatus != 'all' && c.status != _selectedStatus) return false;
      return true;
    }).toList();
  }

  void _showFileComplaintDialog({String initialCategory = ComplaintCategory.hostel}) async {
    final created = await ComplaintsScreen.showFileComplaintDialog(
      context: context,
      storage: widget.storage,
      currentUser: widget.currentUser,
      initialCategory: initialCategory,
      onSubmitted: _loadComplaints,
    );
    if (created != null && mounted) {
      await _loadComplaints();
    }
  }

  void _showUpdateStatusDialog(ComplaintModel complaint) {
    String newStatus = complaint.status;
    final remarksCtrl = TextEditingController(text: complaint.resolutionRemarks ?? '');
    String? validationError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            key: const Key('dialog-update-complaint-status'),
            title: Text(
              'Update Grievance Status • ${complaint.id}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint.title,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${ComplaintCategory.displayName(complaint.category)} • Reported by ${complaint.submitterName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Dropdown
                    AppDropdown<String>(
                      key: const Key('select-new-status'),
                      labelText: 'Investigation / Resolution Status',
                      value: newStatus,
                      items: ComplaintStatus.all.map((st) {
                        final color = ComplaintStatus.colorFor(st);
                        return AppDropdownItem<String>(
                          value: st,
                          label: ComplaintStatus.displayName(st),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(ComplaintStatus.displayName(st), style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => newStatus = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Resolution Remarks
                    TextField(
                      key: const Key('input-resolution-remarks'),
                      controller: remarksCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Resolution & Action Remarks',
                        hintText: 'Record investigation findings, contractor dispatch notes, or resolution outcome...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    if (validationError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.statusRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.statusRed),
                        ),
                        child: Text(
                          validationError!,
                          style: const TextStyle(fontSize: 11, color: AppColors.statusRed),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const Key('btn-save-complaint-status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await widget.storage.updateComplaintStatus(
                      complaintId: complaint.id,
                      status: newStatus,
                      remarks: remarksCtrl.text.trim(),
                      resolvedBy: widget.currentUser?.id ?? 'officer',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadComplaints();
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Complaint ${complaint.id} status updated to ${ComplaintStatus.displayName(newStatus)}.')),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => validationError = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Save Status'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
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
                            'Institutional Grievances & Complaints',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lodge verified or anonymous complaints across student, employee, contractor, campus, and hostel categories.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        key: const Key('btn-file-complaint'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.wineRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: _showFileComplaintDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('File Complaint'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // KPI Metric Cards
                  _buildKpiRibbon(isDark),
                  const SizedBox(height: 18),

                  // Navigation Tabs (if admin access is present)
                  if (_hasAdminAccess) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: AppColors.wineRed,
                        unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        indicatorColor: AppColors.wineRed,
                        indicatorWeight: 3,
                        onTap: (_) => setState(() {}),
                        tabs: const [
                          Tab(
                            key: Key('tab-my-complaints'),
                            icon: Icon(Icons.person_outline, size: 16),
                            text: 'My Filed Grievances',
                          ),
                          Tab(
                            key: Key('tab-admin-complaints'),
                            icon: Icon(Icons.admin_panel_settings_outlined, size: 16),
                            text: 'Administrative Review & Redressal',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Category & Status Filters
                  _buildFilters(isDark),
                  const SizedBox(height: 16),

                  // Complaints List
                  _buildComplaintsList(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiRibbon(bool isDark) {
    final list = _hasAdminAccess && _tabController.index == 1 ? _adminComplaints : _myComplaints;
    final total = list.length;
    final openCount = list.where((c) => c.isOpen).length;
    final inProgressCount = list.where((c) => c.isInProgress).length;
    final resolvedCount = list.where((c) => c.isResolved).length;

    final cards = [
      _buildKpiCard('Total Reported', '$total', 'Across Selected Filters', const Color(0xFF0969DA), isDark),
      _buildKpiCard('Open / Pending', '$openCount', 'Awaiting Investigation', const Color(0xFFD97706), isDark),
      _buildKpiCard('In Progress', '$inProgressCount', 'Action Dispatched', const Color(0xFF8250DF), isDark),
      _buildKpiCard('Resolved', '$resolvedCount', 'Satisfactorily Closed', const Color(0xFF238636), isDark),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        final double itemWidth = constraints.maxWidth < 340 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, Color accentColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 240,
            child: AppDropdown<String>(
              key: const Key('filter-complaints-domain'),
              labelText: 'Domain Filter',
              value: _selectedCategory,
              items: [
                const AppDropdownItem(value: 'all', label: 'All Domains / Categories'),
                ...ComplaintCategory.all.map((cat) => AppDropdownItem(
                  value: cat,
                  label: ComplaintCategory.displayName(cat),
                )),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
          ),
          SizedBox(
            width: 200,
            child: AppDropdown<String>(
              key: const Key('filter-complaints-status'),
              labelText: 'Status Filter',
              value: _selectedStatus,
              items: [
                const AppDropdownItem(value: 'all', label: 'All Statuses'),
                ...ComplaintStatus.all.map((st) => AppDropdownItem(
                  value: st,
                  label: ComplaintStatus.displayName(st),
                )),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedStatus = val);
              },
            ),
          ),
          if (_selectedCategory != 'all' || _selectedStatus != 'all')
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: OutlinedButton.icon(
                key: const Key('btn-reset-complaint-filters'),
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.wineRed,
                  side: const BorderSide(color: AppColors.wineRed, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: () => setState(() {
                  _selectedCategory = 'all';
                  _selectedStatus = 'all';
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComplaintsList(bool isDark) {
    final list = _hasAdminAccess && _tabController.index == 1 ? _adminComplaints : _myComplaints;

    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            const SizedBox(height: 12),
            Text(
              'No complaints found matching the selected filters.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Use the "+ File Complaint" button above to register an institutional grievance.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final complaint = list[idx];
        return _buildComplaintCard(complaint, isDark);
      },
    );
  }

  Widget _buildComplaintCard(ComplaintModel complaint, bool isDark) {
    final user = widget.currentUser;
    final canManageThisCategory = user != null && user.canManageComplaintsFor(complaint.category);

    final statusColor = ComplaintStatus.colorFor(complaint.status);
    final urgencyColor = ComplaintUrgency.colorFor(complaint.urgency);

    return Container(
      key: Key('card-complaint-${complaint.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header badges row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.wineRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ComplaintCategory.iconFor(complaint.category), size: 12, color: AppColors.wineRed),
                        const SizedBox(width: 4),
                        Text(
                          ComplaintCategory.displayName(complaint.category).toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.wineRed),
                        ),
                      ],
                    ),
                  ),

                  // Urgency Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ComplaintUrgency.displayName(complaint.urgency).toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: urgencyColor),
                    ),
                  ),

                  // Anonymous or Reporter Badge
                  if (complaint.isAnonymous)
                    Container(
                      key: Key('badge-anonymous-${complaint.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF261D1D) : const Color(0xFFFFF0F2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.wineRed.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.lock, size: 10, color: AppColors.wineRed),
                          SizedBox(width: 4),
                          Text(
                            'Anonymous Reporter',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.wineRed),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            complaint.submitterName,
                            key: Key('text-submitter-name-${complaint.id}'),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  ComplaintStatus.displayName(complaint.status).toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            complaint.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            complaint.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),

          // Resolution Remarks (if present)
          if (complaint.resolutionRemarks != null && complaint.resolutionRemarks!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              key: Key('box-resolution-${complaint.id}'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B2E24) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF238636)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INVESTIGATION & RESOLUTION REMARKS:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF238636),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint.resolutionRemarks!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white : const Color(0xFF0F5132),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Footer actions & timestamps
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'ID: ${complaint.id} • Reported on ${_formatDate(complaint.createdAt)}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              if (canManageThisCategory)
                OutlinedButton.icon(
                  key: Key('btn-resolve-complaint-${complaint.id}'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => _showUpdateStatusDialog(complaint),
                  icon: const Icon(Icons.edit_note, size: 14),
                  label: const Text('Update Status', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
