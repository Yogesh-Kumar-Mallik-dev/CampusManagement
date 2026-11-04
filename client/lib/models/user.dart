class UserModel {
  final String id;
  final String campusHandle;
  final String firstName;
  final String lastName;
  final String email;
  final String archetype; // 'student', 'employee', 'external'
  final String? universityRollNo;
  final List<String> activeScopes;

  UserModel({
    required this.id,
    required this.campusHandle,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.archetype,
    this.universityRollNo,
    this.activeScopes = const [],
  });

  String get fullName => '$firstName $lastName';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      campusHandle: json['campus_handle'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      archetype: json['archetype'] ?? 'student',
      universityRollNo: json['university_roll_no'],
      activeScopes: json['active_scopes'] != null
          ? List<String>.from(json['active_scopes'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campus_handle': campusHandle,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'archetype': archetype,
      'university_roll_no': universityRollNo,
      'active_scopes': activeScopes,
    };
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
