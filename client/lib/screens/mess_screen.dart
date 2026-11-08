import 'package:flutter/material.dart';
import '../models/mess.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';

class MessScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;

  const MessScreen({
    super.key,
    required this.storage,
    this.currentUser,
  });

  @override
  State<MessScreen> createState() => _MessScreenState();
}

class _MessScreenState extends State<MessScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MessMealModel> _timetable = [];
  MessReportSummary? _report;
  bool _isLoading = true;

  String _selectedDay = 'monday';
  String _messageFilter = 'all'; // 'all', 'compulsory', 'positive', 'abstained'

  static const List<String> _daysOfWeek = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Default selected day to current day of week
    final weekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    if (weekday >= 1 && weekday <= 7) {
      _selectedDay = _daysOfWeek[weekday - 1];
    }

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final meals = await widget.storage.getMessTimetable();
    final rep = await widget.storage.getMessRatingsReport();
    if (mounted) {
      setState(() {
        _timetable = meals;
        _report = rep;
        _isLoading = false;
      });
    }
  }

  List<MessMealModel> get _mealsForSelectedDay {
    return _timetable.where((m) => m.dayOfWeek.toLowerCase() == _selectedDay).toList();
  }

  void _showRatingDialog({MessMealModel? targetMeal}) {
    MessMealModel selectedMeal = targetMeal ??
        (_mealsForSelectedDay.isNotEmpty ? _mealsForSelectedDay.first : _timetable.first);
    MessRatingValue selectedRating = MessRatingValue.good;
    final messageCtrl = TextEditingController();
    String? validationError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isCompulsory = selectedRating.isMessageCompulsory;

          return AlertDialog(
            key: const Key('dialog-rate-mess-meal'),
            title: const Text(
              'Submit Meal Rating & Feedback',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target Meal Dropdown
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Select Meal Slot',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedMeal.id,
                          isDense: true,
                          isExpanded: true,
                          items: _timetable.map((m) {
                            final dayCap = '${m.dayOfWeek[0].toUpperCase()}${m.dayOfWeek.substring(1)}';
                            return DropdownMenuItem<String>(
                              value: m.id,
                              child: Text(
                                '$dayCap • ${m.title} (${m.startTime} - ${m.endTime})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final found = _timetable.firstWhere((m) => m.id == val);
                              setDialogState(() {
                                selectedMeal = found;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rating Options Label
                    const Text(
                      'RATING CLASSIFICATION',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // 6 Rating Option Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: MessRatingValue.values.map((rv) {
                        final isSelected = selectedRating == rv;
                        Color chipColor = _colorForRating(rv.code, isDark);
                        return ChoiceChip(
                          key: Key('chip-rating-${rv.code}'),
                          label: Text(
                            rv.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: chipColor,
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                selectedRating = rv;
                                validationError = null;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Compulsory vs Optional Hint Notice
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isCompulsory
                            ? (isDark ? const Color(0xFF3E1F1F) : const Color(0xFFFFECEE))
                            : (isDark ? const Color(0xFF1B2E24) : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCompulsory
                              ? AppColors.statusRed
                              : (isDark ? const Color(0xFF238636) : const Color(0xFFA7F3D0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCompulsory ? Icons.warning_amber_rounded : Icons.info_outline,
                            size: 14,
                            color: isCompulsory ? AppColors.statusRed : const Color(0xFF238636),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isCompulsory
                                  ? 'Feedback message is COMPULSORY for Very Poor, Poor, and Average ratings.'
                                  : 'Feedback message is OPTIONAL for Good, Very Good, and Abstained ratings.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isCompulsory ? AppColors.statusRed : const Color(0xFF238636),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Message Input Field
                    TextField(
                      key: const Key('input-mess-feedback-message'),
                      controller: messageCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: isCompulsory
                            ? 'Feedback Message (Compulsory)'
                            : 'Feedback Message (Optional)',
                        hintText: isCompulsory
                            ? 'Please provide specifics on taste, hygiene, temperature, or service...'
                            : 'Optional compliments or suggestions...',
                        border: const OutlineInputBorder(),
                        errorText: validationError,
                        isDense: true,
                      ),
                      onChanged: (val) {
                        if (validationError != null) {
                          setDialogState(() => validationError = null);
                        }
                      },
                    ),
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
                key: const Key('btn-submit-mess-rating'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final err = MessRatingModel.validateRatingFeedback(
                    rating: selectedRating,
                    message: messageCtrl.text,
                  );
                  if (err != null) {
                    setDialogState(() => validationError = err);
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  final user = widget.currentUser;
                  try {
                    await widget.storage.submitMessRating(
                      mealId: selectedMeal.id,
                      userId: user?.id ?? 'u-guest',
                      userName: user?.fullName ?? 'Student Resident',
                      campusHandle: user?.campusHandle ?? 'resident',
                      rating: selectedRating.code,
                      message: messageCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadData();
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Thank you! Rating (${selectedRating.label}) recorded for ${selectedMeal.title}.'),
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => validationError = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Submit Rating'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _colorForRating(String rating, bool isDark) {
    switch (rating.toLowerCase()) {
      case 'very_good':
        return const Color(0xFF238636);
      case 'good':
        return const Color(0xFF2DA44E);
      case 'average':
        return const Color(0xFFD97706);
      case 'poor':
        return const Color(0xFFEA580C);
      case 'very_poor':
        return AppColors.statusRed;
      case 'abstained':
      default:
        return isDark ? const Color(0xFF6E7681) : const Color(0xFF64748B);
    }
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hostel Mess System & Meal Timetable',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '6 days a week (Mon-Sat): 3 meals daily • Sunday: Grand Brunch replaces Breakfast & Lunch • Rating & Messages Feedback Portal',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        key: const Key('btn-open-rate-meal-dialog'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.wineRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _showRatingDialog(),
                        icon: const Icon(Icons.star_rate_rounded, size: 16),
                        label: const Text('Rate a Meal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Sunday Schedule Notice Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF231B15) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFFD97706) : const Color(0xFFFDBA74),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Sunday Meal Schedule: A grand Brunch is served from 10:00 to 13:00 replacing separate breakfast and lunch. Dinner is served as usual from 19:30 to 21:30.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Navigation Tabs
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
                          icon: Icon(Icons.calendar_month_outlined, size: 16),
                          text: 'Weekly Menu & Timetable',
                        ),
                        Tab(
                          icon: Icon(Icons.rate_review_outlined, size: 16),
                          text: 'Messages & Ratings Report',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Tab Views Content
                  if (_tabController.index == 0) ...[
                    _buildWeeklyTimetableView(isDark),
                  ] else ...[
                    _buildMessagesAndReportView(isDark),
                  ],
                ],
              ),
            ),
    );
  }

  // ----------------------------------------------------
  // TAB 1: WEEKLY MENU & TIMETABLE VIEW
  // ----------------------------------------------------

  Widget _buildWeeklyTimetableView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day Selector Row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _daysOfWeek.map((day) {
            final isSelected = _selectedDay == day;
            final dayTitle = '${day[0].toUpperCase()}${day.substring(1)}';
            final isSunday = day == 'sunday';

            return ChoiceChip(
              key: Key('chip-day-$day'),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayTitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  if (isSunday) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFD97706).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Brunch',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              selectedColor: isSunday ? const Color(0xFFD97706) : AppColors.wineRed,
              onSelected: (_) => setState(() => _selectedDay = day),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // Meal Cards for Selected Day
        if (_mealsForSelectedDay.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: const Text('No meals scheduled for this day.'),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _mealsForSelectedDay.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, idx) {
              final meal = _mealsForSelectedDay[idx];
              return _buildMealSlotCard(meal, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildMealSlotCard(MessMealModel meal, bool isDark) {
    final isSundayBrunch = meal.isSundayBrunch;

    return Container(
      key: Key('card-meal-${meal.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSundayBrunch
              ? const Color(0xFFD97706)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isSundayBrunch ? 1.5 : 1,
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
                  color: isSundayBrunch
                      ? const Color(0xFFD97706).withValues(alpha: 0.15)
                      : AppColors.wineRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  meal.mealType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSundayBrunch ? const Color(0xFFD97706) : AppColors.wineRed,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meal.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${meal.startTime} - ${meal.endTime}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            meal.menuSummary,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Menu Items Wrap
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: meal.items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 11),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Action
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                key: Key('btn-rate-meal-${meal.id}'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: AppColors.wineRed),
                  foregroundColor: AppColors.wineRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _showRatingDialog(targetMeal: meal),
                icon: const Icon(Icons.rate_review_outlined, size: 14),
                label: const Text('Rate This Meal', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 2: MESSAGES & RATINGS REPORT VIEW
  // ----------------------------------------------------

  Widget _buildMessagesAndReportView(bool isDark) {
    final rep = _report;
    final messages = rep?.recentMessages ?? [];

    final filteredMessages = messages.where((m) {
      if (_messageFilter == 'compulsory') return m.isMessageCompulsory;
      if (_messageFilter == 'positive') {
        return m.rating == 'good' || m.rating == 'very_good';
      }
      if (_messageFilter == 'abstained') return m.rating == 'abstained';
      return true; // 'all'
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary KPI Metrics Ribbon
        if (rep != null) ...[
          _buildRatingKpiRibbon(rep, isDark),
          const SizedBox(height: 18),
        ],

        // Filter Bar & Messages Heading
        Row(
          children: [
            const Expanded(
              child: Text(
                'STUDENT FEEDBACK & MESSAGES',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                _buildMessageFilterChip('all', 'All Messages', isDark),
                _buildMessageFilterChip('compulsory', 'Compulsory (Very Poor - Average)', isDark),
                _buildMessageFilterChip('positive', 'Positive (Good - Very Good)', isDark),
                _buildMessageFilterChip('abstained', 'Abstained', isDark),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Messages List
        if (filteredMessages.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: const Text('No feedback messages found matching your criteria.'),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredMessages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final msg = filteredMessages[idx];
              return _buildMessageCard(msg, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildMessageFilterChip(String filterKey, String label, bool isDark) {
    final isSelected = _messageFilter == filterKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
      selected: isSelected,
      selectedColor: AppColors.wineRed.withValues(alpha: 0.18),
      side: BorderSide(
        color: isSelected ? AppColors.wineRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      onSelected: (_) => setState(() => _messageFilter = filterKey),
    );
  }

  Widget _buildRatingKpiRibbon(MessReportSummary rep, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Average Score Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.wineRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.wineRed),
                ),
                child: Column(
                  children: [
                    Text(
                      rep.averageScore > 0 ? rep.averageScore.toStringAsFixed(1) : 'N/A',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.wineRed,
                      ),
                    ),
                    const Text(
                      'Avg Score (/ 5.0)',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Total Reviews
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rep.totalRatings} Total Student Ratings',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sentiment breakdown across weekly meals (compulsory messages logged for issues)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rating Breakdown Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: MessRatingValue.values.map((rv) {
              final count = rep.ratingCounts[rv.code] ?? 0;
              final color = _colorForRating(rv.code, isDark);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${rv.label}: $count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(MessRatingModel msg, bool isDark) {
    final ratingVal = msg.ratingEnum;
    final ratingColor = _colorForRating(msg.rating, isDark);
    final dayCap = '${msg.dayOfWeek[0].toUpperCase()}${msg.dayOfWeek.substring(1)}';

    return Container(
      key: Key('card-message-${msg.id}'),
      padding: const EdgeInsets.all(14),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ratingColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ratingColor),
                ),
                child: Text(
                  ratingVal.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: ratingColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$dayCap ${msg.mealType.toUpperCase()} • ${msg.userName} (@${msg.campusHandle})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (msg.isMessageCompulsory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.statusRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Compulsory Feedback',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.statusRed),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E2229) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Optional Note',
                    style: TextStyle(fontSize: 9.5, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg.message.trim().isNotEmpty
                ? msg.message
                : '(No optional message provided with this submission)',
            style: TextStyle(
              fontSize: 12,
              fontStyle: msg.message.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
