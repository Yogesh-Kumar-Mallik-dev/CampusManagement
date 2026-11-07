import 'package:flutter/material.dart';
import '../models/academic.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_skeleton.dart';

/// Geometry categorization for timetable visual rendering.
enum TimetableRenderGeometry {
  /// 1-unit block representing a single 1-hour slot (9-10, 10-11, etc.)
  square,

  /// 2-unit block representing two consecutive occupied slots
  rectangle,
}

/// View modes supported by the timetable screen.
enum TimetableViewMode {
  dayTimeline,
  weekMatrix,
}

/// A rendered timetable block in the daily schedule.
class RenderedTimetableBlock {
  final TimetableRenderGeometry geometry;
  final int blockIndex;
  final int span; // 1 for square, 2 for rectangle
  final String startTime;
  final String endTime;
  final String periodLabel; // e.g. "P1" or "P1-P2"
  final TimetableSlotModel firstSlot;
  final TimetableSlotModel? secondSlot;

  RenderedTimetableBlock.square({
    required this.blockIndex,
    required this.startTime,
    required this.endTime,
    required this.periodLabel,
    required this.firstSlot,
  })  : geometry = TimetableRenderGeometry.square,
        span = 1,
        secondSlot = null;

  RenderedTimetableBlock.rectangle({
    required this.blockIndex,
    required this.startTime,
    required this.endTime,
    required this.periodLabel,
    required this.firstSlot,
    required this.secondSlot,
  })  : geometry = TimetableRenderGeometry.rectangle,
        span = 2;

  bool get isOccupied => firstSlot.isOccupied;
  bool get isFree => firstSlot.isFree;
  bool get isOff => firstSlot.isOff;
  bool get isRectangle => geometry == TimetableRenderGeometry.rectangle;
}

/// Canonical 8 one-hour blocks spanning the operational day from 9 AM to 5 PM.
class CanonicalScheduleDef {
  static const List<Map<String, String>> blocks = [
    {'start': '09:00', 'end': '10:00', 'period': 'P1', 'label': '09:00 - 10:00'},
    {'start': '10:00', 'end': '11:00', 'period': 'P2', 'label': '10:00 - 11:00'},
    {'start': '11:00', 'end': '12:00', 'period': 'P3', 'label': '11:00 - 12:00'},
    {'start': '12:00', 'end': '13:00', 'period': 'P4', 'label': '12:00 - 13:00'},
    {'start': '13:00', 'end': '14:00', 'period': 'P5', 'label': '13:00 - 14:00'},
    {'start': '14:00', 'end': '15:00', 'period': 'P6', 'label': '14:00 - 15:00'},
    {'start': '15:00', 'end': '16:00', 'period': 'P7', 'label': '15:00 - 16:00'},
    {'start': '16:00', 'end': '17:00', 'period': 'P8', 'label': '16:00 - 17:00'},
  ];
}

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
  TimetableViewMode _viewMode = TimetableViewMode.dayTimeline;
  PageLoadState _loadState = PageLoadState.pending;
  String? _errorMessage;

  List<TimetableSlotModel> _allSlots = [];
  List<TimetableSlotModel> _canonicalDaySlots = [];
  List<RenderedTimetableBlock> _renderedBlocks = [];

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    // Default to current weekday if Mon-Sat, else Monday
    final currentWeekday = DateTime.now().weekday;
    if (currentWeekday >= 1 && currentWeekday <= 6) {
      _selectedDay = currentWeekday;
    }

    final cached = widget.storage.cachedTimetable;
    if (cached.isNotEmpty) {
      _allSlots = List.from(cached);
      _recomputeDaySchedule();
      _loadState = PageLoadState.success;
    }
    _loadData();
  }

  void _recomputeDaySchedule() {
    // 1. Build the canonical 8 1-hour slots for the selected day
    _canonicalDaySlots = List.generate(8, (i) {
      final def = CanonicalScheduleDef.blocks[i];
      final start = def['start']!;
      final end = def['end']!;

      final match = _allSlots.firstWhere(
        (s) => s.dayOfWeek == _selectedDay && s.startTime == start,
        orElse: () => TimetableSlotModel(
          id: 'temp-slot-$_selectedDay-$start',
          courseId: '',
          courseCode: 'FREE',
          courseName: i == 3 ? 'Midday Recess & Lunch' : 'Open Study Period',
          scopeCode: widget.activeScope,
          instructorName: '',
          dayOfWeek: _selectedDay,
          startTime: start,
          endTime: end,
          roomNumber: i == 3 ? 'Cafeteria' : 'Library / Study Hall',
          slotType: 'free',
        ),
      );
      return match;
    });

    // 2. Greedy grouping: consecutive occupied blocks -> Rectangle (2 units), otherwise Square (1 unit)
    final List<RenderedTimetableBlock> grouped = [];
    int i = 0;
    while (i < _canonicalDaySlots.length) {
      final current = _canonicalDaySlots[i];
      final currentDef = CanonicalScheduleDef.blocks[i];

      if (current.isOccupied &&
          i + 1 < _canonicalDaySlots.length &&
          _canonicalDaySlots[i + 1].isOccupied) {
        final next = _canonicalDaySlots[i + 1];
        final nextDef = CanonicalScheduleDef.blocks[i + 1];

        grouped.add(RenderedTimetableBlock.rectangle(
          blockIndex: i,
          startTime: currentDef['start']!,
          endTime: nextDef['end']!,
          periodLabel: '${currentDef['period']}-${nextDef['period']}',
          firstSlot: current,
          secondSlot: next,
        ));
        i += 2;
      } else {
        grouped.add(RenderedTimetableBlock.square(
          blockIndex: i,
          startTime: currentDef['start']!,
          endTime: currentDef['end']!,
          periodLabel: currentDef['period']!,
          firstSlot: current,
        ));
        i += 1;
      }
    }
    _renderedBlocks = grouped;
  }

  Future<void> _loadData() async {
    if (_allSlots.isEmpty) {
      setState(() {
        _loadState = PageLoadState.pending;
        _errorMessage = null;
      });
    }
    try {
      final data = await widget.storage.getTimetable(widget.activeScope);
      if (mounted) {
        setState(() {
          _allSlots = data;
          _recomputeDaySchedule();
          _loadState = PageLoadState.success;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_allSlots.isEmpty) {
            _loadState = PageLoadState.failed;
            _errorMessage = 'Failed to load timetable schedule. Check network connection.';
          }
        });
      }
    }
  }

  Future<void> _openEditBlockModal(TimetableSlotModel slot, int blockIndex) async {
    final updated = await showModalBottomSheet<TimetableSlotModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BlockEditorSheet(
        slot: slot,
        blockIndex: blockIndex,
        dayOfWeek: _selectedDay,
        scopeCode: widget.activeScope,
      ),
    );

    if (updated != null && mounted) {
      await widget.storage.saveTimetableSlot(updated);
      setState(() {
        final existingIdx = _allSlots.indexWhere((s) => s.id == updated.id);
        if (existingIdx >= 0) {
          _allSlots[existingIdx] = updated;
        } else {
          _allSlots.add(updated);
        }
        _recomputeDaySchedule();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Timetable (9 AM - 5 PM)'),
        actions: [
          // View Mode Toggle (Day Timeline vs Week Matrix)
          IconButton(
            icon: Icon(
              _viewMode == TimetableViewMode.dayTimeline
                  ? Icons.calendar_view_week
                  : Icons.view_agenda_outlined,
              size: 20,
            ),
            tooltip: _viewMode == TimetableViewMode.dayTimeline
                ? 'Switch to Week Matrix View'
                : 'Switch to Day Timeline View',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == TimetableViewMode.dayTimeline
                    ? TimetableViewMode.weekMatrix
                    : TimetableViewMode.dayTimeline;
              });
            },
          ),
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
          // Fixed Day Selector Bar
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
                          _recomputeDaySchedule();
                        });
                      },
                    ),
                  ),
                );
              }),
            ),
          ),

          // Operational Status Summary Ribbon
          _buildMetricsRibbon(isDark),

          // Main View Content
          Expanded(
            child: _buildContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRibbon(bool isDark) {
    int classCount = 0;
    int rectCount = 0;
    int freeCount = 0;
    int offCount = 0;

    for (final s in _canonicalDaySlots) {
      if (s.isOccupied) {
        classCount++;
      } else if (s.isFree) {
        freeCount++;
      } else if (s.isOff) {
        offCount++;
      }
    }

    for (final b in _renderedBlocks) {
      if (b.isRectangle) {
        rectCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildSummaryChip(
            isDark: isDark,
            label: '$classCount Classes',
            sublabel: '$rectCount Rectangles',
            badgeColor: AppColors.wineRed,
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            isDark: isDark,
            label: '$freeCount Free Periods',
            sublabel: 'Campus Open',
            badgeColor: const Color(0xFF238636),
          ),
          const SizedBox(width: 8),
          _buildSummaryChip(
            isDark: isDark,
            label: '$offCount Declared Off',
            sublabel: 'Dismissed',
            badgeColor: const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required bool isDark,
    required String label,
    required String sublabel,
    required Color badgeColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                sublabel,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
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
        if (_viewMode == TimetableViewMode.weekMatrix) {
          return _buildWeekMatrixView(isDark);
        }
        return _buildDayTimelineView(isDark);
    }
  }

  Widget _buildDayTimelineView(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _renderedBlocks.length,
      itemBuilder: (context, idx) {
        final block = _renderedBlocks[idx];
        if (block.isRectangle) {
          return _buildRectangleBlock(isDark, block);
        }
        return _buildSquareBlock(isDark, block);
      },
    );
  }

  /// Builds a 2-unit continuous RECTANGLE block formed by two consecutive occupied blocks.
  Widget _buildRectangleBlock(bool isDark, RenderedTimetableBlock block) {
    final first = block.firstSlot;
    final second = block.secondSlot!;
    final isLab = first.slotType.toLowerCase() == 'lab' ||
        second.slotType.toLowerCase() == 'lab';
    final isSameCourse = first.courseCode == second.courseCode &&
        first.courseCode.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 228, // Exactly 2 units high (2 x 108 + gap)
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.wineRed.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Continuous 2-Hour Time Ruler on Left
          Container(
            width: 86,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8.5)),
              border: Border(
                right: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text(
                      block.startTime,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      block.periodLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.wineRed,
                      ),
                    ),
                  ],
                ),
                // Visual continuous connector indicator
                Container(
                  width: 3,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.wineRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.wineRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'RECTANGLE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppColors.wineRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      block.endTime,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main 2-Unit Card Body
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8.5)),
                onTap: () => _openEditBlockModal(first, block.blockIndex),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: isSameCourse
                      ? _buildUnifiedRectangleContent(isDark, first, isLab, block)
                      : _buildSplitRectangleContent(isDark, first, second, block),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedRectangleContent(
    bool isDark,
    TimetableSlotModel slot,
    bool isLab,
    RenderedTimetableBlock block,
  ) {
    final typeBadge = isLab
        ? AppColors.primaryBadge(isDark)
        : AppColors.greenBadge(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: typeBadge.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: typeBadge.border, width: 1),
              ),
              child: Text(
                isLab ? '2-HOUR LAB SESSION' : 'DOUBLE LECTURE BLOCK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: typeBadge.text,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'RECTANGLE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          slot.courseCode,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          slot.courseName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const Spacer(),
        const Divider(height: 16),
        Row(
          children: [
            const AppSvgIcon(svgString: AppSvgIcon.user, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                slot.instructorName.isNotEmpty ? slot.instructorName : 'Faculty Lead',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const AppSvgIcon(svgString: AppSvgIcon.mapPin, size: 14),
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
    );
  }

  Widget _buildSplitRectangleContent(
    bool isDark,
    TimetableSlotModel first,
    TimetableSlotModel second,
    RenderedTimetableBlock block,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.wineRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'CONSECUTIVE PERIODS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.wineRed,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'RECTANGLE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Sub-block 1
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    first.courseCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.wineRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      first.slotType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.wineRed,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    first.roomNumber,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                first.courseName,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                first.instructorName,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ),
        // Connecting Divider
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'CONSECUTIVE OCCUPIED',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                height: 1,
              ),
            ),
          ],
        ),
        // Sub-block 2
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    second.courseCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.wineRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      second.slotType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.wineRed,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    second.roomNumber,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                second.courseName,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                second.instructorName,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a 1-unit SQUARE block (Standard 1-hour unit: standalone occupied, free, or off).
  Widget _buildSquareBlock(bool isDark, RenderedTimetableBlock block) {
    final slot = block.firstSlot;

    if (slot.isFree) {
      return _buildFreeSquareBlock(isDark, block);
    } else if (slot.isOff) {
      return _buildOffSquareBlock(isDark, block);
    }
    return _buildOccupiedSquareBlock(isDark, block);
  }

  Widget _buildOccupiedSquareBlock(bool isDark, RenderedTimetableBlock block) {
    final slot = block.firstSlot;
    final isLab = slot.slotType.toLowerCase() == 'lab';
    final typeBadge = isLab
        ? AppColors.primaryBadge(isDark)
        : AppColors.greenBadge(isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 108, // Standard 1-unit height ("Square")
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openEditBlockModal(slot, block.blockIndex),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 1-Hour Time Box
                Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        block.startTime,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        block.endTime,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        block.periodLabel,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.wineRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Course Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeBadge.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: typeBadge.border, width: 1),
                            ),
                            child: Text(
                              slot.slotType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: typeBadge.text,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'SQUARE',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slot.courseName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const AppSvgIcon(svgString: AppSvgIcon.user, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              slot.instructorName.isNotEmpty ? slot.instructorName : 'Faculty',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const AppSvgIcon(svgString: AppSvgIcon.mapPin, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            slot.roomNumber,
                            style: TextStyle(
                              fontSize: 11,
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
          ),
        ),
      ),
    );
  }

  /// Distinct FREE PERIOD styling (Campus is open, self-study/recess, NOT OFF).
  Widget _buildFreeSquareBlock(bool isDark, RenderedTimetableBlock block) {
    final slot = block.firstSlot;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 108,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1B2E24).withValues(alpha: 0.35)
            : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? const Color(0xFF238636).withValues(alpha: 0.6)
              : const Color(0xFFA7F3D0),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openEditBlockModal(slot, block.blockIndex),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Time box with emerald accent
                Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F2017)
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF238636).withValues(alpha: 0.4)
                          : const Color(0xFF6EE7B7),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        block.startTime,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: isDark ? const Color(0xFF7EE787) : const Color(0xFF065F46),
                        ),
                      ),
                      Text(
                        block.endTime,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: isDark ? const Color(0xFF7EE787).withValues(alpha: 0.7) : const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        block.periodLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF7EE787) : const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Free Period Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF238636) : const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FREE PERIOD',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            slot.courseName.isNotEmpty ? slot.courseName : 'Self-Study & Research',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'SQUARE',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Active academic hours - open for library, recess, or faculty sync',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF7EE787) : const Color(0xFF047857),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const AppSvgIcon(svgString: AppSvgIcon.book, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            slot.roomNumber.isNotEmpty ? slot.roomNumber : 'Open Campus / Library',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Distinct DECLARED OFF styling (Session dismissed / cancelled / closed, NOT FREE).
  Widget _buildOffSquareBlock(bool isDark, RenderedTimetableBlock block) {
    final slot = block.firstSlot;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 108,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2229).withValues(alpha: 0.6)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openEditBlockModal(slot, block.blockIndex),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Time box with neutral muted styling
                Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        block.startTime,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      Text(
                        block.endTime,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        block.periodLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Declared Off Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF484F58) : const Color(0xFF64748B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DECLARED OFF',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            slot.courseName.isNotEmpty ? slot.courseName : 'No Class / Dismissed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'SQUARE',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No academic operations scheduled - campus day concluded or session off',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const AppSvgIcon(svgString: AppSvgIcon.clock, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Dismissed / Day Concluded',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Full Weekly Matrix View (Mon-Sat x 8 Hours = 48 Cells with merged rectangles)
  Widget _buildWeekMatrixView(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 840,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Matrix Header (Days)
              Container(
                height: 40,
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
                  children: [
                    Container(
                      width: 90,
                      alignment: Alignment.center,
                      child: Text(
                        'TIME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                    ...List.generate(_days.length, (idx) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            _days[idx],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Matrix Rows (8 1-Hour Blocks)
              ...List.generate(8, (hourIdx) {
                final def = CanonicalScheduleDef.blocks[hourIdx];
                return Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: hourIdx.isEven
                        ? (isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFAFA))
                        : (isDark ? const Color(0xFF161B22) : Colors.white),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Time Label
                      Container(
                        width: 90,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              def['start']!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              def['end']!,
                              style: TextStyle(
                                fontSize: 9,
                                fontFamily: 'monospace',
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Day Cells
                      ...List.generate(_days.length, (dayIdx) {
                        final dayNum = dayIdx + 1;
                        final slot = _allSlots.firstWhere(
                          (s) => s.dayOfWeek == dayNum && s.startTime == def['start'],
                          orElse: () => TimetableSlotModel(
                            id: 'temp-$dayNum-$hourIdx',
                            courseId: '',
                            courseCode: 'FREE',
                            courseName: 'Free',
                            scopeCode: widget.activeScope,
                            instructorName: '',
                            dayOfWeek: dayNum,
                            startTime: def['start']!,
                            endTime: def['end']!,
                            roomNumber: '-',
                            slotType: 'free',
                          ),
                        );

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: slot.isOccupied
                                  ? AppColors.wineRed.withValues(alpha: isDark ? 0.25 : 0.1)
                                  : (slot.isFree
                                      ? (isDark
                                          ? const Color(0xFF238636).withValues(alpha: 0.2)
                                          : const Color(0xFFD1FAE5))
                                      : (isDark
                                          ? const Color(0xFF30363D).withValues(alpha: 0.3)
                                          : const Color(0xFFE2E8F0))),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: slot.isOccupied
                                    ? AppColors.wineRed.withValues(alpha: 0.4)
                                    : (slot.isFree
                                        ? const Color(0xFF238636).withValues(alpha: 0.4)
                                        : Colors.transparent),
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => _openEditBlockModal(slot, hourIdx),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    slot.isOccupied
                                        ? slot.courseCode
                                        : (slot.isFree ? 'FREE' : 'OFF'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: slot.isOccupied
                                          ? AppColors.wineRed
                                          : (slot.isFree
                                              ? (isDark ? const Color(0xFF7EE787) : const Color(0xFF047857))
                                              : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (slot.isOccupied)
                                    Text(
                                      slot.roomNumber,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontFamily: 'monospace',
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
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
              const AppSkeleton(width: 72, height: 60, borderRadius: 6),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppSkeleton(width: 80, height: 16, borderRadius: 4),
                    SizedBox(height: 8),
                    AppSkeleton(width: 180, height: 13, borderRadius: 4),
                    SizedBox(height: 12),
                    AppSkeleton(width: 120, height: 12, borderRadius: 4),
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

/// Interactive Bottom Sheet for Editing / Declaring Block Status (Period, Free, Off).
class _BlockEditorSheet extends StatefulWidget {
  final TimetableSlotModel slot;
  final int blockIndex;
  final int dayOfWeek;
  final String scopeCode;

  const _BlockEditorSheet({
    required this.slot,
    required this.blockIndex,
    required this.dayOfWeek,
    required this.scopeCode,
  });

  @override
  State<_BlockEditorSheet> createState() => _BlockEditorSheetState();
}

class _BlockEditorSheetState extends State<_BlockEditorSheet> {
  late String _statusType; // 'lecture', 'lab', 'tutorial', 'free', 'off'
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _instructorCtrl;
  late TextEditingController _roomCtrl;

  @override
  void initState() {
    super.initState();
    _statusType = widget.slot.slotType.toLowerCase();
    if (_statusType != 'free' && _statusType != 'off' && _statusType != 'lab' && _statusType != 'tutorial') {
      _statusType = 'lecture';
    }
    _codeCtrl = TextEditingController(text: widget.slot.courseCode);
    _nameCtrl = TextEditingController(text: widget.slot.courseName);
    _instructorCtrl = TextEditingController(text: widget.slot.instructorName);
    _roomCtrl = TextEditingController(text: widget.slot.roomNumber);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _instructorCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final def = CanonicalScheduleDef.blocks[widget.blockIndex];

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configure Schedule Block (${def['label']})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '1-Hour Slot: assign a class period, declare free, or declare off',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode Selector: Period vs Free vs Off
            Text(
              'BLOCK TYPE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildModeTab('Lecture', 'lecture', isDark),
                const SizedBox(width: 8),
                _buildModeTab('Lab', 'lab', isDark),
                const SizedBox(width: 8),
                _buildModeTab('Free Period', 'free', isDark),
                const SizedBox(width: 8),
                _buildModeTab('Declared Off', 'off', isDark),
              ],
            ),
            const SizedBox(height: 18),

            if (_statusType == 'free') ...[
              _buildFreeGuidance(isDark),
            ] else if (_statusType == 'off') ...[
              _buildOffGuidance(isDark),
            ] else ...[
              // Period Form
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Course Code (e.g. CS301)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Course Name (e.g. Operating Systems)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instructorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instructor Name (e.g. Dr. Priya Nair)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _roomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Room / Venue (e.g. LHC-302)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Save Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final String code;
                  final String name;
                  final String room;
                  if (_statusType == 'free') {
                    code = 'FREE';
                    name = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Self-Study & Open Library';
                    room = _roomCtrl.text.isNotEmpty ? _roomCtrl.text : 'Central Library';
                  } else if (_statusType == 'off') {
                    code = 'OFF';
                    name = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Declared Off';
                    room = '-';
                  } else {
                    code = _codeCtrl.text.trim();
                    name = _nameCtrl.text.trim();
                    room = _roomCtrl.text.trim();
                  }

                  final updated = widget.slot.copyWith(
                    courseCode: code,
                    courseName: name,
                    instructorName: (_statusType == 'free' || _statusType == 'off') ? '' : _instructorCtrl.text.trim(),
                    roomNumber: room,
                    slotType: _statusType,
                  );
                  Navigator.pop(context, updated);
                },
                child: const Text(
                  'Save Block Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, String type, bool isDark) {
    final isSelected = _statusType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _statusType = type;
            if (type == 'free' && _nameCtrl.text.isEmpty) {
              _nameCtrl.text = 'Self-Study & Recess';
              _roomCtrl.text = 'Central Library';
            } else if (type == 'off' && _nameCtrl.text.isEmpty) {
              _nameCtrl.text = 'Declared Off / Dismissed';
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.wineRed
                : (isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? AppColors.wineRed
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreeGuidance(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E24) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF238636) : const Color(0xFFA7F3D0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              AppSvgIcon(svgString: AppSvgIcon.book, size: 14),
              SizedBox(width: 6),
              Text(
                'Free Period (Campus Open)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Students are active on campus without scheduled lectures. Ideal for library research, lab open hours, peer study circles, and lunch recess.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF7EE787) : const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffGuidance(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              AppSvgIcon(svgString: AppSvgIcon.clock, size: 14),
              SizedBox(width: 6),
              Text(
                'Declared Off (Campus Hours Closed)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Keep in mind: Free is not the same as Off. Declared Off marks the schedule as closed, cancelled, or half-day weekend dismissal with no campus operations.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
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
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
