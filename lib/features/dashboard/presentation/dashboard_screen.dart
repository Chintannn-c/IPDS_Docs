import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_stroage_system/core/presentation/widgets/secure_avatar.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'package:file_stroage_system/core/presentation/widgets/status_indicator.dart';
import 'package:file_stroage_system/core/presentation/widgets/animations.dart';
import 'package:file_stroage_system/core/presentation/widgets/touch_card.dart';
import 'package:file_stroage_system/core/presentation/widgets/notification_badge.dart';

// Providers
import '../../auth/presentation/auth_provider.dart';
import '../../ipds/presentation/ipds_provider.dart';
import '../../dashboard/presentation/file_provider.dart';
import 'widgets/dashboard_metric_card.dart';
import 'widgets/ipds_live_dashboard_card.dart';
import '../../ipds/presentation/ipds_screen.dart';
import '../../../core/presentation/utils/screen_utils.dart'; // Fixed import

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  Future<void> _refreshAll() async {
    // We use read to trigger actions, watch is for build
    await Future.wait([
      context.read<IPDSProvider>().fetchLogs(),
      context.read<IPDSProvider>().fetchDashboardStats(),
      context.read<IPDSProvider>().fetchRiskAnalysis(),
      context.read<FileProvider>().fetchFiles(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to providers for UI updates
    final authProvider = context.watch<AuthProvider>();
    final ipdsProvider = context.watch<IPDSProvider>();
    final fileProvider = context.watch<FileProvider>();
    // final timeProvider = context.watch<TimeProvider>(); // Unused locally now

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: CustomScrollView(
            slivers: [
              // Custom Header
              SliverToBoxAdapter(
                child: FadeIn(
                  duration: AppTheme.animNormal,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ScreenUtils.spacing(context),
                      vertical: ScreenUtils.spacing(context) / 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/icon.png',
                              height: 32,
                              width: 32,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'IPDS DOCS',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NotificationBadge(
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/notifications',
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildProfileAvatar(context, authProvider),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              SliverPadding(
                padding: EdgeInsets.all(ScreenUtils.spacing(context)),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Security Status Banner
                    SlideUp(
                      delay: const Duration(milliseconds: 100),
                      child: Builder(
                        builder: (context) {
                          // Get multiple security indicators
                          final riskScore =
                              ipdsProvider.risk['risk_score'] ?? 0;
                          final blockedDevices = ipdsProvider.riskDeviceCount;
                          final securityAlerts =
                              ipdsProvider.securityAlerts.length;

                          // Determine security status based on multiple factors
                          SecurityStatus status;
                          String message;

                          if (riskScore >= 70 || blockedDevices > 0) {
                            // Critical - high risk or blocked devices
                            status = SecurityStatus.critical;
                            if (blockedDevices > 0) {
                              message =
                                  '$blockedDevices device${blockedDevices > 1 ? 's' : ''} blocked - Immediate action required';
                            } else {
                              message =
                                  'High risk detected - Review security settings';
                            }
                          } else if (riskScore >= 40 || securityAlerts > 0) {
                            // Attention needed
                            status = SecurityStatus.attention;
                            if (securityAlerts > 0) {
                              message =
                                  '$securityAlerts security alert${securityAlerts > 1 ? 's' : ''} need attention';
                            } else {
                              message = 'Security score needs improvement';
                            }
                          } else {
                            // All clear
                            status = SecurityStatus.secure;
                            message = 'All systems operating normally';
                          }

                          return StatusBanner(
                            status: status,
                            customMessage: message,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const IPDSScreen(initialIndex: 2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    // 1. Device Card
                    SlideUp(
                      delay: const Duration(milliseconds: 200),
                      child: DashboardMetricCard(
                        title: 'Devices',
                        value: '${ipdsProvider.safeDeviceCount} Safe',
                        subValue: ipdsProvider.riskDeviceCount > 0
                            ? '${ipdsProvider.riskDeviceCount} need review'
                            : 'All devices secure',
                        icon: Icons.devices_rounded,
                        iconColor: ipdsProvider.riskDeviceCount > 0
                            ? AppTheme.warningColor
                            : AppTheme.successColor,
                        onTap: () => Navigator.pushNamed(context, '/devices'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    // 2. Files Card
                    SlideUp(
                      delay: const Duration(milliseconds: 300),
                      child: DashboardMetricCard(
                        title: 'Files',
                        value: '${fileProvider.files.length} Total',
                        subValue: 'All files secure',
                        icon: Icons.folder_rounded,
                        iconColor: AppTheme.primaryColor,
                        onTap: () => Navigator.pushNamed(context, '/all_files'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    // 3. Security Health Score Card
                    SlideUp(
                      delay: const Duration(milliseconds: 400),
                      child: Builder(
                        builder: (context) {
                          // Calculate protection score
                          final riskScore =
                              ipdsProvider.risk['risk_score'] ?? 0;
                          final protectionScore =
                              100 -
                              (riskScore is int
                                  ? riskScore
                                  : (riskScore as num).toInt());

                          // Dynamic color and status based on score
                          Color scoreColor;
                          String statusText;

                          if (protectionScore >= 80) {
                            scoreColor = const Color(
                              0xFF10B981,
                            ); // Emerald green
                            statusText = 'Excellent protection';
                          } else if (protectionScore >= 60) {
                            scoreColor = const Color(0xFF22C55E); // Green
                            statusText = 'Good protection';
                          } else if (protectionScore >= 40) {
                            scoreColor = const Color(0xFFF59E0B); // Amber
                            statusText = 'Needs improvement';
                          } else if (protectionScore >= 20) {
                            scoreColor = const Color(0xFFF97316); // Orange
                            statusText = 'At risk';
                          } else {
                            scoreColor = const Color(0xFFEF4444); // Red
                            statusText = 'Critical - Take action';
                          }

                          return DashboardMetricCard(
                            title: 'Security Health',
                            value: '$protectionScore%',
                            subValue: statusText,
                            icon: Icons.shield_rounded,
                            iconColor: scoreColor,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),

                    // 4. Live Dashboard
                    SlideUp(
                      delay: const Duration(milliseconds: 500),
                      child: IpdsLiveDashboardCard(
                        logs: ipdsProvider.logs
                            .take(3)
                            .map(
                              (log) => {
                                'action': log.action,
                                'level': log.severity,
                                'timestamp': log.timestamp.toIso8601String(),
                              },
                            )
                            .toList(),
                        onViewAll: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const IPDSScreen(initialIndex: 1),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // 5. Recent Files Section
                    SlideUp(
                      delay: const Duration(milliseconds: 600),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Files',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/all_files'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingM,
                                    vertical: AppTheme.spacingS,
                                  ),
                                  minimumSize: const Size(
                                    0,
                                    AppTheme.touchTargetMin,
                                  ),
                                ),
                                child: const Text(
                                  'View All',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          if (fileProvider.isLoading &&
                              fileProvider.files.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppTheme.spacingL),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (fileProvider.files.isEmpty)
                            TouchCard(
                              padding: const EdgeInsets.all(AppTheme.spacingL),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.folder_open_rounded,
                                    size: 48,
                                    color: AppTheme.textSecondary.withOpacity(
                                      0.5,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                  Text(
                                    'No files yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingXS),
                                  Text(
                                    'Upload your first file to get started',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary.withOpacity(
                                        0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...fileProvider.files
                                .take(2)
                                .map(
                                  (file) => _buildFileCard(
                                    context,
                                    file,
                                    fileProvider,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user;
    if (user == null) return const SizedBox.shrink();

    final userName = user['name'] ?? 'User';
    final userEmail = user['email'] ?? '';
    final profileImage = user['profile_image'];

    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'logout') {
          await authProvider.logout();
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          }
        } else if (value == 'profile') {
          Navigator.pushNamed(context, '/profile');
        } else if (value == 'refresh') {
          _refreshAll();
        }
      },
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      color: const Color(0xFF1E293B),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.3),
      itemBuilder: (context) => [
        // User Header Section
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.15),
                  const Color(0xFF3B82F6).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: SecureAvatar(
                    radius: 22,
                    imageUrl: profileImage,
                    fallbackInitials: userName,
                    backgroundColor: const Color(0xFF3B82F6).withOpacity(0.2),
                    textColor: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (userEmail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          userEmail,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Divider
        PopupMenuItem<String>(
          enabled: false,
          height: 1,
          padding: EdgeInsets.zero,
          child: Container(height: 1, color: Colors.white.withOpacity(0.08)),
        ),

        // Profile Option
        PopupMenuItem<String>(
          value: 'profile',
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _buildMenuItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            iconColor: const Color(0xFF3B82F6),
          ),
        ),

        // Refresh Option
        PopupMenuItem<String>(
          value: 'refresh',
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _buildMenuItem(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            iconColor: const Color(0xFF22C55E),
          ),
        ),

        // Divider before logout
        PopupMenuItem<String>(
          enabled: false,
          height: 1,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white.withOpacity(0.08),
          ),
        ),

        // Logout Option
        PopupMenuItem<String>(
          value: 'logout',
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _buildMenuItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            iconColor: const Color(0xFFEF4444),
            textColor: const Color(0xFFEF4444),
          ),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: SecureAvatar(
          radius: 18,
          imageUrl: profileImage,
          fallbackInitials: userName,
          backgroundColor: const Color(0xFF3B82F6).withOpacity(0.15),
          textColor: const Color(0xFF3B82F6),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: textColor ?? Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(
    BuildContext context,
    dynamic file,
    FileProvider fileProvider,
  ) {
    final fileName = file['filename'] ?? 'Unknown File';
    final fileSize = file['size'] ?? 0;
    final isImage =
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg');

    return TouchCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      onTap: () => fileProvider.openFile(file['id'], fileName),
      child: Row(
        children: [
          // File Icon
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(
              isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),

          // File Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileSize(fileSize),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),

          // Download Button with proper touch target
          SizedBox(
            width: AppTheme.touchTargetMin,
            height: AppTheme.touchTargetMin,
            child: IconButton(
              icon: Icon(
                Icons.download_rounded,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              onPressed: () => fileProvider.downloadFile(file['id'], fileName),
              splashRadius: 20,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(dynamic size) {
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
