import 'package:flutter/material.dart';
import '../models/academic.dart';
import '../services/offline_storage_service.dart';

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
    final daySlots = _slots.where((s) => s.dayOfWeek == _selectedDay).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Timetable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Schedule',
          ),
        ],
      ),
      body: Column(
        children: [
          // Day selector chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_days.length, (idx) {
                final dayNum = idx + 1;
                final isSelected = _selectedDay == dayNum;
                return ChoiceChip(
                  label: Text(_days[idx]),
                  selected: isSelected,
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
                            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No scheduled classes for this day',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
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
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isLab ? Colors.purple.shade200 : Colors.blue.shade200,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Time column
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isLab ? Colors.purple.shade50 : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          slot.startTime,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isLab ? Colors.purple.shade900 : Colors.blue.shade900,
                                          ),
                                        ),
                                        Text(
                                          slot.endTime,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Subject & Details
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
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isLab ? Colors.purple.shade100 : Colors.blue.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                slot.slotType.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isLab ? Colors.purple.shade800 : Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          slot.courseName,
                                          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              slot.instructorName.isNotEmpty ? slot.instructorName : 'Faculty',
                                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                            ),
                                            const Spacer(),
                                            Icon(Icons.room, size: 16, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              slot.roomNumber,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade800,
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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
