import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'package:file_stroage_system/core/presentation/widgets/app_toast.dart';
import '../../../../core/presentation/utils/screen_utils.dart'; // Add import

class MFASetupScreen extends StatefulWidget {
  const MFASetupScreen({super.key});

  @override
  State<MFASetupScreen> createState() => _MFASetupScreenState();
}

class _MFASetupScreenState extends State<MFASetupScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _checkingStatus = true;
  bool _isSetupMode = false;
  bool _isDisableMode = false;
  bool _isMfaEnabled = false;
  bool _obscurePassword = true;

  String? _email;

  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _checkMFAStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  Future<void> _checkMFAStatus() async {
    setState(() => _checkingStatus = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.getMFAStatus();
      if (mounted) {
        setState(() {
          _isMfaEnabled = result['mfa_enabled'] ?? false;
          _isSetupMode = false;
          _isDisableMode = false;
          _codeController.clear();
          _passwordController.clear();
          for (var c in _otpControllers) {
            c.clear();
          }
          _error = null;
          _successMessage = null;
        });
        _animationController.forward();
      }
    } catch (e) {
      debugPrint("Error checking MFA status: $e");
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  Future<void> _enableMFA() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.enableMFA();
      if (mounted) {
        if (result['success'] == true) {
          _animationController.reset();
          setState(() {
            _isSetupMode = true;
            _isDisableMode = false;
            _email = result['email'];
            _successMessage = result['message'];
          });
          _animationController.forward();
        } else {
          setState(() => _error = result['error'] ?? 'Failed to enable MFA');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startDisableProcess() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.requestDisableOTP();
      if (mounted) {
        if (result['success'] == true) {
          _animationController.reset();
          setState(() {
            _isDisableMode = true;
            _isSetupMode = false;
            _email = authProvider.user?['email'];
            _successMessage = result['message'];
          });
          _animationController.forward();
        } else {
          setState(() => _error = result['error'] ?? 'Failed to request code');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final authProvider = context.read<AuthProvider>();
      Map<String, dynamic> result;
      if (_isDisableMode) {
        result = await authProvider.requestDisableOTP();
      } else {
        result = await authProvider.resendMFAOTP(purpose: 'enable');
      }

      if (mounted) {
        if (result['success'] == true) {
          setState(() => _successMessage = 'New verification code sent!');
        } else {
          setState(() => _error = result['error'] ?? 'Failed to resend');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to resend code: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpCode;
    if (code.length != 6) {
      setState(() => _error = 'Please enter a 6-digit code');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.verifyMFA(code);
      if (mounted) {
        if (result['success'] == true) {
          AppToast.success(
            context,
            "2-Step verification enabled successfully!",
          );
          Navigator.pop(context, true);
        } else {
          setState(() {
            _error = result['error'] ?? 'Invalid code';
            for (var c in _otpControllers) {
              c.clear();
            }
          });
          _otpFocusNodes[0].requestFocus();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAndDisable() async {
    final code = _otpCode;
    if (code.length != 6) {
      setState(() => _error = 'Please enter a 6-digit code');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.disableMFA(
        _passwordController.text,
        code,
      );
      if (mounted) {
        if (result['success'] == true) {
          AppToast.success(
            context,
            "2-Step verification disabled successfully!",
          );
          _checkMFAStatus();
        } else {
          setState(() => _error = result['error'] ?? 'Failed to disable MFA');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Disable failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;

    return Scaffold(
      body: SafeArea(
        child: _checkingStatus
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: colorScheme.primary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading security settings...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(ScreenUtils.spacing(context)),
                          child: _buildContent(
                            theme,
                            colorScheme,
                            size,
                            isSmallScreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    bool isSmallScreen,
  ) {
    if (_isDisableMode) {
      return _buildDisableVerificationView(
        theme,
        colorScheme,
        size,
        isSmallScreen,
      );
    }
    if (_isSetupMode) {
      return _buildSetupView(theme, colorScheme, size, isSmallScreen);
    }
    if (_isMfaEnabled) {
      return _buildDisableView(theme, colorScheme, size, isSmallScreen);
    }
    return _buildEnableView(theme, colorScheme, size, isSmallScreen);
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        top: 12,
        left: ScreenUtils.spacing(context),
        right: ScreenUtils.spacing(context),
        bottom: 12,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.all(12),
            ),
          ),
          Expanded(
            child: Text(
              '2-Step Authentication',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildEnableView(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    bool isSmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: size.height * 0.04),
        // Animated Shield Icon
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.security_rounded,
            size: 56,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 36),
        Text(
          'Secure Your Account',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Add an extra layer of protection with\ntwo-factor authentication.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
        // Feature Cards
        _buildFeatureCard(
          icon: Icons.email_rounded,
          title: 'Email Verification',
          description: 'Receive a 6-digit code to your email',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          icon: Icons.lock_clock_rounded,
          title: 'Time-Based Codes',
          description: 'Codes expire after a short time for security',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          icon: Icons.devices_rounded,
          title: 'Device Protection',
          description: 'Verify new devices before they can access',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 36),
        if (_error != null) _buildErrorCard(_error!, colorScheme),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _enableMFA,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: colorScheme.onPrimary,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_rounded, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Enable 2-Step verification",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupView(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    bool isSmallScreen,
  ) {
    return _buildCommonVerificationView(
      theme,
      colorScheme,
      size,
      isSmallScreen,
      false,
    );
  }

  Widget _buildDisableVerificationView(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    bool isSmallScreen,
  ) {
    return _buildCommonVerificationView(
      theme,
      colorScheme,
      size,
      isSmallScreen,
      true,
    );
  }

  Widget _buildDisableView(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    bool isSmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: size.height * 0.04),
        // Success Shield
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.verified_user_rounded,
            size: 56,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 36),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ACTIVE',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '2-Step verification is Enabled',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your account is protected with\ntwo-factor authentication.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
        // Security Status Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Login requires email verification',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'New devices are verified',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Account is protected from unauthorized access',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _startDisableProcess,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.red.shade400,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Disable 2-Step verification",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommonVerificationView(
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
    bool isSmallScreen,
    bool isDisable,
  ) {
    final accentColor = isDisable ? Colors.red : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: size.height * 0.02),
        // Icon with glow
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.2),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            isDisable ? Icons.gpp_bad_rounded : Icons.mark_email_read_rounded,
            size: 48,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          isDisable ? 'Disable 2-Step verification' : 'Verify Your Email',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (_email != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _email!,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        if (_successMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _successMessage!,
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 36),

        // Password field for disable mode
        if (isDisable) ...[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: "Enter your password",
                prefixIcon: Icon(
                  Icons.lock_rounded,
                  color: colorScheme.primary,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // OTP Input Label
        Text(
          'Enter 6-digit verification code',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 16),

        // OTP Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            6,
            (index) => _buildOTPBox(index, accentColor),
          ),
        ),

        const SizedBox(height: 24),
        if (_error != null) _buildErrorCard(_error!, colorScheme),
        const SizedBox(height: 24),

        // Verify Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : (isDisable ? _verifyAndDisable : _verifyCode),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDisable ? Icons.remove_moderator : Icons.verified,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isDisable
                            ? "Disable 2-Step verifications"
                            : "Verify & Enable",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _isLoading ? null : _resendOTP,
          icon: Icon(
            Icons.refresh_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
          label: Text(
            "Resend Code",
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Code expires in 10 minutes',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPBox(int index, Color accentColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 52,
      margin: EdgeInsets.symmetric(
        horizontal: index == 2 || index == 3 ? 4 : 2,
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: _otpControllers[index].text.isNotEmpty
              ? accentColor.withOpacity(0.08)
              : colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _otpControllers[index].text.isNotEmpty
                  ? accentColor.withOpacity(0.5)
                  : colorScheme.outline.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: accentColor, width: 2),
          ),
        ),
        onChanged: (value) {
          setState(() {});
          if (value.isNotEmpty && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
          // Auto-submit when all 6 digits entered
          if (_otpCode.length == 6) {
            FocusScope.of(context).unfocus();
          }
        },
      ),
    );
  }

  Widget _buildErrorCard(String error, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
