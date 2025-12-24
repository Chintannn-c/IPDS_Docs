import 'dart:async';
import 'dart:math';
import 'package:file_stroage_system/core/presentation/theme/motion_system.dart';
import 'package:file_stroage_system/core/presentation/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:file_stroage_system/core/presentation/widgets/responsive_center.dart';
import 'package:file_stroage_system/core/services/biometric_service.dart';
import 'package:file_stroage_system/core/presentation/widgets/glass_container.dart';
import 'package:file_stroage_system/core/presentation/widgets/glass_text_field.dart';
import 'package:file_stroage_system/core/presentation/widgets/neon_button.dart';
import '../../../core/presentation/widgets/password_strength_indicator.dart';
import '../../../core/presentation/utils/screen_utils.dart';
import '../../../core/services/notification_service.dart';

import 'auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final BiometricService _biometricService = BiometricService();

  bool _obscurePassword = true;
  bool _biometricAvailable = false;

  // Session state
  bool _hasExistingSession = false;
  String? _savedUserEmail;
  bool _isLoadingLocal = false; // Local loading state for init

  @override
  void initState() {
    super.initState();
    _initializeLoginScreen();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeLoginScreen() async {
    if (!mounted) return;
    setState(() => _isLoadingLocal = true);

    try {
      // Add a collective timeout for initialization to prevent hanging on Android
      await _performInit().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('LoginScreen: Initialization timed out');
        },
      );
    } catch (e) {
      debugPrint('LoginScreen: Init error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocal = false);
    }
  }

  Future<void> _performInit() async {
    final savedToken = await _storage.read(key: 'access_token');
    final savedEmail = await _storage.read(key: 'saved_email');

    _hasExistingSession = savedToken != null && savedToken.isNotEmpty;
    _savedUserEmail = savedEmail;

    if (savedEmail != null) {
      _emailController.text = savedEmail;
    }

    if (!kIsWeb) {
      _biometricAvailable = await _biometricService.isBiometricAvailable();
    }

    // If existing session & biometric available, try unlock
    if (_hasExistingSession && _biometricAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleBiometricUnlock();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final spacing = ScreenUtils.spacing(context);

    return Scaffold(
      body: Center(
        child: ResponsiveCenter(
          maxContentWidth: 450,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + spacing,
            left: spacing,
            right: spacing,
            bottom: spacing,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                FadeInAnimation(
                  delay: const Duration(milliseconds: 100),
                  child: _buildHeader(theme, colorScheme),
                ),
                const SizedBox(height: 30),

                if (_isLoadingLocal || authProvider.isLoading)
                  FadeInAnimation(
                    child: Center(
                      child: Column(
                        children: [
                          PulseAnimation(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: CircularProgressIndicator(
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Loading...'),
                        ],
                      ),
                    ),
                  )
                else if (_hasExistingSession && _biometricAvailable)
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: _buildBiometricUnlockCard(
                      theme,
                      colorScheme,
                      authProvider,
                    ),
                  )
                else
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: _buildPasswordLoginCard(
                      theme,
                      colorScheme,
                      authProvider,
                    ),
                  ),

                const SizedBox(height: 32),

                if (!_hasExistingSession)
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 400),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            "New User?",
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: const Text('Create Account'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hasExistingSession
                ? Colors.green.withOpacity(0.1)
                : colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _hasExistingSession ? Icons.fingerprint : Icons.lock_outline,
            size: 35,
            color: _hasExistingSession ? Colors.green : colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _hasExistingSession ? 'WELCOME BACK' : 'SECURE ACCESS',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _hasExistingSession
              ? 'Verify your identity to continue'
              : 'Login with your credentials',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBiometricUnlockCard(
    ThemeData theme,
    ColorScheme colorScheme,
    AuthProvider authProvider,
  ) {
    return GlassContainer(
      color: Colors.white,
      opacity: 0.02,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ScreenUtils.spacing(context),
          vertical: ScreenUtils.spacing(context) * 1.5,
        ),
        child: Column(
          children: [
            NeonButton(
              onPressed: authProvider.isLoading ? null : _handleBiometricUnlock,
              color: Colors.transparent, // Custom for icon
              child: Icon(
                Icons.fingerprint_rounded,
                size: 65,
                color: colorScheme.primary, // Cyber color
              ),
            ),
            const SizedBox(height: 20),
            if (_savedUserEmail != null)
              Text(
                _savedUserEmail!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),

            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                onPressed: authProvider.isLoading
                    ? null
                    : _handleBiometricUnlock,
                child: const Text('Tap to Unlock'),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                await _storage.delete(key: 'access_token');
                setState(() {
                  _hasExistingSession = false;
                });
              },
              child: const Text('Use Different Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordLoginCard(
    ThemeData theme,
    ColorScheme colorScheme,
    AuthProvider authProvider,
  ) {
    return GlassContainer(
      child: Padding(
        padding: EdgeInsets.all(ScreenUtils.spacing(context)),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GlassTextField(
                controller: _emailController,
                label: 'Email Address',
                prefixIcon: Icons.email,
                validator: (v) =>
                    v!.contains('@') ? null : 'Valid email required',
              ),
              const SizedBox(height: 20),
              GlassTextField(
                controller: _passwordController,
                label: 'Password',
                obscureText: _obscurePassword,
                prefixIcon: Icons.lock,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) => v!.isNotEmpty ? null : 'Password required',
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showForgotPasswordDialog(context),
                  child: Text(
                    "Forgot Password?",
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: NeonButton(
                  onPressed: () => _handlePasswordLogin(authProvider),
                  isLoading: authProvider.isLoading,
                  child: const Text('LOGIN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBiometricUnlock() async {
    final result = await _biometricService.authenticate(
      reason: 'Unlock Session',
    );
    if (result.success) {
      if (!mounted) return;
      // Restore session (fetch profile + connect WS)
      await context.read<AuthProvider>().restoreSession();
      if (!mounted) return;
      if (context.read<AuthProvider>().isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        NotificationService().warning(
          'Failed to restore session. Please try again.',
          title: 'Session Error',
        );
      }
    }
  }

  Future<void> _handlePasswordLogin(AuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await authProvider.login(
      _emailController.text,
      _passwordController.text,
    );

    if (result['success'] == true) {
      await _storage.write(key: 'saved_email', value: _emailController.text);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } else if (result['mfa_required'] == true) {
      // MFA Required - Show verification dialog
      if (mounted) {
        final mfaResult = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: false,
          enableDrag: false,
          builder: (ctx) => MFAVerificationDialog(
            email: result['email'] ?? _emailController.text,
            authProvider: authProvider,
          ),
        );

        if (mfaResult == true && mounted) {
          await _storage.write(
            key: 'saved_email',
            value: _emailController.text,
          );
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      }
    } else {
      if (mounted) {
        NotificationService().error(
          result['error'] ?? 'Login failed',
          title: 'Login Error',
        );
      }
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ForgotPasswordDialog(),
    );
  }
}

// ==================== FORGOT PASSWORD DIALOG ====================

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 0; // 0: email, 1: OTP, 2: new password
  bool _isLoading = false;
  String? _resetToken;
  bool _obscurePassword = true;
  String _newPassword = '';

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(ScreenUtils.spacing(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _step == 0
                    ? Icons.email_outlined
                    : _step == 1
                    ? Icons.pin_outlined
                    : Icons.lock_reset,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              _step == 0
                  ? 'Forgot Password?'
                  : _step == 1
                  ? 'Verify Code'
                  : 'New Password',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              _step == 0
                  ? 'Enter your email to receive a reset code'
                  : _step == 1
                  ? 'Enter the code sent to ${_emailController.text}'
                  : 'Create a new secure password',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Step Content
            if (_step == 0) _buildEmailStep(colorScheme),
            if (_step == 1) _buildOtpStep(colorScheme),
            if (_step == 2) _buildPasswordStep(colorScheme),

            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _step == 0
                            ? 'SEND CODE'
                            : _step == 1
                            ? 'VERIFY'
                            : 'RESET PASSWORD',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            if (_step > 0) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _step--),
                child: const Text('Go Back'),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailStep(ColorScheme colorScheme) {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email Address',
        prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colorScheme.onSurface.withOpacity(0.05),
      ),
    );
  }

  Widget _buildOtpStep(ColorScheme colorScheme) {
    return TextField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: 8),
      decoration: InputDecoration(
        labelText: 'Enter 6-digit code',
        prefixIcon: Icon(Icons.pin_outlined, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colorScheme.onSurface.withOpacity(0.05),
      ),
    );
  }

  Widget _buildPasswordStep(ColorScheme colorScheme) {
    return Column(
      children: [
        TextField(
          controller: _newPasswordController,
          obscureText: _obscurePassword,
          onChanged: (value) {
            setState(() => _newPassword = value);
          },
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: colorScheme.onSurface.withOpacity(0.05),
          ),
        ),
        // Password Strength Indicator
        if (_newPassword.isNotEmpty) ...[
          const SizedBox(height: 12),
          PasswordStrengthIndicator(
            password: _newPassword,
            showRequirements: true,
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: colorScheme.onSurface.withOpacity(0.05),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction() async {
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();

      if (_step == 0) {
        // Request OTP
        if (_emailController.text.isEmpty ||
            !_emailController.text.contains('@')) {
          _showError('Please enter a valid email');
          return;
        }
        final res = await auth.requestPasswordReset(_emailController.text);
        if (res['success'] == true) {
          _showSuccess('Code sent! Check your email.');
          setState(() => _step = 1);
        } else {
          _showError(res['error'] ?? 'Failed to send code');
        }
      } else if (_step == 1) {
        // Verify OTP
        if (_otpController.text.isEmpty) {
          _showError('Please enter the code');
          return;
        }
        final res = await auth.verifyPasswordResetOTP(
          _emailController.text,
          _otpController.text,
        );
        if (res['success'] == true) {
          _resetToken = res['reset_token'];
          _showSuccess('Code verified!');
          setState(() => _step = 2);
        } else {
          _showError(res['error'] ?? 'Invalid code');
        }
      } else {
        // Reset password
        final validationError = PasswordValidator.getValidationError(
          _newPasswordController.text,
        );
        if (validationError != null) {
          _showError(validationError);
          return;
        }
        if (_newPasswordController.text != _confirmPasswordController.text) {
          _showError('Passwords do not match');
          return;
        }
        final res = await auth.resetPasswordWithToken(
          _resetToken!,
          _newPasswordController.text,
        );
        if (res['success'] == true) {
          _showSuccess('Password reset successful!');
          if (mounted) Navigator.pop(context);
        } else {
          _showError(res['error'] ?? 'Failed to reset password');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    AppToast.error(context, message);
  }

  void _showSuccess(String message) {
    AppToast.success(context, message);
  }
}

// ==================== MFA VERIFICATION DIALOG ====================

class MFAVerificationDialog extends StatefulWidget {
  final String email;
  final AuthProvider authProvider;

  const MFAVerificationDialog({
    super.key,
    required this.email,
    required this.authProvider,
  });

  @override
  State<MFAVerificationDialog> createState() => _MFAVerificationDialogState();
}

class _MFAVerificationDialogState extends State<MFAVerificationDialog>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  AnimationController? _animationController;
  Animation<double>? _shakeAnimation;

  bool _isLoading = false;
  bool _isSuccess = false;
  String? _error;
  int _resendTimer = 0;

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.elasticIn),
    );

    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onOtpChanged(int index, String value) {
    // Only allow digits
    if (value.isNotEmpty && !RegExp(r'^[0-9]$').hasMatch(value)) {
      _otpControllers[index].clear();
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    // Auto-submit when all 6 digits are entered
    if (_otpCode.length == 6) {
      _verifyOTP();
    }

    setState(() => _error = null);
  }

  void _onKeyPressed(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _startResendTimer() async {
    setState(() => _resendTimer = 60);
    while (_resendTimer > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendTimer--);
    }
  }

  Future<void> _resendCode() async {
    if (_resendTimer > 0) return;

    setState(() => _isLoading = true);
    try {
      final result = await widget.authProvider.resendMFAOTP(
        purpose: 'login',
        email: widget.email,
      );
      if (result['success'] == true) {
        _startResendTimer();
        if (mounted) {
          AppToast.success(context, 'New code sent!');
        }
      } else {
        if (mounted) {
          AppToast.error(context, result['error'] ?? 'Failed to resend code');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _triggerShake() {
    _animationController?.forward().then((_) {
      _animationController?.reverse();
    });
  }

  Future<void> _verifyOTP() async {
    final code = _otpCode;
    if (code.length != 6) {
      setState(() => _error = 'Please enter all 6 digits');
      _triggerShake();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.authProvider.verifyMFALogin(
        widget.email,
        code,
      );

      if (result['success'] == true) {
        setState(() => _isSuccess = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      } else {
        final errorMsg = result['error'] ?? 'Verification failed';
        final isExpiredOrInvalid =
            errorMsg.toLowerCase().contains('expired') ||
            errorMsg.toLowerCase().contains('invalid') ||
            errorMsg.toLowerCase().contains('timeout');

        setState(() {
          _error = errorMsg;
          // Reset resend timer if OTP expired/invalid so user can resend immediately
          if (isExpiredOrInvalid && _resendTimer > 0) {
            _resendTimer = 0;
          }
        });
        _triggerShake();
        // Clear OTP boxes on error
        for (var c in _otpControllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      setState(() {
        _error = 'Verification failed. Please try again.';
        // Allow resend on any error
        if (_resendTimer > 0) _resendTimer = 0;
      });
      _triggerShake();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [colorScheme.surface, colorScheme.surface.withOpacity(0.95)]
              : [Colors.white, colorScheme.primary.withOpacity(0.02)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          ScreenUtils.spacing(context),
          16,
          ScreenUtils.spacing(context),
          32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 28),

            // Animated Icon
            _buildAnimatedIcon(colorScheme),
            const SizedBox(height: 28),

            // Title
            Text(
              'Two-Factor Authentication',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle with email
            Text(
              'Enter the verification code sent to',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            _buildEmailChip(colorScheme),
            const SizedBox(height: 32),

            // OTP Input Boxes
            if (_shakeAnimation != null)
              AnimatedBuilder(
                animation: _shakeAnimation!,
                builder: (context, child) {
                  final offset = sin(_shakeAnimation!.value * 3 * 3.14159) * 10;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: _buildOtpBoxes(colorScheme, isDark),
              )
            else
              _buildOtpBoxes(colorScheme, isDark),

            // Error Message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildErrorCard(colorScheme),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 28),

            // Verify Button
            _buildVerifyButton(colorScheme),

            const SizedBox(height: 16),

            // Resend Code
            _buildResendSection(colorScheme),

            const SizedBox(height: 16),

            // Cancel Button
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isSuccess
              ? [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.1)]
              : [
                  colorScheme.primary.withOpacity(0.15),
                  colorScheme.primary.withOpacity(0.05),
                ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (_isSuccess ? Colors.green : colorScheme.primary)
                .withOpacity(0.25),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isSuccess
            ? const Icon(
                Icons.check_circle_rounded,
                key: ValueKey('success'),
                size: 48,
                color: Colors.green,
              )
            : Icon(
                Icons.shield_rounded,
                key: const ValueKey('shield'),
                size: 48,
                color: colorScheme.primary,
              ),
      ),
    );
  }

  Widget _buildEmailChip(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.email_rounded, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            widget.email,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBoxes(ColorScheme colorScheme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final hasValue = _otpControllers[index].text.isNotEmpty;
        final isFocused = _focusNodes[index].hasFocus;

        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? 0 : 4,
            right: index == 5 ? 0 : 4,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 52,
            decoration: BoxDecoration(
              color: hasValue
                  ? colorScheme.primary.withOpacity(0.08)
                  : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFocused
                    ? colorScheme.primary
                    : (hasValue
                          ? colorScheme.primary.withOpacity(0.4)
                          : colorScheme.onSurface.withOpacity(0.1)),
                width: isFocused ? 2 : 1.5,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) => _onKeyPressed(index, event),
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) => _onOtpChanged(index, value),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildErrorCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.red, size: 16),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading || _isSuccess ? null : _verifyOTP,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSuccess ? Colors.green : colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: colorScheme.primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : _isSuccess
              ? const Row(
                  key: ValueKey('success'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'VERIFIED!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontSize: 15,
                      ),
                    ),
                  ],
                )
              : const Row(
                  key: ValueKey('verify'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'VERIFY & LOGIN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildResendSection(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't receive the code? ",
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
        if (_resendTimer > 0)
          Text(
            'Resend in ${_resendTimer ~/ 60}:${(_resendTimer % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          GestureDetector(
            onTap: _isLoading ? null : _resendCode,
            child: Text(
              'Resend Code',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
