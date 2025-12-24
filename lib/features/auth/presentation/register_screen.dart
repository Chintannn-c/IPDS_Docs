import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/presentation/widgets/responsive_center.dart';
import '../../../core/presentation/theme/motion_system.dart';
import '../../../core/presentation/widgets/glass_container.dart';
import '../../../core/presentation/widgets/glass_text_field.dart';
import '../../../core/presentation/widgets/neon_button.dart';
import '../../../core/presentation/widgets/password_strength_indicator.dart';
import '../../../core/presentation/utils/screen_utils.dart';
import 'package:file_stroage_system/core/presentation/widgets/app_toast.dart';
import 'auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _currentPassword = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final spacing = ScreenUtils.spacing(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ResponsiveCenter(
            maxContentWidth: 450,
            padding: EdgeInsets.symmetric(horizontal: spacing),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxHeight < 650;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: spacing),

                          /// HEADER
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 100),
                            child: _buildHeader(theme, colorScheme, isSmall),
                          ),

                          const SizedBox(height: 25),

                          /// FORM CARD
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 200),
                            child: _buildRegistrationCard(
                              theme,
                              colorScheme,
                              authProvider,
                            ),
                          ),

                          SizedBox(height: spacing),

                          /// Login link
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 400),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: 12,
                                top: 8,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Already have an account?",
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Login"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isSmallDevice,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(
            isSmallDevice ? 14 : ScreenUtils.spacing(context),
          ),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_add_outlined,
            size: isSmallDevice ? 28 : 35,
            color: colorScheme.primary,
          ),
        ),
        SizedBox(height: isSmallDevice ? 14 : 18),
        Text(
          "CREATE ACCOUNT",
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Join our secure platform",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationCard(
    ThemeData theme,
    ColorScheme colorScheme,
    AuthProvider authProvider,
  ) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      blur: 0,
      opacity: 0.15,
      child: Padding(
        padding: EdgeInsets.all(ScreenUtils.spacing(context)),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GlassTextField(
                controller: _nameController,
                label: 'Full Name',
                prefixIcon: Icons.person_outline,
                validator: (v) => v!.isEmpty ? "Name required" : null,
              ),
              const SizedBox(height: 16),

              GlassTextField(
                controller: _emailController,
                label: 'Email Address',
                prefixIcon: Icons.email_outlined,
                validator: (v) =>
                    v!.contains('@') ? null : "Valid email required",
              ),
              const SizedBox(height: 16),

              GlassTextField(
                controller: _passwordController,
                label: 'Password',
                obscureText: _obscurePassword,
                prefixIcon: Icons.lock_outline,
                onChanged: (value) {
                  setState(() => _currentPassword = value);
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) => PasswordValidator.getValidationError(v),
              ),

              // Password Strength Indicator
              if (_currentPassword.isNotEmpty) ...[
                const SizedBox(height: 12),
                PasswordStrengthIndicator(
                  password: _currentPassword,
                  showRequirements: true,
                ),
              ],
              const SizedBox(height: 16),

              GlassTextField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                obscureText: _obscureConfirmPassword,

                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
                validator: (v) {
                  if (v != _passwordController.text) {
                    return "Passwords do not match";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: NeonButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () => _handleRegister(authProvider),
                  isLoading: authProvider.isLoading,
                  child: const Text("REGISTER"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister(AuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) return;

    final errorMessage = await authProvider.register(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _nameController.text.trim(),
    );

    if (!mounted) return;

    if (errorMessage == null) {
      Navigator.pushReplacementNamed(context, '/');
      AppToast.success(context, "Registration successful! Please login.");
    } else {
      AppToast.error(context, errorMessage);
    }
  }
}
