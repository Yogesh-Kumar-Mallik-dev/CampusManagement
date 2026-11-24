import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

/// Interactive modal for first-time user activation via WhatsApp OTP.
/// Prompts newly onboarded users to verify their WhatsApp number,
/// establish a permanent password, and configure their recovery security question.
class FirstLoginOtpDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final ValueChanged<UserModel> onSuccess;
  final String? initialIdentifier;

  const FirstLoginOtpDialog({
    super.key,
    required this.storage,
    required this.onSuccess,
    this.initialIdentifier,
  });

  static Future<UserModel?> show(
    BuildContext context, {
    required OfflineStorageService storage,
    String? initialIdentifier,
  }) {
    return showDialog<UserModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FirstLoginOtpDialog(
        storage: storage,
        initialIdentifier: initialIdentifier,
        onSuccess: (u) => Navigator.of(context).pop(u),
      ),
    );
  }

  @override
  State<FirstLoginOtpDialog> createState() => _FirstLoginOtpDialogState();
}

class _FirstLoginOtpDialogState extends State<FirstLoginOtpDialog> {
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _securityAnswerController = TextEditingController();

  static const List<String> standardSecurityQuestions = [
    'What was the name of your first school?',
    'What is your mother\'s maiden name?',
    'What was the model of your first vehicle?',
    'In what city was your first academic admission?',
    'What is your favorite academic subject?',
  ];

  late String _selectedQuestion;
  bool _otpSent = false;
  String? _targetPhoneMasked;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _selectedQuestion = standardSecurityQuestions.first;
    if (widget.initialIdentifier != null && widget.initialIdentifier!.isNotEmpty) {
      _identifierController.text = widget.initialIdentifier!;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _identifierController.dispose();
    _otpController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownSeconds = seconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 1) {
          _cooldownSeconds--;
        } else {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleRequestOtp() async {
    final id = _identifierController.text.trim();
    if (id.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Campus Handle, email, or registered phone.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final res = await widget.storage.requestFirstLoginOtp(id);
      if (mounted) {
        setState(() {
          _otpSent = true;
          _targetPhoneMasked = res['target_phone_masked'] ?? '';
          _statusMessage = 'WhatsApp verification code sent to $_targetPhoneMasked';
          _isSubmitting = false;
        });
        _startCooldown(res['resend_cooldown_seconds'] ?? 60);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleSubmitActivation() async {
    final id = _identifierController.text.trim();
    final otp = _otpController.text.trim();
    final newPass = _newPassController.text;
    final confirmPass = _confirmPassController.text;
    final answer = _securityAnswerController.text.trim();

    if (id.isEmpty || otp.isEmpty) {
      setState(() => _errorMessage = 'Identifier and 6-digit WhatsApp OTP code are required.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _errorMessage = 'New password must be at least 6 characters long.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'New password and confirmation do not match.');
      return;
    }
    if (answer.isEmpty) {
      setState(() => _errorMessage = 'Please provide an answer to your recovery security question.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = await widget.storage.verifyFirstLoginAndSetPassword(
        identifier: id,
        otpCode: otp,
        newPassword: newPass,
        securityQuestion: _selectedQuestion,
        securityAnswer: answer,
      );

      if (mounted) {
        widget.onSuccess(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.githubGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const AppSvgIcon(
                      svgString: AppSvgIcon.shield,
                      size: 22,
                      color: AppColors.githubGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Activation',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'First-time login via WhatsApp OTP',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status / Info Banner
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.githubGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.githubGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppColors.githubGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(fontSize: 12, color: AppColors.githubGreen, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Error Banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.wineRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.wineRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: AppColors.wineRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: AppColors.wineRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Step 1: Campus Handle / Phone Identifier
              Text(
                'Campus Handle, Email, or WhatsApp Number',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('input-first-login-identifier'),
                      controller: _identifierController,
                      decoration: InputDecoration(
                        hintText: 'e.g. rohit_2026_reg_btech_1 or phone',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('btn-request-first-login-otp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wineRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _isSubmitting || _cooldownSeconds > 0 ? null : _handleRequestOtp,
                    child: Text(
                      _cooldownSeconds > 0 ? '${_cooldownSeconds}s' : (_otpSent ? 'Resend' : 'Send OTP'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_otpSent) ...[
                // Step 2: 6-Digit WhatsApp OTP Code
                Text(
                  '6-Digit WhatsApp Verification Code',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('input-first-login-otp'),
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter 6-digit code received on WhatsApp',
                    prefixIcon: const Icon(Icons.message_outlined, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(height: 14),

                // Step 3: Establish New Password
                Text(
                  'Create Permanent Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('input-first-login-new-pass'),
                  controller: _newPassController,
                  obscureText: _obscureNewPass,
                  decoration: InputDecoration(
                    hintText: 'Minimum 6 characters',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPass ? Icons.visibility : Icons.visibility_off, size: 18),
                      onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  'Confirm Permanent Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('input-first-login-confirm-pass'),
                  controller: _confirmPassController,
                  obscureText: _obscureConfirmPass,
                  decoration: InputDecoration(
                    hintText: 'Re-enter password to confirm',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPass ? Icons.visibility : Icons.visibility_off, size: 18),
                      onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Step 4: Security Question Setup
                Text(
                  'Recovery Security Question',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: const Key('dropdown-first-login-security-question'),
                  initialValue: _selectedQuestion,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  items: standardSecurityQuestions.map((q) {
                    return DropdownMenuItem(
                      value: q,
                      child: Text(q, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedQuestion = val);
                  },
                ),
                const SizedBox(height: 10),

                Text(
                  'Security Question Answer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('input-first-login-security-answer'),
                  controller: _securityAnswerController,
                  decoration: InputDecoration(
                    hintText: 'Secret answer (used for self-service password reset)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  key: const Key('btn-submit-first-login-activation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.githubGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmitActivation,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Activate Account & Enter CampusOS',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
