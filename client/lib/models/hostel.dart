class HostelAssetModel {
  final String id;
  final int roomNumber;
  final String assetType; // 'bed', 'table', 'tubelight', 'fan', 'locker'
  final String serialNumber; // at most 14 alphanumeric characters
  final String condition; // 'operational', 'maintenance_needed', 'damaged'
  final DateTime installedAt;

  const HostelAssetModel({
    required this.id,
    required this.roomNumber,
    required this.assetType,
    required this.serialNumber,
    this.condition = 'operational',
    required this.installedAt,
  });

  factory HostelAssetModel.fromJson(Map<String, dynamic> json) {
    return HostelAssetModel(
      id: json['id'] as String? ?? '',
      roomNumber: json['room_number'] as int? ?? 100,
      assetType: (json['asset_type'] as String? ?? 'bed').toLowerCase(),
      serialNumber: json['serial_number'] as String? ?? '',
      condition: json['condition'] as String? ?? 'operational',
      installedAt: json['installed_at'] != null
          ? DateTime.tryParse(json['installed_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_number': roomNumber,
      'asset_type': assetType,
      'serial_number': serialNumber,
      'condition': condition,
      'installed_at': installedAt.toIso8601String(),
    };
  }

  HostelAssetModel copyWith({
    String? id,
    int? roomNumber,
    String? assetType,
    String? serialNumber,
    String? condition,
    DateTime? installedAt,
  }) {
    return HostelAssetModel(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      assetType: assetType ?? this.assetType,
      serialNumber: serialNumber ?? this.serialNumber,
      condition: condition ?? this.condition,
      installedAt: installedAt ?? this.installedAt,
    );
  }
}

class HostelOccupantModel {
  final String userId;
  final String campusHandle;
  final String name;
  final DateTime allottedAt;

  const HostelOccupantModel({
    required this.userId,
    required this.campusHandle,
    required this.name,
    required this.allottedAt,
  });

  factory HostelOccupantModel.fromJson(Map<String, dynamic> json) {
    return HostelOccupantModel(
      userId: json['user_id'] as String? ?? '',
      campusHandle: json['campus_handle'] as String? ?? '',
      name: json['name'] as String? ?? '',
      allottedAt: json['allotted_at'] != null
          ? DateTime.tryParse(json['allotted_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'campus_handle': campusHandle,
      'name': name,
      'allotted_at': allottedAt.toIso8601String(),
    };
  }
}

class HostelRoomModel {
  final String id;
  final int roomNumber; // 100 to 999
  final String blockName;
  final int floor;
  final List<HostelAssetModel> assets;
  final List<HostelOccupantModel> occupants; // at most 3
  final DateTime createdAt;
  final DateTime updatedAt;

  // Domain Capacity Limits
  static const int minRoomNumber = 100;
  static const int maxRoomNumber = 999;
  static const int maxBeds = 3;
  static const int maxTables = 3;
  static const int maxChairs = 3;
  static const int maxTubelights = 2;
  static const int maxFans = 2;
  static const int maxLockers = 3;
  static const int maxOccupants = 3;
  static const int maxSerialLength = 14;

  const HostelRoomModel({
    required this.id,
    required this.roomNumber,
    this.blockName = 'Block 1',
    required this.floor,
    this.assets = const [],
    this.occupants = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get bedCount => assets.where((a) => a.assetType == 'bed').length;
  int get tableCount => assets.where((a) => a.assetType == 'table').length;
  int get chairCount => assets.where((a) => a.assetType == 'chair').length;
  int get tubelightCount => assets.where((a) => a.assetType == 'tubelight').length;
  int get fanCount => assets.where((a) => a.assetType == 'fan').length;
  int get lockerCount => assets.where((a) => a.assetType == 'locker').length;
  int get occupantCount => occupants.length;

  bool get canAddBed => bedCount < maxBeds;
  bool get canAddTable => tableCount < maxTables;
  bool get canAddChair => chairCount < maxChairs;
  bool get canAddTubelight => tubelightCount < maxTubelights;
  bool get canAddFan => fanCount < maxFans;
  bool get canAddLocker => lockerCount < maxLockers;
  bool get canAddOccupant => occupantCount < maxOccupants;

  int countForAssetType(String type) {
    switch (type.toLowerCase()) {
      case 'bed':
        return bedCount;
      case 'table':
        return tableCount;
      case 'chair':
        return chairCount;
      case 'tubelight':
        return tubelightCount;
      case 'fan':
        return fanCount;
      case 'locker':
        return lockerCount;
      default:
        return 0;
    }
  }

  int maxCapacityForAssetType(String type) {
    switch (type.toLowerCase()) {
      case 'bed':
        return maxBeds;
      case 'table':
        return maxTables;
      case 'chair':
        return maxChairs;
      case 'tubelight':
        return maxTubelights;
      case 'fan':
        return maxFans;
      case 'locker':
        return maxLockers;
      default:
        return 0;
    }
  }

  bool canAddAsset(String type) {
    final cap = maxCapacityForAssetType(type);
    if (cap == 0) return false;
    return countForAssetType(type) < cap;
  }

  static String? validateRoomNumber(int? number) {
    if (number == null) {
      return 'Room number is required';
    }
    if (number < minRoomNumber || number > maxRoomNumber) {
      return 'Room number must be between $minRoomNumber and $maxRoomNumber';
    }
    return null;
  }

  /// Derives the hostel floor (0 to 4) from the room number.
  /// Floor 0: 101 - 199
  /// Floor 1: 201 - 299
  /// Floor 2: 301 - 399
  /// Floor 3: 401 - 499
  /// Floor 4: 501 - 599
  static int deriveFloor(int roomNumber) {
    final floor = (roomNumber ~/ 100) - 1;
    if (floor < 0) return 0;
    if (floor > 4) return 4;
    return floor;
  }

  static String? validateSerialNumber(String? serial) {
    final trimmed = serial?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Serial number is required';
    }
    if (trimmed.length > maxSerialLength) {
      return 'Serial number cannot exceed $maxSerialLength alphanumeric characters';
    }
    final regex = RegExp(r'^[A-Za-z0-9\-_]{1,14}$');
    if (!regex.hasMatch(trimmed)) {
      return 'Serial number must be alphanumeric (max 14 characters)';
    }
    return null;
  }

  factory HostelRoomModel.fromJson(Map<String, dynamic> json) {
    final roomNum = json['room_number'] as int? ?? 100;
    return HostelRoomModel(
      id: json['id'] as String? ?? '',
      roomNumber: roomNum,
      blockName: json['block_name'] as String? ?? 'Block 1',
      floor: json['floor'] as int? ?? deriveFloor(roomNum),
      assets: (json['assets'] as List<dynamic>? ?? [])
          .map((e) => HostelAssetModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      occupants: (json['occupants'] as List<dynamic>? ?? [])
          .map((e) => HostelOccupantModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_number': roomNumber,
      'block_name': blockName,
      'floor': floor,
      'assets': assets.map((a) => a.toJson()).toList(),
      'occupants': occupants.map((o) => o.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  HostelRoomModel copyWith({
    String? id,
    int? roomNumber,
    String? blockName,
    int? floor,
    List<HostelAssetModel>? assets,
    List<HostelOccupantModel>? occupants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HostelRoomModel(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      blockName: blockName ?? this.blockName,
      floor: floor ?? this.floor,
      assets: assets ?? this.assets,
      occupants: occupants ?? this.occupants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
