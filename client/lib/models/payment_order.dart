class VirtualAccountModel {
  final String beneficiaryName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String branchName;
  final String referenceVan;

  const VirtualAccountModel({
    required this.beneficiaryName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.branchName,
    required this.referenceVan,
  });

  factory VirtualAccountModel.fromJson(Map<String, dynamic> json) {
    return VirtualAccountModel(
      beneficiaryName: json['beneficiary_name'] as String? ?? 'Babu Banarasi Das Institute of Technology & BBDIT College of Pharmacy',
      bankName: json['bank_name'] as String? ?? 'State Bank of India (SBI)',
      accountNumber: json['account_number'] as String? ?? 'BBDITCOLLECT01',
      ifscCode: json['ifsc_code'] as String? ?? 'SBIN0001234',
      branchName: json['branch_name'] as String? ?? 'Main Branch',
      referenceVan: json['reference_van'] as String? ?? 'BBDIT-VAN',
    );
  }

  Map<String, dynamic> toJson() => {
        'beneficiary_name': beneficiaryName,
        'bank_name': bankName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'branch_name': branchName,
        'reference_van': referenceVan,
      };
}

class PaymentGatewayConfigModel {
  final String provider;
  final String keyId;
  final String merchantName;
  final String merchantVpa;
  final String environment;
  final List<String> supportedMethods;
  final VirtualAccountModel? virtualAccount;

  const PaymentGatewayConfigModel({
    required this.provider,
    required this.keyId,
    required this.merchantName,
    required this.merchantVpa,
    required this.environment,
    required this.supportedMethods,
    this.virtualAccount,
  });

  bool get isSandbox => environment.toLowerCase() == 'sandbox';

  factory PaymentGatewayConfigModel.fromJson(Map<String, dynamic> json) {
    return PaymentGatewayConfigModel(
      provider: json['provider'] as String? ?? 'sandbox',
      keyId: json['key_id'] as String? ?? 'sandbox_inst_key_campus_9901',
      merchantName: json['merchant_name'] as String? ?? 'Babu Banarasi Das Institute of Technology & BBDIT College of Pharmacy',
      merchantVpa: json['merchant_vpa'] as String? ?? 'bbditfees@sbi',
      environment: json['environment'] as String? ?? 'sandbox',
      supportedMethods: (json['supported_methods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['upi', 'debit_card', 'credit_card', 'net_banking', 'challan'],
      virtualAccount: json['virtual_account'] != null
          ? VirtualAccountModel.fromJson(json['virtual_account'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'key_id': keyId,
        'merchant_name': merchantName,
        'merchant_vpa': merchantVpa,
        'environment': environment,
        'supported_methods': supportedMethods,
        'virtual_account': virtualAccount?.toJson(),
      };
}

class PaymentOrderModel {
  final String orderId;
  final String entityType; // invoice, fine
  final String entityId;
  final String studentId;
  final String studentName;
  final double amount;
  final String currency;
  final String status;
  final String gatewayProvider;
  final String gatewayOrderId;
  final String gatewayKeyId;
  final String upiLink;
  final VirtualAccountModel? virtualAccount;
  final String notes;
  final DateTime? expiresAt;

  const PaymentOrderModel({
    required this.orderId,
    required this.entityType,
    required this.entityId,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.gatewayProvider,
    required this.gatewayOrderId,
    required this.gatewayKeyId,
    required this.upiLink,
    this.virtualAccount,
    this.notes = '',
    this.expiresAt,
  });

  factory PaymentOrderModel.fromJson(Map<String, dynamic> json) {
    return PaymentOrderModel(
      orderId: json['order_id'] as String? ?? '',
      entityType: json['entity_type'] as String? ?? 'invoice',
      entityId: json['entity_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String? ?? 'created',
      gatewayProvider: json['gateway_provider'] as String? ?? 'sandbox',
      gatewayOrderId: json['gateway_order_id'] as String? ?? '',
      gatewayKeyId: json['gateway_key_id'] as String? ?? '',
      upiLink: json['upi_link'] as String? ?? '',
      virtualAccount: json['virtual_account'] != null
          ? VirtualAccountModel.fromJson(json['virtual_account'] as Map<String, dynamic>)
          : null,
      notes: json['notes'] as String? ?? '',
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'entity_type': entityType,
        'entity_id': entityId,
        'student_id': studentId,
        'student_name': studentName,
        'amount': amount,
        'currency': currency,
        'status': status,
        'gateway_provider': gatewayProvider,
        'gateway_order_id': gatewayOrderId,
        'gateway_key_id': gatewayKeyId,
        'upi_link': upiLink,
        'virtual_account': virtualAccount?.toJson(),
        'notes': notes,
        'expires_at': expiresAt?.toIso8601String(),
      };
}
