import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/presentation/widgets/responsive_center.dart';
import 'file_provider.dart';
import '../../../core/presentation/utils/screen_utils.dart'; // Add import

class AllFilesScreen extends StatefulWidget {
  const AllFilesScreen({super.key});

  @override
  State<AllFilesScreen> createState() => _AllFilesScreenState();
}

class _AllFilesScreenState extends State<AllFilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fileProvider = context.watch<FileProvider>();

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            children: [
              _buildHeader(context),
              Padding(
                padding: EdgeInsets.all(ScreenUtils.spacing(context)),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'SEARCH ENCRYPTED FILES...',
                    prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : const SizedBox(),
                  ),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (fileProvider.isLoading && fileProvider.files.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final filtered = fileProvider.files.where((f) {
                      return (f['filename']?.toLowerCase() ?? '').contains(
                        _searchQuery.toLowerCase(),
                      );
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          "NO FILES FOUND",
                          style: theme.textTheme.titleMedium,
                        ),
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ScreenUtils.spacing(context),
                      ),
                      child: GridView.builder(
                        itemCount: filtered.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                        itemBuilder: (context, index) => _buildFileItem(
                          context,
                          filtered[index],
                          fileProvider,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'all_files_fab',
        onPressed: () => fileProvider.uploadFile(),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 0,
        left: ScreenUtils.spacing(context),
        right: ScreenUtils.spacing(context),
        bottom: 6,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered Title
          Center(
            child: Text(
              "File Vault",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          // Right-aligned History Button
          Positioned(
            right: 0,
            child: IconButton(
              icon: Icon(
                Icons.history_edu_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              tooltip: "Summarized History",
              onPressed: () {
                Navigator.pushNamed(context, '/history'); // Go to History Page
              },
            ),
          ),
        ],
      ),
    );
  }

  // ... (Keep existing methods until _showSummarizingDialog)

  Widget _buildFileItem(
    BuildContext context,
    Map<String, dynamic> file,
    FileProvider provider,
  ) {
    final isRisky = file['is_risky'] == true;
    final isQuarantined = file['is_quarantined'] == true;
    final isUnsafe = isRisky || isQuarantined;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine border color based on file status
    Color borderColor = colorScheme.outline.withOpacity(0.1);
    if (isQuarantined) {
      borderColor = Colors.red.withOpacity(0.5);
    } else if (isRisky) {
      borderColor = Colors.orange.withOpacity(0.4);
    }

    return Card(
      elevation: isUnsafe ? 2 : 0,
      shadowColor: isQuarantined
          ? Colors.red.withOpacity(0.3)
          : (isRisky ? Colors.orange.withOpacity(0.3) : Colors.transparent),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: isUnsafe ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Only block access if file is quarantined
          // Risky files with accepted risk should be accessible
          if (file['is_quarantined'] == true) {
            _showRiskConfirmationDialog(context, file, provider);
          } else {
            _showFileOptionsSheet(context, file, provider);
          }
        },
        onLongPress: () => _confirmDelete(context, file, provider),
        child: Container(
          decoration: isUnsafe
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (isQuarantined ? Colors.red : Colors.orange).withOpacity(
                        0.08,
                      ),
                      Colors.transparent,
                    ],
                  ),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // File Icon with Warning Overlay
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Background glow for risky files
                    if (isUnsafe)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              (isQuarantined ? Colors.red : Colors.orange)
                                  .withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    Icon(
                      _getFileIcon(file['filename']),
                      size: 48,
                      color: isUnsafe
                          ? (isQuarantined
                                ? Colors.red.shade400
                                : Colors.orange.shade400)
                          : colorScheme.primary,
                    ),
                    // Warning badge positioned at top-right
                    if (isUnsafe)
                      Positioned(
                        top: -4,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isQuarantined ? Colors.red : Colors.orange,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isQuarantined ? Colors.red : Colors.orange)
                                        .withOpacity(0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            isQuarantined ? Icons.block : Icons.warning_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // File name
                Text(
                  file['filename'] ?? 'Unknown',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: isUnsafe
                        ? (isQuarantined
                              ? Colors.red.shade700
                              : colorScheme.onSurface)
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                // Safety badge
                _buildSafetyBadge(context, file),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String? filename) {
    if (filename == null) return Icons.insert_drive_file;
    final ext = filename.split('.').last.toLowerCase();
    if (['jpg', 'png', 'jpeg'].contains(ext)) return Icons.image;
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  Widget _buildSafetyBadge(BuildContext context, Map<String, dynamic> file) {
    final isRisky = file['is_risky'] == true;
    final isQuarantined = file['is_quarantined'] == true;

    Color color;
    String label;
    IconData icon;

    if (isQuarantined) {
      color = Colors.red;
      label = "QUARANTINED";
      icon = Icons.gpp_bad_rounded;
    } else if (isRisky) {
      color = Colors.orange;
      label = "RISKY";
      icon = Icons.warning_amber_rounded;
    } else {
      color = Colors.green;
      label = "SECURE";
      icon = Icons.verified_user_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  void _showRiskConfirmationDialog(
    BuildContext context,
    Map<String, dynamic> file,
    FileProvider provider,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            const Text("Security Alert"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This file has been detected as risky.",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Reason: ${file['risk_reason'] ?? 'Suspicious patterns detected'}",
            ),
            const SizedBox(height: 16),
            const Text("Do you want to remove it from the file vault?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.declineRisk(file['id']);
            },
            child: const Text("Keep Quarantined"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await provider.confirmRisk(file['id']);
            },
            child: const Text("Yes, Remove It"),
          ),
        ],
      ),
    );
  }

  void _showFileOptionsSheet(
    BuildContext context,
    Map<String, dynamic> file,
    FileProvider provider,
  ) {
    final id = file['id'];
    final name = file['filename'] ?? 'unknown';
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // File name header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          _getFileIcon(name),
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Open File
                  _buildOptionTile(
                    context,
                    icon: Icons.open_in_new_rounded,
                    iconColor: Colors.blue,
                    title: 'Open File',
                    subtitle: 'View or download this file',
                    onTap: () {
                      Navigator.pop(context);
                      provider.openFile(id, name);
                    },
                  ),

                  // Summarize File (Real AI Analysis)
                  _buildOptionTile(
                    context,
                    icon: Icons.summarize_rounded,
                    iconColor: Colors.orange,
                    title: 'Summarize',
                    subtitle: 'AI Analysis & Key Insights',
                    onTap: () {
                      Navigator.pop(context); // Close sheet
                      Navigator.pushNamed(
                        context,
                        '/document_analysis',
                        arguments: {'fileId': id, 'filename': name},
                      );
                    },
                  ),

                  // File Details
                  _buildOptionTile(
                    context,
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.purple,
                    title: 'File Details',
                    subtitle: 'View security info and metadata',
                    onTap: () {
                      Navigator.pop(context);
                      _showFileDetailsModal(context, file);
                    },
                  ),

                  // Download File
                  _buildOptionTile(
                    context,
                    icon: Icons.download_rounded,
                    iconColor: Colors.green,
                    title: 'Download File',
                    subtitle: 'Save to Downloads folder',
                    onTap: () {
                      Navigator.pop(context);
                      provider.downloadFile(id, name);
                    },
                  ),

                  // Share / Save As
                  _buildOptionTile(
                    context,
                    icon: Icons.share_rounded,
                    iconColor: Colors.pink,
                    title: 'Share / Save As',
                    subtitle: 'Save to Downloads, Drive, or share',
                    onTap: () {
                      Navigator.pop(context);
                      provider.shareFile(id, name);
                    },
                  ),

                  // Delete File
                  _buildOptionTile(
                    context,
                    icon: Icons.delete_outline_rounded,
                    iconColor: Colors.red,
                    title: 'Delete File',
                    subtitle: 'Permanently remove this file',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDelete(context, file, provider);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      onTap: onTap,
    );
  }

  void _showFileDetailsModal(BuildContext context, Map<String, dynamic> file) {
    final name = file['filename'] ?? 'Unknown';
    final size = file['size'] as int? ?? 0;
    final safetyScore = file['safety_score'] as int? ?? 80;
    final uploadedAt = file['uploaded_at'] as String?;
    final colorScheme = Theme.of(context).colorScheme;

    // Determine security status
    final isSecure = safetyScore >= 70;
    final statusColor = isSecure
        ? Colors.green
        : (safetyScore >= 40 ? Colors.orange : Colors.red);
    final statusLabel = isSecure
        ? 'SECURE'
        : (safetyScore >= 40 ? 'CAUTION' : 'RISK');
    final statusMessage = isSecure
        ? 'This file passed all security checks'
        : (safetyScore >= 40
              ? 'This file has some security concerns'
              : 'This file may be unsafe');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),

              // Security Score Ring
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      statusColor.withOpacity(0.15),
                      statusColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: safetyScore / 100,
                              strokeWidth: 8,
                              backgroundColor: statusColor.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation(statusColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$safetyScore',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'SCORE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      statusMessage,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // File Name Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getFileIcon(name),
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FILE NAME',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withOpacity(0.5),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Metadata Row
              Row(
                children: [
                  // Uploaded
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 20,
                            color: Colors.purple,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'UPLOADED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _formatDate(uploadedAt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Size
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storage_rounded,
                            size: 20,
                            color: Colors.pink,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SIZE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _formatFileSize(size),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  void _confirmDelete(
    BuildContext context,
    Map<String, dynamic> file,
    FileProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete File?"),
        content: Text("Permanently delete ${file['filename']}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteFile(file['id']);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
