import 'package:flutter/material.dart';
import '../models/academic.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_skeleton.dart';

/// Geometry categorization for timetable visual rendering.
enum TimetableRenderGeometry {
  /// 1-unit block representing a single 1-hour slot (aspect ratio ~1:1 Square)
  square,

  /// 2-unit block representing two consecutive occupied slots (horizontal Rectangle)
  rectangle,
}

/// View modes supported by the timetable screen.
enum TimetableViewMode {
  /// Selected single day rendered in horizontal row format
  dayRow,

  /// Full week with each day (Mon-Sat) rendered as a horizontal row
  weekRows,
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
  TimetableViewMode _viewMode = TimetableViewMode.dayRow;
  PageLoadState _loadState = PageLoadState.pending;
  String? _errorMessage;

  List<TimetableSlotModel> _allSlots = [];
  List<TimetableSlotModel> _canonicalDaySlots = [];
  List<RenderedTimetableBlock> _renderedBlocks = [];
  int _selectedBlockIndex = 0;

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
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

  final Set<String> _conflictingSlotIds = {};

  void _recomputeDaySchedule() {
    _canonicalDaySlots = _computeCanonicalDaySlotsForDay(_selectedDay);
    _conflictingSlotIds.clear();

    // Detect double-booking conflicts across sections/rooms/instructors
    for (final s in _canonicalDaySlots) {
      if (s.isOccupied) {
        for (final other in _allSlots) {
          if (other.id != s.id && other.dayOfWeek == s.dayOfWeek && other.isOccupied) {
            final overlaps = other.startTime.compareTo(s.endTime) < 0 && s.startTime.compareTo(other.endTime) < 0;
            if (overlaps) {
              final sameRoom = s.roomNumber.isNotEmpty && s.roomNumber != '-' && s.roomNumber.toLowerCase() == other.roomNumber.toLowerCase();
              final sameInst = s.instructorName.isNotEmpty && s.instructorName.toLowerCase() == other.instructorName.toLowerCase();
              final sameScope = s.scopeCode.isNotEmpty && s.scopeCode.toLowerCase() == other.scopeCode.toLowerCase();
              if (sameRoom || sameInst || sameScope) {
                _conflictingSlotIds.add(s.id);
              }
            }
          }
        }
      }
    }

    _renderedBlocks = _computeGroupedBlocks(_canonicalDaySlots);
    if (_selectedBlockIndex >= _renderedBlocks.length) {
      _selectedBlockIndex = 0;
    }
  }

  List<TimetableSlotModel> _computeCanonicalDaySlotsForDay(int dayNum) {
    return List.generate(8, (i) {
      final def = CanonicalScheduleDef.blocks[i];
      final start = def['start']!;
      final end = def['end']!;

      return _allSlots.firstWhere(
        (s) => s.dayOfWeek == dayNum && s.startTime == start,
        orElse: () => TimetableSlotModel(
          id: 'temp-slot-$dayNum-$start',
          courseId: '',
          courseCode: 'FREE',
          courseName: i == 3 ? 'Midday Recess & Lunch' : 'Open Study Period',
          scopeCode: widget.activeScope,
          instructorName: '',
          dayOfWeek: dayNum,
          startTime: start,
          endTime: end,
          roomNumber: i == 3 ? 'Cafeteria' : 'Library / Study Hall',
          slotType: 'free',
        ),
      );
    });
  }

  List<RenderedTimetableBlock> _computeGroupedBlocks(List<TimetableSlotModel> daySlots) {
    final List<RenderedTimetableBlock> grouped = [];
    int i = 0;
    while (i < daySlots.length) {
      final current = daySlots[i];
      final currentDef = CanonicalScheduleDef.blocks[i];

      // Two consecutive occupied blocks render as a horizontal Rectangle
      if (current.isOccupied &&
          i + 1 < daySlots.length &&
          daySlots[i + 1].isOccupied) {
        final next = daySlots[i + 1];
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
    return grouped;
  }

  bool _isDayDeclaredOff(int dayNum) {
    final daySlots = _allSlots.where((s) => s.dayOfWeek == dayNum).toList();
    if (daySlots.isEmpty) return false;
    // If all canonical blocks for that day are marked off, the day is declared off
    final dayCanonical = _computeCanonicalDaySlotsForDay(dayNum);
    return dayCanonical.every((s) => s.isOff);
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

  /// Action: Power to declare the selected day off.
  Future<void> _showDeclareDayOffDialog(int dayNum) async {
    final dayName = _days[dayNum - 1];
    String selectedReason = 'National Holiday / Festival';
    final customCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.event_busy, color: AppColors.wineRed, size: 22),
                const SizedBox(width: 8),
                Text('Declare $dayName Off'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mark all 8 one-hour blocks (09:00 - 17:00) as Declared Off for $dayName.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Note: Free periods are distinct from Declared Off. Declaring the day off marks the schedule as closed/dismissed with zero academic operations.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'REASON FOR CLOSURE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...[
                    'National Holiday / Festival',
                    'Institutional Recess / Semester Break',
                    'Campus Closure / Maintenance',
                    'Examinations / Study Leave',
                    'Saturday Half-Day Recess',
                    'Other / Custom Reason',
                  ].map((r) {
                    final isChecked = selectedReason == r;
                    return InkWell(
                      onTap: () => setDlgState(() => selectedReason = r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isChecked ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              size: 16,
                              color: isChecked ? AppColors.wineRed : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(r, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (selectedReason == 'Other / Custom Reason')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: customCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter custom reason for closure',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm Day Off'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && mounted) {
      final reason = selectedReason == 'Other / Custom Reason' && customCtrl.text.isNotEmpty
          ? customCtrl.text.trim()
          : selectedReason;

      await widget.storage.declareDayOff(
        dayOfWeek: dayNum,
        reason: reason,
        scopeCode: widget.activeScope,
      );

      final fresh = await widget.storage.getTimetable(widget.activeScope);
      if (mounted) {
        setState(() {
          _allSlots = fresh;
          _recomputeDaySchedule();
        });
      }
    }
  }

  /// Action: Reopen / Restore a day that was declared off.
  Future<void> _restoreDaySchedule(int dayNum) async {
    await widget.storage.restoreDaySchedule(
      dayOfWeek: dayNum,
      scopeCode: widget.activeScope,
    );
    final fresh = await widget.storage.getTimetable(widget.activeScope);
    if (mounted) {
      setState(() {
        _allSlots = fresh;
        _recomputeDaySchedule();
      });
    }
  }

  Future<void> _openEditBlockModal(TimetableSlotModel slot, int blockIndex) async {
    final updated = await showModalBottomSheet<TimetableSlotModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BlockEditorSheet(
        storage: widget.storage,
        slot: slot,
        blockIndex: blockIndex,
        dayOfWeek: _selectedDay,
        scopeCode: widget.activeScope,
      ),
    );

    if (updated != null && mounted) {
      await widget.storage.saveTimetableSlot(updated);
      if (!mounted) return;
      setState(() {
        final existingIdx = _allSlots.indexWhere((s) => s.id == updated.id);
        if (existingIdx >= 0) {
          _allSlots[existingIdx] = updated;
        } else {
          _allSlots.add(updated);
        }
        _recomputeDaySchedule();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isFree
                ? 'Allocated Free Period for ${updated.startTime} - ${updated.endTime}'
                : (updated.isOff
                    ? 'Declared Off Period for ${updated.startTime} - ${updated.endTime}'
                    : 'Allocated ${updated.courseCode} (${updated.roomNumber}) for ${updated.startTime} - ${updated.endTime}'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Timetable (9 AM - 5 PM)'),
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == TimetableViewMode.dayRow
                  ? Icons.calendar_view_week
                  : Icons.view_agenda_outlined,
              size: 20,
            ),
            tooltip: _viewMode == TimetableViewMode.dayRow
                ? 'Switch to All Days Rows View'
                : 'Switch to Single Day Row View',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == TimetableViewMode.dayRow
                    ? TimetableViewMode.weekRows
                    : TimetableViewMode.dayRow;
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
          // Day Selector Bar + Declare Day Off Action
          _buildDaySelectorBar(isDark),

          // Operational Status Summary Ribbon
          _buildMetricsRibbon(isDark),

          // Main View Content in Row Format
          Expanded(
            child: _buildContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelectorBar(bool isDark) {
    final isDayOff = _isDayDeclaredOff(_selectedDay);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
          // Day Pills Mon-Sat
          ...List.generate(_days.length, (idx) {
            final dayNum = idx + 1;
            final isSelected = _selectedDay == dayNum;
            final dayOff = _isDayDeclaredOff(dayNum);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _DaySelectorPill(
                  label: _days[idx],
                  isOff: dayOff,
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

          const SizedBox(width: 8),

          // Declare Day Off / Restore Day Action Button
          Tooltip(
            message: isDayOff
                ? 'Restore original schedule for ${_days[_selectedDay - 1]}'
                : 'Declare ${_days[_selectedDay - 1]} as Day Off (All 8 blocks dismissed)',
            child: OutlinedButton.icon(
              icon: Icon(
                isDayOff ? Icons.restart_alt : Icons.event_busy,
                size: 15,
                color: isDayOff ? const Color(0xFF238636) : AppColors.wineRed,
              ),
              label: Text(
                isDayOff ? 'Restore Schedule' : 'Declare Day Off',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDayOff ? const Color(0xFF238636) : AppColors.wineRed,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isDayOff
                      ? const Color(0xFF238636).withValues(alpha: 0.6)
                      : AppColors.wineRed.withValues(alpha: 0.6),
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () {
                if (isDayOff) {
                  _restoreDaySchedule(_selectedDay);
                } else {
                  _showDeclareDayOffDialog(_selectedDay);
                }
              },
            ),
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

    final isDayOff = _isDayDeclaredOff(_selectedDay);

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
          if (isDayOff)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF381A22).withValues(alpha: 0.5)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark
                        ? AppColors.wineRed.withValues(alpha: 0.6)
                        : const Color(0xFFFCA5A5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy, color: AppColors.wineRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_days[_selectedDay - 1]} is Declared Off — No academic operations scheduled for today.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFFF7B72) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _restoreDaySchedule(_selectedDay),
                      child: const Text(
                        'Restore',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.wineRed),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _buildSummaryChip(
              isDark: isDark,
              label: '$classCount Classes',
              sublabel: '$rectCount Double Sessions',
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
        return _buildSkeletonRow(isDark);
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
        if (_viewMode == TimetableViewMode.weekRows) {
          return _buildWeekRowsView(isDark);
        }
        return _buildDayRowView(isDark);
    }
  }

  /// Primary View: The selected day's 8 blocks laid out in horizontal ROW format.
  Widget _buildDayRowView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header: Day & Operational Track
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_days[_selectedDay - 1]} Operational Track (09:00 - 17:00)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Horizontal Row Format • 1-Hr Blocks',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Time Ruler Header
          _buildHorizontalTimeRuler(isDark),
          const SizedBox(height: 6),

          // Horizontal Track of Blocks (Squares and Rectangles)
          SizedBox(
            height: 172,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(_renderedBlocks.length, (idx) {
                  final block = _renderedBlocks[idx];
                  final isSelected = _selectedBlockIndex == idx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedBlockIndex = idx);
                        _openEditBlockModal(block.firstSlot, block.blockIndex);
                      },
                      child: block.isRectangle
                          ? _buildHorizontalRectangleCard(isDark, block, isSelected)
                          : _buildHorizontalSquareCard(isDark, block, isSelected),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Block Inspector Panel
          if (_renderedBlocks.isNotEmpty) ...[
            _buildBlockInspectorCard(
              isDark,
              _renderedBlocks[_selectedBlockIndex.clamp(0, _renderedBlocks.length - 1)],
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a horizontal time ruler for row alignment.
  Widget _buildHorizontalTimeRuler(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text('09:00', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold)),
          Text('10:00', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
          Text('11:00', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
          Text('12:00', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
          Text('13:00', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
          Text('14:00', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
          Text('15:00', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
          Text('16:00', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
          Text('17:00', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Horizontal SQUARE card (1 Unit = 156 x 156 px).
  Widget _buildHorizontalSquareCard(bool isDark, RenderedTimetableBlock block, bool isSelected) {
    final slot = block.firstSlot;

    final borderColor = isSelected
        ? AppColors.wineRed
        : (slot.isFree
            ? (isDark ? const Color(0xFF238636).withValues(alpha: 0.6) : const Color(0xFFA7F3D0))
            : (slot.isOff
                ? (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder)));

    final bgColor = slot.isFree
        ? (isDark ? const Color(0xFF1B2E24).withValues(alpha: 0.35) : const Color(0xFFECFDF5))
        : (slot.isOff
            ? (isDark ? const Color(0xFF161B22).withValues(alpha: 0.8) : const Color(0xFFF1F5F9))
            : (isDark ? AppColors.darkSurface : AppColors.lightSurface));

    return Container(
      width: 156, // 1 Unit wide
      height: 156, // 1 Unit high -> Literally a SQUARE!
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2.0 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Header + Period
          Row(
            children: [
              Expanded(
                child: Text(
                  '${block.startTime} - ${block.endTime}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  block.periodLabel,
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Status Badge
          if (slot.isFree) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF238636) : const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'FREE PERIOD',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              slot.courseName.isNotEmpty ? slot.courseName : 'Self-Study & Open Library',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const AppSvgIcon(svgString: AppSvgIcon.book, size: 11),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    slot.roomNumber.isNotEmpty ? slot.roomNumber : 'Library',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF7EE787) : const Color(0xFF047857),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ] else if (slot.isOff) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF484F58) : const Color(0xFF64748B),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'DECLARED OFF',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              slot.courseName.isNotEmpty ? slot.courseName : 'Campus Concluded',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const AppSvgIcon(svgString: AppSvgIcon.clock, size: 11),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'No Class',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Flexible(
                  child: Text(
                    slot.courseCode,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.wineRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    slot.slotType.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: AppColors.wineRed,
                    ),
                  ),
                ),
                if (_conflictingSlotIds.contains(slot.id)) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCF222E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'CONFLICT',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCF222E),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              slot.courseName,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const AppSvgIcon(svgString: AppSvgIcon.mapPin, size: 11),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    slot.roomNumber,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Horizontal RECTANGLE card (2 Consecutive Units = 324 x 156 px).
  Widget _buildHorizontalRectangleCard(bool isDark, RenderedTimetableBlock block, bool isSelected) {
    final first = block.firstSlot;
    final second = block.secondSlot!;
    final isSameCourse = first.courseCode == second.courseCode && first.courseCode.isNotEmpty;

    return Container(
      width: 324, // Exactly 2 units wide (2 x 156 + 12 = 324) -> Literally a RECTANGLE!
      height: 156,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppColors.wineRed : AppColors.wineRed.withValues(alpha: 0.6),
          width: isSelected ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Rectangle Ribbon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.wineRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CONSECUTIVE PERIODS',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.wineRed,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${block.startTime} - ${block.endTime}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_conflictingSlotIds.contains(first.id) || _conflictingSlotIds.contains(second.id)) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCF222E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'CONFLICT',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFCF222E)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          if (isSameCourse) ...[
            Row(
              children: [
                Text(
                  first.courseCode,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.wineRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    first.slotType.toLowerCase() == 'lab' ? '2-HR LAB PRACTICAL' : 'DOUBLE LECTURE',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              first.courseName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const AppSvgIcon(svgString: AppSvgIcon.user, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    first.instructorName.isNotEmpty ? first.instructorName : 'Faculty Lead',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const AppSvgIcon(svgString: AppSvgIcon.mapPin, size: 12),
                const SizedBox(width: 4),
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
          ] else ...[
            // Side-by-side sub-blocks in horizontal rectangle
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          first.courseCode,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          first.courseName,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          first.roomNumber,
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 16,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          second.courseCode,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          second.courseName,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          second.roomNumber,
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Detailed Inspection Card below the horizontal track.
  Widget _buildBlockInspectorCard(bool isDark, RenderedTimetableBlock block) {
    final slot = block.firstSlot;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: block.isRectangle
                      ? AppColors.wineRed.withValues(alpha: 0.15)
                      : (slot.isFree
                          ? const Color(0xFF238636).withValues(alpha: 0.15)
                          : (slot.isOff
                              ? const Color(0xFF64748B).withValues(alpha: 0.15)
                              : AppColors.wineRed.withValues(alpha: 0.15))),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  block.isRectangle ? '2-HOUR EXTENDED SESSION' : '1-HOUR SESSION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: block.isRectangle
                        ? AppColors.wineRed
                        : (slot.isFree
                            ? (isDark ? const Color(0xFF7EE787) : const Color(0xFF047857))
                            : (slot.isOff
                                ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                                : AppColors.wineRed)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${block.startTime} - ${block.endTime} (${block.periodLabel})',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (_conflictingSlotIds.contains(slot.id)) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCF222E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DOUBLE-BOOKING CONFLICT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCF222E),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 13),
                label: const Text('Edit Block', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _openEditBlockModal(slot, block.blockIndex),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            slot.isOccupied
                ? '${slot.courseCode} — ${slot.courseName}'
                : (slot.isFree ? 'Free Academic Period' : 'Declared Off Period'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            slot.isOccupied
                ? 'Instructor: ${slot.instructorName.isNotEmpty ? slot.instructorName : "Faculty"} • Room: ${slot.roomNumber} • Type: ${slot.slotType.toUpperCase()}'
                : (slot.isFree
                    ? 'Active campus hours. Open for library access, faculty consultation, or recess. Not an off day.'
                    : 'Schedule is officially dismissed or cancelled. No academic operations scheduled.'),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// View Mode: ALL DAYS ROWS (Every day from Mon to Sat is a horizontal row).
  Widget _buildWeekRowsView(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _days.length,
      itemBuilder: (context, dayIdx) {
        final dayNum = dayIdx + 1;
        final dayCanonical = _computeCanonicalDaySlotsForDay(dayNum);
        final dayBlocks = _computeGroupedBlocks(dayCanonical);
        final isDayOff = _isDayDeclaredOff(dayNum);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day Row Header
              Row(
                children: [
                  Text(
                    _days[dayIdx],
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (isDayOff)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF484F58) : const Color(0xFF64748B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DECLARED OFF',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    icon: Icon(
                      isDayOff ? Icons.restart_alt : Icons.event_busy,
                      size: 13,
                      color: isDayOff ? const Color(0xFF238636) : AppColors.wineRed,
                    ),
                    label: Text(
                      isDayOff ? 'Restore' : 'Declare Off',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDayOff ? const Color(0xFF238636) : AppColors.wineRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      if (isDayOff) {
                        _restoreDaySchedule(dayNum);
                      } else {
                        _showDeclareDayOffDialog(dayNum);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // The Day's Horizontal Row of Blocks
              SizedBox(
                height: 120,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(dayBlocks.length, (bIdx) {
                      final block = dayBlocks[bIdx];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDay = dayNum;
                              _recomputeDaySchedule();
                              _selectedBlockIndex = bIdx;
                              _viewMode = TimetableViewMode.dayRow;
                            });
                          },
                          child: block.isRectangle
                              ? _buildCompactRectangleCard(isDark, block)
                              : _buildCompactSquareCard(isDark, block),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactSquareCard(bool isDark, RenderedTimetableBlock block) {
    final slot = block.firstSlot;
    final bgColor = slot.isFree
        ? (isDark ? const Color(0xFF1B2E24).withValues(alpha: 0.35) : const Color(0xFFECFDF5))
        : (slot.isOff
            ? (isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9))
            : (isDark ? const Color(0xFF21262D) : Colors.white));

    return Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: slot.isOccupied
              ? AppColors.wineRed.withValues(alpha: 0.4)
              : (slot.isFree
                  ? const Color(0xFF238636).withValues(alpha: 0.4)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.startTime,
            style: const TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            slot.isOccupied
                ? slot.courseCode
                : (slot.isFree ? 'FREE' : 'OFF'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: slot.isOccupied
                  ? AppColors.wineRed
                  : (slot.isFree
                      ? (isDark ? const Color(0xFF7EE787) : const Color(0xFF047857))
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
            ),
          ),
          if (slot.isOccupied)
            Text(
              slot.roomNumber,
              style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactRectangleCard(bool isDark, RenderedTimetableBlock block) {
    final first = block.firstSlot;

    return Container(
      width: 232, // Double unit span
      height: 112,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.wineRed.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${block.startTime} - ${block.endTime}',
                style: const TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          Text(
            first.courseCode,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.wineRed),
          ),
          Text(
            first.courseName,
            style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            first.roomNumber,
            style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonRow(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(4, (i) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppSkeleton(width: i == 0 ? 300 : 150, height: 160, borderRadius: 8),
          );
        }),
      ),
    );
  }
}

/// Interactive Bottom Sheet for Editing, Quick Allocating, and Conflict Checking.
class _BlockEditorSheet extends StatefulWidget {
  final OfflineStorageService storage;
  final TimetableSlotModel slot;
  final int blockIndex;
  final int dayOfWeek;
  final String scopeCode;

  const _BlockEditorSheet({
    required this.storage,
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

  List<TimetableConflictModel> _conflicts = [];

  static const _catalogCourses = [
    {'code': 'CS301', 'name': 'Operating Systems'},
    {'code': 'CS302', 'name': 'Design & Analysis of Algorithms'},
    {'code': 'CS303', 'name': 'Computer Networks'},
    {'code': 'CS304', 'name': 'Database Management Systems'},
    {'code': 'CS305', 'name': 'Software Engineering'},
  ];

  static const _facultyList = [
    'Dr. Priya Nair',
    'Prof. Amit Verma',
    'Dr. Sandeep Rao',
    'Dr. Ananya Sharma',
  ];

  static const _roomList = [
    'LH-101',
    'LH-102',
    'LHC-201',
    'Lab-1',
    'Lab-2',
    'Lab-3',
    'Seminar Hall',
  ];

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

    _codeCtrl.addListener(_onFieldChanged);
    _nameCtrl.addListener(_onFieldChanged);
    _instructorCtrl.addListener(_onFieldChanged);
    _roomCtrl.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateConflicts();
    });
  }

  void _onFieldChanged() {
    _validateConflicts();
  }

  Future<void> _validateConflicts() async {
    if (!mounted) return;
    if (_statusType == 'free' || _statusType == 'off') {
      if (_conflicts.isNotEmpty) {
        setState(() => _conflicts = []);
      }
      return;
    }

    final def = CanonicalScheduleDef.blocks[widget.blockIndex];
    final candidate = widget.slot.copyWith(
      courseCode: _codeCtrl.text.trim(),
      courseName: _nameCtrl.text.trim(),
      instructorName: _instructorCtrl.text.trim(),
      roomNumber: _roomCtrl.text.trim(),
      slotType: _statusType,
      dayOfWeek: widget.dayOfWeek,
      startTime: def['start']!,
      endTime: def['end']!,
      scopeCode: widget.scopeCode,
    );

    final res = await widget.storage.checkTimetableConflicts(candidate);
    if (mounted) {
      setState(() {
        _conflicts = res;
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.removeListener(_onFieldChanged);
    _nameCtrl.removeListener(_onFieldChanged);
    _instructorCtrl.removeListener(_onFieldChanged);
    _roomCtrl.removeListener(_onFieldChanged);

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
                        '1-Hour Slot (${def['start']} - ${def['end']}): assign course, faculty, room or declare status',
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

            // Dynamic Conflict Alert Banner
            if (_conflicts.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCF222E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCF222E), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFCF222E)),
                        SizedBox(width: 8),
                        Text(
                          'Scheduling Conflict Detected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFFCF222E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._conflicts.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCF222E))),
                              Expanded(
                                child: Text(
                                  c.message,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 4),
                    Text(
                      'Double-booking instructors or lecture halls leads to timetable clashes across sections. Choose another room or instructor, or save to force override.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_statusType == 'free') ...[
              _buildFreeGuidance(isDark),
            ] else if (_statusType == 'off') ...[
              _buildOffGuidance(isDark),
            ] else ...[
              // Quick Course Suggestions
              Text(
                'QUICK SELECT COURSE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _catalogCourses.map((c) {
                  final isSelected = _codeCtrl.text.toUpperCase() == c['code'];
                  return ActionChip(
                    label: Text(
                      '${c['code']} - ${c['name']}',
                      style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    ),
                    backgroundColor: isSelected ? AppColors.wineRed.withValues(alpha: 0.18) : null,
                    side: BorderSide(
                      color: isSelected ? AppColors.wineRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    onPressed: () {
                      _codeCtrl.text = c['code']!;
                      _nameCtrl.text = c['name']!;
                      _validateConflicts();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

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
              const SizedBox(height: 14),

              // Quick Faculty Suggestions
              Text(
                'QUICK SELECT FACULTY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _facultyList.map((f) {
                  final isSelected = _instructorCtrl.text == f;
                  return ActionChip(
                    label: Text(
                      f,
                      style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    ),
                    backgroundColor: isSelected ? AppColors.wineRed.withValues(alpha: 0.18) : null,
                    side: BorderSide(
                      color: isSelected ? AppColors.wineRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    onPressed: () {
                      _instructorCtrl.text = f;
                      _validateConflicts();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _instructorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instructor Name (e.g. Dr. Priya Nair)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),

              // Quick Room Suggestions
              Text(
                'QUICK SELECT ROOM / LAB',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _roomList.map((r) {
                  final isSelected = _roomCtrl.text == r;
                  return ActionChip(
                    label: Text(
                      r,
                      style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    ),
                    backgroundColor: isSelected ? AppColors.wineRed.withValues(alpha: 0.18) : null,
                    side: BorderSide(
                      color: isSelected ? AppColors.wineRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    onPressed: () {
                      _roomCtrl.text = r;
                      _validateConflicts();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

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
                key: const Key('btn-save-block-configuration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _conflicts.isNotEmpty ? const Color(0xFFCF222E) : AppColors.wineRed,
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
                child: Text(
                  _conflicts.isNotEmpty ? 'Override Conflict & Save Slot' : 'Save Block Allocation',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
        key: Key('tab-block-type-$type'),
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
          _validateConflicts();
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
  final bool isOff;
  final VoidCallback onTap;

  const _DaySelectorPill({
    required this.label,
    required this.isSelected,
    this.isOff = false,
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
            : (widget.isOff
                ? (isDark ? const Color(0xFF484F58) : const Color(0xFF94A3B8))
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder)));

    final textColor = widget.isSelected
        ? Colors.white
        : (_isHovered
            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
            : (widget.isOff
                ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)));

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (widget.isOff) ...[
                const SizedBox(width: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF64748B),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
