import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

/// Mandatory first-time login security dialog.
///
/// Prompts newly onboarded users whose initial password equals their username
/// to establish a permanent, secure password before accessing institutional workspaces.
class ForcePasswordChangeDialog extends StatefulWidget {
  final UserModel user;
  final OfflineStorageService storage;
  final ValueChanged<UserModel> onPasswordChanged;
  final String? initialPassword;
  final VoidCallback? onCancel;

  const ForcePasswordChangeDialog({
    super.key,
    required this.user,
    required this.storage,
    required this.onPasswordChanged,
    this.initialPassword,
    this.onCancel,
  });

  static Future<UserModel?> show(
    BuildContext context, {
    required UserModel user,
    required OfflineStorageService storage,
    String? initialPassword,
    VoidCallback? onCancel,
  }) {
    return showDialog<UserModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForcePasswordChangeDialog(
        user: user,
        storage: storage,
        initialPassword: initialPassword,
        onPasswordChanged: (updated) => Navigator.of(context).pop(updated),
        onCancel: onCancel ?? () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<ForcePasswordChangeDialog> createState() =>
      _ForcePasswordChangeDialogState();
}

class _ForcePasswordChangeDialogState extends State<ForcePasswordChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _currentController;
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentController = TextEditingController(
      text: widget.initialPassword ?? widget.user.campusHandle,
    );
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentController.text;
    final newPass = _newController.text;
    final confirmPass = _confirmController.text;

    if (newPass.length < 6) {
      setState(() => _errorMessage = 'New password must be at least 6 characters.');
      return;
    }
    if (newPass == currentPass) {
      setState(() => _errorMessage =
          'New password must be different from your temporary initial password.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'New password and confirmation do not match.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updatedUser = await widget.storage.changePassword(
        identifier: widget.user.campusHandle,
        currentPassword: currentPass,
        newPassword: newPass,
      );

      if (mounted) {
        widget.onPasswordChanged(updatedUser);
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

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Security Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0969DA).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const AppSvgIcon(
                          svgString: AppSvgIcon.shield,
                          size: 22,
                          color: Color(0xFF0969DA),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Password Change Required',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'First-time login security verification',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Institutional notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2638)
                          : const Color(0xFFF1F6FD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF0969DA).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Activation for ${widget.user.fullName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0969DA),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your account was initialized with your username (${widget.user.campusHandle}) as the temporary password. To protect your records and institutional access, please set a permanent personal password.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Current / Temporary Password
                  _buildPasswordField(
                    label: 'Current Temporary Password',
                    controller: _currentController,
                    obscure: _obscureCurrent,
                    onToggleObscure: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                    hintText: 'Enter temporary password',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // New Password
                  _buildPasswordField(
                    label: 'New Permanent Password',
                    controller: _newController,
                    obscure: _obscureNew,
                    onToggleObscure: () =>
                        setState(() => _obscureNew = !_obscureNew),
                    hintText: 'Minimum 6 characters',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Confirm New Password
                  _buildPasswordField(
                    label: 'Confirm New Password',
                    controller: _confirmController,
                    obscure: _obscureConfirm,
                    onToggleObscure: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    hintText: 'Re-enter new password',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 22),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('btn-cancel-password-change'),
                          onPressed: _isSubmitting ? null : widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          key: const Key('btn-submit-password-change'),
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0969DA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Set Password & Continue',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String hintText,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.1,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextPlaceholder
                    : AppColors.lightTextPlaceholder,
                letterSpacing: -0.1,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  size: 16,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                onPressed: onToggleObscure,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
