import 'package:flutter/material.dart';
import '../main.dart';
import '../models/user.dart';
import '../services/offline_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/svg_icons.dart';
import '../widgets/app_logo.dart';

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
          // Theme Toggle in Header
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
              ),
              onPressed: () {
                appThemeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
          ),

          // Centered Login Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AnimatedContainer(
                  duration: AppTheme.themeAnimationDuration,
                  curve: AppTheme.themeAnimationCurve,
                  padding: const EdgeInsets.all(32),
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
                        // High-Definition Logo
                        const Center(
                          child: AppLogo(height: 54),
                        ),
                        const SizedBox(height: 20),

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
                        const SizedBox(height: 6),
                        Text(
                          'Enter your canonical campus handle or email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error Banner (if any)
                        if (_errorMessage != null) ...[
                          Builder(
                            builder: (context) {
                              final redBadge = AppColors.redBadge(isDark);
                              return AnimatedContainer(
                                duration: AppTheme.themeAnimationDuration,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: redBadge.background,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: redBadge.border, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    AppSvgIcon(
                                      svgString: AppSvgIcon.alertTriangle,
                                      size: 16,
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
                          const SizedBox(height: 16),
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
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _identifierController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'e.g. harish_2025_l_btech_1',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12),
                              child: AppSvgIcon(
                                svgString: AppSvgIcon.user,
                                size: 16,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
                        const SizedBox(height: 16),

                        // Password Field
                        Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter account password',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12),
                              child: AppSvgIcon(
                                svgString: AppSvgIcon.lock,
                                size: 16,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: AppSvgIcon(
                                svgString: _obscurePassword ? AppSvgIcon.eye : AppSvgIcon.eyeOff,
                                size: 16,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
                        const SizedBox(height: 12),

                        // Remember Me Checkbox
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
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
                        const SizedBox(height: 20),

                        // Sign In Button
                        SizedBox(
                          height: 44,
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
                                    width: 20,
                                    height: 20,
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
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      SizedBox(width: 8),
                                      AppSvgIcon(
                                        svgString: AppSvgIcon.arrowRight,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Quick Access Personas (1-Click Fill)
                        Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        const SizedBox(height: 12),
                        Text(
                          'Quick Access Personas (1-Click Fill)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
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
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Institutional Security Note
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppSvgIcon(
                              svgString: AppSvgIcon.shield,
                              size: 13,
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
