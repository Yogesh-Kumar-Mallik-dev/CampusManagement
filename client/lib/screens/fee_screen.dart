import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../di/service_locator.dart';
import '../facade/campus_facade.dart';
import '../models/complaint.dart';
import '../models/fee.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../utils/file_downloader.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/campus_payment_dialog.dart';
import 'complaints_screen.dart';

class FeeScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final UserModel? currentUser;
  final ICampusFacade? facade;

  const FeeScreen({
    super.key,
    required this.storage,
    this.currentUser,
    this.facade,
  });

  @override
  State<FeeScreen> createState() => _FeeScreenState();
}

class _FeeScreenState extends State<FeeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final dateFmt = DateFormat('dd MMM yyyy');
  static final dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  bool _isLoading = true;
  String? _errorMessage;

  FeeSummaryModel? _summary;
  List<FeeInvoiceModel> _invoices = [];
  List<FineRecordModel> _fines = [];
  List<FeePaymentModel> _payments = [];

  String _invoiceFilter = 'all';
  String _fineFilter = 'all';
  final _paymentSearchNotifier = ValueNotifier<String>('');

  ICampusFacade get _facade {
    if (widget.facade != null) return widget.facade!;
    if (CampusDI.instance.isRegistered<ICampusFacade>()) {
      return CampusDI.instance.get<ICampusFacade>();
    }
    return CampusFacade(storage: widget.storage, api: widget.storage.api);
  }

  String get _currentStudentId {
    if (widget.currentUser != null && widget.currentUser!.id.isNotEmpty) {
      if (_canWaiveFines) {
        return 'usr-harish_2025_l_btech_1';
      }
      return widget.currentUser!.id;
    }
    return 'usr-harish_2025_l_btech_1';
  }

  bool get _canWaiveFines {
    if (widget.currentUser == null) return false;
    final r = widget.currentUser!.archetype.toLowerCase();
    return r == 'admin' || r == 'warden' || r == 'staff' || r == 'employee';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      animationDuration: Duration.zero,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _loadFeeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _paymentSearchNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadFeeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final studentId = _currentStudentId;
      final summary = await _facade.getFeeSummary(studentId);
      final invoices = await _facade.getInvoices(studentId: studentId);
      final fines = await _facade.getFines(studentId: studentId);
      final payments = await _facade.getFeePayments(studentId);

      if (mounted) {
        setState(() {
          _summary = summary;
          _invoices = invoices;
          _fines = fines;
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: const Key('screen-fee-portal'),
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Institutional Fee & Fine Management',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Dues settlement, invoice tracking, fine resolution, and transaction receipts',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('btn-refresh-fees'),
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Ledger',
            onPressed: _loadFeeData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: (index) {
            setState(() {
              _tabController.index = index;
            });
          },
          labelColor: AppColors.wineRed,
          unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          indicatorColor: AppColors.wineRed,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              key: Key('tab-fee-invoices'),
              text: 'Fee Portal',
              icon: Icon(Icons.receipt_long_outlined, size: 18),
            ),
            Tab(
              key: Key('tab-fine-portal'),
              text: 'Fine Portal',
              icon: Icon(Icons.gavel_outlined, size: 18),
            ),
            Tab(
              key: Key('tab-records-ledger'),
              text: 'Records & Receipts',
              icon: Icon(Icons.history_edu_outlined, size: 18),
            ),
            Tab(
              key: Key('tab-fee-structure'),
              text: 'Fee Policy & Slabs',
              icon: Icon(Icons.menu_book_outlined, size: 18),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView(isDark)
              : _buildContent(isDark),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.statusRed),
            const SizedBox(height: 12),
            Text(
              'Unable to load fee ledger',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFeeData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return Column(
          children: [
            // Top Overview Cards Banner
            _buildOverviewSummaryCards(isDark, isMobile),
            const Divider(height: 1),
            // Subsystem Tab Views
            Expanded(
              child: IndexedStack(
                index: _tabController.index,
                children: [
                  _buildInvoicesPortal(isDark, isMobile),
                  _buildFinesPortal(isDark, isMobile),
                  _buildLedgerPortal(isDark, isMobile),
                  _buildPolicyPortal(isDark, isMobile),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------
  // OVERVIEW SUMMARY CARDS
  // ----------------------------------------------------

  Widget _buildOverviewSummaryCards(bool isDark, bool isMobile) {
    final summary = _summary ??
        const FeeSummaryModel(
          totalDues: 0.0,
          totalPaid: 0.0,
          pendingFines: 0.0,
          overdueInvoices: 0,
          activeFinesCount: 0,
        );

    final cardItems = [
      _SummaryCardData(
        title: 'Total Outstanding Dues',
        value: currencyFmt.format(summary.totalDues),
        subtext: summary.overdueInvoices > 0
            ? '${summary.overdueInvoices} Overdue Invoices'
            : 'All current invoices on schedule',
        accentColor: summary.totalDues > 0 ? AppColors.statusAmber : AppColors.githubGreen,
        icon: Icons.account_balance_wallet_outlined,
      ),
      _SummaryCardData(
        title: 'Settled Institutional Fees',
        value: currencyFmt.format(summary.totalPaid),
        subtext: 'Paid via verified digital channels',
        accentColor: AppColors.githubGreen,
        icon: Icons.check_circle_outline,
      ),
      _SummaryCardData(
        title: 'Pending Fines & Penalties',
        value: currencyFmt.format(summary.pendingFines),
        subtext: summary.activeFinesCount > 0
            ? '${summary.activeFinesCount} active infractions'
            : 'Zero pending disciplinary penalties',
        accentColor: summary.pendingFines > 0 ? AppColors.statusRed : AppColors.githubGreen,
        icon: Icons.warning_amber_outlined,
      ),
      _SummaryCardData(
        title: 'Next Settlement Deadline',
        value: summary.nextDueDate != null
            ? dateFmt.format(summary.nextDueDate!)
            : 'No Upcoming Due',
        subtext: summary.nextDueDate != null && summary.nextDueDate!.isBefore(DateTime.now())
            ? 'Action required immediately'
            : 'Payment window active',
        accentColor: AppColors.wineRed,
        icon: Icons.event_available_outlined,
      ),
    ];

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        child: SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cardItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 210,
                child: _buildSummaryCard(cardItems[index], isDark),
              );
            },
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Row(
        children: cardItems.map((item) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildSummaryCard(item, isDark),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCard(_SummaryCardData data, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 16, color: data.accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: data.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 1: FEE INVOICES PORTAL
  // ----------------------------------------------------

  Widget _buildInvoicesPortal(bool isDark, bool isMobile) {
    final filtered = _invoices.where((inv) {
      if (_invoiceFilter == 'all') return true;
      return inv.status.toLowerCase() == _invoiceFilter.toLowerCase();
    }).toList();

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: AppDropdown<String>(
                        key: const Key('filter-fee-invoices-status'),
                        labelText: 'Invoice Status Filter',
                        value: _invoiceFilter,
                        items: const [
                          AppDropdownItem(value: 'all', label: 'All Invoices'),
                          AppDropdownItem(value: InvoiceStatus.pending, label: 'Pending Dues'),
                          AppDropdownItem(value: InvoiceStatus.partial, label: 'Partially Settled'),
                          AppDropdownItem(value: InvoiceStatus.paid, label: 'Fully Paid'),
                          AppDropdownItem(value: InvoiceStatus.overdue, label: 'Overdue Invoices'),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _invoiceFilter = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Showing ${filtered.length} of ${_invoices.length} invoices',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: AppDropdown<String>(
                        key: const Key('filter-fee-invoices-status'),
                        labelText: 'Invoice Status Filter',
                        value: _invoiceFilter,
                        items: const [
                          AppDropdownItem(value: 'all', label: 'All Invoices'),
                          AppDropdownItem(value: InvoiceStatus.pending, label: 'Pending Dues'),
                          AppDropdownItem(value: InvoiceStatus.partial, label: 'Partially Settled'),
                          AppDropdownItem(value: InvoiceStatus.paid, label: 'Fully Paid'),
                          AppDropdownItem(value: InvoiceStatus.overdue, label: 'Overdue Invoices'),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _invoiceFilter = val);
                        },
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Showing ${filtered.length} of ${_invoices.length} invoices',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1),
        // Invoice list
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState('No invoices found matching criteria', isDark)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildInvoiceCard(filtered[index], isDark, isMobile);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceCard(FeeInvoiceModel invoice, bool isDark, bool isMobile) {
    final statusColor = InvoiceStatus.colorFor(invoice.status);
    final isPayable = invoice.dueAmount > 0.001;
    final progress = invoice.totalAmount > 0
        ? (invoice.paidAmount / invoice.totalAmount).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      key: Key('invoice-card-${invoice.id}'),
      child: Material(
        color: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: Key('invoice-expansion-${invoice.id}'),
          initiallyExpanded: isPayable,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.wineRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              FeeType.iconFor(invoice.feeType),
              color: AppColors.wineRed,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  invoice.title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  InvoiceStatus.displayName(invoice.status),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Session: ${invoice.academicYear} | Sem ${invoice.semesterNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Due: ${dateFmt.format(invoice.dueDate)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: invoice.isOverdue ? AppColors.statusRed : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      invoice.isPaid ? AppColors.githubGreen : AppColors.wineRed,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Total: ${currencyFmt.format(invoice.totalAmount)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Paid: ${currencyFmt.format(invoice.paidAmount)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.githubGreen, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Balance: ${currencyFmt.format(invoice.dueAmount)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isPayable ? AppColors.statusAmber : AppColors.githubGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            // Itemized Breakdown
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Itemized Fee Head Breakdown',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (invoice.breakdown.isNotEmpty)
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1.5),
                      },
                      children: invoice.breakdown.map((head) {
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                head.headName,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                currencyFmt.format(head.amount),
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    )
                  else
                    Text(
                      'Single composite fee head item.',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          key: Key('btn-dispute-invoice-${invoice.id}'),
                          onPressed: () => _openDisputeForInvoice(invoice),
                          icon: const Icon(Icons.gavel, size: 16),
                          label: const Text('Dispute Invoice', style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          key: Key('btn-download-invoice-pdf-${invoice.id}'),
                          onPressed: () => _downloadInvoicePdf(invoice),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.wineRed),
                          label: const Text('Download Invoice PDF', style: TextStyle(fontSize: 12)),
                        ),
                        if (isPayable)
                          ElevatedButton.icon(
                            key: Key('btn-pay-fee-${invoice.id}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.wineRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            onPressed: () => _showPayInvoiceDialog(invoice),
                            icon: const Icon(Icons.payment, size: 16),
                            label: Text('Pay Dues (${currencyFmt.format(invoice.dueAmount)})', style: const TextStyle(fontSize: 12)),
                          )
                        else
                          OutlinedButton.icon(
                            key: Key('btn-settled-${invoice.id}'),
                            onPressed: null,
                            icon: const Icon(Icons.check_circle, size: 16, color: AppColors.githubGreen),
                            label: const Text('Invoice Settled in Full', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 2: FINE PORTAL
  // ----------------------------------------------------

  Widget _buildFinesPortal(bool isDark, bool isMobile) {
    final filtered = _fines.where((fine) {
      if (_fineFilter == 'all') return true;
      return fine.status.toLowerCase() == _fineFilter.toLowerCase();
    }).toList();

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: AppDropdown<String>(
                        key: const Key('filter-fines-status'),
                        labelText: 'Fine Status Filter',
                        value: _fineFilter,
                        items: const [
                          AppDropdownItem(value: 'all', label: 'All Penalties'),
                          AppDropdownItem(value: FineStatus.unpaid, label: 'Unpaid Fines'),
                          AppDropdownItem(value: FineStatus.appealed, label: 'Appeals Under Review'),
                          AppDropdownItem(value: FineStatus.paid, label: 'Cleared (Paid)'),
                          AppDropdownItem(value: FineStatus.waived, label: 'Waived by Authority'),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _fineFilter = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Showing ${filtered.length} of ${_fines.length} penalties',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: AppDropdown<String>(
                        key: const Key('filter-fines-status'),
                        labelText: 'Fine Status Filter',
                        value: _fineFilter,
                        items: const [
                          AppDropdownItem(value: 'all', label: 'All Penalties'),
                          AppDropdownItem(value: FineStatus.unpaid, label: 'Unpaid Fines'),
                          AppDropdownItem(value: FineStatus.appealed, label: 'Appeals Under Review'),
                          AppDropdownItem(value: FineStatus.paid, label: 'Cleared (Paid)'),
                          AppDropdownItem(value: FineStatus.waived, label: 'Waived by Authority'),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _fineFilter = val);
                        },
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Showing ${filtered.length} of ${_fines.length} penalties',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1),
        // Fines list
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState('No fines recorded matching criteria', isDark)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildFineCard(filtered[index], isDark, isMobile);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFineCard(FineRecordModel fine, bool isDark, bool isMobile) {
    final statusColor = FineStatus.colorFor(fine.status);
    final canPay = fine.isUnpaid || fine.isAppealed;
    final canAppeal = fine.isUnpaid;

    return Container(
      key: Key('fine-card-${fine.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FineCategory.iconFor(fine.category), size: 18, color: AppColors.wineRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  FineCategory.displayName(fine.category),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  FineStatus.displayName(fine.status),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            fine.reason,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          if (fine.appealReason != null && fine.appealReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.statusAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.statusAmber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Appeal Statement: ${fine.appealReason}',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (fine.waivedBy != null && fine.waivedBy!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.githubGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.githubGreen.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Penalty officially waived by: ${fine.waivedBy}',
                style: const TextStyle(fontSize: 11, color: AppColors.githubGreen, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Issued: ${dateFmt.format(fine.issuedAt)} | Due: ${dateFmt.format(fine.dueDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currencyFmt.format(fine.amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: fine.isPaid ? AppColors.githubGreen : (fine.isWaived ? Colors.grey : AppColors.statusRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: Key('btn-dispute-fine-${fine.id}'),
                  onPressed: () => _openDisputeForFine(fine),
                  icon: const Icon(Icons.gavel, size: 15),
                  label: const Text('Dispute Fine', style: TextStyle(fontSize: 12)),
                ),
                if (canAppeal)
                  OutlinedButton.icon(
                    key: Key('btn-appeal-fine-${fine.id}'),
                    onPressed: () => _showAppealFineDialog(fine),
                    icon: const Icon(Icons.rule_folder_outlined, size: 15),
                    label: const Text('Appeal Fine', style: TextStyle(fontSize: 12)),
                  ),
                if (_canWaiveFines && !fine.isPaid && !fine.isWaived)
                  OutlinedButton.icon(
                    key: Key('btn-waive-fine-${fine.id}'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.statusAmber),
                    onPressed: () => _confirmWaiveFine(fine),
                    icon: const Icon(Icons.cleaning_services_outlined, size: 15),
                    label: const Text('Waive Penalty', style: TextStyle(fontSize: 12)),
                  ),
                if (canPay)
                  ElevatedButton.icon(
                    key: Key('btn-pay-fine-${fine.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wineRed,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showPayFineDialog(fine),
                    icon: const Icon(Icons.payment, size: 15),
                    label: Text('Pay Fine (${currencyFmt.format(fine.amount)})', style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 3: RECORDS & RECEIPTS LEDGER
  // ----------------------------------------------------

  Widget _buildLedgerPortal(bool isDark, bool isMobile) {
    return ValueListenableBuilder<String>(
      valueListenable: _paymentSearchNotifier,
      builder: (context, searchQuery, _) {
        final filtered = _payments.where((p) {
          if (searchQuery.isEmpty) return true;
          final q = searchQuery.toLowerCase();
          return p.receiptNumber.toLowerCase().contains(q) ||
              p.transactionRef.toLowerCase().contains(q) ||
              p.paymentMethod.toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            // Search & Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const Key('input-search-payments'),
                          decoration: InputDecoration(
                            hintText: 'Search by Receipt Number, Ref ID, or Payment Mode...',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                              child: AppSvgIcon(
                                svgString: AppSvgIcon.search,
                                size: 13,
                                strokeWidth: 1.5,
                                color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                              ),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            _paymentSearchNotifier.value = val.trim();
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${filtered.length} receipts found',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('input-search-payments'),
                            decoration: InputDecoration(
                              hintText: 'Search by Receipt Number, Ref ID, or Payment Mode...',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                                child: AppSvgIcon(
                                  svgString: AppSvgIcon.search,
                                  size: 13,
                                  strokeWidth: 1.5,
                                  color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                                ),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              _paymentSearchNotifier.value = val.trim();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${filtered.length} receipts found',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState('No payment transactions or receipts found', isDark)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildPaymentRecordCard(filtered[index], isDark);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentRecordCard(FeePaymentModel payment, bool isDark) {
    return Container(
      key: Key('payment-record-${payment.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.githubGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt, color: AppColors.githubGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        payment.receiptNumber,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.wineRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VERIFIED',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.wineRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Ref: ${payment.transactionRef} | ${dateTimeFmt.format(payment.paidAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFmt.format(payment.amount),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.githubGreen,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                key: Key('btn-view-receipt-${payment.receiptNumber}'),
                onTap: () => _showReceiptDetailsDialog(payment.receiptNumber),
                child: const Text(
                  'View Proof',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.wineRed,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 4: FEE POLICY & SLABS
  // ----------------------------------------------------

  Widget _buildPolicyPortal(bool isDark, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPolicySection(
            title: 'Institutional Fee Settlement Policies',
            content: 'Semester fees must be cleared by the 15th calendar day of each academic semester. Partial fee settlement is permitted in up to two installments with warden/dean permission.',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildPolicySection(
            title: 'Late Surcharge Slabs',
            content: '• Days 1 - 15 past deadline: ₹50 per day late fine.\n• Days 16 - 30 past deadline: ₹100 per day surcharge.\n• Beyond 30 days: Examination hall ticket hold and portal lockout until cleared.',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildPolicySection(
            title: 'Library Overdue Penalties',
            content: 'Standard circulation book: ₹10 per day overdue.\nReference / Reserved shelf material: ₹25 per day overdue.',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildPolicySection(
            title: 'Disciplinary & Hostel Infractions',
            content: 'Late hostel check-in past curfew: ₹500.\nProperty damage: Assessed replacement cost plus ₹1,000 administrative handling penalty.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection({
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // DIALOGS: PAY INVOICE, PAY FINE, APPEAL, RECEIPT
  // ----------------------------------------------------

  Future<void> _downloadInvoicePdf(FeeInvoiceModel invoice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Generating PDF for ${invoice.id}...'),
          duration: const Duration(milliseconds: 900),
        ),
      );

      final bytes = await _facade.downloadInvoicePdf(invoice.id);
      final filename = 'invoice-${invoice.id}.pdf';
      await triggerPdfDownload(filename: filename, bytes: bytes);

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invoice PDF downloaded: $filename (${bytes.length} bytes)'),
          backgroundColor: AppColors.githubGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (err) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to download invoice PDF: $err'),
          backgroundColor: AppColors.statusRed,
        ),
      );
    }
  }

  Future<void> _showPayInvoiceDialog(FeeInvoiceModel invoice) async {
    await showDialog(
      context: context,
      builder: (ctx) => CampusPaymentDialog(
        invoice: invoice,
        facade: _facade,
        studentId: _currentStudentId,
        onPaymentSuccess: _loadFeeData,
      ),
    );
  }

  Future<void> _showPayFineDialog(FineRecordModel fine) async {
    await showDialog(
      context: context,
      builder: (ctx) => CampusPaymentDialog(
        fine: fine,
        facade: _facade,
        studentId: _currentStudentId,
        onPaymentSuccess: _loadFeeData,
      ),
    );
  }

  void _openDisputeForInvoice(FeeInvoiceModel invoice) {
    ComplaintsScreen.showRaiseDisputeDialog(
      context: context,
      storage: widget.storage,
      currentUser: widget.currentUser,
      initialTargetType: DisputeTargetType.fee,
      initialTargetId: invoice.id,
      initialTitle: 'Billing Dispute for Fee Invoice ${invoice.id}',
      initialDescription: 'Contesting billing charges and calculations on invoice ${invoice.id} (${invoice.title}).',
      initialRequestedResolution: 'Adjustment / recalculation of billed amount',
      onSubmitted: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispute raised for Invoice ${invoice.id}. Track under Complaints / Disputes.'),
            backgroundColor: AppColors.wineRed,
          ),
        );
      },
    );
  }

  void _openDisputeForFine(FineRecordModel fine) {
    ComplaintsScreen.showRaiseDisputeDialog(
      context: context,
      storage: widget.storage,
      currentUser: widget.currentUser,
      initialTargetType: DisputeTargetType.fine,
      initialTargetId: fine.id,
      initialTitle: 'Dispute regarding Fine ${fine.id}',
      initialDescription: 'Contesting fine ${fine.id} of amount ${currencyFmt.format(fine.amount)}: ${fine.reason}.',
      initialRequestedResolution: 'Complete waiver of fine due to valid justification',
      onSubmitted: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispute submitted for Fine ${fine.id}. Track under Complaints / Disputes.'),
            backgroundColor: AppColors.wineRed,
          ),
        );
      },
    );
  }

  Future<void> _showAppealFineDialog(FineRecordModel fine) async {
    final messenger = ScaffoldMessenger.of(context);
    final reasonCtrl = TextEditingController();
    String? validationError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            key: const Key('dialog-appeal-fine'),
            title: const Text('Submit Formal Fine Appeal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Penalty: ${FineCategory.displayName(fine.category)} (${currencyFmt.format(fine.amount)})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Infraction Reason: ${fine.reason}', style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('input-appeal-reason'),
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Appeal Statement & Justification',
                      hintText: 'State official grounds for penalty review (medical, authorized lab work, etc.)...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Text(validationError!, style: const TextStyle(fontSize: 11, color: AppColors.statusRed)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                key: const Key('btn-submit-appeal'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.wineRed, foregroundColor: Colors.white),
                onPressed: () async {
                  if (reasonCtrl.text.trim().isEmpty) {
                    setDialogState(() => validationError = 'Explanation is required for appeal submission.');
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await _facade.appealFine(fineId: fine.id, reason: reasonCtrl.text.trim());
                    await _loadFeeData();
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Fine appeal submitted for administrative review.'), backgroundColor: AppColors.githubGreen),
                    );
                  } catch (err) {
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(content: Text('Appeal submission failed: $err'), backgroundColor: AppColors.statusRed),
                    );
                  }
                },
                child: const Text('Submit Appeal'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmWaiveFine(FineRecordModel fine) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('dialog-waive-fine'),
        title: const Text('Confirm Penalty Waiver', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to officially waive the penalty of ${currencyFmt.format(fine.amount)} for ${fine.studentName}? This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            key: const Key('btn-confirm-waive'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusAmber, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Waive Penalty'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authority = widget.currentUser?.fullName ?? 'Institution Administrator';
        await _facade.waiveFine(fineId: fine.id, waivedBy: authority);
        await _loadFeeData();
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(content: Text('Penalty successfully waived.'), backgroundColor: AppColors.githubGreen),
        );
      } catch (err) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text('Waiver failed: $err'), backgroundColor: AppColors.statusRed),
        );
      }
    }
  }

  Future<void> _showReceiptDetailsDialog(String receiptNumber) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final receipt = await _facade.getFeeReceipt(receiptNumber);
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            key: const Key('dialog-view-receipt'),
            title: const Row(
              children: [
                Icon(Icons.verified, color: AppColors.githubGreen, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Official Settlement Receipt',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        children: [
                          Text(
                            receipt.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Receipt ID: Verified Official',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.wineRed),
                          ),
                          const Divider(height: 18),
                          _buildReceiptRow('Student Name', receipt.studentName, isDark),
                          _buildReceiptRow('Campus Handle', receipt.campusHandle, isDark),
                          _buildReceiptRow('Settlement Amount', currencyFmt.format(receipt.amount), isDark, isBold: true),
                          _buildReceiptRow('Payment Mode', receipt.paymentMethod.toUpperCase(), isDark),
                          _buildReceiptRow('Transaction Ref', receipt.transactionRef, isDark),
                          _buildReceiptRow('Issued At', dateTimeFmt.format(receipt.issuedAt), isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tamper-evident proof of settlement issued by BBDIT & BBDIT College of Pharmacy Treasury Operations.',
                      style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      );
    } catch (err) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to load receipt: $err'), backgroundColor: AppColors.statusRed),
      );
    }
  }

  Widget _buildReceiptRow(String label, String value, bool isDark, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCardData {
  final String title;
  final String value;
  final String subtext;
  final Color accentColor;
  final IconData icon;

  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.subtext,
    required this.accentColor,
    required this.icon,
  });
}
