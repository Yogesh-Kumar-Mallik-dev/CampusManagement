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

class DisputeTargetType {
  static const String fine = 'fine';
  static const String fee = 'fee';
  static const String result = 'result';
  static const String attendance = 'attendance';
  static const String payroll = 'payroll';
  static const String other = 'other';

  static const List<String> all = [
    fine,
    fee,
    result,
    attendance,
    payroll,
    other,
  ];

  static String displayName(String? targetType) {
    if (targetType == null) return 'Other';
    switch (targetType.trim().toLowerCase()) {
      case fine:
        return 'Institutional Fine (Late / Disciplinary)';
      case fee:
        return 'Fee Invoice & Ledger Charges';
      case result:
        return 'Exam Result & Gradebook Evaluation';
      case attendance:
        return 'Attendance Calculation & Shortage';
      case payroll:
        return 'Staff Workload & Payroll Allocation';
      case other:
        return 'Other Official Institutional Record';
      default:
        return targetType.toUpperCase();
    }
  }

  static IconData iconFor(String? targetType) {
    if (targetType == null) return Icons.assignment_outlined;
    switch (targetType.trim().toLowerCase()) {
      case fine:
        return Icons.gavel_outlined;
      case fee:
        return Icons.receipt_long_outlined;
      case result:
        return Icons.school_outlined;
      case attendance:
        return Icons.event_available_outlined;
      case payroll:
        return Icons.account_balance_wallet_outlined;
      case other:
        return Icons.help_outline;
      default:
        return Icons.assignment_outlined;
    }
  }

  static List<String> resolutionOptionsFor(String? targetType) {
    if (targetType == null) return ['Formal Administrative Review', 'Correction of Official Record'];
    switch (targetType.trim().toLowerCase()) {
      case fine:
        return [
          'Full Fine Waiver / Dismissal',
          'Fine Amount Recalculation / Reduction',
          'Extension of Fine Settlement Deadline',
          'Administrative Warning in lieu of Fine',
        ];
      case fee:
        return [
          'Fee Correction & Ledger Credit',
          'Removal of Duplicate Charge',
          'Scholarship / Concession Reconciliation',
          'Installment Restructuring',
        ];
      case result:
        return [
          'Answer Script Re-evaluation',
          'Retabulation / Recalculation (+ Marks)',
          'Practical / Viva Score Correction',
          'Gradebook System Entry Rectification',
        ];
      case attendance:
        return [
          'Duty Leave / On-Duty Condonation (+%)',
          'Medical Certificate Approval & Exemption',
          'Biometric / QR Scan Error Correction',
          'Hall Ticket Debarment Waiver',
        ];
      case payroll:
        return [
          'Salary Slip Adjustment / Arrears Credit',
          'Conference Travel Reimbursement Reconciliation',
          'Overtime / Extra Duty Allowance Credit',
          'Tax / Deduction Rectification',
        ];
      default:
        return [
          'Official Administrative Rectification',
          'Record Re-investigation & Resolution',
          'Waiver of Penalty / Charge',
        ];
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

  // Dispute System additions
  final bool isDispute;
  final String? disputeTargetType; // fine, fee, result, attendance, payroll, other
  final String? disputeTargetId; // e.g. INV-2026-001, fine-lib-01, CS301-Midterm
  final String? disputeEvidence; // Statement of facts, proof
  final String? requestedResolution; // Desired resolution

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
    this.isDispute = false,
    this.disputeTargetType,
    this.disputeTargetId,
    this.disputeEvidence,
    this.requestedResolution,
  });

  bool get supportsAnonymous => isDispute ? false : ComplaintCategory.supportsAnonymous(category);

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
    bool? isDispute,
    String? disputeTargetType,
    String? disputeTargetId,
    String? disputeEvidence,
    String? requestedResolution,
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
      isDispute: isDispute ?? this.isDispute,
      disputeTargetType: disputeTargetType ?? this.disputeTargetType,
      disputeTargetId: disputeTargetId ?? this.disputeTargetId,
      disputeEvidence: disputeEvidence ?? this.disputeEvidence,
      requestedResolution: requestedResolution ?? this.requestedResolution,
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
      isDispute: json['is_dispute'] as bool? ?? false,
      disputeTargetType: json['dispute_target_type'] as String?,
      disputeTargetId: json['dispute_target_id'] as String?,
      disputeEvidence: json['dispute_evidence'] as String?,
      requestedResolution: json['requested_resolution'] as String?,
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
      'is_dispute': isDispute,
      if (disputeTargetType != null) 'dispute_target_type': disputeTargetType,
      if (disputeTargetId != null) 'dispute_target_id': disputeTargetId,
      if (disputeEvidence != null) 'dispute_evidence': disputeEvidence,
      if (requestedResolution != null) 'requested_resolution': requestedResolution,
    };
  }
}
