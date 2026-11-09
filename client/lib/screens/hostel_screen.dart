import 'package:flutter/material.dart';
import '../models/complaint.dart';
import '../models/hostel.dart';
import '../models/user.dart';
import '../screens/complaints_screen.dart';
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
    final canManage = (widget.currentUser?.canManageHostel ?? false) || (widget.currentUser?.canEditHostelRoom ?? false);
    if (!canManage) {
      if (widget.currentUser == null) return [];
      return _rooms.where((r) => r.occupants.any((o) =>
          o.userId == widget.currentUser!.id ||
          o.campusHandle == widget.currentUser!.campusHandle)).toList();
    }
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

  void _showEditRoomDialog(HostelRoomModel room) {
    final roomCtrl = TextEditingController(text: room.roomNumber.toString());
    final blockCtrl = TextEditingController(text: room.blockName);
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            key: const Key('dialog-edit-hostel-room'),
            title: Text('Edit Room ${room.roomNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modify room number (100 - 999) and block allocation. All registered fixtures and residents will transition to the updated room identifier.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('input-edit-room-number'),
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
                    key: const Key('input-edit-block-name'),
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
                key: const Key('btn-save-room-edits'),
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
                    await widget.storage.updateHostelRoom(room.roomNumber, num!, blockCtrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadRooms();
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Hostel room $num successfully updated.')),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditAssetDialog(HostelRoomModel room, HostelAssetModel asset) {
    final serialCtrl = TextEditingController(text: asset.serialNumber);
    String condition = asset.condition;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            key: const Key('dialog-edit-hostel-asset'),
            title: Text('Edit Fixture ${asset.assetType.toUpperCase()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update serial number (alphanumeric, max 14 characters) and operational condition.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('input-edit-asset-serial'),
                    controller: serialCtrl,
                    decoration: InputDecoration(
                      labelText: 'Serial Number (<= 14 chars)',
                      hintText: 'e.g. BED-101-01',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        errorText = HostelRoomModel.validateSerialNumber(val.trim());
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('select-edit-asset-condition'),
                    initialValue: condition,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Operational Condition',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'operational', child: Text('Operational (In Good Standing)')),
                      DropdownMenuItem(value: 'maintenance_needed', child: Text('Maintenance Needed')),
                      DropdownMenuItem(value: 'damaged', child: Text('Damaged / Defective')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => condition = val);
                      }
                    },
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
                key: const Key('btn-save-asset-edits'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final serialErr = HostelRoomModel.validateSerialNumber(serialCtrl.text.trim());
                  if (serialErr != null) {
                    setDialogState(() => errorText = serialErr);
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await widget.storage.updateHostelAsset(
                      room.roomNumber,
                      asset.id,
                      serialNumber: serialCtrl.text.trim(),
                      condition: condition,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadRooms();
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Fixture ${asset.assetType} successfully updated.')),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Save Fixture'),
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
      } else if (room.canAddChair) {
        selectedType = 'chair';
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
                    'A room can have at most 3 beds, 3 tables, 3 chairs, 2 tubelights, 2 fans, and 3 lockers. Every asset must have an alphanumeric serial number of at most 14 characters.',
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
                          DropdownMenuItem(value: 'chair', child: Text('Study Chair (Max 3)')),
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

            final canManage = (widget.currentUser?.canManageHostel ?? false) || (widget.currentUser?.canEditHostelRoom ?? false);

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
                      Expanded(
                        child: Text(
                          'Floor ${currentRoom.floor} • ${currentRoom.blockName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (canManage) ...[
                        IconButton(
                          key: Key('btn-modal-edit-room-${currentRoom.roomNumber}'),
                          icon: const Icon(Icons.edit, size: 16),
                          tooltip: 'Edit Room',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showEditRoomDialog(currentRoom);
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (!canManage)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Text(
                            'Resident View (Read-Only)',
                            style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                        ),
                      const SizedBox(width: 8),
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
                      if (canManage && currentRoom.canAddOccupant)
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
                            if (canManage)
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
                          'FIXTURE INVENTORY (MAX: 3 BEDS, 3 TABLES, 3 CHAIRS, 2 TUBELIGHTS, 2 FANS, 3 LOCKERS)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (canManage)
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
                                    if (canManage) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        key: Key('btn-edit-asset-${a.id}'),
                                        icon: const Icon(Icons.edit, size: 16),
                                        tooltip: 'Edit Fixture',
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _showEditAssetDialog(currentRoom, a);
                                        },
                                      ),
                                      IconButton(
                                        key: Key('btn-delete-asset-${a.id}'),
                                        icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.statusRed),
                                        tooltip: 'Remove Asset',
                                        onPressed: () async {
                                          await widget.storage.removeHostelAsset(currentRoom.roomNumber, a.id);
                                          await _loadRooms();
                                          setSheetState(() {});
                                        },
                                      ),
                                    ],
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
      case 'chair':
        return Icons.chair_outlined;
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
    final canManage = (widget.currentUser?.canManageHostel ?? false) || (widget.currentUser?.canEditHostelRoom ?? false);

    HostelRoomModel? myRoom;
    if (widget.currentUser != null) {
      for (final r in _rooms) {
        if (r.occupants.any((o) =>
            o.userId == widget.currentUser!.id ||
            o.campusHandle == widget.currentUser!.campusHandle)) {
          myRoom = r;
          break;
        }
      }
    }

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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            canManage
                                ? 'Hostel Room System & Asset Inventory'
                                : 'Hostel Residence Portal',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            canManage
                                ? 'Warden Console • Room numbers 100 to 999 • Strict capacity limits: 3 beds, 3 tables, 3 chairs, 2 tubelights, 2 fans, 3 lockers, and 3 occupants • 14-character alphanumeric serial tracking'
                                : 'Student Resident View • Personal room allotment, roommates, and serial-tracked fixture inventory.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('btn-shortcut-hostel-complaint'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.statusRed,
                              side: const BorderSide(color: AppColors.statusRed, width: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () {
                              ComplaintsScreen.showFileComplaintDialog(
                                context: context,
                                storage: widget.storage,
                                currentUser: widget.currentUser,
                                initialCategory: ComplaintCategory.hostel,
                                initialTitle: 'Hostel Maintenance / Fixture Grievance',
                              );
                            },
                            icon: const AppSvgIcon(
                              svgString: AppSvgIcon.alertTriangle,
                              size: 14,
                              color: AppColors.statusRed,
                            ),
                            label: const Text(
                              'Report Hostel Issue',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (canManage)
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
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.wineRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.wineRed),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school, size: 14, color: AppColors.wineRed),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.currentUser?.fullName ?? 'Student Resident',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.wineRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  if (canManage) ...[
                    // Supervisor/Warden Console: Metrics Ribbon, Floor Filters, Search, and Full Campus Directory
                    _buildMetricsRibbon(isDark),
                    const SizedBox(height: 20),

                    // Filters & Search Bar
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildFloorChip(null, 'All Floors', isDark),
                            _buildFloorChip(1, 'Floor 1 (100-199)', isDark),
                            _buildFloorChip(2, 'Floor 2 (200-299)', isDark),
                            _buildFloorChip(3, 'Floor 3 (300-399)', isDark),
                          ],
                        ),
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

                    // Room Cards Grid (All Rooms)
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
                              mainAxisExtent: constraints.maxWidth < 500 ? 470 : (constraints.maxWidth < 750 ? 350 : 335),
                            ),
                            itemCount: _filteredRooms.length,
                            itemBuilder: (context, idx) {
                              return _buildRoomCard(_filteredRooms[idx], isDark, true);
                            },
                          );
                        },
                      ),
                  ] else ...[
                    // Student Resident View: Redesigned full-page residence portal
                    _buildStudentHostelView(myRoom, isDark),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStudentHostelView(HostelRoomModel? myRoom, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStudentMetricsRibbon(myRoom, isDark),
        const SizedBox(height: 20),
        if (myRoom == null)
          _buildMyRoomCardVacant(isDark)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _buildStudentMainCard(myRoom, isDark),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: _buildStudentSidebar(myRoom, isDark),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStudentMainCard(myRoom, isDark),
                  const SizedBox(height: 20),
                  _buildStudentSidebar(myRoom, isDark),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildStudentMetricsRibbon(HostelRoomModel? myRoom, bool isDark) {
    final cards = [
      _buildMetricCard(
        'Allotted Residence',
        myRoom != null ? 'Room ${myRoom.roomNumber}' : 'Unallotted',
        myRoom != null ? '${myRoom.blockName} • Floor ${myRoom.floor}' : 'Warden Office G-04',
        AppColors.wineRed,
        isDark,
      ),
      _buildMetricCard(
        'Roommate Capacity',
        myRoom != null ? '${myRoom.occupantCount}/${HostelRoomModel.maxOccupants} Occupants' : '0/3 Occupants',
        myRoom != null
            ? (myRoom.canAddOccupant
                ? '${HostelRoomModel.maxOccupants - myRoom.occupantCount} Bed Available'
                : 'Fully Occupied')
            : 'No Active Room',
        const Color(0xFF0969DA),
        isDark,
      ),
      _buildMetricCard(
        'Verified Fixtures',
        myRoom != null ? '${myRoom.assets.length} Fixtures' : '0 Fixtures',
        'Max 14-char alphanumeric',
        const Color(0xFF2DA44E),
        isDark,
      ),
      _buildMetricCard(
        'Hostel Gate Curfew',
        '22:30 IST',
        'Gate 1 Biometric Log',
        const Color(0xFFD97706),
        isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        final double itemWidth = constraints.maxWidth < 340
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildMyRoomCardVacant(bool isDark) {
    return Container(
      key: const Key('card-my-allotted-room-vacant'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No Hostel Room Allotted',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You are currently not allocated to any campus residence room. Contact the hostel warden office to apply for room allotment.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(height: 16),
          const Text(
            'HOSTEL ALLOTMENT HELP & INSTRUCTIONS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '1. Ensure tuition and hostel accommodation fees are cleared for the current academic session.\n2. Submit room preference (Aryabhatta Block, Floor 1-3) at the Warden Office (Gate 1, Room G-04).\n3. Room allotments are capped at 3 occupants and 16 serial-tracked fixtures per room.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentMainCard(HostelRoomModel myRoom, bool isDark) {
    final currentUserHandle = widget.currentUser?.campusHandle;

    return Container(
      key: const Key('card-my-allotted-room'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.wineRed, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.wineRed.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Row
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.wineRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MY ALLOTTED ROOM: ROOM ${myRoom.roomNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    '${myRoom.blockName} • Floor ${myRoom.floor}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2E24) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? const Color(0xFF238636) : const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 12, color: Color(0xFF238636)),
                    SizedBox(width: 4),
                    Text(
                      'Active Allocation',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF238636)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('btn-student-inspect-room'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _showInspectRoomModal(myRoom),
                icon: const Icon(Icons.inventory_2_outlined, size: 14),
                label: const Text('View All Serial Numbers', style: TextStyle(fontSize: 11)),
              ),
              ElevatedButton.icon(
                key: const Key('btn-report-fixture-issue'),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Maintenance ticket submitted to Hostel Warden for Room ${myRoom.roomNumber}.'),
                    ),
                  );
                },
                icon: const Icon(Icons.report_problem_outlined, size: 14),
                label: const Text('Report Fixture Issue', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Roommates Section
          Text(
            'ROOMMATES (${myRoom.occupantCount} / ${HostelRoomModel.maxOccupants})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          ...myRoom.occupants.asMap().entries.map((entry) {
            final idx = entry.key;
            final occ = entry.value;
            final isMe = occ.campusHandle == currentUserHandle || occ.userId == widget.currentUser?.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.wineRed.withValues(alpha: 0.08)
                    : (isDark ? const Color(0xFF1E2229) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMe ? AppColors.wineRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isMe ? AppColors.wineRed : (isDark ? const Color(0xFF2D333B) : const Color(0xFFE2E8F0)),
                    child: Icon(
                      Icons.person,
                      size: 15,
                      color: isMe ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${occ.name} (@${occ.campusHandle})${isMe ? " (You)" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                            color: isMe ? AppColors.wineRed : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bed Slot #${idx + 1} • ${isMe ? "Primary Resident" : "Roommate Resident"}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMe)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.wineRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'You',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                ],
              ),
            );
          }),
          if (myRoom.occupantCount < HostelRoomModel.maxOccupants) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14181F) : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.bed_outlined, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bed Slot #${myRoom.occupantCount + 1}: Vacant • Managed by Warden Office',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Verified Room Fixtures Summary Pills
          Text(
            'VERIFIED ROOM FIXTURES (${myRoom.assets.length} ITEMS REGISTERED)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Capacity limits: 3 beds, 3 tables, 3 chairs, 2 tubelights, 2 fans, 3 lockers. All tracked with unique alphanumeric serial numbers.',
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMyRoomAssetSummary('Beds', myRoom.bedCount, HostelRoomModel.maxBeds, myRoom.assets.where((a) => a.assetType == 'bed').toList(), isDark),
              _buildMyRoomAssetSummary('Tables', myRoom.tableCount, HostelRoomModel.maxTables, myRoom.assets.where((a) => a.assetType == 'table').toList(), isDark),
              _buildMyRoomAssetSummary('Chairs', myRoom.chairCount, HostelRoomModel.maxChairs, myRoom.assets.where((a) => a.assetType == 'chair').toList(), isDark),
              _buildMyRoomAssetSummary('Tubelights', myRoom.tubelightCount, HostelRoomModel.maxTubelights, myRoom.assets.where((a) => a.assetType == 'tubelight').toList(), isDark),
              _buildMyRoomAssetSummary('Fans', myRoom.fanCount, HostelRoomModel.maxFans, myRoom.assets.where((a) => a.assetType == 'fan').toList(), isDark),
              _buildMyRoomAssetSummary('Lockers', myRoom.lockerCount, HostelRoomModel.maxLockers, myRoom.assets.where((a) => a.assetType == 'locker').toList(), isDark),
            ],
          ),
          const SizedBox(height: 18),

          // Physical Asset Inventory Showcase (Utilizing the Full Space)
          Text(
            'PHYSICAL FIXTURE INVENTORY & SERIAL TAGS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final colCount = constraints.maxWidth >= 550 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: colCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 68,
                ),
                itemCount: myRoom.assets.length,
                itemBuilder: (context, idx) {
                  return _buildStudentAssetTile(myRoom.assets[idx], isDark);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAssetTile(HostelAssetModel asset, bool isDark) {
    IconData icon;
    Color iconColor;
    String typeLabel;

    switch (asset.assetType.toLowerCase()) {
      case 'bed':
        icon = Icons.single_bed_outlined;
        iconColor = AppColors.wineRed;
        typeLabel = 'Bed Unit';
        break;
      case 'table':
        icon = Icons.table_restaurant_outlined;
        iconColor = const Color(0xFF0969DA);
        typeLabel = 'Study Table';
        break;
      case 'chair':
        icon = Icons.chair_outlined;
        iconColor = const Color(0xFF238636);
        typeLabel = 'Study Chair';
        break;
      case 'tubelight':
        icon = Icons.lightbulb_outline;
        iconColor = const Color(0xFFD97706);
        typeLabel = 'Tubelight';
        break;
      case 'fan':
        icon = Icons.air;
        iconColor = const Color(0xFF6E7781);
        typeLabel = 'Ceiling Fan';
        break;
      case 'locker':
        icon = Icons.lock_outline;
        iconColor = const Color(0xFF8250DF);
        typeLabel = 'Locker Unit';
        break;
      default:
        icon = Icons.inventory_2_outlined;
        iconColor = AppColors.wineRed;
        typeLabel = asset.assetType;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        typeLabel,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF238636),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Verified',
                          style: TextStyle(fontSize: 9.5, color: Color(0xFF238636), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  asset.serialNumber,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSidebar(HostelRoomModel myRoom, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rules Card
        _buildSidebarInfoCard(
          title: 'RESIDENCE RULES & TIMINGS',
          icon: Icons.rule_folder_outlined,
          iconColor: AppColors.wineRed,
          isDark: isDark,
          items: const [
            ('Hostel Curfew', '22:30 IST sharp (Gate 1 Biometric Verification)'),
            ('Night Out Pass', 'Submit on student portal 6 hours prior to departure'),
            ('Quiet Hours', '23:00 - 06:00 daily across all wings'),
            ('Asset Integrity', 'Barring occupants, all 16 items have 14-char SN tags'),
          ],
        ),
        const SizedBox(height: 16),

        // Amenities Card
        _buildSidebarInfoCard(
          title: 'HOSTEL AMENITIES & SERVICES',
          icon: Icons.apartment_outlined,
          iconColor: const Color(0xFF0969DA),
          isDark: isDark,
          items: [
            ('Wi-Fi Network', 'Aryabhatta-Res-5G (WPA2-Enterprise 1 Gbps)'),
            ('Laundromat', 'Ground Floor West Wing • 06:00 - 22:00'),
            ('Drinking Water', 'Central RO + UV cooler station on Floor ${myRoom.floor}'),
            ('Study Lounge', '2nd Floor Central Atrium (24/7 Access)'),
          ],
        ),
        const SizedBox(height: 16),

        // Contacts Card
        _buildSidebarInfoCard(
          title: 'WARDEN & EMERGENCY HELPDESK',
          icon: Icons.contact_support_outlined,
          iconColor: const Color(0xFF238636),
          isDark: isDark,
          items: const [
            ('Chief Warden', 'Dr. Ramesh Singh • Gate 1 Office (Ext: 2401)'),
            ('Resident Caretaker', 'Mr. Kailash Nath • +91 98765 43210 (24/7)'),
            ('Medical Emergency', 'Campus Health Center (Ext: 1001 / Dial 108)'),
            ('Maintenance Response', 'Reported fixture issues inspected within 24 hours'),
          ],
        ),
      ],
    );
  }

  Widget _buildSidebarInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required List<(String, String)> items,
  }) {
    return Container(
      width: double.infinity,
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: '${item.$1}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: item.$2,
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMyRoomAssetSummary(String title, int count, int max, List<HostelAssetModel> assets, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$title: $count/$max',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (assets.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              assets.map((a) => a.serialNumber).join(', '),
              style: TextStyle(
                fontSize: 9.5,
                fontFamily: 'monospace',
                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
              ),
            ),
          ],
        ],
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

    final cards = [
      _buildMetricCard('Registered Rooms', '${_rooms.length}', '100-999 range', AppColors.wineRed, isDark),
      _buildMetricCard('Total Residents', '$totalOccupants', 'Max 3 / room', const Color(0xFF0969DA), isDark),
      _buildMetricCard('Available Beds', '${availableBeds < 0 ? 0 : availableBeds}', 'Vacant allocations', const Color(0xFF2DA44E), isDark),
      _buildMetricCard('Tracked Fixtures', '$totalAssets', '<= 14 alphanumeric SN', const Color(0xFFD97706), isDark),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        final double itemWidth = constraints.maxWidth < 340
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String val, String subtitle, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(HostelRoomModel room, bool isDark, bool canManage) {
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
              _buildCapacityPill('Chairs', room.chairCount, HostelRoomModel.maxChairs, isDark),
              _buildCapacityPill('Tubelights', room.tubelightCount, HostelRoomModel.maxTubelights, isDark),
              _buildCapacityPill('Fans', room.fanCount, HostelRoomModel.maxFans, isDark),
              _buildCapacityPill('Lockers', room.lockerCount, HostelRoomModel.maxLockers, isDark),
            ],
          ),

          const SizedBox(height: 12),

          // Actions
          if (canManage)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  key: Key('btn-edit-room-${room.roomNumber}'),
                  icon: const Icon(Icons.edit, size: 16),
                  tooltip: 'Edit Room',
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  onPressed: () => _showEditRoomDialog(room),
                ),
                OutlinedButton(
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
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('btn-inspect-room-${room.roomNumber}'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _showInspectRoomModal(room),
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: const Text('Inspect Fixtures & Occupancy', style: TextStyle(fontSize: 11)),
              ),
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
