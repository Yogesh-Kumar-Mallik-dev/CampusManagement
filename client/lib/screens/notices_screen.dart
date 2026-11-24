import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/academic.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/app_skeleton.dart';

class NoticesScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final List<String> userScopes;
  final UserModel? currentUser;

  const NoticesScreen({
    super.key,
    required this.storage,
    required this.userScopes,
    this.currentUser,
  });

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  static final DateFormat _noticeDateFormat = DateFormat('dd MMM, hh:mm a');

  PageLoadState _loadState = PageLoadState.pending;
  String? _errorMessage;
  List<NoticeModel> _notices = [];
  List<NoticeModel> _filteredNotices = [];
  String _selectedCategory = 'all';

  final List<String> _categories = ['all', 'academic', 'exam', 'urgent', 'hostel', 'general'];

  void _recomputeFilteredNotices() {
    if (_selectedCategory == 'all') {
      _filteredNotices = _notices;
      return;
    }
    final catLower = _selectedCategory.toLowerCase();
    _filteredNotices = _notices.where((n) => n.category.toLowerCase() == catLower).toList();
  }

  @override
  void initState() {
    super.initState();
    final cached = widget.storage.cachedNotices;
    if (cached.isNotEmpty) {
      _notices = List.from(cached);
      _recomputeFilteredNotices();
      _loadState = PageLoadState.success;
    }
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    if (_notices.isEmpty) {
      setState(() {
        _loadState = PageLoadState.pending;
        _errorMessage = null;
      });
    }
    try {
      final data = await widget.storage.getNotices(widget.userScopes);
      if (mounted) {
        setState(() {
          _notices = data;
          _recomputeFilteredNotices();
          _loadState = PageLoadState.success;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_notices.isEmpty) {
            _loadState = PageLoadState.failed;
            _errorMessage = 'Failed to load notices. Check connection.';
          }
        });
      }
    }
  }

  Future<void> _openPublishNoticeDialog(BuildContext context, bool isDark) async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final scopeCtrl = TextEditingController(text: 'global');
    String selectedCategory = 'general';
    String selectedPriority = 'normal';
    String? dialogError;
    bool isPublishing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              key: const Key('dialog-publish-notice'),
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              title: const Row(
                children: [
                  AppSvgIcon(svgString: AppSvgIcon.bell, size: 18, color: AppColors.wineRed),
                  SizedBox(width: 8),
                  Text('Issue Institutional Notice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.statusRedSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.statusRed),
                          ),
                          child: Text(dialogError!, style: const TextStyle(fontSize: 12, color: AppColors.statusRed)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text('Notice Title *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        key: const Key('input-notice-title'),
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Schedule for Mid-Term Examination 2026',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                AppDropdown<String>(
                                  key: const Key('dropdown-notice-category'),
                                  value: selectedCategory,
                                  items: const [
                                    AppDropdownItem(value: 'academic', label: 'Academic'),
                                    AppDropdownItem(value: 'exam', label: 'Examination'),
                                    AppDropdownItem(value: 'urgent', label: 'Urgent Advisory'),
                                    AppDropdownItem(value: 'hostel', label: 'Hostel & Housing'),
                                    AppDropdownItem(value: 'general', label: 'General Circular'),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedCategory = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Priority', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                AppDropdown<String>(
                                  key: const Key('dropdown-notice-priority'),
                                  value: selectedPriority,
                                  items: const [
                                    AppDropdownItem(value: 'normal', label: 'Normal'),
                                    AppDropdownItem(value: 'high', label: 'High Priority'),
                                    AppDropdownItem(value: 'urgent', label: 'Urgent / Flash'),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedPriority = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Target Scope Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        key: const Key('input-notice-scope'),
                        controller: scopeCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. global, dept:cse, or sec:cse-3a',
                          helperText: 'Use "global" for campus-wide bulletins',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Circular Content / Body *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        key: const Key('input-notice-content'),
                        controller: contentCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Enter official circular details, instructions, and dates...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isPublishing ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('btn-submit-notice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.wineRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: isPublishing
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          final content = contentCtrl.text.trim();
                          final scope = scopeCtrl.text.trim().isEmpty ? 'global' : scopeCtrl.text.trim();

                          if (title.isEmpty) {
                            setDialogState(() => dialogError = 'Notice title is required.');
                            return;
                          }
                          if (content.isEmpty) {
                            setDialogState(() => dialogError = 'Circular content cannot be empty.');
                            return;
                          }

                          setDialogState(() {
                            isPublishing = true;
                            dialogError = null;
                          });

                          try {
                            final payload = {
                              'title': title,
                              'content': content,
                              'category': selectedCategory,
                              'priority': selectedPriority,
                              'target_scope_code': scope,
                              'publisher_id': widget.currentUser?.id,
                              'publisher_name': widget.currentUser?.fullName ?? 'Campus Administration',
                            };

                            final created = await widget.storage.publishNotice(payload);
                            if (mounted) {
                              setState(() {
                                _notices.removeWhere((n) => n.id == created.id);
                                _notices.insert(0, created);
                                _recomputeFilteredNotices();
                              });
                            }
                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Notice "$title" published successfully.'),
                                  backgroundColor: AppColors.githubGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isPublishing = false;
                              dialogError = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: isPublishing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Publish Bulletin'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredNotices;
    final canPublish = widget.currentUser?.canPublishNotice ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Targeted Notice Board'),
        actions: [
          if (canPublish) ...[
            ElevatedButton.icon(
              key: const Key('btn-issue-notice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wineRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const AppSvgIcon(svgString: AppSvgIcon.plus, size: 14, color: Colors.white),
              label: const Text('Issue Notice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _openPublishNoticeDialog(context, isDark),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const AppSvgIcon(svgString: AppSvgIcon.refresh, size: 18),
            onPressed: _loadNotices,
            tooltip: 'Refresh Notices',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips (Pre-allocated geometry - permanently set in stone)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat;
                return _CategoryFilterPill(
                  label: cat.toUpperCase(),
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                      _recomputeFilteredNotices();
                    });
                  },
                );
              },
            ),
          ),
          // Notice List / Skeletons / Inline Error
          Expanded(
            child: _buildContent(isDark, filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, List<NoticeModel> filtered) {
    switch (_loadState) {
      case PageLoadState.pending:
        return _buildSkeletonList(isDark);
      case PageLoadState.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InlineStateError(
              message: _errorMessage ?? 'Failed to load campus notices.',
              onRetry: _loadNotices,
            ),
          ),
        );
      case PageLoadState.success:
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppSvgIcon(
                  svgString: AppSvgIcon.bell,
                  size: 48,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'No notices found for this category',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final notice = filtered[i];
            final isUrgent = notice.priority.toLowerCase() == 'urgent';
            final isHigh = notice.priority.toLowerCase() == 'high';

            final priorityBadge = isUrgent
                ? AppColors.redBadge(isDark)
                : (isHigh
                    ? AppColors.yellowBadge(isDark)
                    : AppColors.neutralBadge(isDark));
            final scopeBadge = AppColors.neutralBadge(isDark);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isUrgent
                      ? AppColors.wineRed
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityBadge.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: priorityBadge.border,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          notice.priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: priorityBadge.text,
                          ),
                        ),
                      ),
                      Container(
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
                          'Scope: ${notice.targetScopeCode.isEmpty ? 'Global' : notice.targetScopeCode}',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: scopeBadge.text,
                          ),
                        ),
                      ),
                      Text(
                        _noticeDateFormat.format(notice.publishedAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    notice.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notice.content,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
    }
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
                children: const [
                  AppSkeleton(width: 60, height: 18, borderRadius: 4),
                  SizedBox(width: 8),
                  AppSkeleton(width: 90, height: 18, borderRadius: 4),
                  Spacer(),
                  AppSkeleton(width: 80, height: 14, borderRadius: 4),
                ],
              ),
              const SizedBox(height: 12),
              const AppSkeleton(width: 220, height: 16, borderRadius: 4),
              const SizedBox(height: 8),
              const AppSkeleton.rect(height: 13, borderRadius: 4),
              const SizedBox(height: 6),
              const AppSkeleton(width: 160, height: 13, borderRadius: 4),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryFilterPill extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryFilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryFilterPill> createState() => _CategoryFilterPillState();
}

class _CategoryFilterPillState extends State<_CategoryFilterPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = widget.isSelected
        ? AppColors.wineRed
        : (_isHovered
            ? (isDark ? AppColors.darkSurfaceHover : AppColors.lightSurfaceHover)
            : (isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9)));

    final borderColor = widget.isSelected
        ? AppColors.wineRed
        : (_isHovered
            ? (isDark ? AppColors.darkBorderHover : AppColors.lightBorderHover)
            : (isDark ? AppColors.darkBorder : AppColors.lightBorder));

    final textColor = widget.isSelected
        ? Colors.white
        : (_isHovered
            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: borderColor,
              width: 1, // Constant 1px width
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor, // Pure bright white in active wine overlay!
            ),
          ),
        ),
      ),
    );
  }
}
