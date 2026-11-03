import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/academic.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

class NoticesScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final List<String> userScopes;

  const NoticesScreen({
    super.key,
    required this.storage,
    required this.userScopes,
  });

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  bool _loading = false;
  List<NoticeModel> _notices = [];
  String _selectedCategory = 'all';

  final List<String> _categories = ['all', 'academic', 'exam', 'urgent', 'hostel', 'general'];

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _loading = true);
    final data = await widget.storage.getNotices(widget.userScopes);
    setState(() {
      _notices = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _notices.where((n) {
      if (_selectedCategory == 'all') return true;
      return n.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Targeted Notice Board'),
        actions: [
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
          // Filter Chips
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
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat.toUpperCase()),
                  selected: isSelected,
                  selectedColor: isDark ? AppColors.wineRedDark : AppColors.wineRedSubtle,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : AppColors.wineRed)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.wineRed
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                );
              },
            ),
          ),
          // Notice List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
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
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final notice = filtered[i];
                          final isUrgent = notice.priority.toLowerCase() == 'urgent';
                          final isHigh = notice.priority.toLowerCase() == 'high';

                          Color badgeBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);
                          Color badgeText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
                          Color badgeBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

                          if (isUrgent) {
                            badgeBg = isDark ? const Color(0xFF4C1D24) : AppColors.statusRedSubtle;
                            badgeText = isDark ? const Color(0xFFFF8585) : AppColors.statusRed;
                            badgeBorder = isDark ? AppColors.wineRed : AppColors.statusRedBorder;
                          } else if (isHigh) {
                            badgeBg = isDark ? const Color(0xFF3B2A10) : AppColors.statusYellowSubtle;
                            badgeText = isDark ? const Color(0xFFFFD600) : AppColors.statusYellow;
                            badgeBorder = isDark ? AppColors.statusYellow : AppColors.statusYellowBorder;
                          }

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
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: badgeBorder),
                                      ),
                                      child: Text(
                                        notice.priority.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: badgeText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                        ),
                                      ),
                                      child: Text(
                                        'Scope: ${notice.targetScopeCode.isEmpty ? 'Global' : notice.targetScopeCode}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat('dd MMM, hh:mm a').format(notice.publishedAt),
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
                      ),
          ),
        ],
      ),
    );
  }
}
