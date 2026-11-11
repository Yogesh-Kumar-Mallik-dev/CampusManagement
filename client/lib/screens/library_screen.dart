import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../di/service_locator.dart';
import '../facade/campus_facade.dart';
import '../models/library.dart';
import '../models/user.dart';
import '../services/app_cache.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../utils/pdf_picker.dart';
import '../utils/file_downloader.dart';
import '../utils/app_error_catalog.dart';
import '../widgets/app_dropdown.dart';

class LibraryScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;
  final ICampusFacade? facade;
  final void Function(int)? onNavigateToTab;
  final int? initialTabIndex;
  final bool restoreCachedTab;

  const LibraryScreen({
    super.key,
    required this.storage,
    this.currentUser,
    this.facade,
    this.onNavigateToTab,
    this.initialTabIndex,
    this.restoreCachedTab = false,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final dateFmt = DateFormat('dd MMM yyyy');
  final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  bool _isLoading = true;
  String? _errorMessage;

  LibrarySummaryModel? _summary;
  List<BorrowRecordModel> _borrows = [];
  List<PhysicalBookModel> _books = [];
  List<EBookModel> _ebooks = [];
  List<BorrowRecordModel> _pendingApprovals = [];
  List<EBookModel> _pendingPdfBooks = [];

  String _borrowStatusFilter = 'all';
  String _bookCategoryFilter = 'All Categories';
  String _bookSearchQuery = '';
  String _ebookCategoryFilter = 'All Categories';
  String _ebookSearchQuery = '';

  ICampusFacade get _facade {
    if (widget.facade != null) return widget.facade!;
    if (CampusDI.instance.isRegistered<ICampusFacade>()) {
      return CampusDI.instance.get<ICampusFacade>();
    }
    return CampusFacade(storage: widget.storage, api: widget.storage.api);
  }

  bool get _canManageLibrary {
    if (widget.currentUser != null) {
      return widget.currentUser!.canManageLibrary;
    }
    return false;
  }

  String get _currentStudentId {
    if (widget.currentUser != null && widget.currentUser!.id.isNotEmpty) {
      final arch = widget.currentUser!.archetype.toLowerCase();
      if (arch == 'admin' || arch == 'faculty' || arch == 'staff') {
        return 'usr-harish_2025_l_btech_1';
      }
      return widget.currentUser!.id;
    }
    return 'usr-harish_2025_l_btech_1';
  }

  @override
  void initState() {
    super.initState();
    final totalLength = _canManageLibrary ? 5 : 4;
    int initialIndex = widget.initialTabIndex ?? 0;
    if (widget.initialTabIndex == null && widget.restoreCachedTab) {
      final cached = AppCache.instance.getLastLibraryTab(userHandle: widget.currentUser?.campusHandle);
      if (cached != null && cached >= 0 && cached < totalLength) {
        initialIndex = cached;
      }
    }
    _tabController = TabController(
      length: totalLength,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        AppCache.instance.setLastLibraryTab(_tabController.index, userHandle: widget.currentUser?.campusHandle);
      }
    });
    _loadLibraryData();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLength = oldWidget.currentUser?.canManageLibrary == true ? 5 : 4;
    final newLength = _canManageLibrary ? 5 : 4;
    if (oldLength != newLength) {
      _tabController.dispose();
      _tabController = TabController(length: newLength, vsync: this);
      _loadLibraryData();
    } else if (oldWidget.currentUser?.id != widget.currentUser?.id) {
      _loadLibraryData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _downloadEBookPdf(EBookModel ebook) async {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloading '${ebook.title}' (${ebook.fileSize})..."),
          backgroundColor: AppColors.wineRed,
          duration: const Duration(seconds: 2),
        ),
      );

      final bytes = await _facade.downloadEBookPdf(ebook.id);
      final filename = '${ebook.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_').trim()}.pdf';
      final saved = await triggerPdfDownload(filename: filename, bytes: bytes);

      if (mounted && saved) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Downloading completed: '$filename' (${bytes.length} bytes). Opened in File Manager."),
            backgroundColor: AppColors.githubGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Download failed: $e"),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    }
  }

  Future<void> _loadLibraryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final studentId = _currentStudentId;
      final summary = await _facade.getLibrarySummary(studentId);
      final borrows = await _facade.getBorrowRecords(studentId: studentId);
      final books = await _facade.getPhysicalBooks();
      final ebooks = await _facade.getEBooks();
      List<BorrowRecordModel> pendingApprovals = [];
      List<EBookModel> pendingPdfBooks = [];
      if (_canManageLibrary) {
        final allBorrows = await _facade.getBorrowRecords();
        pendingApprovals = allBorrows
            .where((r) => r.isPendingApproval || r.isPendingRenewal || r.isPendingReturn)
            .toList();
        pendingPdfBooks = ebooks.where((e) => e.isPendingApproval).toList();
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _borrows = borrows;
          _books = books;
          _ebooks = ebooks;
          _pendingApprovals = pendingApprovals;
          _pendingPdfBooks = pendingPdfBooks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleBorrowBook(PhysicalBookModel book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Confirm Book Checkout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Author: ${book.author}',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Shelf Location: ${book.shelfLocation}',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                'Available Copies: ${book.availableCopies} of ${book.totalCopies}',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const Divider(height: 24),
              Text(
                'Standard Loan Policy:\n• Loan duration: 14 calendar days\n• Up to 2 renewals allowed\n• Late fine rate: ₹10/day\n• Approval Rule: Physical loan requires Library In-Charge authorization before pickup at circulation counter.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wineRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Checkout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final isLibrarian = widget.currentUser?.canManageLibrary == true;
      final approvedBy = isLibrarian ? widget.currentUser!.id : null;
      final approvedByName = isLibrarian ? widget.currentUser!.fullName : null;

      final newBorrow = await _facade.borrowBook(
        studentId: _currentStudentId,
        bookId: book.id,
        approvedBy: approvedBy,
        approvedByName: approvedByName,
      );

      if (mounted) {
        final message = newBorrow.isPendingApproval
            ? "Successfully borrowed request submitted for '${newBorrow.bookTitle}'. Awaiting approval from Library In-Charge."
            : "Successfully borrowed '${newBorrow.bookTitle}'. Due on ${dateFmt.format(newBorrow.dueDate)}.";
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.githubGreen,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  void _showMildError(Object e, {AppErrorItem defaultError = AppErrorCatalog.systemUnexpected}) {
    if (!mounted) return;
    final err = AppErrorCatalog.resolveException(e, defaultError: defaultError);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err.displayString),
        backgroundColor: AppColors.statusRed,
      ),
    );
  }

  Future<void> _handleApproveBorrow(BorrowRecordModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Approve Borrow Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.bookTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Student: ${record.studentName} (${record.campusHandle})',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                'Shelf Location: ${record.shelfLocation}',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Authorizing this checkout will activate the 14-day loan period starting today and permit physical copy release to the student.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-approve-borrow'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.githubGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve Loan'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final inChargeId = widget.currentUser?.id ?? 'incharge-lib';
      final inChargeName = widget.currentUser?.fullName ?? 'Library In-Charge';
      await _facade.approveBorrowRequest(
        borrowId: record.id,
        approvedBy: inChargeId,
        approvedByName: inChargeName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Borrow request for '${record.bookTitle}' approved successfully. Loan is now active.",
            ),
            backgroundColor: AppColors.githubGreen,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  Future<void> _handleRejectBorrow(BorrowRecordModel record) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Reject Borrow Request'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.bookTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Student: ${record.studentName} (${record.campusHandle})',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('input-rejection-reason'),
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason *',
                    hintText: 'Enter reason for rejecting request',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Rejection reason is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Rejecting this request will restore the physical book copy back to the catalog.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-reject-borrow'),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject Request'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final inChargeId = widget.currentUser?.id ?? 'incharge-lib';
      await _facade.rejectBorrowRequest(
        borrowId: record.id,
        rejectedBy: inChargeId,
        rejectionReason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Borrow request for '${record.bookTitle}' has been rejected. Catalog copy restored.",
            ),
            backgroundColor: AppColors.statusRed,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  Future<void> _handleReturnBook(BorrowRecordModel record) async {
    final isLate = record.isOverdue;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final redBadge = AppColors.redBadge(isDark);
        return AlertDialog(
          title: const Text('Confirm Book Return'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.bookTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Loan Borrowed: ${dateFmt.format(record.borrowedAt)}',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                'Due Date: ${dateFmt.format(record.dueDate)}',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Return Process Notice:\nReturning a physical book requires presenting the copy at the circulation counter for inspection and in-charge sign-off.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              if (isLate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: redBadge.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: redBadge.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Late Return Notice',
                        style: TextStyle(
                          color: redBadge.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This loan is overdue by ${record.overdueDaysCount} days. A late fine of ₹${record.accruedLateFine.toStringAsFixed(2)} will be issued to your Institutional Fine Portal upon acceptance.',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.githubGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Return Copy'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final isLibrarian = widget.currentUser?.canManageLibrary == true;
      final approvedBy = isLibrarian ? widget.currentUser!.id : null;
      final approvedByName = isLibrarian ? widget.currentUser!.fullName : null;

      final res = await _facade.returnBook(
        borrowId: record.id,
        studentId: _currentStudentId,
        approvedBy: approvedBy,
        approvedByName: approvedByName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final message = res.isPendingReturn
            ? "Book '${record.bookTitle}' return request initiated. Book returned successfully pending Library In-Charge counter inspection."
            : "Book '${record.bookTitle}' returned successfully. Physical catalog copy incremented.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.githubGreen,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  Future<void> _handleApproveReturn(BorrowRecordModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Accept Physical Book Return'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.bookTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Student: ${record.studentName} (${record.campusHandle})',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                'Shelf Location: ${record.shelfLocation}',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Confirm counter physical copy inspection. Accepting this return will check in the book, restore available catalog copy count, and sync any late fines.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-approve-return'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.githubGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Accept Return'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final inChargeId = widget.currentUser?.id ?? 'incharge-lib';
      final inChargeName = widget.currentUser?.fullName ?? 'Library In-Charge';
      await _facade.approveReturnRequest(
        borrowId: record.id,
        approvedBy: inChargeId,
        approvedByName: inChargeName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Return for '${record.bookTitle}' verified and accepted. Catalog copy incremented.",
            ),
            backgroundColor: AppColors.githubGreen,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  Future<void> _handleRejectReturn(BorrowRecordModel record) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Reject Book Return'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.bookTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Student: ${record.studentName} (${record.campusHandle})',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('input-return-rejection-reason'),
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason *',
                    hintText: 'e.g., Book damaged, missing pages, wrong copy',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Rejection reason is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-reject-return'),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject Return'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final inChargeId = widget.currentUser?.id ?? 'incharge-lib';
      await _facade.rejectReturnRequest(
        borrowId: record.id,
        rejectedBy: inChargeId,
        rejectionReason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Return request for '${record.bookTitle}' has been rejected.",
            ),
            backgroundColor: AppColors.statusRed,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  Future<void> _handleRenewBook(BorrowRecordModel record) async {
    try {
      final isLibrarian = widget.currentUser?.canManageLibrary == true;
      final approvedBy = isLibrarian ? widget.currentUser!.id : null;
      final approvedByName = isLibrarian ? widget.currentUser!.fullName : null;

      final res = await _facade.renewBook(
        borrowId: record.id,
        studentId: _currentStudentId,
        approvedBy: approvedBy,
        approvedByName: approvedByName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final message = res.isPendingRenewal
            ? "Loan extension request submitted for '${record.bookTitle}'. Loan extended by 14 days subject to Library In-Charge authorization."
            : "Loan extended by 14 days. New due date: ${dateFmt.format(res.dueDate)} (${res.renewalCount}/${res.maxRenewals} renewals used).";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.wineRed,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  Future<void> _handleApproveRenewal(BorrowRecordModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Approve Loan Extension'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.bookTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Student: ${record.studentName} (${record.campusHandle})',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                'Current Due Date: ${dateFmt.format(record.dueDate)}',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                'Renewals: ${record.renewalCount}/${record.maxRenewals}',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Authorizing this extension will extend the due date by 14 calendar days.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-approve-renewal'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.githubGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve Extension'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final inChargeId = widget.currentUser?.id ?? 'incharge-lib';
      final inChargeName = widget.currentUser?.fullName ?? 'Library In-Charge';
      final res = await _facade.approveRenewalRequest(
        borrowId: record.id,
        approvedBy: inChargeId,
        approvedByName: inChargeName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Renewal for '${record.bookTitle}' approved. New due date: ${dateFmt.format(res.dueDate)}.",
            ),
            backgroundColor: AppColors.githubGreen,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  Future<void> _handleRejectRenewal(BorrowRecordModel record) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Reject Loan Extension'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.bookTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Student: ${record.studentName} (${record.campusHandle})',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('input-renewal-rejection-reason'),
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason *',
                    hintText: 'e.g., Book on high hold request, maximum renewals reached',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Rejection reason is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-reject-renewal'),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject Extension'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final inChargeId = widget.currentUser?.id ?? 'incharge-lib';
      await _facade.rejectRenewalRequest(
        borrowId: record.id,
        rejectedBy: inChargeId,
        rejectionReason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Renewal request for '${record.bookTitle}' has been rejected.",
            ),
            backgroundColor: AppColors.statusRed,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  Future<void> _handleRemoveCatalogue(PhysicalBookModel book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          key: const Key('dialog-confirm-remove-book'),
          title: const Text('Remove from Catalog?'),
          content: Text(
            'Are you sure you want to remove "${book.title}" from the institutional physical library catalog? This action will archive the volume.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-remove-book'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove Book'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _facade.deletePhysicalBook(book.id);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Physical book '${book.title}' removed from catalog."),
            backgroundColor: AppColors.githubGreen,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  Future<void> _showAddCatalogDialog() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final isbnController = TextEditingController();
    final publisherController = TextEditingController();
    final editionController = TextEditingController(text: '1st Edition');
    final copiesController = TextEditingController(text: '3');
    final shelfController = TextEditingController(text: 'Rack C-1, 2nd Floor Central Wing');
    final costController = TextEditingController(text: '3500');
    String selectedCategory = BookCategory.cse;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Add Book to Catalog'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const Key('input-catalog-title'),
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Book Title',
                          hintText: 'e.g. Distributed Operating Systems',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('input-catalog-author'),
                        controller: authorController,
                        decoration: const InputDecoration(
                          labelText: 'Author(s)',
                          hintText: 'e.g. Andrew S. Tanenbaum',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('input-catalog-isbn'),
                        controller: isbnController,
                        decoration: const InputDecoration(
                          labelText: 'ISBN',
                          hintText: 'e.g. 978-0132199087',
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppDropdown<String>(
                        key: const Key('dropdown-catalog-category'),
                        value: selectedCategory,
                        items: BookCategory.catalogCategories
                            .where((c) => c != BookCategory.all)
                            .map((c) => AppDropdownItem(value: c, label: c))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedCategory = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('input-catalog-publisher'),
                              controller: publisherController,
                              decoration: const InputDecoration(
                                labelText: 'Publisher',
                                hintText: 'e.g. Pearson',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: const Key('input-catalog-edition'),
                              controller: editionController,
                              decoration: const InputDecoration(
                                labelText: 'Edition',
                                hintText: 'e.g. 2nd Edition',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('input-catalog-copies'),
                              controller: copiesController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Total Copies',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: const Key('input-catalog-cost'),
                              controller: costController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cost (₹)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('input-catalog-shelf'),
                        controller: shelfController,
                        decoration: const InputDecoration(
                          labelText: 'Shelf Location',
                          hintText: 'e.g. Rack B-3, 2nd Floor',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ),
                ElevatedButton(
                  key: const Key('btn-submit-catalog'),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final author = authorController.text.trim();
                    final isbn = isbnController.text.trim();
                    if (title.isEmpty || author.isEmpty || isbn.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill title, author, and ISBN'),
                          backgroundColor: AppColors.statusRed,
                        ),
                      );
                      return;
                    }
                    final copies = int.tryParse(copiesController.text.trim()) ?? 1;
                    final cost = double.tryParse(costController.text.trim()) ?? 3000.0;
                    final newBook = PhysicalBookModel(
                      id: 'bk-${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      author: author,
                      isbn: isbn,
                      category: selectedCategory,
                      publisher: publisherController.text.trim().isNotEmpty
                          ? publisherController.text.trim()
                          : 'Academic Press',
                      edition: editionController.text.trim().isNotEmpty
                          ? editionController.text.trim()
                          : '1st Edition',
                      departmentId: 'dept-cse',
                      totalCopies: copies,
                      availableCopies: copies,
                      shelfLocation: shelfController.text.trim().isNotEmpty
                          ? shelfController.text.trim()
                          : 'Rack C-1, 2nd Floor Central Wing',
                      replacementCost: cost,
                    );

                    Navigator.of(ctx).pop();
                    try {
                      await _facade.createPhysicalBook(newBook);
                      if (mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Book '$title' added to catalog successfully."),
                            backgroundColor: AppColors.githubGreen,
                          ),
                        );
                        await _loadLibraryData();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', '')),
                            backgroundColor: AppColors.statusRed,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.wineRed,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add to Catalog'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddPdfBookDialog() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final publisherController = TextEditingController();
    final descriptionController = TextEditingController();
    final sizeController = TextEditingController(text: '12.4 MB');
    final tagsController = TextEditingController(text: 'Textbook, Reference, Engineering');
    String selectedCategory = BookCategory.cse;
    final isLibrarian = _canManageLibrary;
    PickedPdfFile? pickedPdfFile;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text(isLibrarian ? 'Add PDF E-Book (In-Charge)' : 'Upload PDF E-Book for Approval'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLibrarian
                            ? 'As Library In-Charge, newly added PDF e-books will immediately be published into the institutional digital collection.'
                            : 'Submit a digital PDF textbook to the campus library. Your submission will be reviewed and approved by the Library In-Charge.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Native / Web PDF File Picker Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: pickedPdfFile != null
                                ? AppColors.githubGreen
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: pickedPdfFile != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              pickedPdfFile != null ? Icons.picture_as_pdf : Icons.upload_file,
                              color: pickedPdfFile != null ? AppColors.githubGreen : AppColors.wineRed,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pickedPdfFile != null
                                        ? pickedPdfFile!.name
                                        : 'No PDF file selected yet',
                                    key: const Key('badge-picked-pdf'),
                                    style: TextStyle(
                                      fontWeight: pickedPdfFile != null ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    pickedPdfFile != null
                                        ? '${pickedPdfFile!.formattedSize} • Ready to upload'
                                        : 'Select an authentic PDF document from device',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              key: const Key('btn-pick-pdf-file'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                                foregroundColor: AppColors.wineRed,
                                elevation: 0,
                                side: const BorderSide(color: AppColors.wineRed, width: 1),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              icon: const Icon(Icons.attach_file, size: 14),
                              label: Text(pickedPdfFile == null ? 'Browse...' : 'Change'),
                              onPressed: () async {
                                final picked = await pickPdfFile();
                                if (picked != null) {
                                  setDialogState(() {
                                    pickedPdfFile = picked;
                                    sizeController.text = picked.formattedSize;
                                    if (titleController.text.trim().isEmpty) {
                                      final baseName = picked.name
                                          .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
                                          .replaceAll(RegExp(r'[-_]'), ' ');
                                      titleController.text = baseName;
                                    }
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('input-pdf-title'),
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'E-Book / PDF Title',
                          hintText: 'e.g. Modern Compiler Implementation in C',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('input-pdf-author'),
                        controller: authorController,
                        decoration: const InputDecoration(
                          labelText: 'Author(s)',
                          hintText: 'e.g. Andrew W. Appel',
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppDropdown<String>(
                        key: const Key('dropdown-pdf-category'),
                        value: selectedCategory,
                        items: BookCategory.catalogCategories
                            .where((c) => c != BookCategory.all)
                            .map((c) => AppDropdownItem(value: c, label: c))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedCategory = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('input-pdf-publisher'),
                              controller: publisherController,
                              decoration: const InputDecoration(
                                labelText: 'Publisher / Source',
                                hintText: 'e.g. Cambridge Univ. Press',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: const Key('input-pdf-size'),
                              controller: sizeController,
                              decoration: const InputDecoration(
                                labelText: 'PDF Size',
                                hintText: 'e.g. 14.2 MB',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('input-pdf-tags'),
                        controller: tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          hintText: 'e.g. compilers, c, parsing',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('input-pdf-description'),
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description / Syllabus Scope',
                          hintText: 'Brief summary of the textbook contents...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ),
                ElevatedButton(
                  key: const Key('btn-submit-pdf-book'),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final author = authorController.text.trim();
                    if (title.isEmpty || author.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter book title and author'),
                          backgroundColor: AppColors.statusRed,
                        ),
                      );
                      return;
                    }

                    final now = DateTime.now();
                    final id = 'ebk-${now.millisecondsSinceEpoch}';
                    final tagList = tagsController.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    final navigator = Navigator.of(ctx);
                    String downloadUrl = '/api/v1/library/ebooks/download/$id.pdf';
                    if (pickedPdfFile != null) {
                      try {
                        final uploadRes = await _facade.uploadPdfDocument(
                          bytes: pickedPdfFile!.bytes,
                          filename: pickedPdfFile!.name,
                        );
                        if (uploadRes['url'] != null) {
                          downloadUrl = uploadRes['url'].toString();
                        }
                      } catch (_) {}
                    }

                    final newEbook = EBookModel(
                      id: id,
                      title: title,
                      author: author,
                      category: selectedCategory,
                      publisher: publisherController.text.trim().isNotEmpty
                          ? publisherController.text.trim()
                          : (isLibrarian ? 'Institutional Library' : 'Student Contribution'),
                      format: 'PDF',
                      fileSize: sizeController.text.trim().isNotEmpty
                          ? sizeController.text.trim()
                          : (pickedPdfFile != null ? pickedPdfFile!.formattedSize : '12.5 MB'),
                      downloadUrl: downloadUrl,
                      readUrl: '/library/reader/$id',
                      isInfiniteBorrow: true,
                      description: descriptionController.text.trim().isNotEmpty
                          ? descriptionController.text.trim()
                          : 'Digital PDF reference textbook available for campus scholarship.',
                      tags: tagList.isNotEmpty ? tagList : [selectedCategory, 'PDF'],
                      status: isLibrarian ? EBookStatus.approved : EBookStatus.pendingApproval,
                      submittedBy: _currentStudentId,
                      submittedByName: widget.currentUser?.fullName ?? (isLibrarian ? 'Library In-Charge' : 'Student'),
                      submittedByRole: isLibrarian ? 'in_charge' : 'student',
                      approvedBy: isLibrarian ? widget.currentUser?.id : null,
                      approvedByName: isLibrarian ? widget.currentUser?.fullName : null,
                      approvedAt: isLibrarian ? now : null,
                      createdAt: now,
                      updatedAt: now,
                    );

                    navigator.pop();
                    try {
                      await _facade.createEBook(newEbook);
                      if (mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isLibrarian
                                ? "PDF Book '$title' added to library collection."
                                : "PDF Book '$title' submitted. Awaiting Library In-Charge approval."),
                            backgroundColor: AppColors.githubGreen,
                          ),
                        );
                        await _loadLibraryData();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', '')),
                            backgroundColor: AppColors.statusRed,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.wineRed,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isLibrarian ? 'Add PDF Book' : 'Submit for Approval'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleApprovePdf(EBookModel ebook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Approve PDF E-Book'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ebook.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text('Author: ${ebook.author} • Category: ${ebook.category}'),
              const SizedBox(height: 6),
              Text(
                'Submitted by: ${ebook.submittedByName ?? "Student"} (${ebook.submittedBy ?? "N/A"})',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Approving this PDF will immediately publish it to the Infinite Digital Repository for all campus scholars.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-approve-pdf'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.githubGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve & Publish'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final inChargeId = widget.currentUser?.id ?? 'incharge-lib';
      final inChargeName = widget.currentUser?.fullName ?? 'Library In-Charge';
      await _facade.approveEBook(
        ebookId: ebook.id,
        approvedBy: inChargeId,
        approvedByName: inChargeName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF Book '${ebook.title}' approved and added to active library collection."),
            backgroundColor: AppColors.githubGreen,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  Future<void> _handleRejectPdf(EBookModel ebook) async {
    final reasonController = TextEditingController(text: 'Does not meet institutional curriculum criteria');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Reject PDF Submission'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Provide reason for declining "${ebook.title}":',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-reject-pdf'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Decline Submission'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final inChargeId = widget.currentUser?.id ?? 'incharge-lib';
      await _facade.rejectEBook(
        ebookId: ebook.id,
        rejectedBy: inChargeId,
        rejectionReason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF Book submission for '${ebook.title}' declined."),
            backgroundColor: AppColors.statusRed,
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      _showMildError(e, defaultError: AppErrorCatalog.libBookUnavailable);
    }
  }

  void _showEBookReader(EBookModel ebook) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.wineRedDark : AppColors.wineRedSubtle),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppSvgIcon(
                        svgString: AppSvgIcon.book,
                        size: 22,
                        color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ebook.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${ebook.author} • ${ebook.format} (${ebook.fileSize})',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              // Reader Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBg : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.all_inclusive, color: AppColors.githubGreen, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Infinite Concurrent Institutional License',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Text(
                                  'Unlimited concurrent readers • No loan expiration • Institutional copy',
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Overview & Abstract',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ebook.description,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Table of Contents (Institutional Digital Edition)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(5, (index) {
                      final chapters = [
                        'Chapter 1: Foundations and Theoretical Principles',
                        'Chapter 2: Structural Architecture and Design Patterns',
                        'Chapter 3: Algorithmic Implementation and Scaling',
                        'Chapter 4: Empirical Evaluation and Case Studies',
                        'Chapter 5: Advanced Industry Systems and Best Practices',
                      ];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                chapters[index],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            Text(
                              'p. ${(index + 1) * 35}',
                              style: TextStyle(
                                color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Modal Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Download Offline Copy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                          side: BorderSide(
                            color: isDark ? AppColors.wineRedDarkBorder : AppColors.wineRedBorder,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _downloadEBookPdf(ebook);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chrome_reader_mode_outlined, size: 18),
                        label: const Text('Start Fullscreen Reader'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.githubGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Opening '${ebook.title}' in campus digital reader..."),
                              backgroundColor: AppColors.githubGreen,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Library & Knowledge Portal'),
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        actions: [
          IconButton(
            key: const Key('btn-library-refresh'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Library Catalog',
            onPressed: _loadLibraryData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: (index) => AppCache.instance.setLastLibraryTab(index, userHandle: widget.currentUser?.campusHandle),
          labelColor: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
          unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          indicatorColor: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
          tabs: [
            const Tab(
              key: Key('tab-borrowed-books'),
              text: 'Borrowed Books & Loans',
            ),
            const Tab(
              key: Key('tab-books-catalog'),
              text: 'Physical Catalog',
            ),
            const Tab(
              key: Key('tab-infinite-ebooks'),
              text: 'Infinite E-Books',
            ),
            const Tab(
              key: Key('tab-library-policy'),
              text: 'Policy & Fine Slabs',
            ),
            if (_canManageLibrary)
              const Tab(
                key: Key('tab-borrow-approvals'),
                text: 'Borrow Approvals',
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBorrowedBooksTab(),
                    _buildPhysicalCatalogTab(),
                    _buildInfiniteEBooksTab(),
                    _buildLibraryPolicyTab(),
                    if (_canManageLibrary)
                      _buildBorrowApprovalsTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.statusRed),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load library data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLibraryData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wineRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: BORROWED BOOKS & LOANS
  Widget _buildBorrowedBooksTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = _summary;

    final filteredBorrows = _borrows.where((r) {
      if (_borrowStatusFilter == 'all') return true;
      if (_borrowStatusFilter == 'active') return r.isActive;
      if (_borrowStatusFilter == 'pending_approval') return r.isPendingApproval;
      if (_borrowStatusFilter == 'overdue') return r.isOverdue;
      if (_borrowStatusFilter == 'returned') return r.isReturned;
      if (_borrowStatusFilter == 'rejected') return r.isRejected;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Metrics Cards Row
          _buildMetricsOverview(summary),

          const SizedBox(height: 16),

          // Overdue Warning Banner linking to Fine Portal if any late loans
          if (summary != null && summary.hasOverdue)
            _buildOverdueAlertBanner(summary),

          const SizedBox(height: 16),

          // Filters Bar
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 450) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Active & Past Loans (${filteredBorrows.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppDropdown<String>(
                      key: const Key('dropdown-borrow-status'),
                      value: _borrowStatusFilter,
                      items: const [
                        AppDropdownItem(value: 'all', label: 'All Loans'),
                        AppDropdownItem(value: 'active', label: 'Active Loans'),
                        AppDropdownItem(value: 'pending_approval', label: 'Pending Approval'),
                        AppDropdownItem(value: 'overdue', label: 'Overdue Loans'),
                        AppDropdownItem(value: 'returned', label: 'Returned History'),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _borrowStatusFilter = val);
                        }
                      },
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Active & Past Loans (${filteredBorrows.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: AppDropdown<String>(
                      key: const Key('dropdown-borrow-status'),
                      value: _borrowStatusFilter,
                      items: const [
                        AppDropdownItem(value: 'all', label: 'All Loans'),
                        AppDropdownItem(value: 'active', label: 'Active Loans'),
                        AppDropdownItem(value: 'pending_approval', label: 'Pending Approval'),
                        AppDropdownItem(value: 'overdue', label: 'Overdue Loans'),
                        AppDropdownItem(value: 'returned', label: 'Returned History'),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _borrowStatusFilter = val);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          if (filteredBorrows.isEmpty)
            _buildEmptyLoansState(isDark)
          else
            ...filteredBorrows.map((loan) => _buildLoanCard(loan, isDark)),
        ],
      ),
    );
  }

  Widget _buildMetricsOverview(LibrarySummaryModel? summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cards = [
          _buildMetricCard(
            title: 'Active Loans',
            value: '${summary?.activeBorrowsCount ?? 0}',
            subtitle: 'Max 4 books quota',
            icon: Icons.book_outlined,
            iconColor: isDark ? const Color(0xFF58A6FF) : AppColors.githubBlue,
            isDark: isDark,
          ),
          _buildMetricCard(
            title: 'Overdue Loans',
            value: '${summary?.overdueBorrowsCount ?? 0}',
            subtitle: summary != null && summary.hasOverdue
                ? 'Fine accrued: ₹${summary.totalLateFineDue.toStringAsFixed(0)}'
                : 'Zero overdue books',
            icon: Icons.warning_amber_rounded,
            iconColor: summary != null && summary.hasOverdue
                ? (isDark ? AppColors.statusRedDarkText : AppColors.statusRed)
                : (isDark ? AppColors.githubGreenDarkText : AppColors.githubGreen),
            isDark: isDark,
          ),
          _buildMetricCard(
            title: 'Borrowing Quota',
            value: '${summary?.availableQuota ?? 0} left',
            subtitle: '${summary?.activeBorrowsCount ?? 0} of 4 copies in use',
            icon: Icons.bookmark_added_outlined,
            iconColor: isDark ? AppColors.githubGreenDarkText : AppColors.githubGreen,
            isDark: isDark,
          ),
          _buildMetricCard(
            title: 'Returned History',
            value: '${summary?.returnedHistoryCount ?? 0}',
            subtitle: 'Lifetime institutional loans',
            icon: Icons.history_rounded,
            iconColor: isDark ? const Color(0xFFBC8CFF) : const Color(0xFF8250DF),
            isDark: isDark,
          ),
        ];

        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueAlertBanner(LibrarySummaryModel summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final redBadge = AppColors.redBadge(isDark);

    return Container(
      key: const Key('banner-library-overdue'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: redBadge.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: redBadge.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: redBadge.text, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Overdue Loans & Late Fines Notice',
                  style: TextStyle(
                    color: redBadge.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '₹${summary.totalLateFineDue.toStringAsFixed(0)} Fine Due',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You have overdue book loans. Borrowing privileges are suspended until copies are returned. Late return fines (₹10/day) have been synced to the Institutional Fine Portal.',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                key: const Key('btn-goto-fine-portal'),
                icon: const Icon(Icons.receipt_long, size: 16),
                label: const Text('Pay Fine in Fine Portal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (widget.onNavigateToTab != null) {
                    widget.onNavigateToTab!(9); // Tab 9 is Fee & Fine Portal
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please navigate to the Fees & Fines Portal from the sidebar to settle your fine.'),
                      ),
                    );
                  }
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('View Fine Waiver Policy'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: redBadge.text,
                  side: BorderSide(color: redBadge.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                onPressed: () => _tabController.animateTo(3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(BorrowRecordModel loan, bool isDark) {
    final BadgeStyle badgeStyle;
    final String badgeText;

    if (loan.isPendingApproval) {
      badgeStyle = AppColors.yellowBadge(isDark);
      badgeText = 'Pending Approval';
    } else if (loan.isPendingRenewal) {
      badgeStyle = AppColors.yellowBadge(isDark);
      badgeText = 'Pending Renewal';
    } else if (loan.isPendingReturn) {
      badgeStyle = AppColors.blueBadge(isDark);
      badgeText = 'Pending Return';
    } else if (loan.isRejected) {
      badgeStyle = AppColors.neutralBadge(isDark);
      badgeText = 'Rejected';
    } else if (loan.isReturned) {
      badgeStyle = AppColors.greenBadge(isDark);
      badgeText = 'Returned';
    } else if (loan.isOverdue) {
      badgeStyle = AppColors.redBadge(isDark);
      badgeText = '${loan.overdueDaysCount}d Overdue (₹${loan.accruedLateFine.toStringAsFixed(0)})';
    } else {
      badgeStyle = AppColors.blueBadge(isDark);
      badgeText = 'Due in ${loan.daysUntilDue} days';
    }

    final yellowBadge = AppColors.yellowBadge(isDark);
    final blueBadge = AppColors.blueBadge(isDark);
    final redBadge = AppColors.redBadge(isDark);

    return Container(
      key: Key('card-loan-${loan.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: loan.isOverdue
              ? (isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder)
              : (loan.isPendingApproval || loan.isPendingRenewal)
                  ? (isDark ? AppColors.statusYellowDarkBorder : AppColors.statusYellowBorder)
                  : loan.isPendingReturn
                      ? blueBadge.border
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeStyle.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  (loan.isPendingApproval || loan.isPendingRenewal)
                      ? Icons.hourglass_top
                      : loan.isPendingReturn
                          ? Icons.assignment_return_outlined
                          : Icons.menu_book,
                  color: badgeStyle.text,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.bookTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Author: ${loan.bookAuthor}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeStyle.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeStyle.border),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeStyle.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (loan.isPendingApproval) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: yellowBadge.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: yellowBadge.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: yellowBadge.text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pending approval from Library In-Charge. Physical copy cannot be issued until authorized.',
                      style: TextStyle(
                        color: yellowBadge.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (loan.isPendingRenewal) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: yellowBadge.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: yellowBadge.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_outlined, size: 16, color: yellowBadge.text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deadline extension submitted. Awaiting Library In-Charge authorization.',
                      style: TextStyle(
                        color: yellowBadge.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (loan.isPendingReturn) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: blueBadge.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: blueBadge.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment_return_outlined, size: 16, color: blueBadge.text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Return initiated. Please present the physical copy at the circulation counter for inspection and check-in sign-off.',
                      style: TextStyle(
                        color: blueBadge.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (loan.isRejected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: redBadge.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: redBadge.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined, size: 16, color: redBadge.text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Request Rejected: ${loan.rejectionReason ?? "No reason specified"}',
                      style: TextStyle(
                        color: redBadge.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Loan Details Grid
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _buildDetailItem('ISBN', loan.bookIsbn, isDark),
              _buildDetailItem('Shelf Location', loan.shelfLocation, isDark),
              _buildDetailItem('Borrowed On', dateFmt.format(loan.borrowedAt), isDark),
              _buildDetailItem('Due Date', dateFmt.format(loan.dueDate), isDark),
              _buildDetailItem('Renewals', '${loan.renewalCount} of ${loan.maxRenewals}', isDark),
              if (loan.approvedByName != null)
                _buildDetailItem('Authorized By', loan.approvedByName!, isDark),
              if (loan.renewalApprovedByName != null)
                _buildDetailItem('Renewal Approved By', loan.renewalApprovedByName!, isDark),
              if (loan.returnApprovedByName != null)
                _buildDetailItem('Return Approved By', loan.returnApprovedByName!, isDark),
            ],
          ),

          if (loan.hasLateFine) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: redBadge.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: redBadge.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined, size: 16, color: redBadge.text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Accrued Late Fine: ₹${loan.accruedLateFine.toStringAsFixed(2)} (@ ₹10/day)',
                      style: TextStyle(
                        color: redBadge.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons
          if (!loan.isReturned && !loan.isRejected) ...[
            if (loan.isPendingApproval) ...[
              if (_canManageLibrary)
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: Key('btn-reject-borrow-${loan.id}'),
                      icon: Icon(Icons.close, size: 16, color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed),
                      label: Text('Reject', style: TextStyle(color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder),
                      ),
                      onPressed: () => _handleRejectBorrow(loan),
                    ),
                    ElevatedButton.icon(
                      key: Key('btn-approve-borrow-${loan.id}'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve Loan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.githubGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _handleApproveBorrow(loan),
                    ),
                  ],
                ),
            ] else if (loan.isPendingReturn) ...[
              if (_canManageLibrary)
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: Key('btn-reject-return-${loan.id}'),
                      icon: Icon(Icons.close, size: 16, color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed),
                      label: Text('Reject Return', style: TextStyle(color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder),
                      ),
                      onPressed: () => _handleRejectReturn(loan),
                    ),
                    ElevatedButton.icon(
                      key: Key('btn-approve-return-${loan.id}'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Accept Return'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.githubGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _handleApproveReturn(loan),
                    ),
                  ],
                ),
            ] else ...[
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_canManageLibrary && loan.isPendingRenewal) ...[
                    OutlinedButton.icon(
                      key: Key('btn-reject-renewal-${loan.id}'),
                      icon: Icon(Icons.close, size: 16, color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed),
                      label: Text('Reject Renewal', style: TextStyle(color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder),
                      ),
                      onPressed: () => _handleRejectRenewal(loan),
                    ),
                    ElevatedButton.icon(
                      key: Key('btn-approve-renewal-${loan.id}'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve Renewal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.githubGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _handleApproveRenewal(loan),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      key: Key('btn-renew-${loan.id}'),
                      icon: const Icon(Icons.replay, size: 16),
                      label: Text(loan.isPendingRenewal ? 'Renewal Pending' : 'Renew Loan (+14d)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                        side: BorderSide(color: isDark ? AppColors.wineRedDarkBorder : AppColors.wineRedBorder),
                      ),
                      onPressed: loan.canRenew ? () => _handleRenewBook(loan) : null,
                    ),
                  ],
                  ElevatedButton.icon(
                    key: Key('btn-return-${loan.id}'),
                    icon: const Icon(Icons.assignment_return_outlined, size: 16),
                    label: const Text('Return Book'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.githubGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _handleReturnBook(loan),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // TAB 5: BORROW APPROVALS (LIBRARY IN-CHARGE / ADMIN)
  Widget _buildBorrowApprovalsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.statusYellowDarkSubtle : AppColors.statusYellowSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.rule_folder_outlined,
                    color: isDark ? AppColors.statusYellowDarkText : AppColors.statusYellow,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrow Approvals Counter (${_pendingApprovals.length} Pending)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'As Library In-Charge, verify student requests and authorize book checkouts, renewal extensions, and physical copy returns.',
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
          ),
          const SizedBox(height: 16),
          Text(
            'Pending Authorization Requests (${_pendingApprovals.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_pendingApprovals.isEmpty)
            _buildEmptyApprovalsState(isDark)
          else
            ..._pendingApprovals.map((req) => _buildApprovalRequestCard(req, isDark)),

          const SizedBox(height: 24),
          Text(
            'Student-Submitted PDF Books (${_pendingPdfBooks.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_pendingPdfBooks.isEmpty)
            _buildEmptyPdfApprovalsState(isDark)
          else
            ..._pendingPdfBooks.map((pdf) => _buildPdfApprovalCard(pdf, isDark)),
        ],
      ),
    );
  }

  Widget _buildApprovalRequestCard(BorrowRecordModel req, bool isDark) {
    final isRenewal = req.isPendingRenewal;
    final isReturn = req.isPendingReturn;
    final isBorrow = req.isPendingApproval;

    final BadgeStyle badgeStyle;
    final String badgeLabel;
    final IconData iconData;

    if (isReturn) {
      badgeStyle = AppColors.blueBadge(isDark);
      badgeLabel = 'Pending Return Inspection';
      iconData = Icons.assignment_return_outlined;
    } else if (isRenewal) {
      badgeStyle = AppColors.yellowBadge(isDark);
      badgeLabel = 'Pending Renewal Extension';
      iconData = Icons.replay;
    } else {
      badgeStyle = AppColors.yellowBadge(isDark);
      badgeLabel = 'Awaiting In-Charge Approval';
      iconData = Icons.hourglass_top;
    }

    return Container(
      key: Key('card-approval-${req.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReturn
              ? badgeStyle.border
              : (isDark ? AppColors.statusYellowDarkBorder : AppColors.statusYellowBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeStyle.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, color: badgeStyle.text, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.bookTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Author: ${req.bookAuthor}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeStyle.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeStyle.border),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          color: badgeStyle.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _buildDetailItem('Student Name', req.studentName, isDark),
              _buildDetailItem('Campus Handle', req.campusHandle, isDark),
              _buildDetailItem('Shelf Location', req.shelfLocation, isDark),
              if (isBorrow) ...[
                _buildDetailItem('Requested On', dateFmt.format(req.borrowedAt), isDark),
                _buildDetailItem('Standard Term', '14 Days from Approval', isDark),
              ] else if (isRenewal) ...[
                _buildDetailItem('Current Due Date', dateFmt.format(req.dueDate), isDark),
                _buildDetailItem('Renewals Used', '${req.renewalCount}/${req.maxRenewals}', isDark),
                _buildDetailItem('Extension Term', '+14 Calendar Days', isDark),
              ] else if (isReturn) ...[
                _buildDetailItem('Due Date', dateFmt.format(req.dueDate), isDark),
                _buildDetailItem('Status', req.isOverdue ? 'Overdue Return' : 'On-Time Return', isDark),
                if (req.hasLateFine)
                  _buildDetailItem('Late Fine', '₹${req.accruedLateFine.toStringAsFixed(2)}', isDark),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isReturn) ...[
                OutlinedButton.icon(
                  key: Key('btn-reject-return-${req.id}'),
                  icon: Icon(Icons.close, size: 16, color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed),
                  label: Text('Reject Return', style: TextStyle(color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder),
                  ),
                  onPressed: () => _handleRejectReturn(req),
                ),
                ElevatedButton.icon(
                  key: Key('btn-approve-return-${req.id}'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Accept Return'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.githubGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _handleApproveReturn(req),
                ),
              ] else if (isRenewal) ...[
                OutlinedButton.icon(
                  key: Key('btn-reject-renewal-${req.id}'),
                  icon: Icon(Icons.close, size: 16, color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed),
                  label: Text('Reject Renewal', style: TextStyle(color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder),
                  ),
                  onPressed: () => _handleRejectRenewal(req),
                ),
                ElevatedButton.icon(
                  key: Key('btn-approve-renewal-${req.id}'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve Renewal (+14d)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.githubGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _handleApproveRenewal(req),
                ),
              ] else ...[
                OutlinedButton.icon(
                  key: Key('btn-reject-borrow-${req.id}'),
                  icon: Icon(Icons.close, size: 16, color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed),
                  label: Text('Reject Request', style: TextStyle(color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder),
                  ),
                  onPressed: () => _handleRejectBorrow(req),
                ),
                ElevatedButton.icon(
                  key: Key('btn-approve-borrow-${req.id}'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve Loan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.githubGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _handleApproveBorrow(req),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyApprovalsState(bool isDark) {
    return Container(
      key: const Key('empty-approvals-state'),
      padding: const EdgeInsets.all(48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.done_all_rounded,
            size: 48,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightBorderHover,
          ),
          const SizedBox(height: 12),
          Text(
            'All Clear! No Pending Approvals',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Student requests for book checkout, deadline extension, and return inspection will appear here for verification.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPdfApprovalsState(bool isDark) {
    return Container(
      key: const Key('empty-pdf-approvals-state'),
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 40,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightBorderHover,
          ),
          const SizedBox(height: 10),
          Text(
            'No Pending PDF Submissions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Student-donated digital PDF textbooks awaiting Library In-Charge review will appear here.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPdfApprovalCard(EBookModel pdf, bool isDark) {
    return Container(
      key: Key('card-pdf-approval-${pdf.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.statusYellowDarkBorder : AppColors.statusYellowBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.statusYellowDarkSubtle : AppColors.statusYellowSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.picture_as_pdf,
                  color: isDark ? AppColors.statusYellowDarkText : AppColors.statusYellow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pdf.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Author: ${pdf.author} • ${pdf.publisher}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.statusYellowDarkSubtle : AppColors.statusYellowSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.statusYellowDarkBorder : AppColors.statusYellowBorder,
                        ),
                      ),
                      child: Text(
                        'Pending PDF Review',
                        style: TextStyle(
                          color: isDark ? AppColors.statusYellowDarkText : AppColors.statusYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pdf.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _buildDetailItem('Submitted By', pdf.submittedByName ?? 'Student', isDark),
              _buildDetailItem('Student ID', pdf.submittedBy ?? 'N/A', isDark),
              _buildDetailItem('Category', pdf.category, isDark),
              _buildDetailItem('File Size', pdf.fileSize, isDark),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('btn-reject-pdf-${pdf.id}'),
                icon: Icon(Icons.close, size: 16, color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed),
                label: Text('Reject PDF', style: TextStyle(color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder),
                ),
                onPressed: () => _handleRejectPdf(pdf),
              ),
              ElevatedButton.icon(
                key: Key('btn-approve-pdf-${pdf.id}'),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.githubGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _handleApprovePdf(pdf),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyLoansState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.menu_book,
            size: 48,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightBorderHover,
          ),
          const SizedBox(height: 12),
          Text(
            'No matching loans found',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Explore the physical catalog or digital e-books to borrow copies.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: PHYSICAL CATALOG & BOOKS REMAINING
  Widget _buildPhysicalCatalogTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = _summary;

    final filteredBooks = _books.where((b) {
      if (_bookCategoryFilter != 'All Categories' && b.category != _bookCategoryFilter) {
        return false;
      }
      if (_bookSearchQuery.isNotEmpty) {
        final q = _bookSearchQuery.toLowerCase();
        final match = b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q) ||
            b.isbn.toLowerCase().contains(q) ||
            b.shelfLocation.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    final canBorrow = summary != null && summary.canBorrowMore;

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Borrowing Quota Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.githubGreenDarkSubtle : AppColors.githubGreenSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: isDark ? AppColors.githubGreenDarkText : AppColors.githubGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrowing Quota: ${summary?.activeBorrowsCount ?? 0} of 4 books in use',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary != null && summary.hasOverdue
                            ? 'Suspended: Settle overdue loans before checking out new books'
                            : '${summary?.availableQuota ?? 0} additional physical book loans remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: summary != null && summary.hasOverdue
                              ? (isDark ? AppColors.statusRedDarkText : AppColors.statusRed)
                              : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_canManageLibrary) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                key: const Key('btn-add-catalog'),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('Add Book to Catalog'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: _showAddCatalogDialog,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Search & Category Filter Bar
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 480) {
                return Column(
                  children: [
                    TextField(
                      key: const Key('input-book-search'),
                      decoration: InputDecoration(
                        hintText: 'Search title, author, ISBN, shelf...',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                          child: AppSvgIcon(
                            svgString: AppSvgIcon.search,
                            size: 13,
                            strokeWidth: 1.5,
                            color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        setState(() => _bookSearchQuery = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    AppDropdown<String>(
                      key: const Key('dropdown-book-category'),
                      value: _bookCategoryFilter,
                      items: BookCategory.catalogCategories.map((c) {
                        return AppDropdownItem(value: c, label: c);
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _bookCategoryFilter = val);
                        }
                      },
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('input-book-search'),
                      decoration: InputDecoration(
                        hintText: 'Search title, author, ISBN, shelf...',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                          child: AppSvgIcon(
                            svgString: AppSvgIcon.search,
                            size: 13,
                            strokeWidth: 1.5,
                            color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        setState(() => _bookSearchQuery = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: AppDropdown<String>(
                      key: const Key('dropdown-book-category'),
                      value: _bookCategoryFilter,
                      items: BookCategory.catalogCategories.map((c) {
                        return AppDropdownItem(value: c, label: c);
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _bookCategoryFilter = val);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          Text(
            'Physical Volumes Catalog (${filteredBooks.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),

          const SizedBox(height: 12),

          if (filteredBooks.isEmpty)
            _buildEmptyCatalogState(isDark)
          else
            ...filteredBooks.map((book) => _buildBookCard(book, canBorrow, isDark)),
        ],
      ),
    );
  }

  Widget _buildBookCard(PhysicalBookModel book, bool canStudentBorrow, bool isDark) {
    final BadgeStyle remainingBadge;
    final String remainingText;

    if (book.availableCopies > 2) {
      remainingBadge = AppColors.greenBadge(isDark);
      remainingText = '${book.availableCopies} of ${book.totalCopies} available';
    } else if (book.availableCopies > 0) {
      remainingBadge = AppColors.yellowBadge(isDark);
      remainingText = 'Only ${book.availableCopies} copy left';
    } else {
      remainingBadge = AppColors.redBadge(isDark);
      remainingText = '0 copies left (Checked out)';
    }

    final isEligible = canStudentBorrow && book.isAvailable;

    return Container(
      key: Key('card-book-${book.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.wineRedDarkSubtle : AppColors.wineRedSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AppSvgIcon(
                  svgString: AppSvgIcon.book,
                  size: 22,
                  color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${book.author} • ${book.edition} • ${book.publisher}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Remaining copies badge
                    Container(
                      key: Key('badge-copies-${book.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: remainingBadge.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: remainingBadge.border),
                      ),
                      child: Text(
                        remainingText,
                        style: TextStyle(
                          color: remainingBadge.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _buildDetailItem('ISBN', book.isbn, isDark),
              _buildDetailItem('Category', book.category, isDark),
              _buildDetailItem('Shelf Location', book.shelfLocation, isDark),
              _buildDetailItem('Replacement Value', '₹${book.replacementCost.toStringAsFixed(0)}', isDark),
            ],
          ),

          const SizedBox(height: 14),

          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Total Copies: ${book.totalCopies} (${book.copiesBorrowed} checked out)',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_canManageLibrary)
                    OutlinedButton.icon(
                      key: Key('btn-remove-book-${book.id}'),
                      icon: Icon(Icons.delete_outline, size: 16, color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed),
                      label: Text('Remove Catalogue', style: TextStyle(color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder),
                      ),
                      onPressed: () => _handleRemoveCatalogue(book),
                    ),
                  ElevatedButton.icon(
                    key: Key('btn-borrow-${book.id}'),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                    label: const Text('Borrow Book'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wineRed,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isEligible ? () => _handleBorrowBook(book) : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCatalogState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightBorderHover,
          ),
          const SizedBox(height: 12),
          Text(
            'No matching physical volumes found',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search keywords or category filters.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: DIGITAL E-BOOKS FOR INFINITE BORROWING
  Widget _buildInfiniteEBooksTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredEBooks = _ebooks.where((e) {
      if (_ebookCategoryFilter != 'All Categories' && e.category != _ebookCategoryFilter) {
        return false;
      }
      if (_ebookSearchQuery.isNotEmpty) {
        final q = _ebookSearchQuery.toLowerCase();
        final match = e.title.toLowerCase().contains(q) ||
            e.author.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q) ||
            e.tags.any((t) => t.toLowerCase().contains(q));
        if (!match) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Infinite Digital Access Hero Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [AppColors.wineRedDarkSubtle, AppColors.darkSurface]
                    : const [AppColors.wineRed, AppColors.wineRedLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.wineRedDarkBorder : AppColors.wineRedBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.all_inclusive,
                      color: isDark ? AppColors.wineRedDarkText : Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Institutional Digital Knowledge Repository',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Infinite Concurrent Access • Zero Loan Expiration • Unlimited Institutional Licensing',
                  style: TextStyle(
                    color: isDark ? AppColors.wineRedDarkText : AppColors.wineRedSubtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All enrolled campus scholars have non-expiring, concurrent digital borrowing privileges. E-books do not count against your 4-physical-books checkout quota.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              key: const Key('btn-add-pdf-book'),
              icon: const Icon(Icons.upload_file, size: 16),
              label: Text(_canManageLibrary ? 'Add PDF E-Book' : 'Upload PDF E-Book'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wineRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: _showAddPdfBookDialog,
            ),
          ),

          const SizedBox(height: 16),

          // Search & Filter
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 480) {
                return Column(
                  children: [
                    TextField(
                      key: const Key('input-ebook-search'),
                      decoration: InputDecoration(
                        hintText: 'Search digital textbooks, authors, topics...',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                          child: AppSvgIcon(
                            svgString: AppSvgIcon.search,
                            size: 13,
                            strokeWidth: 1.5,
                            color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        setState(() => _ebookSearchQuery = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    AppDropdown<String>(
                      key: const Key('dropdown-ebook-category'),
                      value: _ebookCategoryFilter,
                      items: BookCategory.catalogCategories.map((c) {
                        return AppDropdownItem(value: c, label: c);
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _ebookCategoryFilter = val);
                        }
                      },
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('input-ebook-search'),
                      decoration: InputDecoration(
                        hintText: 'Search digital textbooks, authors, topics...',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                          child: AppSvgIcon(
                            svgString: AppSvgIcon.search,
                            size: 13,
                            strokeWidth: 1.5,
                            color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        setState(() => _ebookSearchQuery = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: AppDropdown<String>(
                      key: const Key('dropdown-ebook-category'),
                      value: _ebookCategoryFilter,
                      items: BookCategory.catalogCategories.map((c) {
                        return AppDropdownItem(value: c, label: c);
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _ebookCategoryFilter = val);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          Text(
            'Digital Titles with Infinite Borrowing (${filteredEBooks.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),

          const SizedBox(height: 12),

          if (filteredEBooks.isEmpty)
            _buildEmptyCatalogState(isDark)
          else
            ...filteredEBooks.map((ebook) => _buildEBookCard(ebook, isDark)),
        ],
      ),
    );
  }

  Widget _buildEBookCard(EBookModel ebook, bool isDark) {
    final greenBadge = AppColors.greenBadge(isDark);

    return Container(
      key: Key('card-ebook-${ebook.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.githubGreenDarkSubtle : AppColors.githubGreenSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tablet_mac_outlined,
                  color: isDark ? AppColors.githubGreenDarkText : AppColors.githubGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ebook.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ebook.author} • ${ebook.publisher}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (ebook.isApproved)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: greenBadge.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: greenBadge.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.all_inclusive, size: 14, color: greenBadge.text),
                                const SizedBox(width: 4),
                                Text(
                                  'Infinite Borrow',
                                  style: TextStyle(
                                    color: greenBadge.text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (ebook.isPendingApproval)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.statusYellowDarkSubtle : AppColors.statusYellowSubtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.statusYellowDarkBorder : AppColors.statusYellowBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hourglass_top, size: 14, color: isDark ? AppColors.statusYellowDarkText : AppColors.statusYellow),
                                const SizedBox(width: 4),
                                Text(
                                  'Pending In-Charge Approval',
                                  style: TextStyle(
                                    color: isDark ? AppColors.statusYellowDarkText : AppColors.statusYellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (ebook.isRejected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.statusRedDarkSubtle : AppColors.statusRedSubtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cancel_outlined, size: 14, color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed),
                                const SizedBox(width: 4),
                                Text(
                                  'Rejected',
                                  style: TextStyle(
                                    color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (ebook.submittedByName != null && ebook.submittedByName!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Submitted by: ${ebook.submittedByName}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            ebook.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.wineRedDarkSubtle : AppColors.wineRedSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ebook.format,
                      style: TextStyle(
                        color: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${ebook.fileSize} • ${ebook.totalReaders} readers',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_canManageLibrary && ebook.isPendingApproval) ...[
                    OutlinedButton.icon(
                      key: Key('btn-card-reject-pdf-${ebook.id}'),
                      icon: Icon(Icons.close, size: 16, color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed),
                      label: Text('Reject PDF', style: TextStyle(color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.statusRedDarkBorder : AppColors.statusRedBorder),
                      ),
                      onPressed: () => _handleRejectPdf(ebook),
                    ),
                    ElevatedButton.icon(
                      key: Key('btn-card-approve-pdf-${ebook.id}'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.githubGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _handleApprovePdf(ebook),
                    ),
                  ],
                  OutlinedButton.icon(
                    key: Key('btn-read-ebook-${ebook.id}'),
                    icon: const Icon(Icons.menu_book, size: 16),
                    label: const Text('Read Online'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.wineRedDarkText : AppColors.wineRed,
                      side: BorderSide(
                        color: isDark ? AppColors.wineRedDarkBorder : AppColors.wineRedBorder,
                      ),
                    ),
                    onPressed: () => _showEBookReader(ebook),
                  ),
                  ElevatedButton.icon(
                    key: Key('btn-download-ebook-${ebook.id}'),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wineRed,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _downloadEBookPdf(ebook),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 4: POLICY & FINE SLABS
  Widget _buildLibraryPolicyTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      key: const Key('list-library-policy'),
      padding: const EdgeInsets.all(16),
      children: [
        _buildPolicySection(
          title: 'Institutional Borrowing Privileges & Quotas',
          icon: Icons.verified_user_outlined,
          color: isDark ? const Color(0xFF58A6FF) : AppColors.githubBlue,
          items: const [
            'Maximum 4 physical books can be checked out concurrently per student.',
            'Standard loan duration is 14 calendar days per book.',
            'Up to 2 renewals are permitted per loan if no holds have been placed.',
            'Digital e-books have infinite concurrent borrowing and do not count toward physical quota.',
          ],
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildPolicySection(
          title: 'Overdue Fine Slabs & Settle Protocol',
          icon: Icons.payments_outlined,
          color: isDark ? AppColors.statusRedDarkText : AppColors.statusRed,
          items: const [
            'Late return fine accrues at ₹10.00 per calendar day past due date.',
            'Fines automatically sync to the Institutional Fine Portal (FineCategory.library).',
            'Students can settle outstanding fines directly via NetBanking/UPI in the Fees Portal.',
            'New book checkouts are paused while any overdue books remain unreturned.',
          ],
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildPolicySection(
          title: 'Fine Appeals & Medical Waivers',
          icon: Icons.gavel_outlined,
          color: isDark ? AppColors.statusYellowDarkText : AppColors.statusAmber,
          items: const [
            'Fine appeals can be filed directly through the Institutional Fine Portal.',
            'Dean of Student Affairs / Head Librarian reviews appeals within 3 working days.',
            'Legitimate medical certificates and authorized institutional duty allow complete waiver.',
            'Appealed fines are marked pending and do not block graduation clearance.',
          ],
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildPolicySection(
          title: 'Book Care & Replacement Policy',
          icon: Icons.security_outlined,
          color: isDark ? AppColors.githubGreenDarkText : AppColors.githubGreen,
          items: const [
            'Books must be maintained in pristine condition without markings or water damage.',
            'Lost volumes require reimbursement of the institutional replacement cost + ₹200 handling fee.',
            'Damaged barcodes or RFID tags should be reported immediately to the circulation desk.',
          ],
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildPolicySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
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
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.4,
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
}
