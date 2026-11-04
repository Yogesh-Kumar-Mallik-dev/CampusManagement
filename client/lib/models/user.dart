class UserModel {
  final String id;
  final String campusHandle;
  final String firstName;
  final String lastName;
  final String email;
  final String? personalEmail;
  final String? phone;
  final String archetype; // 'student', 'employee', 'external'
  final String? universityRollNo;
  final String? admissionApplicationNo;
  final String? universityRegNo;
  final String status; // 'active', 'graduated', 'discontinued', 'suspended', 'resigned', 'retired'
  final String? discontinuationReason;
  final String? discontinuedAt;
  final String? discontinuedBy;
  final List<String> activeScopes;

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
    required this.archetype,
    this.universityRollNo,
    this.admissionApplicationNo,
    this.universityRegNo,
    this.status = 'active',
    this.discontinuationReason,
    this.discontinuedAt,
    this.discontinuedBy,
    this.activeScopes = const [],
    this.studentProfile,
    this.employeeRecord,
    this.academicProfile,
    this.administrativeProfile,
    this.contractorProfile,
  });

  String get fullName => '$firstName $lastName';
  bool get isActive => status.toLowerCase() == 'active';

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
    return UserModel(
      id: json['id'] ?? '',
      campusHandle: json['campus_handle'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      personalEmail: json['personal_email'],
      phone: json['phone'],
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
      'archetype': archetype,
      'university_roll_no': universityRollNo,
      'admission_application_no': admissionApplicationNo,
      'university_reg_no': universityRegNo,
      'status': status,
      'discontinuation_reason': discontinuationReason,
      'discontinued_at': discontinuedAt,
      'discontinued_by': discontinuedBy,
      'active_scopes': activeScopes,
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
    String? archetype,
    String? universityRollNo,
    String? admissionApplicationNo,
    String? universityRegNo,
    String? status,
    String? discontinuationReason,
    String? discontinuedAt,
    String? discontinuedBy,
    List<String>? activeScopes,
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
      archetype: archetype ?? this.archetype,
      universityRollNo: universityRollNo ?? this.universityRollNo,
      admissionApplicationNo: admissionApplicationNo ?? this.admissionApplicationNo,
      universityRegNo: universityRegNo ?? this.universityRegNo,
      status: status ?? this.status,
      discontinuationReason: discontinuationReason ?? this.discontinuationReason,
      discontinuedAt: discontinuedAt ?? this.discontinuedAt,
      discontinuedBy: discontinuedBy ?? this.discontinuedBy,
      activeScopes: activeScopes ?? this.activeScopes,
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
