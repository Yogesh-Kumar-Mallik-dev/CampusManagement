import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../di/service_locator.dart';
import '../facade/campus_facade.dart';
import '../models/library.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_dropdown.dart';

class LibraryScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;
  final ICampusFacade? facade;
  final void Function(int)? onNavigateToTab;

  const LibraryScreen({
    super.key,
    required this.storage,
    this.currentUser,
    this.facade,
    this.onNavigateToTab,
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
    _tabController = TabController(length: _canManageLibrary ? 5 : 4, vsync: this);
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
      if (_canManageLibrary) {
        pendingApprovals = await _facade.getBorrowRecords(status: 'pending_approval');
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _borrows = borrows;
          _books = books;
          _ebooks = ebooks;
          _pendingApprovals = pendingApprovals;
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
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text('Shelf Location: ${book.shelfLocation}'),
              Text('Available Copies: ${book.availableCopies} of ${book.totalCopies}'),
              const Divider(height: 24),
              const Text(
                'Standard Loan Policy:\n• Loan duration: 14 calendar days\n• Up to 2 renewals allowed\n• Late fine rate: ₹10/day\n• Approval Rule: Physical loan requires Library In-Charge authorization before pickup at circulation counter.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
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
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleApproveBorrow(BorrowRecordModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
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
              Text('Student: ${record.studentName} (${record.campusHandle})'),
              Text('Shelf Location: ${record.shelfLocation}'),
              const SizedBox(height: 12),
              const Text(
                'Authorizing this checkout will activate the 14-day loan period starting today and permit physical copy release to the student.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-approve-borrow'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
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
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleRejectBorrow(BorrowRecordModel record) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
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
                Text('Student: ${record.studentName} (${record.campusHandle})'),
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
                const Text(
                  'Rejecting this request will restore the physical book copy back to the catalog.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-reject-borrow'),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
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
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleReturnBook(BorrowRecordModel record) async {
    final isLate = record.isOverdue;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
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
              Text('Loan Borrowed: ${dateFmt.format(record.borrowedAt)}'),
              Text('Due Date: ${dateFmt.format(record.dueDate)}'),
              if (isLate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDC2626)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Late Return Notice',
                        style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This loan is overdue by ${record.overdueDaysCount} days. A late fine of ₹${record.accruedLateFine.toStringAsFixed(2)} will be issued to your Institutional Fine Portal.',
                        style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 12),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
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
      await _facade.returnBook(
        borrowId: record.id,
        studentId: _currentStudentId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Book '${record.bookTitle}' returned successfully. Physical catalog copy incremented.",
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleRenewBook(BorrowRecordModel record) async {
    try {
      final renewed = await _facade.renewBook(
        borrowId: record.id,
        studentId: _currentStudentId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Loan extended by 14 days. New due date: ${dateFmt.format(renewed.dueDate)} (${renewed.renewalCount}/${renewed.maxRenewals} renewals used).",
            ),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
        await _loadLibraryData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
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
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const AppSvgIcon(
                        svgString: AppSvgIcon.book,
                        size: 22,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ebook.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${ebook.author} • ${ebook.format} (${ebook.fileSize})',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
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
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.all_inclusive, color: Color(0xFF16A34A), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Infinite Concurrent Institutional License',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'Unlimited concurrent readers • No loan expiration • Institutional copy',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                    const Text(
                      'Overview & Abstract',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ebook.description,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Table of Contents (Institutional Digital Edition)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                chapters[index],
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              'p. ${(index + 1) * 35}',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
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
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Download Offline Copy'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Downloading '${ebook.title}' (${ebook.fileSize})..."),
                              backgroundColor: const Color(0xFF2563EB),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chrome_reader_mode_outlined, size: 18),
                        label: const Text('Start Fullscreen Reader'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Opening '${ebook.title}' in campus digital reader..."),
                              backgroundColor: const Color(0xFF16A34A),
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Library & Knowledge Portal'),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
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
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load library data',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLibraryData,
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            iconColor: const Color(0xFF2563EB),
            isDark: isDark,
          ),
          _buildMetricCard(
            title: 'Overdue Loans',
            value: '${summary?.overdueBorrowsCount ?? 0}',
            subtitle: summary != null && summary.hasOverdue
                ? 'Fine accrued: ₹${summary.totalLateFineDue.toStringAsFixed(0)}'
                : 'Zero overdue books',
            icon: Icons.warning_amber_rounded,
            iconColor: summary != null && summary.hasOverdue ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            isDark: isDark,
          ),
          _buildMetricCard(
            title: 'Borrowing Quota',
            value: '${summary?.availableQuota ?? 0} left',
            subtitle: '${summary?.activeBorrowsCount ?? 0} of 4 copies in use',
            icon: Icons.bookmark_added_outlined,
            iconColor: const Color(0xFF0D9488),
            isDark: isDark,
          ),
          _buildMetricCard(
            title: 'Returned History',
            value: '${summary?.returnedHistoryCount ?? 0}',
            subtitle: 'Lifetime institutional loans',
            icon: Icons.history_rounded,
            iconColor: const Color(0xFF8B5CF6),
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueAlertBanner(LibrarySummaryModel summary) {
    return Container(
      key: const Key('banner-library-overdue'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF87171)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error, color: Color(0xFFDC2626), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Overdue Loans & Late Fines Notice',
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
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
          const Text(
            'You have overdue book loans. Borrowing privileges are suspended until copies are returned. Late return fines (₹10/day) have been synced to the Institutional Fine Portal.',
            style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 13, height: 1.4),
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
                  backgroundColor: const Color(0xFFDC2626),
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
                  foregroundColor: const Color(0xFF991B1B),
                  side: const BorderSide(color: Color(0xFFF87171)),
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
    Color badgeColor;
    String badgeText;

    if (loan.isPendingApproval) {
      badgeColor = const Color(0xFFD97706);
      badgeText = 'Pending Approval';
    } else if (loan.isRejected) {
      badgeColor = const Color(0xFF6B7280);
      badgeText = 'Rejected';
    } else if (loan.isReturned) {
      badgeColor = const Color(0xFF16A34A);
      badgeText = 'Returned';
    } else if (loan.isOverdue) {
      badgeColor = const Color(0xFFDC2626);
      badgeText = '${loan.overdueDaysCount}d Overdue (₹${loan.accruedLateFine.toStringAsFixed(0)})';
    } else {
      badgeColor = const Color(0xFF2563EB);
      badgeText = 'Due in ${loan.daysUntilDue} days';
    }

    return Container(
      key: Key('card-loan-${loan.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: loan.isOverdue
              ? const Color(0xFFF87171)
              : loan.isPendingApproval
                  ? const Color(0xFFF59E0B)
                  : isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
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
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  loan.isPendingApproval ? Icons.hourglass_top : Icons.menu_book,
                  color: badgeColor,
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Author: ${loan.bookAuthor}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeColor),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
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
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pending approval from Library In-Charge. Physical copy cannot be issued until authorized.',
                      style: TextStyle(
                        color: Color(0xFF92400E),
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
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Request Rejected: ${loan.rejectionReason ?? "No reason specified"}',
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
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
            ],
          ),

          if (loan.hasLateFine) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Accrued Late Fine: ₹${loan.accruedLateFine.toStringAsFixed(2)} (@ ₹10/day)',
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
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
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                      label: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626))),
                      onPressed: () => _handleRejectBorrow(loan),
                    ),
                    ElevatedButton.icon(
                      key: Key('btn-approve-borrow-${loan.id}'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve Loan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _handleApproveBorrow(loan),
                    ),
                  ],
                ),
            ] else ...[
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: Key('btn-renew-${loan.id}'),
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text('Renew Loan (+14d)'),
                    onPressed: loan.canRenew ? () => _handleRenewBook(loan) : null,
                  ),
                  ElevatedButton.icon(
                    key: Key('btn-return-${loan.id}'),
                    icon: const Icon(Icons.assignment_return_outlined, size: 16),
                    label: const Text('Return Book'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
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
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rule_folder_outlined, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrow Approvals Counter (${_pendingApprovals.length} Pending)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'As Library In-Charge, verify student eligibility and authorize book checkouts before physical copy dispatch.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (_pendingApprovals.isEmpty)
            _buildEmptyApprovalsState(isDark)
          else
            ..._pendingApprovals.map((req) => _buildApprovalRequestCard(req, isDark)),
        ],
      ),
    );
  }

  Widget _buildApprovalRequestCard(BorrowRecordModel req, bool isDark) {
    return Container(
      key: Key('card-approval-${req.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
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
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.hourglass_top, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.bookTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Author: ${req.bookAuthor}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Text(
                        'Awaiting In-Charge Approval',
                        style: TextStyle(
                          color: Color(0xFFB45309),
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
              _buildDetailItem('Requested On', dateFmt.format(req.borrowedAt), isDark),
              _buildDetailItem('Standard Term', '14 Days from Approval', isDark),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('btn-reject-borrow-${req.id}'),
                icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                label: const Text('Reject Request', style: TextStyle(color: Color(0xFFDC2626))),
                onPressed: () => _handleRejectBorrow(req),
              ),
              ElevatedButton.icon(
                key: Key('btn-approve-borrow-${req.id}'),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve Loan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _handleApproveBorrow(req),
              ),
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
            color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          const Text(
            'All Clear! No Pending Approvals',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'New physical book borrowing requests from students will appear here for verification.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
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
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 12),
          const Text(
            'No matching loans found',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Explore the physical catalog or digital e-books to borrow copies.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
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
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0D9488), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrowing Quota: ${summary?.activeBorrowsCount ?? 0} of 4 books in use',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary != null && summary.hasOverdue
                            ? 'Suspended: Settle overdue loans before checking out new books'
                            : '${summary?.availableQuota ?? 0} additional physical book loans remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: summary != null && summary.hasOverdue
                              ? const Color(0xFFDC2626)
                              : isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

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
                        prefixIcon: const Icon(Icons.search, size: 20),
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
                        prefixIcon: const Icon(Icons.search, size: 20),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    Color remainingBadgeColor;
    String remainingText;

    if (book.availableCopies > 2) {
      remainingBadgeColor = const Color(0xFF16A34A);
      remainingText = '${book.availableCopies} of ${book.totalCopies} available';
    } else if (book.availableCopies > 0) {
      remainingBadgeColor = const Color(0xFFD97706);
      remainingText = 'Only ${book.availableCopies} copy left';
    } else {
      remainingBadgeColor = const Color(0xFFDC2626);
      remainingText = '0 copies left (Checked out)';
    }

    final isEligible = canStudentBorrow && book.isAvailable;

    return Container(
      key: Key('card-book-${book.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const AppSvgIcon(
                  svgString: AppSvgIcon.book,
                  size: 22,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${book.author} • ${book.edition} • ${book.publisher}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Remaining copies badge
                    Container(
                      key: Key('badge-copies-${book.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: remainingBadgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: remainingBadgeColor),
                      ),
                      child: Text(
                        remainingText,
                        style: TextStyle(
                          color: remainingBadgeColor,
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
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              ElevatedButton.icon(
                key: Key('btn-borrow-${book.id}'),
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const Text('Borrow Book'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                onPressed: isEligible ? () => _handleBorrowBook(book) : null,
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
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 12),
          const Text(
            'No matching physical volumes found',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your search keywords or category filters.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
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
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.all_inclusive, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Institutional Digital Knowledge Repository',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Infinite Concurrent Access • Zero Loan Expiration • Unlimited Institutional Licensing',
                  style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'All enrolled campus scholars have non-expiring, concurrent digital borrowing privileges. E-books do not count against your 4-physical-books checkout quota.',
                  style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                ),
              ],
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
                        prefixIcon: const Icon(Icons.search, size: 20),
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
                        prefixIcon: const Icon(Icons.search, size: 20),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    return Container(
      key: Key('card-ebook-${ebook.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tablet_mac_outlined, color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ebook.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ebook.author} • ${ebook.publisher}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF16A34A)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.all_inclusive, size: 14, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            'Infinite Borrow',
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
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
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ebook.format,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
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
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: Key('btn-read-ebook-${ebook.id}'),
                    icon: const Icon(Icons.menu_book, size: 16),
                    label: const Text('Read Online'),
                    onPressed: () => _showEBookReader(ebook),
                  ),
                  ElevatedButton.icon(
                    key: Key('btn-download-ebook-${ebook.id}'),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Downloading '${ebook.title}' (${ebook.fileSize})..."),
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                      );
                    },
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
          color: const Color(0xFF2563EB),
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
          color: const Color(0xFFDC2626),
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
          color: const Color(0xFFD97706),
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
          color: const Color(0xFF0D9488),
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
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
