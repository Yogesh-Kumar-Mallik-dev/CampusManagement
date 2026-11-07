import 'package:flutter/material.dart';
import '../models/academic.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_skeleton.dart';

class TimetableScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final String activeScope;

  const TimetableScreen({
    super.key,
    required this.storage,
    required this.activeScope,
  });

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  int _selectedDay = 1; // 1 = Monday ... 6 = Saturday
  PageLoadState _loadState = PageLoadState.pending;
  String? _errorMessage;
  List<TimetableSlotModel> _slots = [];
  List<TimetableSlotModel> _daySlots = [];

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  void _recomputeDaySlots() {
    _daySlots = _slots.where((s) => s.dayOfWeek == _selectedDay).toList();
  }

  @override
  void initState() {
    super.initState();
    final cached = widget.storage.cachedTimetable;
    if (cached.isNotEmpty) {
      _slots = List.from(cached);
      _recomputeDaySlots();
      _loadState = PageLoadState.success;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    if (_slots.isEmpty) {
      setState(() {
        _loadState = PageLoadState.pending;
        _errorMessage = null;
      });
    }
    try {
      final data = await widget.storage.getTimetable(widget.activeScope);
      if (mounted) {
        setState(() {
          _slots = data;
          _recomputeDaySlots();
          _loadState = PageLoadState.success;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_slots.isEmpty) {
            _loadState = PageLoadState.failed;
            _errorMessage = 'Failed to load timetable schedule. Check network connection.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daySlots = _daySlots;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Timetable'),
        actions: [
          IconButton(
            icon: const AppSvgIcon(svgString: AppSvgIcon.refresh, size: 18),
            onPressed: _loadData,
            tooltip: 'Refresh Schedule',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Fixed-slot Day Selector Bar (Pre-allocated geometry eliminates layout shifts)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: List.generate(_days.length, (idx) {
                final dayNum = idx + 1;
                final isSelected = _selectedDay == dayNum;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _DaySelectorPill(
                      label: _days[idx],
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedDay = dayNum;
                          _recomputeDaySlots();
                        });
                      },
                    ),
                  ),
                );
              }),
            ),
          ),
          // Slots list / Skeleton / Inline Error
          Expanded(
            child: _buildContent(isDark, daySlots),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, List<TimetableSlotModel> daySlots) {
    switch (_loadState) {
      case PageLoadState.pending:
        return _buildSkeletonList(isDark);
      case PageLoadState.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InlineStateError(
              message: _errorMessage ?? 'Failed to load timetable schedule.',
              onRetry: _loadData,
            ),
          ),
        );
      case PageLoadState.success:
        if (daySlots.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppSvgIcon(
                  svgString: AppSvgIcon.calendar,
                  size: 48,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'No scheduled classes for this day',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: daySlots.length,
          itemBuilder: (context, i) {
            final slot = daySlots[i];
            final isLab = slot.slotType.toLowerCase() == 'lab';
            final typeBadge = isLab
                ? AppColors.primaryBadge(isDark)
                : AppColors.greenBadge(isDark);
            final timeBadge = AppColors.neutralBadge(isDark);

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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Column
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: timeBadge.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: timeBadge.border,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          slot.startTime,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          slot.endTime,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Subject Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              slot.courseCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeBadge.background,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: typeBadge.border,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                slot.slotType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: typeBadge.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          slot.courseName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            AppSvgIcon(
                              svgString: AppSvgIcon.user,
                              size: 13,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              slot.instructorName.isNotEmpty ? slot.instructorName : 'Faculty',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const Spacer(),
                            AppSvgIcon(
                              svgString: AppSvgIcon.mapPin,
                              size: 13,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              slot.roomNumber,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
          },
        );
    }
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeleton(width: 60, height: 48, borderRadius: 6),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        AppSkeleton(width: 72, height: 16, borderRadius: 4),
                        SizedBox(width: 8),
                        AppSkeleton(width: 48, height: 16, borderRadius: 4),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const AppSkeleton(width: 180, height: 13, borderRadius: 4),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        AppSkeleton(width: 90, height: 12, borderRadius: 4),
                        Spacer(),
                        AppSkeleton(width: 50, height: 12, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DaySelectorPill extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DaySelectorPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DaySelectorPill> createState() => _DaySelectorPillState();
}

class _DaySelectorPillState extends State<_DaySelectorPill> {
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
          height: 36,
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor, // Pure bright white in active wine overlay!
            ),
          ),
        ),
      ),
    );
  }
}
