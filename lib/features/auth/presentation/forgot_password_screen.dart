import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_stroage_system/core/services/notification_service.dart';
import 'package:file_stroage_system/features/auth/presentation/auth_provider.dart';
import 'package:file_stroage_system/core/presentation/widgets/custom_header.dart';
import 'package:file_stroage_system/core/presentation/utils/screen_utils.dart'; // Add import

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  int _step = 0;
  String? _resetToken;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const CustomHeader(title: 'Reset Password'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ScreenUtils.spacing(context)),
                child: Column(
                  children: [
                    if (_step == 0) _buildEmailStep(),
                    if (_step == 1) _buildOtpStep(),
                    if (_step == 2) _buildNewPasswordStep(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      children: [
        const Text("Enter your email to receive a reset code."),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: "Email"),
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _requestOtp, child: const Text("Send Code")),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      children: [
        Text("Enter the code sent to ${_emailController.text}"),
        const SizedBox(height: 16),
        TextField(
          controller: _otpController,
          decoration: const InputDecoration(labelText: "OTP Code"),
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _verifyOtp, child: const Text("Verify Code")),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      children: [
        const Text("Enter your new password."),
        const SizedBox(height: 16),
        TextField(
          controller: _newPasswordController,
          decoration: const InputDecoration(labelText: "New Password"),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _resetPassword,
          child: const Text("Reset Password"),
        ),
      ],
    );
  }

  Future<void> _requestOtp() async {
    if (_emailController.text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final res = await auth.requestPasswordReset(_emailController.text);

    if (res['success']) {
      NotificationService().success("Code sent! Check your email.");
      setState(() => _step = 1);
    } else {
      NotificationService().error(res['error'] ?? "Failed to send code");
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final res = await auth.verifyPasswordResetOTP(
      _emailController.text,
      _otpController.text,
    );

    if (res['success']) {
      _resetToken = res['reset_token'];
      NotificationService().success("Code verified!");
      setState(() => _step = 2);
    } else {
      NotificationService().error(res['error'] ?? "Invalid code");
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.isEmpty || _resetToken == null) return;

    final auth = context.read<AuthProvider>();
    final res = await auth.resetPasswordWithToken(
      _resetToken!,
      _newPasswordController.text,
    );

    if (res['success']) {
      NotificationService().success("Password reset! Please login.");
      if (context.mounted) {
        Navigator.pop(context);
      }
    } else {
      NotificationService().error(res['error'] ?? "Failed to reset password");
    }
  }
}
