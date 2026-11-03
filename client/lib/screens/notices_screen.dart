import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/academic.dart';
import '../services/offline_storage_service.dart';

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
    final filtered = _notices.where((n) {
      if (_selectedCategory == 'all') return true;
      return n.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Targeted Notice Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotices,
            tooltip: 'Refresh Notices',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                );
              },
            ),
          ),
          // Notice list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No notices found for this category.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
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

                          Color badgeColor = Colors.blue.shade100;
                          Color textColor = Colors.blue.shade900;
                          if (isUrgent) {
                            badgeColor = Colors.red.shade100;
                            textColor = Colors.red.shade900;
                          } else if (isHigh) {
                            badgeColor = Colors.orange.shade100;
                            textColor = Colors.orange.shade900;
                          }

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isUrgent ? Colors.red.shade300 : Colors.grey.shade300,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: badgeColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          notice.priority.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Scope: ${notice.targetScopeCode.isEmpty ? 'Global' : notice.targetScopeCode}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('dd MMM, hh:mm a').format(notice.publishedAt),
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    notice.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notice.content,
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                                  ),
                                ],
                              ),
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
