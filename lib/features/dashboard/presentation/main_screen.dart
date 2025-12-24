import 'package:file_stroage_system/features/dashboard/presentation/file_provider.dart';
import 'package:file_stroage_system/features/auth/presentation/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:file_stroage_system/features/dashboard/presentation/dashboard_screen.dart';
import 'package:file_stroage_system/features/dashboard/presentation/all_files_screen.dart';
import 'package:file_stroage_system/features/auth/presentation/device_trust_screen.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_stroage_system/features/items/presentation/items_screen.dart';
import 'package:file_stroage_system/core/presentation/widgets/app_toast.dart'; // Add this import

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    AllFilesScreen(),
    ItemsScreen(), // This now refers to the imported ItemsScreen
    DeviceTrustScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final fileProvider = context.watch<FileProvider>();

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _pages),

          // Upload Progress Overlay
          if (fileProvider.isUploading) _buildUploadOverlay(fileProvider),
        ],
      ),

      // Minimalistic Bottom Navigation
      bottomNavigationBar: _buildMinimalNavBar(),
    );
  }

  Widget _buildUploadOverlay(FileProvider fileProvider) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Upload Icon with Animation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Uploading File',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // File Name
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fileProvider.uploadingFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 24),

              // Progress Bar
              SizedBox(
                width: 200,
                child: Stack(
                  children: [
                    // Background
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    // Progress
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 200 * fileProvider.uploadProgress,
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Percentage
              Text(
                '${fileProvider.uploadProgressPercent}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Please wait...',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalNavBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / 4; // 4 nav items

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.textSecondary.withOpacity(0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 72,
          child: Stack(
            children: [
              // Sliding Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: (_currentIndex * itemWidth) + (itemWidth / 2) - 20,
                top: 0,
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(3),
                      bottomRight: Radius.circular(3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              // Navigation Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    0,
                    Icons.home_outlined,
                    Icons.home_rounded,
                    'Home',
                  ),
                  _buildNavItem(
                    1,
                    Icons.folder_outlined,
                    Icons.folder_rounded,
                    'Files',
                  ),
                  _buildNavItem(2, Icons.notes, Icons.notes_rounded, 'Notes'),
                  _buildNavItem(
                    3,
                    Icons.devices_outlined,
                    Icons.devices_rounded,
                    'Devices',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppTheme.animFast,
        curve: Curves.easeOut,
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with scale animation
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: AppTheme.animFast,
                padding: EdgeInsets.all(isSelected ? 8 : 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Label with animation
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;
        final fileProvider = context.read<FileProvider>();

        // Show uploading toast
        AppToast.info(
          context,
          'Uploading ${file.name}...',
          duration: const Duration(seconds: 10),
        );

        await fileProvider.uploadFile(file);

        // Refresh user profile to update storage usage
        if (mounted) {
          await context.read<AuthProvider>().fetchUserProfile();
        }

        if (mounted) {
          // Hide previous toast is not directly supported by AppToast like SnackBar,
          // but showing a new one usually overlays or is fine.
          // If AppToast implementation supports removing, we could use that.
          // For now, just showing success.
          AppToast.success(context, '${file.name} uploaded successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Upload failed: $e');
      }
    }
  }
}
