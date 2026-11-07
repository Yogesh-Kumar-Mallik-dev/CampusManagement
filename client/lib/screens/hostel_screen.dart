import 'package:flutter/material.dart';
import '../models/hostel.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

class HostelScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;

  const HostelScreen({
    super.key,
    required this.storage,
    this.currentUser,
  });

  @override
  State<HostelScreen> createState() => _HostelScreenState();
}

class _HostelScreenState extends State<HostelScreen> {
  List<HostelRoomModel> _rooms = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int? _selectedFloor; // null = all floors

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    final rooms = await widget.storage.getHostelRooms(floor: _selectedFloor);
    if (mounted) {
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    }
  }

  List<HostelRoomModel> get _filteredRooms {
    return _rooms.where((r) {
      if (_selectedFloor != null && r.floor != _selectedFloor) {
        return false;
      }
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      if (r.roomNumber.toString().contains(q)) return true;
      if (r.blockName.toLowerCase().contains(q)) return true;
      for (final a in r.assets) {
        if (a.serialNumber.toLowerCase().contains(q) || a.assetType.toLowerCase().contains(q)) {
          return true;
        }
      }
      for (final o in r.occupants) {
        if (o.name.toLowerCase().contains(q) || o.campusHandle.toLowerCase().contains(q)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  void _showCreateRoomDialog() {
    final roomCtrl = TextEditingController();
    final blockCtrl = TextEditingController(text: 'Aryabhatta Block');
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            key: const Key('dialog-create-hostel-room'),
            title: const Text('Register Hostel Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room numbers are strictly bounded between 100 and 999. Floor is auto-derived from the hundreds digit.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('input-hostel-room-number'),
                    controller: roomCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Room Number (100 - 999)',
                      hintText: 'e.g. 105, 204, 308',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                      isDense: true,
                    ),
                    onChanged: (val) {
                      final n = int.tryParse(val.trim());
                      setDialogState(() {
                        errorText = HostelRoomModel.validateRoomNumber(n);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('input-hostel-block-name'),
                    controller: blockCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Block / Hall Name',
                      hintText: 'Aryabhatta Block',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const Key('btn-confirm-create-room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final num = int.tryParse(roomCtrl.text.trim());
                  final err = HostelRoomModel.validateRoomNumber(num);
                  if (err != null) {
                    setDialogState(() => errorText = err);
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await widget.storage.createHostelRoom(num!, blockCtrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadRooms();
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Hostel room $num successfully registered.')),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Register Room'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddAssetDialog(HostelRoomModel room) {
    String selectedType = 'bed';
    if (!room.canAddBed) {
      if (room.canAddTable) {
        selectedType = 'table';
      } else if (room.canAddTubelight) {
        selectedType = 'tubelight';
      } else if (room.canAddFan) {
        selectedType = 'fan';
      } else if (room.canAddLocker) {
        selectedType = 'locker';
      }
    }

    final serialCtrl = TextEditingController();
    String condition = 'operational';
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final current = room.countForAssetType(selectedType);
          final maxCap = room.maxCapacityForAssetType(selectedType);
          final isCapReached = current >= maxCap;

          return AlertDialog(
            key: const Key('dialog-add-hostel-asset'),
            title: Text('Add Fixture Asset to Room ${room.roomNumber}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A room can have at most 3 beds, 3 tables, 2 tubelights, 2 fans, and 3 lockers. Every asset must have an alphanumeric serial number of at most 14 characters.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Asset Type Dropdown
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fixture Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'bed', child: Text('Bed (Max 3)')),
                          DropdownMenuItem(value: 'table', child: Text('Study Table (Max 3)')),
                          DropdownMenuItem(value: 'tubelight', child: Text('Tubelight (Max 2)')),
                          DropdownMenuItem(value: 'fan', child: Text('Ceiling Fan (Max 2)')),
                          DropdownMenuItem(value: 'locker', child: Text('Wardrobe / Locker (Max 3)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedType = val;
                              errorText = null;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Capacity indicator chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCapReached
                          ? (isDark ? const Color(0xFF3E1F1F) : const Color(0xFFFFECEE))
                          : (isDark ? const Color(0xFF1B2E24) : const Color(0xFFECFDF5)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCapReached
                            ? AppColors.statusRed
                            : (isDark ? const Color(0xFF238636) : const Color(0xFFA7F3D0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCapReached ? Icons.cancel_outlined : Icons.check_circle_outline,
                          size: 14,
                          color: isCapReached ? AppColors.statusRed : const Color(0xFF238636),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$selectedType Capacity: $current/$maxCap installed ${isCapReached ? "(Full)" : "(${maxCap - current} available)"}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCapReached ? AppColors.statusRed : const Color(0xFF238636),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Serial Number input (max 14 chars alphanumeric)
                  TextField(
                    key: const Key('input-hostel-asset-serial'),
                    controller: serialCtrl,
                    maxLength: 14,
                    decoration: InputDecoration(
                      labelText: 'Alphanumeric Serial Number (Max 14 Chars)',
                      hintText: 'e.g. ${selectedType.toUpperCase().substring(0, 3)}-${room.roomNumber}-01',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                      isDense: true,
                      counterText: '${serialCtrl.text.length}/14 alphanumeric characters',
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        errorText = HostelRoomModel.validateSerialNumber(val);
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  // Condition
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Initial Fixture Condition',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: condition,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'operational', child: Text('Operational / New')),
                          DropdownMenuItem(value: 'maintenance_needed', child: Text('Maintenance Needed')),
                          DropdownMenuItem(value: 'damaged', child: Text('Damaged / Decommissioned')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => condition = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const Key('btn-confirm-add-asset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCapReached ? Colors.grey : AppColors.wineRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: isCapReached
                    ? null
                    : () async {
                        final valErr = HostelRoomModel.validateSerialNumber(serialCtrl.text);
                        if (valErr != null) {
                          setDialogState(() => errorText = valErr);
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await widget.storage.addHostelAsset(
                            room.roomNumber,
                            selectedType,
                            serialCtrl.text.trim(),
                            condition,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadRooms();
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Added $selectedType (${serialCtrl.text.trim()}) to Room ${room.roomNumber}')),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                child: const Text('Add Asset'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignOccupantDialog(HostelRoomModel room) {
    if (!room.canAddOccupant) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Room ${room.roomNumber} is at maximum occupant capacity (${HostelRoomModel.maxOccupants}/${HostelRoomModel.maxOccupants}).'),
        ),
      );
      return;
    }

    final cachedUsers = widget.storage.cachedUsers;
    final students = cachedUsers.where((u) => u.archetype == 'student').toList();

    UserModel? selectedStudent = students.isNotEmpty ? students.first : null;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            key: const Key('dialog-assign-hostel-occupant'),
            title: Text('Allot Resident to Room ${room.roomNumber}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A room can have at most 3 occupants. Current occupancy: ${room.occupantCount} / ${HostelRoomModel.maxOccupants}.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (errorText != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.statusRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.statusRed),
                      ),
                      child: Text(
                        errorText!,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.statusRed),
                      ),
                    ),
                  ],
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Select Student Resident',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<UserModel>(
                        value: selectedStudent,
                        isDense: true,
                        isExpanded: true,
                        items: students.map((s) {
                          return DropdownMenuItem<UserModel>(
                            value: s,
                            child: Text(
                              '${s.fullName} (@${s.campusHandle})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedStudent = val;
                              errorText = null;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const Key('btn-confirm-assign-occupant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: selectedStudent == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await widget.storage.assignHostelOccupant(
                            room.roomNumber,
                            selectedStudent!.id,
                            selectedStudent!.campusHandle,
                            selectedStudent!.fullName,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadRooms();
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Allotted ${selectedStudent!.fullName} to Room ${room.roomNumber}')),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                child: const Text('Allot Resident'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInspectRoomModal(HostelRoomModel room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentRoom = _rooms.firstWhere((r) => r.roomNumber == room.roomNumber, orElse: () => room);

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.wineRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.wineRed, width: 1),
                        ),
                        child: Text(
                          'ROOM ${currentRoom.roomNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.wineRed),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Floor ${currentRoom.floor} • ${currentRoom.blockName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Occupants Header
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'RESIDENT OCCUPANTS (MAX 3)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (currentRoom.canAddOccupant)
                        TextButton.icon(
                          key: const Key('btn-modal-add-resident'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAssignOccupantDialog(currentRoom);
                          },
                          icon: const Icon(Icons.person_add, size: 14),
                          label: const Text('Add Resident', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (currentRoom.occupants.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Text(
                        'No residents currently allocated (Room is vacant).',
                        style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                    )
                  else
                    ...currentRoom.occupants.map((occ) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Row(
                          children: [
                            const AppSvgIcon(svgString: AppSvgIcon.user, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${occ.name} (@${occ.campusHandle})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_remove, size: 16, color: AppColors.statusRed),
                              tooltip: 'Discharge Resident',
                              onPressed: () async {
                                await widget.storage.removeHostelOccupant(currentRoom.roomNumber, occ.userId);
                                await _loadRooms();
                                setSheetState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // Assets Header
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'FIXTURE INVENTORY (MAX: 3 BEDS, 3 TABLES, 2 TUBELIGHTS, 2 FANS, 3 LOCKERS)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        key: const Key('btn-modal-add-fixture'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddAssetDialog(currentRoom);
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Fixture', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Expanded(
                    child: currentRoom.assets.isEmpty
                        ? Center(
                            child: Text(
                              'No fixtures registered in this room yet.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: currentRoom.assets.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final a = currentRoom.assets[idx];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _iconForAsset(a.assetType),
                                      size: 16,
                                      color: AppColors.wineRed,
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.assetType.toUpperCase(),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Condition: ${a.condition}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2E2211) : const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A),
                                        ),
                                      ),
                                      child: Text(
                                        'SN: ${a.serialNumber}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.statusRed),
                                      tooltip: 'Remove Asset',
                                      onPressed: () async {
                                        await widget.storage.removeHostelAsset(currentRoom.roomNumber, a.id);
                                        await _loadRooms();
                                        setSheetState(() {});
                                      },
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
          },
        );
      },
    );
  }

  IconData _iconForAsset(String type) {
    switch (type.toLowerCase()) {
      case 'bed':
        return Icons.bed;
      case 'table':
        return Icons.table_restaurant;
      case 'tubelight':
        return Icons.lightbulb_outline;
      case 'fan':
        return Icons.mode_fan_off;
      case 'locker':
        return Icons.lock_outline;
      default:
        return Icons.inventory_2_outlined;
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
                  // Title & Action Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hostel Room System & Asset Inventory',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Room numbers 100 to 999 • Strict capacity limits: 3 beds, 3 tables, 2 tubelights, 2 fans, 3 lockers, and 3 occupants • 14-character alphanumeric serial tracking',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        key: const Key('btn-add-hostel-room'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.wineRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: _showCreateRoomDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Room'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Metrics Ribbon
                  _buildMetricsRibbon(isDark),
                  const SizedBox(height: 20),

                  // Filters & Search Bar
                  Row(
                    children: [
                      // Floor Filter Chips
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildFloorChip(null, 'All Floors', isDark),
                          _buildFloorChip(1, 'Floor 1 (100-199)', isDark),
                          _buildFloorChip(2, 'Floor 2 (200-299)', isDark),
                          _buildFloorChip(3, 'Floor 3 (300-399)', isDark),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 260,
                        height: 38,
                        child: TextField(
                          key: const Key('input-search-hostel-room'),
                          decoration: InputDecoration(
                            hintText: 'Search room, resident, SN...',
                            prefixIcon: const Icon(Icons.search, size: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Room Cards Grid
                  if (_filteredRooms.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Text(
                        'No hostel rooms found matching your criteria.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth >= 1100 ? 3 : (constraints.maxWidth >= 700 ? 2 : 1);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 280,
                          ),
                          itemCount: _filteredRooms.length,
                          itemBuilder: (context, idx) {
                            return _buildRoomCard(_filteredRooms[idx], isDark);
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildFloorChip(int? floor, String label, bool isDark) {
    final isSelected = _selectedFloor == floor;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.wineRed.withValues(alpha: 0.18),
      side: BorderSide(
        color: isSelected ? AppColors.wineRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      onSelected: (_) {
        setState(() => _selectedFloor = floor);
        _loadRooms();
      },
    );
  }

  Widget _buildMetricsRibbon(bool isDark) {
    int totalOccupants = 0;
    int totalBeds = 0;
    int totalAssets = 0;

    for (final r in _rooms) {
      totalOccupants += r.occupantCount;
      totalBeds += r.bedCount;
      totalAssets += r.assets.length;
    }

    final availableBeds = totalBeds - totalOccupants;

    return Row(
      children: [
        _buildMetricCard('Registered Rooms', '${_rooms.length}', '100 to 999 range', AppColors.wineRed, isDark),
        const SizedBox(width: 12),
        _buildMetricCard('Total Residents', '$totalOccupants', 'Max 3 / room', const Color(0xFF0969DA), isDark),
        const SizedBox(width: 12),
        _buildMetricCard('Available Beds', '${availableBeds < 0 ? 0 : availableBeds}', 'Vacant allocations', const Color(0xFF2DA44E), isDark),
        const SizedBox(width: 12),
        _buildMetricCard('Tracked Fixtures', '$totalAssets', '<= 14 alphanumeric SN', const Color(0xFFD97706), isDark),
      ],
    );
  }

  Widget _buildMetricCard(String title, String val, String subtitle, Color accent, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  val,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accent),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '• $subtitle',
                    style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(HostelRoomModel room, bool isDark) {
    final isFull = room.occupantCount >= HostelRoomModel.maxOccupants;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.wineRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.wineRed),
                ),
                child: Text(
                  'ROOM ${room.roomNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.wineRed),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Floor ${room.floor} • ${room.blockName}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isFull
                      ? (isDark ? const Color(0xFF3E1F1F) : const Color(0xFFFFECEE))
                      : (isDark ? const Color(0xFF1B2E24) : const Color(0xFFECFDF5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isFull ? 'FULL (3/3)' : '${room.occupantCount}/3 RESIDENTS',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isFull ? AppColors.statusRed : const Color(0xFF238636),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Occupants List
          Text(
            'RESIDENTS (${room.occupantCount} / ${HostelRoomModel.maxOccupants})',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 4),
          if (room.occupants.isEmpty)
            Text(
              'No resident allocated (Vacant)',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: room.occupants.map((occ) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, size: 11),
                      const SizedBox(width: 4),
                      Text(occ.name, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 10),

          // Fixture Capacity Meters
          Text(
            'FIXTURE CAPACITIES (14-DIGIT SERIAL TRACKING)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildCapacityPill('Beds', room.bedCount, HostelRoomModel.maxBeds, isDark),
              _buildCapacityPill('Tables', room.tableCount, HostelRoomModel.maxTables, isDark),
              _buildCapacityPill('Tubelights', room.tubelightCount, HostelRoomModel.maxTubelights, isDark),
              _buildCapacityPill('Fans', room.fanCount, HostelRoomModel.maxFans, isDark),
              _buildCapacityPill('Lockers', room.lockerCount, HostelRoomModel.maxLockers, isDark),
            ],
          ),

          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: Key('btn-inspect-room-${room.roomNumber}'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => _showInspectRoomModal(room),
                  child: const Text('Inspect Fixtures', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                key: Key('btn-add-asset-${room.roomNumber}'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  side: const BorderSide(color: AppColors.wineRed),
                  foregroundColor: AppColors.wineRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _showAddAssetDialog(room),
                child: const Text('+ Asset', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                key: Key('btn-assign-occupant-${room.roomNumber}'),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  backgroundColor: room.canAddOccupant ? AppColors.wineRed : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: room.canAddOccupant ? () => _showAssignOccupantDialog(room) : null,
                child: const Text('+ Resident', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityPill(String name, int current, int max, bool isDark) {
    final isFull = current >= max;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isFull
            ? (isDark ? const Color(0xFF2E2211) : const Color(0xFFFFFBEB))
            : (isDark ? const Color(0xFF1E2229) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isFull
              ? const Color(0xFFD97706)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Text(
        '$name $current/$max',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
          color: isFull
              ? const Color(0xFFD97706)
              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
      ),
    );
  }
}
