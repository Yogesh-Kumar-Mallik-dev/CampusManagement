import 'package:flutter/material.dart';

/// Borrow status enumeration matching backend service
class BorrowStatus {
  static const String pendingApproval = 'pending_approval';
  static const String pendingRenewal = 'pending_renewal';
  static const String pendingReturn = 'pending_return';
  static const String active = 'active';
  static const String overdue = 'overdue';
  static const String returned = 'returned';
  static const String rejected = 'rejected';

  static const List<String> all = [pendingApproval, pendingRenewal, pendingReturn, active, overdue, returned, rejected];

  static String displayName(String status) {
    switch (status.trim().toLowerCase()) {
      case pendingApproval:
        return 'Pending Approval';
      case pendingRenewal:
        return 'Pending Renewal';
      case pendingReturn:
        return 'Pending Return';
      case active:
        return 'Active Loan';
      case overdue:
        return 'Overdue';
      case returned:
        return 'Returned';
      case rejected:
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  static Color statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case pendingApproval:
        return const Color(0xFFD97706); // Amber
      case pendingRenewal:
        return const Color(0xFFF59E0B); // Amber / Orange
      case pendingReturn:
        return const Color(0xFF6366F1); // Indigo
      case active:
        return const Color(0xFF2563EB); // Royal Blue
      case overdue:
        return const Color(0xFFDC2626); // Crimson Red
      case returned:
        return const Color(0xFF16A34A); // Emerald Green
      case rejected:
        return const Color(0xFF6B7280); // Neutral Grey
      default:
        return const Color(0xFF6B7280);
    }
  }
}

/// Book categories for catalog organization
class BookCategory {
  static const String all = 'All Categories';
  static const String cse = 'Computer Science';
  static const String ai = 'Artificial Intelligence';
  static const String ece = 'Electronics';
  static const String math = 'Mathematics';
  static const String mgmt = 'Management';

  static const List<String> catalogCategories = [
    all,
    cse,
    ai,
    ece,
    math,
    mgmt,
  ];
}

/// Represents a physical book asset in the campus library
class PhysicalBookModel {
  final String id;
  final String isbn;
  final String title;
  final String author;
  final String publisher;
  final String edition;
  final String category;
  final String departmentId;
  final int totalCopies;
  final int availableCopies;
  final String shelfLocation;
  final double replacementCost;
  final DateTime createdAt;
  final DateTime updatedAt;

  PhysicalBookModel({
    required this.id,
    required this.isbn,
    required this.title,
    required this.author,
    required this.publisher,
    required this.edition,
    required this.category,
    required this.departmentId,
    required this.totalCopies,
    required this.availableCopies,
    required this.shelfLocation,
    required this.replacementCost,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isAvailable => availableCopies > 0;
  bool get isOutOfStock => availableCopies <= 0;
  bool get isLowStock => availableCopies > 0 && availableCopies <= 2;
  int get copiesBorrowed => (totalCopies - availableCopies).clamp(0, totalCopies);

  factory PhysicalBookModel.fromJson(Map<String, dynamic> json) {
    return PhysicalBookModel(
      id: json['id'] as String? ?? '',
      isbn: json['isbn'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      publisher: json['publisher'] as String? ?? '',
      edition: json['edition'] as String? ?? '',
      category: json['category'] as String? ?? '',
      departmentId: json['department_id'] as String? ?? '',
      totalCopies: (json['total_copies'] as num?)?.toInt() ?? 0,
      availableCopies: (json['available_copies'] as num?)?.toInt() ?? 0,
      shelfLocation: json['shelf_location'] as String? ?? '',
      replacementCost: (json['replacement_cost'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isbn': isbn,
      'title': title,
      'author': author,
      'publisher': publisher,
      'edition': edition,
      'category': category,
      'department_id': departmentId,
      'total_copies': totalCopies,
      'available_copies': availableCopies,
      'shelf_location': shelfLocation,
      'replacement_cost': replacementCost,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PhysicalBookModel copyWith({
    String? id,
    String? isbn,
    String? title,
    String? author,
    String? publisher,
    String? edition,
    String? category,
    String? departmentId,
    int? totalCopies,
    int? availableCopies,
    String? shelfLocation,
    double? replacementCost,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhysicalBookModel(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      edition: edition ?? this.edition,
      category: category ?? this.category,
      departmentId: departmentId ?? this.departmentId,
      totalCopies: totalCopies ?? this.totalCopies,
      availableCopies: availableCopies ?? this.availableCopies,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      replacementCost: replacementCost ?? this.replacementCost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents an institutional physical loan transaction
class BorrowRecordModel {
  final String id;
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String bookIsbn;
  final String shelfLocation;
  final String studentId;
  final String studentName;
  final String campusHandle;
  final DateTime borrowedAt;
  final DateTime dueDate;
  final DateTime? returnedAt;
  final String status;
  final int renewalCount;
  final int maxRenewals;
  final double finePerDay;
  final double accruedLateFine;
  final String? finePortalFeeId;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? renewalApprovedBy;
  final String? renewalApprovedByName;
  final DateTime? renewalApprovedAt;
  final String? renewalRejectionReason;
  final String? returnApprovedBy;
  final String? returnApprovedByName;
  final DateTime? returnApprovedAt;
  final String? returnRejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  BorrowRecordModel({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.bookIsbn,
    required this.shelfLocation,
    required this.studentId,
    required this.studentName,
    required this.campusHandle,
    required this.borrowedAt,
    required this.dueDate,
    this.returnedAt,
    required this.status,
    this.renewalCount = 0,
    this.maxRenewals = 2,
    this.finePerDay = 10.0,
    this.accruedLateFine = 0.0,
    this.finePortalFeeId,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    this.renewalApprovedBy,
    this.renewalApprovedByName,
    this.renewalApprovedAt,
    this.renewalRejectionReason,
    this.returnApprovedBy,
    this.returnApprovedByName,
    this.returnApprovedAt,
    this.returnRejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isActive => status == BorrowStatus.active;
  bool get isPendingApproval => status == BorrowStatus.pendingApproval;
  bool get isPendingRenewal => status == BorrowStatus.pendingRenewal;
  bool get isPendingReturn => status == BorrowStatus.pendingReturn;
  bool get isRejected => status == BorrowStatus.rejected;
  bool get isOverdue => status == BorrowStatus.overdue || (returnedAt == null && status != BorrowStatus.pendingApproval && status != BorrowStatus.rejected && DateTime.now().isAfter(dueDate));
  bool get isReturned => status == BorrowStatus.returned || returnedAt != null;
  bool get canRenew => isActive && !isOverdue && renewalCount < maxRenewals && !isPendingApproval && !isPendingRenewal && !isPendingReturn;
  bool get hasLateFine => accruedLateFine > 0.0;

  int get daysUntilDue {
    final diff = dueDate.difference(DateTime.now()).inDays;
    return diff;
  }

  int get overdueDaysCount {
    if (!isOverdue) return 0;
    final compareDate = returnedAt ?? DateTime.now();
    final diff = compareDate.difference(dueDate).inDays;
    return diff > 0 ? diff : 1;
  }

  factory BorrowRecordModel.fromJson(Map<String, dynamic> json) {
    return BorrowRecordModel(
      id: json['id'] as String? ?? '',
      bookId: json['book_id'] as String? ?? '',
      bookTitle: json['book_title'] as String? ?? '',
      bookAuthor: json['book_author'] as String? ?? '',
      bookIsbn: json['book_isbn'] as String? ?? '',
      shelfLocation: json['shelf_location'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      campusHandle: json['campus_handle'] as String? ?? '',
      borrowedAt: json['borrowed_at'] != null ? DateTime.parse(json['borrowed_at'] as String) : DateTime.now(),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : DateTime.now(),
      returnedAt: json['returned_at'] != null ? DateTime.parse(json['returned_at'] as String) : null,
      status: json['status'] as String? ?? BorrowStatus.active,
      renewalCount: (json['renewal_count'] as num?)?.toInt() ?? 0,
      maxRenewals: (json['max_renewals'] as num?)?.toInt() ?? 2,
      finePerDay: (json['fine_per_day'] as num?)?.toDouble() ?? 10.0,
      accruedLateFine: (json['accrued_late_fine'] as num?)?.toDouble() ?? 0.0,
      finePortalFeeId: json['fine_portal_fee_id'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedByName: json['approved_by_name'] as String?,
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      rejectionReason: json['rejection_reason'] as String?,
      renewalApprovedBy: json['renewal_approved_by'] as String?,
      renewalApprovedByName: json['renewal_approved_by_name'] as String?,
      renewalApprovedAt: json['renewal_approved_at'] != null ? DateTime.parse(json['renewal_approved_at'] as String) : null,
      renewalRejectionReason: json['renewal_rejection_reason'] as String?,
      returnApprovedBy: json['return_approved_by'] as String?,
      returnApprovedByName: json['return_approved_by_name'] as String?,
      returnApprovedAt: json['return_approved_at'] != null ? DateTime.parse(json['return_approved_at'] as String) : null,
      returnRejectionReason: json['return_rejection_reason'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'book_title': bookTitle,
      'book_author': bookAuthor,
      'book_isbn': bookIsbn,
      'shelf_location': shelfLocation,
      'student_id': studentId,
      'student_name': studentName,
      'campus_handle': campusHandle,
      'borrowed_at': borrowedAt.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'returned_at': returnedAt?.toIso8601String(),
      'status': status,
      'renewal_count': renewalCount,
      'max_renewals': maxRenewals,
      'fine_per_day': finePerDay,
      'accrued_late_fine': accruedLateFine,
      'fine_portal_fee_id': finePortalFeeId,
      'approved_by': approvedBy,
      'approved_by_name': approvedByName,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'renewal_approved_by': renewalApprovedBy,
      'renewal_approved_by_name': renewalApprovedByName,
      'renewal_approved_at': renewalApprovedAt?.toIso8601String(),
      'renewal_rejection_reason': renewalRejectionReason,
      'return_approved_by': returnApprovedBy,
      'return_approved_by_name': returnApprovedByName,
      'return_approved_at': returnApprovedAt?.toIso8601String(),
      'return_rejection_reason': returnRejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BorrowRecordModel copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    String? bookAuthor,
    String? bookIsbn,
    String? shelfLocation,
    String? studentId,
    String? studentName,
    String? campusHandle,
    DateTime? borrowedAt,
    DateTime? dueDate,
    DateTime? returnedAt,
    String? status,
    int? renewalCount,
    int? maxRenewals,
    double? finePerDay,
    double? accruedLateFine,
    String? finePortalFeeId,
    String? approvedBy,
    String? approvedByName,
    DateTime? approvedAt,
    String? rejectionReason,
    String? renewalApprovedBy,
    String? renewalApprovedByName,
    DateTime? renewalApprovedAt,
    String? renewalRejectionReason,
    String? returnApprovedBy,
    String? returnApprovedByName,
    DateTime? returnApprovedAt,
    String? returnRejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BorrowRecordModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      bookIsbn: bookIsbn ?? this.bookIsbn,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      campusHandle: campusHandle ?? this.campusHandle,
      borrowedAt: borrowedAt ?? this.borrowedAt,
      dueDate: dueDate ?? this.dueDate,
      returnedAt: returnedAt ?? this.returnedAt,
      status: status ?? this.status,
      renewalCount: renewalCount ?? this.renewalCount,
      maxRenewals: maxRenewals ?? this.maxRenewals,
      finePerDay: finePerDay ?? this.finePerDay,
      accruedLateFine: accruedLateFine ?? this.accruedLateFine,
      finePortalFeeId: finePortalFeeId ?? this.finePortalFeeId,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      renewalApprovedBy: renewalApprovedBy ?? this.renewalApprovedBy,
      renewalApprovedByName: renewalApprovedByName ?? this.renewalApprovedByName,
      renewalApprovedAt: renewalApprovedAt ?? this.renewalApprovedAt,
      renewalRejectionReason: renewalRejectionReason ?? this.renewalRejectionReason,
      returnApprovedBy: returnApprovedBy ?? this.returnApprovedBy,
      returnApprovedByName: returnApprovedByName ?? this.returnApprovedByName,
      returnApprovedAt: returnApprovedAt ?? this.returnApprovedAt,
      returnRejectionReason: returnRejectionReason ?? this.returnRejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents an institutional digital e-book with infinite concurrent borrowing
class EBookModel {
  final String id;
  final String title;
  final String author;
  final String category;
  final String publisher;
  final String format; // PDF, EPUB
  final String fileSize;
  final int totalReaders;
  final String downloadUrl;
  final String readUrl;
  final bool isInfiniteBorrow;
  final String description;
  final List<int> requiredSemesters;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  EBookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.publisher,
    required this.format,
    required this.fileSize,
    this.totalReaders = 0,
    required this.downloadUrl,
    required this.readUrl,
    this.isInfiniteBorrow = true,
    required this.description,
    this.requiredSemesters = const [],
    this.tags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isPdf => format.toUpperCase() == 'PDF';
  bool get isEpub => format.toUpperCase() == 'EPUB';

  factory EBookModel.fromJson(Map<String, dynamic> json) {
    return EBookModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      category: json['category'] as String? ?? '',
      publisher: json['publisher'] as String? ?? '',
      format: json['format'] as String? ?? 'PDF',
      fileSize: json['file_size'] as String? ?? '',
      totalReaders: (json['total_readers'] as num?)?.toInt() ?? 0,
      downloadUrl: json['download_url'] as String? ?? '',
      readUrl: json['read_url'] as String? ?? '',
      isInfiniteBorrow: json['is_infinite_borrow'] as bool? ?? true,
      description: json['description'] as String? ?? '',
      requiredSemesters: (json['required_semesters'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'category': category,
      'publisher': publisher,
      'format': format,
      'file_size': fileSize,
      'total_readers': totalReaders,
      'download_url': downloadUrl,
      'read_url': readUrl,
      'is_infinite_borrow': isInfiniteBorrow,
      'description': description,
      'required_semesters': requiredSemesters,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EBookModel copyWith({
    String? id,
    String? title,
    String? author,
    String? category,
    String? publisher,
    String? format,
    String? fileSize,
    int? totalReaders,
    String? downloadUrl,
    String? readUrl,
    bool? isInfiniteBorrow,
    String? description,
    List<int>? requiredSemesters,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EBookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      category: category ?? this.category,
      publisher: publisher ?? this.publisher,
      format: format ?? this.format,
      fileSize: fileSize ?? this.fileSize,
      totalReaders: totalReaders ?? this.totalReaders,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      readUrl: readUrl ?? this.readUrl,
      isInfiniteBorrow: isInfiniteBorrow ?? this.isInfiniteBorrow,
      description: description ?? this.description,
      requiredSemesters: requiredSemesters ?? this.requiredSemesters,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Student library profile metrics
class LibrarySummaryModel {
  final String studentId;
  final int maxBorrowQuota;
  final int activeBorrowsCount;
  final int overdueBorrowsCount;
  final int availableQuota;
  final double totalLateFineDue;
  final int returnedHistoryCount;
  final int ebooksAccessedCount;

  LibrarySummaryModel({
    required this.studentId,
    this.maxBorrowQuota = 4,
    this.activeBorrowsCount = 0,
    this.overdueBorrowsCount = 0,
    this.availableQuota = 4,
    this.totalLateFineDue = 0.0,
    this.returnedHistoryCount = 0,
    this.ebooksAccessedCount = 0,
  });

  bool get hasOverdue => overdueBorrowsCount > 0;
  bool get canBorrowMore => availableQuota > 0 && overdueBorrowsCount == 0;
  double get quotaUsageRatio => maxBorrowQuota > 0 ? activeBorrowsCount / maxBorrowQuota : 0.0;

  factory LibrarySummaryModel.fromJson(Map<String, dynamic> json) {
    return LibrarySummaryModel(
      studentId: json['student_id'] as String? ?? '',
      maxBorrowQuota: (json['max_borrow_quota'] as num?)?.toInt() ?? 4,
      activeBorrowsCount: (json['active_borrows_count'] as num?)?.toInt() ?? 0,
      overdueBorrowsCount: (json['overdue_borrows_count'] as num?)?.toInt() ?? 0,
      availableQuota: (json['available_quota'] as num?)?.toInt() ?? 4,
      totalLateFineDue: (json['total_late_fine_due'] as num?)?.toDouble() ?? 0.0,
      returnedHistoryCount: (json['returned_history_count'] as num?)?.toInt() ?? 0,
      ebooksAccessedCount: (json['ebooks_accessed_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'max_borrow_quota': maxBorrowQuota,
      'active_borrows_count': activeBorrowsCount,
      'overdue_borrows_count': overdueBorrowsCount,
      'available_quota': availableQuota,
      'total_late_fine_due': totalLateFineDue,
      'returned_history_count': returnedHistoryCount,
      'ebooks_accessed_count': ebooksAccessedCount,
    };
  }

  LibrarySummaryModel copyWith({
    String? studentId,
    int? maxBorrowQuota,
    int? activeBorrowsCount,
    int? overdueBorrowsCount,
    int? availableQuota,
    double? totalLateFineDue,
    int? returnedHistoryCount,
    int? ebooksAccessedCount,
  }) {
    return LibrarySummaryModel(
      studentId: studentId ?? this.studentId,
      maxBorrowQuota: maxBorrowQuota ?? this.maxBorrowQuota,
      activeBorrowsCount: activeBorrowsCount ?? this.activeBorrowsCount,
      overdueBorrowsCount: overdueBorrowsCount ?? this.overdueBorrowsCount,
      availableQuota: availableQuota ?? this.availableQuota,
      totalLateFineDue: totalLateFineDue ?? this.totalLateFineDue,
      returnedHistoryCount: returnedHistoryCount ?? this.returnedHistoryCount,
      ebooksAccessedCount: ebooksAccessedCount ?? this.ebooksAccessedCount,
    );
  }
}
