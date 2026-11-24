import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

enum ResetChannel {
  securityQuestion,
  adminEscalation,
}

/// Dual-channel password reset dialog.
/// Channel A: WhatsApp OTP + Security Question verification.
/// Channel B: WhatsApp OTP + Admin Escalation Ticket with authorization token.
class PasswordResetDialog extends StatefulWidget {
  final OfflineStorageService storage;
  final ValueChanged<UserModel>? onPasswordReset;
  final String? initialIdentifier;

  const PasswordResetDialog({
    super.key,
    required this.storage,
    this.onPasswordReset,
    this.initialIdentifier,
  });

  static Future<UserModel?> show(
    BuildContext context, {
    required OfflineStorageService storage,
    String? initialIdentifier,
  }) {
    return showDialog<UserModel>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PasswordResetDialog(
        storage: storage,
        initialIdentifier: initialIdentifier,
        onPasswordReset: (u) => Navigator.of(context).pop(u),
      ),
    );
  }

  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();
  final _securityAnswerController = TextEditingController();

  // Escalation controllers
  final _escalationReasonController = TextEditingController();
  final _adminTokenController = TextEditingController();

  ResetChannel _selectedChannel = ResetChannel.securityQuestion;
  bool _otpSent = false;
  String? _targetPhoneMasked;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  String? _securityQuestionPrompt;
  ResetEscalationModel? _createdTicket;

  bool _obscureNewPass = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
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
    _securityAnswerController.dispose();
    _escalationReasonController.dispose();
    _adminTokenController.dispose();
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
      final res = await widget.storage.requestResetPasswordOtp(id);
      final sqData = await widget.storage.getSecurityQuestionPrompt(id);

      if (mounted) {
        setState(() {
          _otpSent = true;
          _targetPhoneMasked = res['target_phone_masked'] ?? '';
          _securityQuestionPrompt = sqData['security_question'] ?? 'What was your high school name?';
          _statusMessage = 'WhatsApp reset code sent to $_targetPhoneMasked';
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

  Future<void> _handleResetWithSecurityQuestion() async {
    final id = _identifierController.text.trim();
    final otp = _otpController.text.trim();
    final answer = _securityAnswerController.text.trim();
    final newPass = _newPassController.text;

    if (id.isEmpty || otp.isEmpty) {
      setState(() => _errorMessage = 'Identifier and 6-digit WhatsApp OTP code are required.');
      return;
    }
    if (answer.isEmpty) {
      setState(() => _errorMessage = 'Please provide an answer to your security question.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _errorMessage = 'New password must be at least 6 characters long.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updatedUser = await widget.storage.resetPasswordWithSecurityQuestion(
        identifier: id,
        otpCode: otp,
        securityAnswer: answer,
        newPassword: newPass,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully. You may now sign in with your new password.'),
            backgroundColor: AppColors.githubGreen,
          ),
        );
        if (widget.onPasswordReset != null) {
          widget.onPasswordReset!(updatedUser);
        } else {
          Navigator.of(context).pop(updatedUser);
        }
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

  Future<void> _handleSubmitEscalationTicket() async {
    final id = _identifierController.text.trim();
    final otp = _otpController.text.trim();
    final reason = _escalationReasonController.text.trim();

    if (id.isEmpty || otp.isEmpty) {
      setState(() => _errorMessage = 'Identifier and WhatsApp OTP code are required to verify ownership.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final ticket = await widget.storage.createResetAdminEscalation(
        identifier: id,
        otpCode: otp,
        reason: reason.isNotEmpty ? reason : 'Cannot answer security question; requested IT desk password reset token.',
      );

      if (mounted) {
        setState(() {
          _createdTicket = ticket;
          _statusMessage = 'Escalation ticket ${ticket.ticketNumber} created. Awaiting administrator authorization.';
          _isSubmitting = false;
        });
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

  Future<void> _handleResetWithAdminToken() async {
    final id = _identifierController.text.trim();
    final otp = _otpController.text.trim();
    final adminToken = _adminTokenController.text.trim();
    final newPass = _newPassController.text;

    if (id.isEmpty || otp.isEmpty || adminToken.isEmpty) {
      setState(() => _errorMessage = 'Identifier, WhatsApp OTP, and 6-digit Admin Token are required.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _errorMessage = 'New password must be at least 6 characters long.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updatedUser = await widget.storage.resetPasswordWithAdminToken(
        identifier: id,
        otpCode: otp,
        adminToken: adminToken,
        newPassword: newPass,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password successfully reset via Admin Escalation Token.'),
            backgroundColor: AppColors.githubGreen,
          ),
        );
        if (widget.onPasswordReset != null) {
          widget.onPasswordReset!(updatedUser);
        } else {
          Navigator.of(context).pop(updatedUser);
        }
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
        constraints: const BoxConstraints(maxWidth: 520),
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
                      color: AppColors.wineRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const AppSvgIcon(
                      svgString: AppSvgIcon.lock,
                      size: 22,
                      color: AppColors.wineRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Password Recovery',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'WhatsApp OTP & Verified Credential Recovery',
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

              // Status Banner
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

              // Identifier Input & OTP Trigger
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
                      key: const Key('input-reset-identifier'),
                      controller: _identifierController,
                      decoration: InputDecoration(
                        hintText: 'e.g. sanya_2026_reg_btech_1 or phone',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('btn-request-reset-otp'),
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
                // WhatsApp OTP input
                Text(
                  '6-Digit WhatsApp OTP Code',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('input-reset-otp'),
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter code sent via WhatsApp',
                    prefixIcon: const Icon(Icons.message_outlined, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(height: 16),

                // Channel Tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          key: const Key('tab-reset-channel-question'),
                          onTap: () => setState(() => _selectedChannel = ResetChannel.securityQuestion),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedChannel == ResetChannel.securityQuestion
                                  ? (isDark ? AppColors.darkSurface : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: _selectedChannel == ResetChannel.securityQuestion
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'A. Security Question',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedChannel == ResetChannel.securityQuestion
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedChannel == ResetChannel.securityQuestion
                                      ? AppColors.wineRed
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          key: const Key('tab-reset-channel-escalation'),
                          onTap: () => setState(() => _selectedChannel = ResetChannel.adminEscalation),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedChannel == ResetChannel.adminEscalation
                                  ? (isDark ? AppColors.darkSurface : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: _selectedChannel == ResetChannel.adminEscalation
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'B. Admin Escalation',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedChannel == ResetChannel.adminEscalation
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedChannel == ResetChannel.adminEscalation
                                      ? AppColors.wineRed
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Channel A Content: Security Question
                if (_selectedChannel == ResetChannel.securityQuestion) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Registered Security Question:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          _securityQuestionPrompt ?? 'What was your high school name?',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text('Answer to Security Question', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('input-reset-security-answer'),
                    controller: _securityAnswerController,
                    decoration: InputDecoration(
                      hintText: 'Enter secret answer',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text('New Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('input-reset-new-password'),
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
                  const SizedBox(height: 18),

                  ElevatedButton(
                    key: const Key('btn-submit-reset-question'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wineRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _isSubmitting ? null : _handleResetWithSecurityQuestion,
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Reset Password & Sign In', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],

                // Channel B Content: Admin Escalation
                if (_selectedChannel == ResetChannel.adminEscalation) ...[
                  if (_createdTicket == null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cannot answer your security question? Submitting this request escalates to the Campus IT Helpdesk. Once an administrator approves your identity, they will issue an Admin Reset Token.',
                              style: TextStyle(fontSize: 11.5, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text('Reason / Notes (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('input-reset-escalation-reason'),
                      controller: _escalationReasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Forgot security answer; verified in-person with student ID pass',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    ElevatedButton.icon(
                      key: const Key('btn-submit-reset-escalation'),
                      icon: const Icon(Icons.support_agent, size: 18),
                      label: const Text('Submit Escalation Ticket'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.wineRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmitEscalationTicket,
                    ),
                  ] else ...[
                    // Ticket Created View
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.githubGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.githubGreen.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Ticket: ${_createdTicket!.ticketNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.githubGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Submitted', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.githubGreen)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Provide this ticket number to your department administrator or IT desk to obtain your authorization token.', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  const Divider(height: 24),
                  const Text('Complete Reset with Admin Token', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  Text('6-Digit Admin Authorization Token', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('input-reset-admin-token'),
                    controller: _adminTokenController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Enter 6-digit token provided by Administrator',
                      prefixIcon: const Icon(Icons.key, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text('New Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('input-reset-escalation-new-pass'),
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
                  const SizedBox(height: 18),

                  ElevatedButton(
                    key: const Key('btn-submit-reset-admin-token'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.githubGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _isSubmitting ? null : _handleResetWithAdminToken,
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Reset Password with Admin Authorization', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
