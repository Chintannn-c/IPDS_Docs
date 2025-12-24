import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_stroage_system/core/presentation/widgets/secure_avatar.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'widgets/image_crop_screen.dart';
import '../../auth/presentation/auth_provider.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'package:file_stroage_system/core/presentation/widgets/animations.dart';
import 'package:file_stroage_system/core/presentation/widgets/status_indicator.dart';
import 'package:file_stroage_system/core/presentation/widgets/touch_card.dart';
import 'package:image/image.dart' as img;
import 'package:file_stroage_system/core/presentation/widgets/password_strength_indicator.dart';
import 'package:file_stroage_system/core/presentation/widgets/app_toast.dart'; // Add this import

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;

  bool _isEditing = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    _nameController = TextEditingController(text: user?['name'] ?? '');
    _emailController = TextEditingController(text: user?['email'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  static Uint8List _compressImageSync(Uint8List bytes) {
    // Decode the image
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Resize the image to a maximum of 512x512 while maintaining aspect ratio
    img.Image resized;
    if (image.width > 512 || image.height > 512) {
      if (image.width > image.height) {
        resized = img.copyResize(image, width: 512);
      } else {
        resized = img.copyResize(image, height: 512);
      }
    } else {
      resized = image;
    }

    // Encode the image to JPEG with 85% quality
    return img.encodeJpg(resized, quality: 85);
  }

  Future<void> _pickAndCropImage(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final colorScheme = Theme.of(context).colorScheme;

      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (res == null || res.files.single.bytes == null) return;

      final croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropScreen(image: res.files.single.bytes!),
        ),
      );

      if (croppedBytes == null) return;

      setState(() => _isUploading = true);

      // Compress image in background
      final compressedBytes = await compute(_compressImageSync, croppedBytes);

      final platformFile = PlatformFile(
        bytes: compressedBytes,
        name: 'profile.jpg',
        size: compressedBytes.length,
      );

      final result = FilePickerResult([platformFile]);

      await authProvider.uploadProfileImage(result);
    } catch (e) {
      debugPrint('Error picking or cropping image: $e');
      if (context.mounted) {
        AppToast.error(context, 'Error updating profile picture: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Custom Header
              FadeIn(
                duration: AppTheme.animNormal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 24,
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'PROFILE',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isEditing ? Icons.check_rounded : Icons.edit_rounded,
                        ),
                        color: _isEditing
                            ? AppTheme.successColor
                            : colorScheme.primary,
                        splashRadius: 24,
                        onPressed: () async {
                          if (_isEditing) {
                            if (_formKey.currentState!.validate()) {
                              final success = await authProvider.updateProfile(
                                _nameController.text,
                                _emailController.text,
                              );
                              if (success) {
                                setState(() => _isEditing = false);
                              }
                            }
                          } else {
                            setState(() => _isEditing = true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      FadeIn(
                        delay: const Duration(milliseconds: 100),
                        child: Center(
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.primary.withOpacity(0.7),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SecureAvatar(
                                      radius: 55,
                                      imageUrl: user['profile_image'],
                                      fallbackInitials: user['name'] ?? 'U',
                                      backgroundColor: Colors.transparent,
                                      textColor: Colors.white,
                                    ),
                                    if (_isUploading)
                                      Container(
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: ScaleTransition(
                                  scale: const AlwaysStoppedAnimation(1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.camera_alt_rounded,
                                        size: 20,
                                        color: colorScheme.primary,
                                      ),
                                      onPressed: () async {
                                        await _pickAndCropImage(context);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      FadeIn(
                        delay: const Duration(milliseconds: 150),
                        child: Column(
                          children: [
                            Center(
                              child: Text(
                                user['name'] ?? 'User',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: Text(
                                user['email'] ?? '',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingXL),

                      SlideUp(
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          "Personal Information",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),

                      SlideUp(
                        delay: const Duration(milliseconds: 250),
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: "Full Name",
                              enabled: _isEditing,
                              theme: theme,
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            _buildTextField(
                              controller: _emailController,
                              label: "Email",
                              enabled: _isEditing,
                              theme: theme,
                              icon: Icons.email_outlined,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingXL),
                      // Storage
                      SlideUp(
                        delay: const Duration(milliseconds: 300),
                        child: _buildStorageSection(user, theme, colorScheme),
                      ),

                      const SizedBox(height: AppTheme.spacingXL),

                      SlideUp(
                        delay: const Duration(milliseconds: 350),
                        child: Text(
                          "Security",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),

                      SlideUp(
                        delay: const Duration(milliseconds: 400),
                        child: TouchCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _buildSecurityTile(
                                "Two-Step Verification",
                                Icons.security_rounded,
                                () =>
                                    Navigator.pushNamed(context, '/mfa_setup'),
                                subtitle: user['mfa_enabled'] == true
                                    ? "Enabled"
                                    : "Disabled",
                                color: user['mfa_enabled'] == true
                                    ? AppTheme.successColor
                                    : null,
                                theme: theme,
                              ),
                              const SectionDivider(),
                              _buildSecurityTile(
                                "Change Password",
                                Icons.lock_outline_rounded,
                                () => _showChangePasswordDialog(
                                  context,
                                  authProvider,
                                ),
                                theme: theme,
                              ),
                              const SectionDivider(),
                              _buildSecurityTile(
                                "Log Out",
                                Icons.logout_rounded,
                                () => _showLogoutConfirmationDialog(
                                  context,
                                  authProvider,
                                ),
                                color: AppTheme.warningColor,
                                theme: theme,
                              ),
                              const SectionDivider(),
                              _buildSecurityTile(
                                "Log Out All Devices",
                                Icons.devices_rounded,
                                () => _showLogoutAllConfirmationDialog(
                                  context,
                                  authProvider,
                                ),
                                color: AppTheme.errorColor,
                                theme: theme,
                              ),
                              const SectionDivider(),
                              _buildSecurityTile(
                                "Delete Account",
                                Icons.delete_outline_rounded,
                                () => _showDeleteAccountDialog(
                                  context,
                                  authProvider,
                                ),
                                color: AppTheme.errorColor,
                                theme: theme,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    required ThemeData theme,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, color: AppTheme.textSecondary)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        filled: true,
        fillColor: enabled
            ? Colors.transparent
            : theme.colorScheme.surface.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingM,
        ),
      ),
    );
  }

  Widget _buildStorageSection(
    Map<String, dynamic> user,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final used = user['storage_used'] ?? 0;

    final limit = user['storage_limit'] ?? 5368709120; // 5GB default
    final progress = (used / limit).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

    // Dynamic color based on usage
    Color progressColor;
    Color progressColorLight;
    IconData statusIcon;
    String statusText;

    if (progress < 0.5) {
      progressColor = AppTheme.successColor;
      progressColorLight = const Color(0xFF4ADE80);
      statusIcon = Icons.check_circle_rounded;
      statusText = "Plenty of space";
    } else if (progress < 0.8) {
      progressColor = AppTheme.warningColor;
      progressColorLight = const Color(0xFFFBBF24);
      statusIcon = Icons.info_rounded;
      statusText = "Space getting low";
    } else {
      progressColor = AppTheme.errorColor;
      progressColorLight = const Color(0xFFF87171);
      statusIcon = Icons.warning_rounded;
      statusText = "Almost full";
    }

    return TouchCard(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      progressColor.withOpacity(0.2),
                      progressColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storage_rounded,
                  color: progressColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Local Storage",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: progressColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: progressColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Percentage Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [progressColor, progressColorLight],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: progressColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  "$percentage%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingL),

          // Progress Bar
          Stack(
            children: [
              // Background
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Progress
              FractionallySizedBox(
                widthFactor: progress,
                child: AnimatedContainer(
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [progressColor, progressColorLight],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: progressColor.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingM),

          // Storage details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Used storage
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: progressColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${(used / 1024 / 1024).toStringAsFixed(1)} MB used",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Total storage
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${(limit / 1024 / 1024).toStringAsFixed(1)} MB total",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    Color? color,
    String? subtitle,
    required ThemeData theme,
  }) {
    return TouchListTile(
      icon: icon,
      title: title,
      onTap: onTap,
      subtitle: subtitle,
      iconColor: color ?? theme.colorScheme.primary,
      textColor: color,
    );
  }

  // ==================== DIALOGS ====================

  void _showChangePasswordDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    final current = TextEditingController();
    final newPass = TextEditingController();
    final confirmPass = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String newPassword = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text("Change Password", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: current,
                      decoration: InputDecoration(
                        labelText: "Current Password",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureCurrent = !obscureCurrent,
                          ),
                        ),
                      ),
                      obscureText: obscureCurrent,
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPass,
                      onChanged: (value) {
                        setDialogState(() => newPassword = value);
                      },
                      decoration: InputDecoration(
                        labelText: "New Password",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      obscureText: obscureNew,
                      validator: (v) => PasswordValidator.getValidationError(v),
                    ),
                    // Password Strength Indicator
                    const SizedBox(height: 12),
                    PasswordStrengthIndicator(
                      password: newPassword,
                      showRequirements: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPass,
                      decoration: InputDecoration(
                        labelText: "Confirm New Password",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                        ),
                      ),
                      obscureText: obscureConfirm,
                      validator: (v) {
                        if (v != newPass.text) return "Passwords don't match";
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final success = await authProvider.changePassword(
                    current.text,
                    newPass.text,
                  );
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    AppToast.success(context, "Password changed successfully!");
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Text("Log Out"),
          ],
        ),
        content: const Text(
          "Are you sure you want to log out from this device?",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("Log Out"),
          ),
        ],
      ),
    );
  }

  void _showLogoutAllConfirmationDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.devices, color: Colors.deepOrange),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Log Out All Devices",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This will log you out from all devices, including:",
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.smartphone, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text("Mobile devices"),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.computer, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text("Desktop browsers"),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.tablet, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text("Tablets and other devices"),
              ],
            ),
            SizedBox(height: 16),
            Text(
              "You will need to log in again on each device.",
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.logoutAll();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("Log Out All"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    final pass = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever, color: Colors.red),
              ),
              const SizedBox(width: 12),
              const Text("Delete Account", style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "This action cannot be undone. All your data will be permanently deleted.",
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Enter your password to confirm:",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pass,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  obscureText: obscure,
                  validator: (v) => v!.isEmpty ? "Password required" : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await authProvider.deleteAccount(pass.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    );
                  }
                }
              },
              child: const Text("DELETE ACCOUNT"),
            ),
          ],
        ),
      ),
    );
  }
}
