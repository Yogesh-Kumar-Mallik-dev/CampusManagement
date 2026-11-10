import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_logo.dart';
import '../widgets/smooth_theme_toggle.dart';

class LoginScreen extends StatefulWidget {
  final OfflineStorageService storage;
  final ValueChanged<UserModel> onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.storage,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController(text: 'harish_2025_l_btech_1');
  final _passwordController = TextEditingController(text: 'campus2026!');

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await widget.storage.authenticate(
        _identifierController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        widget.onLoginSuccess(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication failed. Please verify your handle and password.';
          _isLoading = false;
        });
      }
    }
  }

  void _fillPersona({required String handle, required String role}) {
    setState(() {
      _identifierController.text = handle;
      _passwordController.text = 'campus2026!';
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Smooth Animated Theme Toggle
          const Positioned(
            top: 16,
            right: 16,
            child: SmoothThemeToggle(),
          ),

          // Strictly Non-Scrollable Centered Login Container
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // High-Definition Emblem
                          const Center(
                            child: AppLogo(height: 52),
                          ),
                          const SizedBox(height: 16),

                          // Title & Subtitle
                          Text(
                            'Institutional Sign In',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Babu Banarasi Das Institute of Technology & BBDIT College of Pharmacy',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your canonical campus handle or email',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Error Banner (if any)
                          if (_errorMessage != null) ...[
                            Builder(
                              builder: (context) {
                                final redBadge = AppColors.redBadge(isDark);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: redBadge.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: redBadge.border, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      AppSvgIcon(
                                        svgString: AppSvgIcon.alertTriangle,
                                        size: 15,
                                        color: redBadge.text,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: redBadge.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Identifier Field
                          Text(
                            'Campus Handle or Email',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _identifierController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'e.g. harish_2025_l_btech_1',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                                child: AppSvgIcon(
                                  svgString: AppSvgIcon.user,
                                  size: 13,
                                  strokeWidth: 1.5,
                                  color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Campus handle or email is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password Field
                          Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Enter account password',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                                child: AppSvgIcon(
                                  svgString: AppSvgIcon.lock,
                                  size: 13,
                                  strokeWidth: 1.5,
                                  color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                                ),
                              ),
                              suffixIcon: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: AppSvgIcon(
                                  svgString: _obscurePassword ? AppSvgIcon.eye : AppSvgIcon.eyeOff,
                                  size: 13,
                                  strokeWidth: 1.5,
                                  color: isDark ? AppColors.darkTextPlaceholder : AppColors.lightTextPlaceholder,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Remember Me Checkbox
                          Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppColors.wineRed,
                                  onChanged: (val) {
                                    setState(() => _rememberMe = val ?? true);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Keep signed in on this workstation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Sign In Button
                          SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.wineRed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign In',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        SizedBox(width: 8),
                                        AppSvgIcon(
                                          svgString: AppSvgIcon.arrowRight,
                                          size: 15,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Quick Access Personas (1-Click Fill)
                          Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          const SizedBox(height: 10),
                          Text(
                            'Quick Access Personas (1-Click Fill)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildQuickPersonaChip(
                                label: 'Student',
                                handle: 'harish_2025_l_btech_1',
                                badgeStyle: AppColors.primaryBadge(isDark),
                              ),
                              _buildQuickPersonaChip(
                                label: 'Faculty',
                                handle: 'priya_2024_emp_1',
                                badgeStyle: AppColors.greenBadge(isDark),
                              ),
                              _buildQuickPersonaChip(
                                label: 'Security',
                                handle: 'ramesh_2023_emp_1',
                                badgeStyle: AppColors.neutralBadge(isDark),
                              ),
                              _buildQuickPersonaChip(
                                label: 'Admin',
                                handle: 'campus_admin',
                                badgeStyle: AppColors.redBadge(isDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Institutional Security Note
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppSvgIcon(
                                svgString: AppSvgIcon.shield,
                                size: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Offline-Capable RBAC Directory Active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPersonaChip({
    required String label,
    required String handle,
    required BadgeStyle badgeStyle,
  }) {
    return InkWell(
      onTap: () => _fillPersona(handle: handle, role: label),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeStyle.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: badgeStyle.border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: badgeStyle.text,
          ),
        ),
      ),
    );
  }
}
