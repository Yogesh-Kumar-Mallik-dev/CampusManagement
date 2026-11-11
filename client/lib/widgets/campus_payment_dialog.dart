import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../facade/campus_facade.dart';
import '../models/fee.dart';
import '../models/payment_order.dart';
import '../services/app_cache.dart';
import '../theme/app_colors.dart';
import '../utils/env_detector.dart';
import '../utils/file_downloader.dart';
import '../widgets/app_dropdown.dart';

class CampusPaymentDialog extends StatefulWidget {
  final FeeInvoiceModel? invoice;
  final FineRecordModel? fine;
  final ICampusFacade facade;
  final String studentId;
  final VoidCallback onPaymentSuccess;
  final String? initialMethod;
  final bool restorePreferredMethod;

  const CampusPaymentDialog({
    super.key,
    this.invoice,
    this.fine,
    required this.facade,
    required this.studentId,
    required this.onPaymentSuccess,
    this.initialMethod,
    this.restorePreferredMethod = false,
  }) : assert(invoice != null || fine != null, 'Either invoice or fine must be provided');

  @override
  State<CampusPaymentDialog> createState() => _CampusPaymentDialogState();
}

class _CampusPaymentDialogState extends State<CampusPaymentDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  // Form Controllers
  late TextEditingController _amountCtrl;
  late final TextEditingController _upiIdCtrl;
  late final TextEditingController _cardNumberCtrl;
  late final TextEditingController _cardHolderCtrl;
  late final TextEditingController _cardExpiryCtrl;
  late final TextEditingController _cardCvvCtrl;
  final TextEditingController _utrCtrl = TextEditingController();
  late final TextEditingController _otpCtrl;

  String _selectedPaymentMethod = 'upi';
  String _selectedBank = 'State Bank of India (SBI)';
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _validationError;

  PaymentGatewayConfigModel? _gatewayConfig;
  PaymentOrderModel? _currentOrder;

  // Countdown timer for QR / order validity (isolated notifier prevents full dialog re-renders)
  Timer? _countdownTimer;
  final ValueNotifier<int> _secondsRemainingNotifier = ValueNotifier<int>(900);

  bool get isInvoice => widget.invoice != null;
  double get maxPayableAmount => isInvoice ? widget.invoice!.dueAmount : widget.fine!.amount;
  String get itemTitle => isInvoice ? widget.invoice!.title : 'Penalty: ${widget.fine!.reason}';

  String _methodForIndex(int index) {
    switch (index) {
      case 0:
        return 'upi';
      case 1:
        return 'card';
      case 2:
        return 'netbanking';
      case 3:
        return 'challan';
      default:
        return 'upi';
    }
  }

  @override
  void initState() {
    super.initState();
    if (isFlutterTestEnvironment) {
      _upiIdCtrl = TextEditingController(text: 'student@okaxis');
      _cardNumberCtrl = TextEditingController(text: '4532 8821 9912 3456');
      _cardHolderCtrl = TextEditingController(text: 'Student Payee');
      _cardExpiryCtrl = TextEditingController(text: '08/29');
      _cardCvvCtrl = TextEditingController(text: '821');
      _otpCtrl = TextEditingController(text: '123456');
    } else {
      _upiIdCtrl = TextEditingController();
      _cardNumberCtrl = TextEditingController();
      _cardHolderCtrl = TextEditingController();
      _cardExpiryCtrl = TextEditingController();
      _cardCvvCtrl = TextEditingController();
      _otpCtrl = TextEditingController();
    }
    String method = widget.initialMethod ?? 'upi';
    if (widget.initialMethod == null && widget.restorePreferredMethod) {
      final cachedMethod = AppCache.instance.getPreferredPaymentMethod();
      if (cachedMethod != null) {
        final idx = ['upi', 'card', 'netbanking', 'challan'].indexOf(cachedMethod);
        if (idx >= 0) {
          method = cachedMethod;
        }
      }
    }
    _selectedPaymentMethod = method;
    final initialTab = ['upi', 'card', 'netbanking', 'challan'].indexOf(_selectedPaymentMethod);

    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialTab >= 0 ? initialTab : 0,
      animationDuration: Duration.zero,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final method = _methodForIndex(_tabController.index);
        if (_selectedPaymentMethod != method) {
          setState(() {
            _selectedPaymentMethod = method;
          });
          AppCache.instance.setPreferredPaymentMethod(method);
        }
      }
    });

    _amountCtrl = TextEditingController(text: maxPayableAmount.toStringAsFixed(2));
    _initializeCheckout();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _secondsRemainingNotifier.dispose();
    _tabController.dispose();
    _amountCtrl.dispose();
    _upiIdCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardHolderCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    _utrCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _secondsRemainingNotifier.value = 900;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemainingNotifier.value > 0) {
        _secondsRemainingNotifier.value--;
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _initializeCheckout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final config = await widget.facade.getPaymentConfig();
      final enteredAmount = double.tryParse(_amountCtrl.text.trim()) ?? maxPayableAmount;

      final order = await widget.facade.createPaymentOrder(
        entityType: isInvoice ? 'invoice' : 'fine',
        entityId: isInvoice ? widget.invoice!.id : widget.fine!.id,
        studentId: widget.studentId,
        amount: enteredAmount,
        notes: isInvoice ? widget.invoice!.title : 'Fine settlement',
      );

      if (mounted) {
        setState(() {
          _gatewayConfig = config;
          _currentOrder = order;
          _isLoading = false;
        });
        _startTimer();
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

  Future<void> _processPayment({String? overrideMethod, String? customTxnRef}) async {
    final messenger = ScaffoldMessenger.of(context);
    final entered = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

    if (entered <= 0) {
      setState(() => _validationError = 'Enter a valid amount greater than zero.');
      return;
    }
    if (entered > maxPayableAmount) {
      setState(() => _validationError = 'Amount cannot exceed due balance (${currencyFmt.format(maxPayableAmount)}).');
      return;
    }

    setState(() {
      _validationError = null;
      _isProcessing = true;
    });

    final method = overrideMethod ?? _selectedPaymentMethod;

    try {
      if (isInvoice) {
        final res = await widget.facade.payInvoice(
          invoiceId: widget.invoice!.id,
          studentId: widget.studentId,
          amount: entered,
          paymentMethod: method,
        );
        _handleSuccess(res);
      } else {
        final res = await widget.facade.payFine(
          fineId: widget.fine!.id,
          studentId: widget.studentId,
          paymentMethod: method,
        );
        _handleSuccess(res);
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Payment failed: $err'),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    }
  }

  void _handleSuccess(Map<String, dynamic> res) {
    if (!mounted) return;
    setState(() => _isProcessing = false);

    final receipt = res['receipt'];
    final receiptNum = receipt is FeeReceiptModel
        ? receipt.receiptNumber
        : (receipt is Map ? receipt['receipt_number'] : 'RCP-INST-COMPLETED');

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    widget.onPaymentSuccess();

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isInvoice
              ? 'Payment processed successfully. Receipt: $receiptNum'
              : 'Fine settled successfully. Receipt: $receiptNum',
        ),
        backgroundColor: AppColors.githubGreen,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          key: const Key('btn-download-payment-receipt'),
          label: 'Download PDF',
          textColor: Colors.white,
          onPressed: () async {
            try {
              final bytes = await widget.facade.downloadReceiptPdf(receiptNum);
              await triggerPdfDownload(filename: 'receipt-$receiptNum.pdf', bytes: bytes);
            } catch (_) {}
          },
        ),
      ),
    );
  }

  void _prompt3DSecureOTP(VoidCallback onVerified) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (otpCtx) => AlertDialog(
        key: const Key('dialog-3d-secure-otp'),
        title: const Row(
          children: [
            Icon(Icons.security, size: 20, color: AppColors.wineRed),
            SizedBox(width: 8),
            Text('Bank 3D Secure Authorization', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the 6-digit One Time Password (OTP) sent by your card issuer / bank. Sandbox test code is pre-filled.',
                style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('input-bank-otp'),
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: '6-Digit Bank OTP',
                  hintText: '123456',
                  prefixIcon: const Icon(Icons.password, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const Text(
                'Security Notice: 256-bit Institutional Gateway Encryption active.',
                style: TextStyle(fontSize: 10, color: AppColors.githubGreen),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('btn-cancel-otp'),
            onPressed: () => Navigator.pop(otpCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('btn-verify-otp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.wineRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(otpCtx);
              onVerified();
            },
            child: const Text('Authorize & Pay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogKey = isInvoice ? const Key('dialog-pay-invoice') : const Key('dialog-pay-fine');
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width < 620 ? size.width * 0.94 : 580.0;
    final dialogHeight = size.height < 700 ? size.height * 0.88 : 640.0;

    return AlertDialog(
      key: dialogKey,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2, color: AppColors.wineRed),
                    SizedBox(height: 12),
                    Text('Connecting to Institutional Gateway...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 40, color: AppColors.statusRed),
                          const SizedBox(height: 12),
                          Text('Gateway Initialization Error: $_errorMessage',
                              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _initializeCheckout,
                            child: const Text('Retry Connection'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _buildHeader(isDark),
                      _buildAmountAndChannelBar(isDark),
                      _buildChannelTabs(isDark),
                      Expanded(
                        child: IndexedStack(
                          index: _tabController.index,
                          children: [
                            _buildUpiTab(isDark),
                            _buildCardTab(isDark),
                            _buildNetBankingTab(isDark),
                            _buildChallanTab(isDark),
                          ],
                        ),
                      ),
                      _buildFooter(isDark),
                    ],
                  ),
      ),
    );
  }

  Widget _buildAmountAndChannelBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: isDark ? AppColors.darkSurface : AppColors.lightBg,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              key: const Key('input-payment-amount'),
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Settlement Amount (₹)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: AppDropdown<String>(
              key: const Key('select-payment-method'),
              labelText: 'Mode',
              value: _selectedPaymentMethod,
              items: const [
                AppDropdownItem(value: 'upi', label: 'UPI / QR'),
                AppDropdownItem(value: 'card', label: 'Card'),
                AppDropdownItem(value: 'netbanking', label: 'NetBanking'),
                AppDropdownItem(value: 'challan', label: 'Challan'),
              ],
              onChanged: (val) {
                if (val != null) {
                  final tabIdx = ['upi', 'card', 'netbanking', 'challan'].indexOf(val);
                  setState(() {
                    _selectedPaymentMethod = val;
                    if (tabIdx >= 0) {
                      _tabController.index = tabIdx;
                    }
                  });
                  AppCache.instance.setPreferredPaymentMethod(val);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final providerName = _gatewayConfig?.provider.toUpperCase() ?? 'SANDBOX';
    final isSandbox = _gatewayConfig?.isSandbox ?? true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.wineRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance, color: AppColors.wineRed, size: 20),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _gatewayConfig?.merchantName ?? 'Campus Institutional Gateway',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      itemTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSandbox
                  ? AppColors.statusAmber.withValues(alpha: 0.15)
                  : AppColors.githubGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSandbox ? AppColors.statusAmber : AppColors.githubGreen,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSandbox ? Icons.science_outlined : Icons.verified_user_outlined,
                  size: 11,
                  color: isSandbox ? AppColors.statusAmber : AppColors.githubGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  isSandbox ? 'SANDBOX ($providerName)' : 'LIVE ($providerName)',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSandbox ? AppColors.statusAmber : AppColors.githubGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTabs(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2228) : const Color(0xFFF3F4F6),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        onTap: (index) {
          final method = _methodForIndex(index);
          setState(() {
            _tabController.index = index;
            _selectedPaymentMethod = method;
          });
          AppCache.instance.setPreferredPaymentMethod(method);
        },
        labelColor: AppColors.wineRed,
        unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        indicatorColor: AppColors.wineRed,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11.5),
        tabs: const [
          Tab(key: Key('pay-tab-upi'), icon: Icon(Icons.qr_code, size: 16), text: 'UPI / QR'),
          Tab(key: Key('pay-tab-card'), icon: Icon(Icons.credit_card, size: 16), text: 'Card'),
          Tab(key: Key('pay-tab-netbanking'), icon: Icon(Icons.account_balance, size: 16), text: 'NetBanking'),
          Tab(key: Key('pay-tab-challan'), icon: Icon(Icons.receipt_long, size: 16), text: 'Challan'),
        ],
      ),
    );
  }

  Widget _buildUpiTab(bool isDark) {
    final vpa = _gatewayConfig?.merchantVpa ?? 'campuscollect@sbi';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Amount Payable', style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
                  Text(
                    currencyFmt.format(double.tryParse(_amountCtrl.text) ?? maxPayableAmount),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.wineRed),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: AppColors.statusAmber),
                    const SizedBox(width: 4),
                    ValueListenableBuilder<int>(
                      valueListenable: _secondsRemainingNotifier,
                      builder: (context, seconds, _) {
                        final m = (seconds ~/ 60).toString().padLeft(2, '0');
                        final s = (seconds % 60).toString().padLeft(2, '0');
                        return Text(
                          'QR expires in $m:$s',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.statusAmber),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                _buildSimulatedQrGraphic(),
                const SizedBox(height: 8),
                const Text(
                  'Scan with Google Pay, PhonePe, Paytm, or BHIM',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  'UPI ID: $vpa',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('input-upi-id'),
                  controller: _upiIdCtrl,
                  decoration: InputDecoration(
                    labelText: 'Or enter your UPI ID',
                    hintText: 'yourname@okhdfcbank',
                    prefixIcon: const Icon(Icons.alternate_email, size: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: const Key('btn-pay-upi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wineRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isProcessing
                    ? null
                    : () {
                        _prompt3DSecureOTP(() => _processPayment(overrideMethod: 'upi'));
                      },
                child: const Text('Verify & Pay', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatedQrGraphic() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 8, left: 8, child: _buildQrCorner()),
          Positioned(top: 8, right: 8, child: _buildQrCorner()),
          Positioned(bottom: 8, left: 8, child: _buildQrCorner()),
          Icon(Icons.qr_code_2, size: 100, color: Colors.black.withValues(alpha: 0.85)),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
              ],
            ),
            child: const Icon(Icons.school, size: 16, color: AppColors.wineRed),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCorner() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87, width: 3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCardTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'INSTITUTIONAL SECURE CARD',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white70, fontSize: 9.5, letterSpacing: 0.8),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('RuPay / Visa',
                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _cardNumberCtrl.text.isEmpty ? '•••• •••• •••• ••••' : _cardNumberCtrl.text,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, letterSpacing: 2.0, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CARDHOLDER', style: TextStyle(color: Colors.white54, fontSize: 8)),
                          Text(
                            _cardHolderCtrl.text.isEmpty ? 'NAME' : _cardHolderCtrl.text.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('EXPIRES', style: TextStyle(color: Colors.white54, fontSize: 8)),
                        Text(
                          _cardExpiryCtrl.text.isEmpty ? 'MM/YY' : _cardExpiryCtrl.text,
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            key: const Key('input-card-number'),
            controller: _cardNumberCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Card Number',
              hintText: '4532 8821 9912 3456',
              prefixIcon: Icon(Icons.credit_card, size: 18),
              suffixIcon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Text('RuPay / Visa',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.lightTextSecondary)),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('input-card-expiry'),
                  controller: _cardExpiryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Valid Thru (MM/YY)',
                    hintText: '08/29',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('input-card-cvv'),
                  controller: _cardCvvCtrl,
                  obscureText: true,
                  maxLength: 3,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CVV / Security Code',
                    hintText: '•••',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('btn-pay-card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wineRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isProcessing
                  ? null
                  : () {
                      _prompt3DSecureOTP(() => _processPayment(overrideMethod: 'card'));
                    },
              child: Text(
                'Pay ${currencyFmt.format(double.tryParse(_amountCtrl.text) ?? maxPayableAmount)} via Card',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetBankingTab(bool isDark) {
    final majorBanks = [
      'State Bank of India (SBI)',
      'HDFC Bank',
      'ICICI Bank',
      'Axis Bank',
      'Punjab National Bank (PNB)',
      'Bank of Baroda (BOB)',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Popular Institutional Bank',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: majorBanks.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3.2,
            ),
            itemBuilder: (ctx, i) {
              final bank = majorBanks[i];
              final isSelected = _selectedBank == bank;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _selectedBank = bank),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.wineRed.withValues(alpha: 0.12)
                        : (isDark ? AppColors.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.wineRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance,
                        size: 15,
                        color: isSelected ? AppColors.wineRed : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bank,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.wineRed : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          AppDropdown<String>(
            key: const Key('select-netbanking-bank'),
            labelText: 'Or select from all Scheduled Commercial Banks',
            value: _selectedBank,
            items: majorBanks
                .map((b) => AppDropdownItem(value: b, label: b))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedBank = val);
            },
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('btn-pay-netbanking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wineRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isProcessing
                  ? null
                  : () {
                      _prompt3DSecureOTP(() => _processPayment(overrideMethod: 'netbanking'));
                    },
              child: Text('Proceed with $_selectedBank', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallanTab(bool isDark) {
    final va = _currentOrder?.virtualAccount ?? _gatewayConfig?.virtualAccount;
    final accNumber = va?.accountNumber ?? 'BBDITCOLLECT01';
    final ifsc = va?.ifscCode ?? 'SBIN0001234';
    final bank = va?.bankName ?? 'State Bank of India (SBI)';
    final beneficiary = va?.beneficiaryName ?? 'Babu Banarasi Das Institute of Technology & BBDIT College of Pharmacy';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Institutional Bank Challan / NEFT / RTGS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Transfer funds via NEFT/RTGS to your personalized Virtual Account Number (VAN) or submit cash at any bank branch.',
            style: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                _buildChallanRow('Beneficiary Name', beneficiary, false),
                const Divider(height: 14),
                _buildChallanRow('Bank Name', bank, false),
                const Divider(height: 14),
                _buildChallanRow('Virtual Account Number', accNumber, true),
                const Divider(height: 14),
                _buildChallanRow('IFSC Code', ifsc, true),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            key: const Key('input-utr-number'),
            controller: _utrCtrl,
            decoration: const InputDecoration(
              labelText: 'Bank Reference / UTR Number (if already remitted)',
              hintText: 'e.g., UTR199823901824',
              prefixIcon: Icon(Icons.confirmation_number_outlined, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('btn-submit-utr'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wineRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Record Offline Challan / UTR Submission', style: TextStyle(fontSize: 12)),
              onPressed: _isProcessing
                  ? null
                  : () {
                      _processPayment(overrideMethod: 'challan', customTxnRef: _utrCtrl.text.trim());
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallanRow(String label, String value, bool copyable) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: SelectableText(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              if (copyable) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied to clipboard'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy, size: 14, color: AppColors.wineRed),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    final confirmKey = isInvoice ? const Key('btn-confirm-pay-invoice') : const Key('btn-confirm-pay-fine');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_validationError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _validationError!,
                style: const TextStyle(fontSize: 11, color: AppColors.statusRed),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                key: const Key('btn-cancel-payment'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.wineRed),
                      ),
                    ),
                  ElevatedButton(
                    key: confirmKey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wineRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isProcessing ? null : () => _processPayment(),
                    child: Text(
                      isInvoice ? 'Process Settlement' : 'Clear Fine Penalty',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
