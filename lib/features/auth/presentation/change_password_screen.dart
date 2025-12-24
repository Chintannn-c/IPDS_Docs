import 'package:file_stroage_system/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'package:file_stroage_system/core/presentation/widgets/custom_header.dart';
import 'package:file_stroage_system/core/presentation/widgets/password_strength_indicator.dart';
import 'package:file_stroage_system/core/presentation/utils/screen_utils.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String _newPassword = '';

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      NotificationService().error(
        'Please fix the errors above',
        title: 'Validation Error',
      );
      return;
    }

    // Extra safety check: verify password strength before submitting
    final passwordError = PasswordValidator.getValidationError(
      _newPasswordController.text,
    );
    if (passwordError != null) {
      NotificationService().error(passwordError, title: 'Weak Password');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );
      if (mounted) {
        if (success) {
          NotificationService().success(
            'Password changed successfully! Please login again.',
            title: 'Password Updated',
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        } else {
          NotificationService().error(
            'Failed to change password. Please check your current password.',
            title: 'Error',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const CustomHeader(title: 'Change Password'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ScreenUtils.spacing(context)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.security,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Secure Your Account',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a strong password to protect your account.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: _obscureCurrent,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureCurrent
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscureCurrent = !_obscureCurrent,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) => v?.isEmpty ?? true
                              ? 'Current password is required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNew,
                          onChanged: (value) {
                            setState(() => _newPassword = value);
                          },
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNew
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureNew = !_obscureNew),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) =>
                              PasswordValidator.getValidationError(v),
                        ),

                        // Password Strength Indicator - always show
                        const SizedBox(height: 12),
                        PasswordStrengthIndicator(
                          password: _newPassword,
                          showRequirements: true,
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v != _newPasswordController.text)
                              return 'Passwords do not match';
                            return null;
                          },
                        ),

                        const SizedBox(height: 32),

                        FilledButton(
                          onPressed: _isLoading ? null : _changePassword,
                          style: FilledButton.styleFrom(
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
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.security),
                                    SizedBox(width: 8),
                                    Text(
                                      'Change Password',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),

                        const SizedBox(height: 16),

                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
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
}
