import 'package:flutter/material.dart';

class ComplaintCategory {
  static const String student = 'student';
  static const String employee = 'employee';
  static const String contractor = 'contractor';
  static const String campus = 'campus';
  static const String hostel = 'hostel';

  static const List<String> all = [
    hostel,
    campus,
    student,
    employee,
    contractor,
  ];

  static bool supportsAnonymous(String category) {
    final cat = category.trim().toLowerCase();
    return cat == campus || cat == hostel;
  }

  static String displayName(String category) {
    switch (category.trim().toLowerCase()) {
      case hostel:
        return 'Hostel & Mess';
      case campus:
        return 'Campus Infrastructure';
      case student:
        return 'Student Affairs & Academics';
      case employee:
        return 'Staff & Workplace';
      case contractor:
        return 'Contractor & Vendor Operations';
      default:
        return category.toUpperCase();
    }
  }

  static IconData iconFor(String category) {
    switch (category.trim().toLowerCase()) {
      case hostel:
        return Icons.bed_outlined;
      case campus:
        return Icons.domain_outlined;
      case student:
        return Icons.school_outlined;
      case employee:
        return Icons.badge_outlined;
      case contractor:
        return Icons.store_outlined;
      default:
        return Icons.report_problem_outlined;
    }
  }
}

class ComplaintUrgency {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';
  static const String critical = 'critical';

  static const List<String> all = [low, medium, high, critical];

  static String displayName(String urgency) {
    switch (urgency.trim().toLowerCase()) {
      case low:
        return 'Low Priority';
      case medium:
        return 'Medium Priority';
      case high:
        return 'High Priority';
      case critical:
        return 'Critical Attention';
      default:
        return urgency.toUpperCase();
    }
  }

  static Color colorFor(String urgency) {
    switch (urgency.trim().toLowerCase()) {
      case low:
        return const Color(0xFF2DA44E); // Green
      case medium:
        return const Color(0xFF0969DA); // Blue
      case high:
        return const Color(0xFFD97706); // Orange/Amber
      case critical:
        return const Color(0xFFCF222E); // Red
      default:
        return const Color(0xFF6E7781);
    }
  }
}

class ComplaintStatus {
  static const String open = 'open';
  static const String inProgress = 'in_progress';
  static const String resolved = 'resolved';
  static const String rejected = 'rejected';

  static const List<String> all = [open, inProgress, resolved, rejected];

  static String displayName(String status) {
    switch (status.trim().toLowerCase()) {
      case open:
        return 'Open / Pending';
      case inProgress:
        return 'Under Investigation';
      case resolved:
        return 'Resolved';
      case rejected:
        return 'Rejected';
      default:
        return status.toUpperCase();
    }
  }

  static Color colorFor(String status) {
    switch (status.trim().toLowerCase()) {
      case open:
        return const Color(0xFFD97706); // Orange
      case inProgress:
        return const Color(0xFF0969DA); // Blue
      case resolved:
        return const Color(0xFF238636); // Green
      case rejected:
        return const Color(0xFFCF222E); // Red
      default:
        return const Color(0xFF6E7781);
    }
  }
}

class ComplaintModel {
  final String id;
  final String title;
  final String description;
  final String category; // student, employee, contractor, campus, hostel
  final String urgency; // low, medium, high, critical
  final bool isAnonymous;
  final String submittedBy;
  final String submitterName;
  final String submitterHandle;
  final String submitterRole;
  final String status; // open, in_progress, resolved, rejected
  final String? resolutionRemarks;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ComplaintModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.urgency = ComplaintUrgency.medium,
    this.isAnonymous = false,
    required this.submittedBy,
    required this.submitterName,
    required this.submitterHandle,
    required this.submitterRole,
    this.status = ComplaintStatus.open,
    this.resolutionRemarks,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get supportsAnonymous => ComplaintCategory.supportsAnonymous(category);

  bool get isOpen => status == ComplaintStatus.open;
  bool get isInProgress => status == ComplaintStatus.inProgress;
  bool get isResolved => status == ComplaintStatus.resolved;
  bool get isRejected => status == ComplaintStatus.rejected;

  ComplaintModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? urgency,
    bool? isAnonymous,
    String? submittedBy,
    String? submitterName,
    String? submitterHandle,
    String? submitterRole,
    String? status,
    String? resolutionRemarks,
    String? resolvedBy,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      urgency: urgency ?? this.urgency,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      submittedBy: submittedBy ?? this.submittedBy,
      submitterName: submitterName ?? this.submitterName,
      submitterHandle: submitterHandle ?? this.submitterHandle,
      submitterRole: submitterRole ?? this.submitterRole,
      status: status ?? this.status,
      resolutionRemarks: resolutionRemarks ?? this.resolutionRemarks,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? ComplaintCategory.hostel,
      urgency: json['urgency'] as String? ?? ComplaintUrgency.medium,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      submittedBy: json['submitted_by'] as String? ?? '',
      submitterName: json['submitter_name'] as String? ?? (json['is_anonymous'] == true ? 'Anonymous Reporter' : 'Campus Member'),
      submitterHandle: json['submitter_handle'] as String? ?? (json['is_anonymous'] == true ? 'anonymous' : ''),
      submitterRole: json['submitter_role'] as String? ?? '',
      status: json['status'] as String? ?? ComplaintStatus.open,
      resolutionRemarks: json['resolution_remarks'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'urgency': urgency,
      'is_anonymous': isAnonymous,
      'submitted_by': submittedBy,
      'submitter_name': submitterName,
      'submitter_handle': submitterHandle,
      'submitter_role': submitterRole,
      'status': status,
      if (resolutionRemarks != null) 'resolution_remarks': resolutionRemarks,
      if (resolvedBy != null) 'resolved_by': resolvedBy,
      if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
