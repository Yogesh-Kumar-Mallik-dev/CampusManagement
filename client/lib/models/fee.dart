import 'package:flutter/material.dart';

class FeeType {
  static const String tuition = 'tuition';
  static const String hostel = 'hostel';
  static const String mess = 'mess';
  static const String laboratory = 'laboratory';
  static const String examination = 'examination';
  static const String library = 'library';
  static const String miscellaneous = 'miscellaneous';

  static const List<String> all = [
    tuition,
    hostel,
    mess,
    laboratory,
    examination,
    library,
    miscellaneous,
  ];

  static String displayName(String feeType) {
    switch (feeType.trim().toLowerCase()) {
      case tuition:
        return 'Tuition & Academic';
      case hostel:
        return 'Hostel & Residence';
      case mess:
        return 'Mess & Dining';
      case laboratory:
        return 'Lab & Equipment';
      case examination:
        return 'Examination';
      case library:
        return 'Library & Digital';
      default:
        return 'Miscellaneous';
    }
  }

  static IconData iconFor(String feeType) {
    switch (feeType.trim().toLowerCase()) {
      case tuition:
        return Icons.school_outlined;
      case hostel:
        return Icons.hotel_outlined;
      case mess:
        return Icons.restaurant_outlined;
      case laboratory:
        return Icons.biotech_outlined;
      case examination:
        return Icons.assignment_turned_in_outlined;
      case library:
        return Icons.menu_book_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}

class InvoiceStatus {
  static const String pending = 'pending';
  static const String partial = 'partial';
  static const String paid = 'paid';
  static const String overdue = 'overdue';

  static const List<String> all = [pending, partial, paid, overdue];

  static String displayName(String status) {
    switch (status.trim().toLowerCase()) {
      case pending:
        return 'Pending';
      case partial:
        return 'Partial Paid';
      case paid:
        return 'Settled (Paid)';
      case overdue:
        return 'Overdue';
      default:
        return status.toUpperCase();
    }
  }

  static Color colorFor(String status) {
    switch (status.trim().toLowerCase()) {
      case paid:
        return const Color(0xFF10B981);
      case partial:
        return const Color(0xFF3B82F6);
      case pending:
        return const Color(0xFFF59E0B);
      case overdue:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class FineCategory {
  static const String library = 'library';
  static const String disciplinary = 'disciplinary';
  static const String hostelDamage = 'hostel_damage';
  static const String lateRegistration = 'late_registration';
  static const String laboratory = 'laboratory';

  static const List<String> all = [
    library,
    disciplinary,
    hostelDamage,
    lateRegistration,
    laboratory,
  ];

  static String displayName(String category) {
    switch (category.trim().toLowerCase()) {
      case library:
        return 'Library Overdue';
      case disciplinary:
        return 'Disciplinary & Conduct';
      case hostelDamage:
        return 'Hostel Property Damage';
      case lateRegistration:
        return 'Late Registration';
      case laboratory:
        return 'Lab Breakage & Apparatus';
      default:
        return category.toUpperCase();
    }
  }

  static IconData iconFor(String category) {
    switch (category.trim().toLowerCase()) {
      case library:
        return Icons.local_library_outlined;
      case disciplinary:
        return Icons.gavel_outlined;
      case hostelDamage:
        return Icons.home_repair_service_outlined;
      case lateRegistration:
        return Icons.schedule_outlined;
      case laboratory:
        return Icons.science_outlined;
      default:
        return Icons.warning_amber_outlined;
    }
  }
}

class FineStatus {
  static const String unpaid = 'unpaid';
  static const String paid = 'paid';
  static const String waived = 'waived';
  static const String appealed = 'appealed';

  static const List<String> all = [unpaid, paid, waived, appealed];

  static String displayName(String status) {
    switch (status.trim().toLowerCase()) {
      case unpaid:
        return 'Unpaid Fine';
      case paid:
        return 'Paid';
      case waived:
        return 'Waived by Authority';
      case appealed:
        return 'Appeal Under Review';
      default:
        return status.toUpperCase();
    }
  }

  static Color colorFor(String status) {
    switch (status.trim().toLowerCase()) {
      case paid:
        return const Color(0xFF10B981);
      case unpaid:
        return const Color(0xFFEF4444);
      case appealed:
        return const Color(0xFFF59E0B);
      case waived:
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class FeeHeadModel {
  final String headName;
  final double amount;

  const FeeHeadModel({
    required this.headName,
    required this.amount,
  });

  factory FeeHeadModel.fromJson(Map<String, dynamic> json) {
    return FeeHeadModel(
      headName: json['head_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'head_name': headName,
      'amount': amount,
    };
  }
}

class FeeInvoiceModel {
  final String id;
  final String studentId;
  final String studentName;
  final String campusHandle;
  final String academicYear;
  final int semesterNumber;
  final String feeType;
  final String title;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;
  final DateTime dueDate;
  final String status;
  final List<FeeHeadModel> breakdown;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeeInvoiceModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.campusHandle,
    required this.academicYear,
    required this.semesterNumber,
    required this.feeType,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.dueAmount,
    required this.dueDate,
    required this.status,
    this.breakdown = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPaid => status == InvoiceStatus.paid || dueAmount <= 0.0;
  bool get isPartial => status == InvoiceStatus.partial;
  bool get isPending => status == InvoiceStatus.pending;
  bool get isOverdue =>
      status == InvoiceStatus.overdue ||
      (!isPaid && dueDate.isBefore(DateTime.now()));

  factory FeeInvoiceModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['breakdown'] as List<dynamic>? ?? [];
    List<FeeHeadModel> heads = rawList
        .map((e) => FeeHeadModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return FeeInvoiceModel(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      campusHandle: json['campus_handle'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
      semesterNumber: json['semester_number'] as int? ?? 1,
      feeType: json['fee_type'] as String? ?? FeeType.tuition,
      title: json['title'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      dueAmount: (json['due_amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? InvoiceStatus.pending,
      breakdown: heads,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'campus_handle': campusHandle,
      'academic_year': academicYear,
      'semester_number': semesterNumber,
      'fee_type': feeType,
      'title': title,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'due_amount': dueAmount,
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'breakdown': breakdown.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FeeInvoiceModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? campusHandle,
    String? academicYear,
    int? semesterNumber,
    String? feeType,
    String? title,
    double? totalAmount,
    double? paidAmount,
    double? dueAmount,
    DateTime? dueDate,
    String? status,
    List<FeeHeadModel>? breakdown,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeeInvoiceModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      campusHandle: campusHandle ?? this.campusHandle,
      academicYear: academicYear ?? this.academicYear,
      semesterNumber: semesterNumber ?? this.semesterNumber,
      feeType: feeType ?? this.feeType,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      dueAmount: dueAmount ?? this.dueAmount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      breakdown: breakdown ?? this.breakdown,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FineRecordModel {
  final String id;
  final String studentId;
  final String studentName;
  final String campusHandle;
  final String category;
  final String reason;
  final double amount;
  final DateTime issuedAt;
  final DateTime dueDate;
  final String status;
  final String? appealReason;
  final String? waivedBy;
  final DateTime? paidAt;
  final String? receiptId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FineRecordModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.campusHandle,
    required this.category,
    required this.reason,
    required this.amount,
    required this.issuedAt,
    required this.dueDate,
    required this.status,
    this.appealReason,
    this.waivedBy,
    this.paidAt,
    this.receiptId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUnpaid => status == FineStatus.unpaid;
  bool get isPaid => status == FineStatus.paid;
  bool get isAppealed => status == FineStatus.appealed;
  bool get isWaived => status == FineStatus.waived;

  factory FineRecordModel.fromJson(Map<String, dynamic> json) {
    return FineRecordModel(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      campusHandle: json['campus_handle'] as String? ?? '',
      category: json['category'] as String? ?? FineCategory.library,
      reason: json['reason'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      issuedAt: json['issued_at'] != null
          ? DateTime.tryParse(json['issued_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? FineStatus.unpaid,
      appealReason: json['appeal_reason'] as String?,
      waivedBy: json['waived_by'] as String?,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : null,
      receiptId: json['receipt_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'campus_handle': campusHandle,
      'category': category,
      'reason': reason,
      'amount': amount,
      'issued_at': issuedAt.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'appeal_reason': appealReason,
      'waived_by': waivedBy,
      'paid_at': paidAt?.toIso8601String(),
      'receipt_id': receiptId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FineRecordModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? campusHandle,
    String? category,
    String? reason,
    double? amount,
    DateTime? issuedAt,
    DateTime? dueDate,
    String? status,
    String? appealReason,
    String? waivedBy,
    DateTime? paidAt,
    String? receiptId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FineRecordModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      campusHandle: campusHandle ?? this.campusHandle,
      category: category ?? this.category,
      reason: reason ?? this.reason,
      amount: amount ?? this.amount,
      issuedAt: issuedAt ?? this.issuedAt,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      appealReason: appealReason ?? this.appealReason,
      waivedBy: waivedBy ?? this.waivedBy,
      paidAt: paidAt ?? this.paidAt,
      receiptId: receiptId ?? this.receiptId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FeePaymentModel {
  final String id;
  final String? invoiceId;
  final String? fineId;
  final String studentId;
  final String studentName;
  final double amount;
  final String paymentMethod;
  final String transactionRef;
  final String paymentStatus;
  final DateTime paidAt;
  final String receiptNumber;

  const FeePaymentModel({
    required this.id,
    this.invoiceId,
    this.fineId,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.paymentMethod,
    required this.transactionRef,
    required this.paymentStatus,
    required this.paidAt,
    required this.receiptNumber,
  });

  factory FeePaymentModel.fromJson(Map<String, dynamic> json) {
    return FeePaymentModel(
      id: json['id'] as String? ?? '',
      invoiceId: json['invoice_id'] as String?,
      fineId: json['fine_id'] as String?,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'upi',
      transactionRef: json['transaction_ref'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? 'success',
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      receiptNumber: json['receipt_number'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'fine_id': fineId,
      'student_id': studentId,
      'student_name': studentName,
      'amount': amount,
      'payment_method': paymentMethod,
      'transaction_ref': transactionRef,
      'payment_status': paymentStatus,
      'paid_at': paidAt.toIso8601String(),
      'receipt_number': receiptNumber,
    };
  }
}

class FeeReceiptModel {
  final String receiptNumber;
  final String paymentId;
  final String? invoiceId;
  final String? fineId;
  final String studentId;
  final String studentName;
  final String campusHandle;
  final double amount;
  final String paymentMethod;
  final String transactionRef;
  final DateTime issuedAt;
  final String title;
  final String category;

  const FeeReceiptModel({
    required this.receiptNumber,
    required this.paymentId,
    this.invoiceId,
    this.fineId,
    required this.studentId,
    required this.studentName,
    required this.campusHandle,
    required this.amount,
    required this.paymentMethod,
    required this.transactionRef,
    required this.issuedAt,
    required this.title,
    required this.category,
  });

  factory FeeReceiptModel.fromJson(Map<String, dynamic> json) {
    return FeeReceiptModel(
      receiptNumber: json['receipt_number'] as String? ?? '',
      paymentId: json['payment_id'] as String? ?? '',
      invoiceId: json['invoice_id'] as String?,
      fineId: json['fine_id'] as String?,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      campusHandle: json['campus_handle'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'upi',
      transactionRef: json['transaction_ref'] as String? ?? '',
      issuedAt: json['issued_at'] != null
          ? DateTime.tryParse(json['issued_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      title: json['title'] as String? ?? 'Institutional Fee Receipt',
      category: json['category'] as String? ?? 'fee',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receipt_number': receiptNumber,
      'payment_id': paymentId,
      'invoice_id': invoiceId,
      'fine_id': fineId,
      'student_id': studentId,
      'student_name': studentName,
      'campus_handle': campusHandle,
      'amount': amount,
      'payment_method': paymentMethod,
      'transaction_ref': transactionRef,
      'issued_at': issuedAt.toIso8601String(),
      'title': title,
      'category': category,
    };
  }
}

class FeeSummaryModel {
  final double totalDues;
  final double totalPaid;
  final double pendingFines;
  final DateTime? nextDueDate;
  final int overdueInvoices;
  final int activeFinesCount;

  const FeeSummaryModel({
    required this.totalDues,
    required this.totalPaid,
    required this.pendingFines,
    this.nextDueDate,
    required this.overdueInvoices,
    required this.activeFinesCount,
  });

  factory FeeSummaryModel.fromJson(Map<String, dynamic> json) {
    return FeeSummaryModel(
      totalDues: (json['total_dues'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0.0,
      pendingFines: (json['pending_fines'] as num?)?.toDouble() ?? 0.0,
      nextDueDate: json['next_due_date'] != null
          ? DateTime.tryParse(json['next_due_date'].toString())
          : null,
      overdueInvoices: json['overdue_invoices'] as int? ?? 0,
      activeFinesCount: json['active_fines_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_dues': totalDues,
      'total_paid': totalPaid,
      'pending_fines': pendingFines,
      'next_due_date': nextDueDate?.toIso8601String(),
      'overdue_invoices': overdueInvoices,
      'active_fines_count': activeFinesCount,
    };
  }
}
