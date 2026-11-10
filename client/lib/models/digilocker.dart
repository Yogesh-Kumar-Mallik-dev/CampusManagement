import 'user.dart';

class DigiLockerAuthResponse {
  final String authUrl;
  final String state;
  final String codeVerifier;
  final String environment;

  DigiLockerAuthResponse({
    required this.authUrl,
    required this.state,
    required this.codeVerifier,
    this.environment = 'sandbox',
  });

  factory DigiLockerAuthResponse.fromJson(Map<String, dynamic> json) {
    return DigiLockerAuthResponse(
      authUrl: json['auth_url'] ?? '',
      state: json['state'] ?? '',
      codeVerifier: json['code_verifier'] ?? '',
      environment: json['environment'] ?? 'sandbox',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auth_url': authUrl,
      'state': state,
      'code_verifier': codeVerifier,
      'environment': environment,
    };
  }
}

class DigiLockerStatusModel {
  final String studentId;
  final bool isConnected;
  final String? abcId;
  final DateTime? verifiedAt;
  final int documentsCount;
  final List<VerifiedDocumentModel> documents;
  final String environmentMode;

  DigiLockerStatusModel({
    required this.studentId,
    required this.isConnected,
    this.abcId,
    this.verifiedAt,
    this.documentsCount = 0,
    this.documents = const [],
    this.environmentMode = 'sandbox',
  });

  factory DigiLockerStatusModel.fromJson(Map<String, dynamic> json) {
    return DigiLockerStatusModel(
      studentId: json['student_id'] ?? '',
      isConnected: json['is_connected'] ?? false,
      abcId: json['abc_id'],
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at']) : null,
      documentsCount: json['documents_count'] ?? 0,
      documents: (json['documents'] as List<dynamic>? ?? [])
          .map((e) => VerifiedDocumentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      environmentMode: json['environment_mode'] ?? 'sandbox',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'is_connected': isConnected,
      'abc_id': abcId,
      'verified_at': verifiedAt?.toIso8601String(),
      'documents_count': documentsCount,
      'documents': documents.map((e) => e.toJson()).toList(),
      'environment_mode': environmentMode,
    };
  }
}
