import 'package:flutter/material.dart';
import '../models/academic.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/svg_icons.dart';

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
  bool _loading = false;
  List<TimetableSlotModel> _slots = [];

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await widget.storage.getTimetable(widget.activeScope);
    setState(() {
      _slots = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daySlots = _slots.where((s) => s.dayOfWeek == _selectedDay).toList();

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
          // Day selector chips
          AnimatedContainer(
            duration: AppTheme.themeAnimationDuration,
            curve: AppTheme.themeAnimationCurve,
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_days.length, (idx) {
                final dayNum = idx + 1;
                final isSelected = _selectedDay == dayNum;
                return ChoiceChip(
                  label: Text(_days[idx]),
                  selected: isSelected,
                  selectedColor: isDark ? AppColors.wineRedDark : AppColors.wineRedSubtle,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600, // Uniform weight prevents layout jitter on active
                    color: isSelected
                        ? (isDark ? Colors.white : AppColors.wineRed)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.wineRed
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: 1,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedDay = dayNum);
                  },
                );
              }),
            ),
          ),
          // Slots list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : daySlots.isEmpty
                    ? Center(
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
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: daySlots.length,
                        itemBuilder: (context, i) {
                          final slot = daySlots[i];
                          final isLab = slot.slotType.toLowerCase() == 'lab';
                          final typeBadge = isLab
                              ? AppColors.primaryBadge(isDark)
                              : AppColors.greenBadge(isDark);
                          final timeBadge = AppColors.neutralBadge(isDark);

                          return AnimatedContainer(
                            duration: AppTheme.themeAnimationDuration,
                            curve: AppTheme.themeAnimationCurve,
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
                                AnimatedContainer(
                                  duration: AppTheme.themeAnimationDuration,
                                  curve: AppTheme.themeAnimationCurve,
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
                                          AnimatedContainer(
                                            duration: AppTheme.themeAnimationDuration,
                                            curve: AppTheme.themeAnimationCurve,
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
                      ),
          ),
        ],
      ),
    );
  }
}
