class UserRoleAssignmentModel {
  final String id;
  final String userId;
  final String roleCode;
  final String roleName;
  final String? scopeCode;
  final String? validFrom;
  final String? validUntil;
  final bool isActive;

  UserRoleAssignmentModel({
    required this.id,
    required this.userId,
    required this.roleCode,
    this.roleName = '',
    this.scopeCode,
    this.validFrom,
    this.validUntil,
    this.isActive = true,
  });

  factory UserRoleAssignmentModel.fromJson(Map<String, dynamic> json) {
    return UserRoleAssignmentModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      roleCode: json['role_code'] ?? '',
      roleName: json['role_name'] ?? json['role_code'] ?? '',
      scopeCode: json['scope_code'],
      validFrom: json['valid_from']?.toString(),
      validUntil: json['valid_until']?.toString(),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'role_code': roleCode,
      'role_name': roleName,
      'scope_code': scopeCode,
      'valid_from': validFrom,
      'valid_until': validUntil,
      'is_active': isActive,
    };
  }
}

class UserModel {
  final String id;
  final String campusHandle;
  final String firstName;
  final String lastName;
  final String email;
  final String? personalEmail;
  final String? phone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? bloodGroup;
  final String? address;
  final String archetype; // 'student', 'employee', 'external'
  final String? universityRollNo;
  final String? admissionApplicationNo;
  final String? universityRegNo;
  final String status; // 'active', 'graduated', 'discontinued', 'suspended', 'resigned', 'retired'
  final String? discontinuationReason;
  final String? discontinuedAt;
  final String? discontinuedBy;
  final List<String> activeScopes;
  final List<UserRoleAssignmentModel> assignedRoles;
  final List<String> permissions;

  // Sub-profile metadata
  final Map<String, dynamic>? studentProfile;
  final Map<String, dynamic>? employeeRecord;
  final Map<String, dynamic>? academicProfile;
  final Map<String, dynamic>? administrativeProfile;
  final Map<String, dynamic>? contractorProfile;

  UserModel({
    required this.id,
    required this.campusHandle,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.personalEmail,
    this.phone,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.bloodGroup,
    this.address,
    required this.archetype,
    this.universityRollNo,
    this.admissionApplicationNo,
    this.universityRegNo,
    this.status = 'active',
    this.discontinuationReason,
    this.discontinuedAt,
    this.discontinuedBy,
    this.activeScopes = const [],
    this.assignedRoles = const [],
    this.permissions = const [],
    this.studentProfile,
    this.employeeRecord,
    this.academicProfile,
    this.administrativeProfile,
    this.contractorProfile,
  });

  String get fullName => '$firstName $lastName';
  bool get isActive => status.toLowerCase() == 'active';

  // Scoped RBAC Engine
  bool isScopeCovered(String? grantedScope, String? targetScope) {
    if (grantedScope == null || grantedScope.isEmpty || grantedScope == 'global') {
      return true; // Institutional / campus-wide authority
    }
    if (targetScope == null || targetScope.isEmpty || targetScope == 'global') {
      return false; // Scoped role cannot cover global scope
    }
    if (grantedScope == targetScope) {
      return true; // Exact match
    }
    if (targetScope.startsWith('$grantedScope:')) {
      return true; // Hierarchy match (e.g. 'dept:cse' covers 'dept:cse:sec-a')
    }
    return false;
  }

  bool hasRole(String roleCode, [String? targetScope]) {
    for (final assign in assignedRoles) {
      if (!assign.isActive) continue;
      if (assign.roleCode == roleCode) {
        if (targetScope == null || isScopeCovered(assign.scopeCode, targetScope)) {
          return true;
        }
      }
    }
    return false;
  }

  bool hasPermission(String permissionCode, [String? targetScope]) {
    if (permissions.contains('*')) return true;

    // Check wildcard role
    if (hasRole('admin', targetScope) || hasRole('campus_director', targetScope)) {
      return true;
    }

    if (permissions.contains(permissionCode)) {
      if (targetScope == null || activeScopes.isEmpty) return true;
      for (final s in activeScopes) {
        if (isScopeCovered(s, targetScope)) return true;
      }
    }
    return false;
  }

  // Persona & Role Getters
  bool get isAdmin =>
      permissions.contains('*') ||
      hasRole('admin') ||
      hasRole('campus_director') ||
      (archetype == 'employee' && campusHandle.contains('admin'));

  bool get isFaculty =>
      hasRole('faculty') ||
      hasRole('hod') ||
      (isEmployee && isAcademic);

  bool get isHOD => hasRole('hod') || isAdmin;

  bool get canManageUsers => isAdmin;

  bool get canManageDepartments => isAdmin || isHOD;

  bool get canManageHostel =>
      isAdmin ||
      hasRole('warden') ||
      hasRole('hostel_warden') ||
      hasPermission('hostel:manage') ||
      hasPermission('hostel:edit_room') ||
      permissions.contains('*') ||
      (isEmployee && !isAcademic);

  bool get canEditHostelRoom =>
      canManageHostel ||
      hasPermission('hostel:edit_room');

  bool get isWarden => hasRole('warden') || hasRole('hostel_warden') || hasPermission('hostel:manage');

  bool get canManageMess =>
      isAdmin ||
      hasRole('mess_manager') ||
      hasRole('canteen_manager') ||
      hasPermission('mess:manage') ||
      hasPermission('mess:edit_menu') ||
      hasPermission('menu:update') ||
      permissions.contains('*') ||
      (isContractor && (permittedScopes.contains('building:canteen') || activeScopes.contains('building:canteen')));

  bool get canEditMessMenu =>
      canManageMess ||
      hasPermission('mess:edit_menu') ||
      hasPermission('menu:update');

  bool get isMessManager =>
      hasRole('mess_manager') ||
      hasRole('canteen_manager') ||
      hasPermission('mess:manage') ||
      hasPermission('mess:edit_menu');

  bool get isLibraryInCharge =>
      isAdmin ||
      hasRole('library_incharge') ||
      hasRole('librarian') ||
      hasPermission('library:approve') ||
      hasPermission('library:manage') ||
      permissions.contains('*');

  bool get canManageLibrary => isLibraryInCharge;

  bool canManageComplaintsFor(String category) {
    final cat = category.trim().toLowerCase();
    if (isAdmin || permissions.contains('*') || hasPermission('complaints:manage')) {
      return true;
    }
    return hasPermission('complaints:$cat');
  }

  bool get canManageStudentComplaints => canManageComplaintsFor('student');
  bool get canManageEmployeeComplaints => canManageComplaintsFor('employee');
  bool get canManageContractorComplaints => canManageComplaintsFor('contractor');
  bool get canManageCampusComplaints => canManageComplaintsFor('campus');
  bool get canManageHostelComplaints => canManageComplaintsFor('hostel');

  bool get hasAnyComplaintManagementPermission =>
      isAdmin ||
      permissions.contains('*') ||
      hasPermission('complaints:manage') ||
      hasPermission('complaints:student') ||
      hasPermission('complaints:employee') ||
      hasPermission('complaints:contractor') ||
      hasPermission('complaints:campus') ||
      hasPermission('complaints:hostel');

  List<String> get manageableComplaintCategories {
    if (isAdmin || permissions.contains('*') || hasPermission('complaints:manage')) {
      return ['student', 'employee', 'contractor', 'campus', 'hostel'];
    }
    final list = <String>[];
    for (final cat in ['student', 'employee', 'contractor', 'campus', 'hostel']) {
      if (hasPermission('complaints:$cat')) {
        list.add(cat);
      }
    }
    return list;
  }

  bool canEditTimetable([String? targetScope]) =>
      isAdmin ||
      isHOD ||
      hasRole('faculty', targetScope) ||
      hasPermission('timetable:edit', targetScope);

  bool canDeclareDayOff([String? targetScope]) =>
      isAdmin ||
      isHOD ||
      hasPermission('timetable:declare_off', targetScope);

  bool canBroadcastAttendance([String? targetScope]) =>
      isAdmin ||
      isFaculty ||
      hasPermission('attendance:broadcast', targetScope);

  bool canScanAttendance([String? targetScope]) =>
      isStudent ||
      hasPermission('attendance:scan', targetScope);

  // Contractor / Vendor convenience getters
  bool get isContractor => archetype == 'external';
  String? get vendorOrganization => contractorProfile?['vendor_organization'];
  String? get serviceType => contractorProfile?['service_type'];
  String? get gatePassId => contractorProfile?['gate_pass_id'] ?? universityRollNo;
  String? get contractExpiresAt => contractorProfile?['contract_expires_at']?.toString();
  String? get supervisorName => contractorProfile?['supervisor_name'];
  String? get supervisorPhone => contractorProfile?['supervisor_phone'];
  List<String> get permittedScopes {
    final scopes = contractorProfile?['permitted_scopes'];
    if (scopes is List) return List<String>.from(scopes);
    return activeScopes;
  }

  // Student convenience getters
  bool get isStudent => archetype == 'student';
  String? get program => studentProfile?['program'];
  String? get entryType => studentProfile?['entry_type'];
  int? get admissionYear => studentProfile?['admission_year'];
  int? get batchYear => studentProfile?['batch_year'];
  int? get currentSemester => studentProfile?['current_semester'];
  String? get sectionScope => studentProfile?['section_scope'];
  String? get advisorName => studentProfile?['advisor_name'];

  // Employee convenience getters
  bool get isEmployee => archetype == 'employee';
  String? get employeeCode => employeeRecord?['employee_code'] ?? universityRollNo;
  String? get employmentType => employeeRecord?['employment_type'];
  bool get isAcademic => employeeRecord?['is_academic'] == true || academicProfile != null;
  bool get isAdministrative => employeeRecord?['is_administrative'] == true || administrativeProfile != null;
  String? get academicRank => academicProfile?['academic_rank'];
  String? get cabinLocation => academicProfile?['cabin_location'];
  String? get designation => administrativeProfile?['designation'];
  String? get primaryUnit => administrativeProfile?['primary_unit'];
  String? get officeLocation => administrativeProfile?['office_location'];

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<UserRoleAssignmentModel> assignedRoles = [];
    if (json['assigned_roles'] is List) {
      assignedRoles = (json['assigned_roles'] as List)
          .map((item) => UserRoleAssignmentModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    List<String> permissions = [];
    if (json['permissions'] is List) {
      permissions = List<String>.from(json['permissions']);
    }

    return UserModel(
      id: json['id'] ?? '',
      campusHandle: json['campus_handle'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      personalEmail: json['personal_email'],
      phone: json['phone'],
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
      bloodGroup: json['blood_group'] ?? json['bloodGroup'],
      address: json['address'],
      archetype: json['archetype'] ?? 'student',
      universityRollNo: json['university_roll_no'],
      admissionApplicationNo: json['admission_application_no'],
      universityRegNo: json['university_reg_no'],
      status: json['status'] ?? (json['is_active'] == false ? 'discontinued' : 'active'),
      discontinuationReason: json['discontinuation_reason'],
      discontinuedAt: json['discontinued_at']?.toString(),
      discontinuedBy: json['discontinued_by'],
      activeScopes: json['active_scopes'] != null
          ? List<String>.from(json['active_scopes'])
          : [],
      assignedRoles: assignedRoles,
      permissions: permissions,
      studentProfile: json['student_profile'] as Map<String, dynamic>?,
      employeeRecord: json['employee_record'] as Map<String, dynamic>?,
      academicProfile: json['academic_profile'] as Map<String, dynamic>?,
      administrativeProfile: json['administrative_profile'] as Map<String, dynamic>?,
      contractorProfile: json['contractor_profile'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campus_handle': campusHandle,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'personal_email': personalEmail,
      'phone': phone,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'blood_group': bloodGroup,
      'address': address,
      'archetype': archetype,
      'university_roll_no': universityRollNo,
      'admission_application_no': admissionApplicationNo,
      'university_reg_no': universityRegNo,
      'status': status,
      'discontinuation_reason': discontinuationReason,
      'discontinued_at': discontinuedAt,
      'discontinued_by': discontinuedBy,
      'active_scopes': activeScopes,
      'assigned_roles': assignedRoles.map((r) => r.toJson()).toList(),
      'permissions': permissions,
      'student_profile': studentProfile,
      'employee_record': employeeRecord,
      'academic_profile': academicProfile,
      'administrative_profile': administrativeProfile,
      'contractor_profile': contractorProfile,
    };
  }

  UserModel copyWith({
    String? id,
    String? campusHandle,
    String? firstName,
    String? lastName,
    String? email,
    String? personalEmail,
    String? phone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? bloodGroup,
    String? address,
    String? archetype,
    String? universityRollNo,
    String? admissionApplicationNo,
    String? universityRegNo,
    String? status,
    String? discontinuationReason,
    String? discontinuedAt,
    String? discontinuedBy,
    List<String>? activeScopes,
    List<UserRoleAssignmentModel>? assignedRoles,
    List<String>? permissions,
    Map<String, dynamic>? studentProfile,
    Map<String, dynamic>? employeeRecord,
    Map<String, dynamic>? academicProfile,
    Map<String, dynamic>? administrativeProfile,
    Map<String, dynamic>? contractorProfile,
  }) {
    return UserModel(
      id: id ?? this.id,
      campusHandle: campusHandle ?? this.campusHandle,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      personalEmail: personalEmail ?? this.personalEmail,
      phone: phone ?? this.phone,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      archetype: archetype ?? this.archetype,
      universityRollNo: universityRollNo ?? this.universityRollNo,
      admissionApplicationNo: admissionApplicationNo ?? this.admissionApplicationNo,
      universityRegNo: universityRegNo ?? this.universityRegNo,
      status: status ?? this.status,
      discontinuationReason: discontinuationReason ?? this.discontinuationReason,
      discontinuedAt: discontinuedAt ?? this.discontinuedAt,
      discontinuedBy: discontinuedBy ?? this.discontinuedBy,
      activeScopes: activeScopes ?? this.activeScopes,
      assignedRoles: assignedRoles ?? this.assignedRoles,
      permissions: permissions ?? this.permissions,
      studentProfile: studentProfile ?? this.studentProfile,
      employeeRecord: employeeRecord ?? this.employeeRecord,
      academicProfile: academicProfile ?? this.academicProfile,
      administrativeProfile: administrativeProfile ?? this.administrativeProfile,
      contractorProfile: contractorProfile ?? this.contractorProfile,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          (id == other.id || campusHandle == other.campusHandle);

  @override
  int get hashCode => id.isNotEmpty ? id.hashCode : campusHandle.hashCode;
}
