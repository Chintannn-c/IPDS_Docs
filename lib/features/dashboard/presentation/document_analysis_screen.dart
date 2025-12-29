import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../../core/api/api_client.dart';
import '../../../../core/presentation/widgets/app_toast.dart'; // Add this import
import 'summary_provider.dart';
import 'widgets/ai_loading_animation.dart';
import 'widgets/note_editor_screen.dart';

class DocumentAnalysisScreen extends StatefulWidget {
  final String fileId;
  final String filename;

  const DocumentAnalysisScreen({
    super.key,
    required this.fileId,
    required this.filename,
  });

  @override
  State<DocumentAnalysisScreen> createState() => _DocumentAnalysisScreenState();
}

class _DocumentAnalysisScreenState extends State<DocumentAnalysisScreen> {
  Map<String, dynamic>? _analysis;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String? _error;
  String? _summaryId; // ID of the saved summary if applicable

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Try fetching existing analysis first
      try {
        final data = await ApiClient().fetchFileAnalysis(widget.fileId);
        setState(() {
          _analysis = data;
        });
      } catch (e) {
        // If not found, trigger a new analysis
        try {
          final data = await ApiClient().analyzeFile(widget.fileId);
          setState(() {
            _analysis = data;
          });
        } catch (analyzeError) {
          // Extract detailed error message from backend
          String errorMessage = 'Failed to analyze document';

          if (analyzeError.toString().contains('DioException')) {
            // Try to extract the actual error message from response
            final errorStr = analyzeError.toString();
            if (errorStr.contains('detail')) {
              // Extract JSON detail if present
              final detailMatch = RegExp(
                r'"detail":"([^"]+)"',
              ).firstMatch(errorStr);
              if (detailMatch != null) {
                errorMessage = detailMatch.group(1) ?? errorMessage;
              }
            } else if (errorStr.contains('message')) {
              final msgMatch = RegExp(
                r'"message":"([^"]+)"',
              ).firstMatch(errorStr);
              if (msgMatch != null) {
                errorMessage = msgMatch.group(1) ?? errorMessage;
              }
            }
          } else {
            errorMessage = analyzeError.toString();
          }

          // Show error dialog and navigate back
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 28),
                    SizedBox(width: 12),
                    Text('Analysis Failed'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unable to analyze this document:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        errorMessage,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Possible reasons:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildErrorReason('File not found or deleted'),
                    _buildErrorReason('Unsupported file format'),
                    _buildErrorReason('File is corrupted or encrypted'),
                    _buildErrorReason('File belongs to another user'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context); // Go back to previous screen
                    },
                    child: Text('OK'),
                  ),
                ],
              ),
            );
          }
          return; // Exit early, don't continue
        }
      }

      // Load history
      await _loadHistory();

      setState(() {
        _isLoading = false;
      });

      // Check if AI couldn't summarize and show alert
      if (_analysis != null &&
          (_analysis!['summary'] == null ||
              _analysis!['summary'].toString().isEmpty)) {
        _showCannotSummarizeDialog();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildErrorReason(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: Colors.grey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  void _showCannotSummarizeDialog() {
    final notes =
        _analysis!['notes']?.toString() ??
        'Unable to extract readable text from this document.';
    final extractionMethod =
        _analysis!['extraction_method']?.toString() ?? 'none';
    final confidence = _analysis!['analysis_confidence']?.toString() ?? 'low';

    String reason = notes;
    if (extractionMethod == 'none') {
      reason =
          'This document could not be processed. The file may be:\n• Encrypted or password-protected\n• An unsupported format\n• Corrupted or damaged\n• An image without readable text';
    } else if (confidence == 'low') {
      reason =
          'Text extraction confidence is too low. The document may be:\n• A scanned image with poor quality\n• Handwritten content\n• Contains non-standard fonts\n\n$notes';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 48,
            ),
            title: const Text('Cannot Summarize Document'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Try uploading a different format or higher quality version.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to file list
                },
                child: const Text('GO BACK'),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ApiClient().fetchSummaryHistory(
        documentId: widget.fileId,
      );
      setState(() {
        _history = history;
        if (history.isNotEmpty) {
          _summaryId = history.first['_id'];
        }
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _reSummarize() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiClient().resummarize(widget.fileId);
      setState(() {
        _analysis = {
          'summary': result['summary'],
          'key_points': result['key_points'],
          'risk_flags': result['risk_flags'],
          'content_preview': result['content_preview'],
        };
        _summaryId = result['_id'];
      });
      await _loadHistory();
      if (mounted) {
        context.read<SummaryProvider>().addSummaryFromData(result);
      }
      AppToast.success(context, 'New version generated and saved');
    } catch (e) {
      AppToast.error(context, 'Re-summarize failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_summaryId == null) {
      AppToast.warning(
        context,
        'Summary is being generated. Please wait a moment.',
      );
      return;
    }

    try {
      final bytes = await ApiClient().exportSummaryPdf(_summaryId!);

      // Create unique filename with timestamp to avoid duplicates
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final baseFilename = _analysis?['document_name'] ?? 'report';
      final filename = 'summary_${baseFilename}_$timestamp.pdf';

      if (kIsWeb) {
        // Web download
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename);
        anchor.click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile/Desktop save
        final directory = await getApplicationDocumentsDirectory();
        final file = io.File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);

        // Open the file
        await OpenFilex.open(file.path);
      }

      if (mounted) {
        AppToast.success(context, 'PDF saved successfully: $filename');
      }
    } catch (e) {
      debugPrint('PDF Error: $e');
      if (mounted) {
        AppToast.error(context, 'Failed to save PDF: $e');
      }
    }
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SUMMARY HISTORY'),
        content: SizedBox(
          width: double.maxFinite,
          child: _history.isEmpty
              ? const Center(child: Text('No history available.'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    String dateStr = item['summarized_at'];
                    if (!dateStr.contains('Z') && !dateStr.contains('+')) {
                      dateStr += 'Z';
                    }
                    final date = DateTime.parse(dateStr).toLocal();
                    final risks = List.from(item['risk_flags'] ?? []);

                    final timeFormat =
                        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

                    return ListTile(
                      leading: CircleAvatar(child: Text('v${item['version']}')),
                      title: Text('Version ${item['version']}'),
                      subtitle: Text(
                        '${date.day}/${date.month}/${date.year} $timeFormat • ${risks.length} Risks',
                      ),
                      onTap: () {
                        setState(() {
                          _analysis = item;
                          _summaryId = item['_id'];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _error != null
            ? _buildErrorState()
            : _buildAnalysisContent(),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: _showHistoryDialog,
                tooltip: 'Summary History',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadAnalysis,
                tooltip: 'Re-analyze',
              ),
            ],
          ),
          const Text(
            'Summary',
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        _buildCustomHeader(),
        Expanded(child: Center(child: AILoadingAnimation())),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        _buildCustomHeader(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'ANALYSIS FAILED',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error ?? 'An unknown error occurred',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadAnalysis,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisContent() {
    if (_analysis == null) return const SizedBox();

    return Column(
      children: [
        _buildCustomHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFileHeader(),
                const SizedBox(height: 20),
                // AI Analysis Panel - New Enhanced Section
                _buildAIAnalysisPanel(),
                const SizedBox(height: 20),
                _buildSummarySection(),
                const SizedBox(height: 20),
                _buildKeyPointsSection(),
                const SizedBox(height: 20),
                _buildRiskFlagsSection(),
                const SizedBox(height: 20),
                _buildPreviewSection(),
                // Show notes if available
                if (_analysis!['notes'] != null &&
                    _analysis!['notes'].toString().isNotEmpty)
                  const SizedBox(height: 20),
                if (_analysis!['notes'] != null &&
                    _analysis!['notes'].toString().isNotEmpty)
                  _buildNotesSection(),
                const SizedBox(height: 30),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _reSummarize,
            icon: const Icon(Icons.restart_alt),
            label: const Text('RE-SUMMARIZE'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _downloadPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('DOWNLOAD PDF'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.filename,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Text(
                //   'Analysis powered by Mistral AI',
                //   style: TextStyle(fontSize: 12, color: colorScheme.outline),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    // Safe string extraction
    String getSummaryText() {
      final value = _analysis!['summary'];
      if (value == null) return 'No summary available.';
      if (value is String) return value;
      if (value is Map || value is List) return 'No summary available.';
      return value.toString();
    }

    return _buildCard(
      title: 'SECURITY-SAFE SUMMARY',
      icon: Icons.summarize,
      child: Text(
        getSummaryText(),
        style: const TextStyle(height: 1.5, fontSize: 15),
      ),
    );
  }

  Widget _buildKeyPointsSection() {
    // Safe list extraction
    List<String> getKeyPoints() {
      final value = _analysis!['key_points'];
      if (value == null) return [];
      if (value is List) {
        return value.whereType<String>().toList();
      }
      return [];
    }

    final points = getKeyPoints();
    return _buildCard(
      title: 'KEY INSIGHTS',
      icon: Icons.lightbulb,
      child: points.isEmpty
          ? const Text('No key points extracted.')
          : Column(
              children: points
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Text(p, style: const TextStyle(height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildRiskFlagsSection() {
    // Safe list extraction
    List<String> getRiskFlags() {
      final value = _analysis!['risk_flags'];
      if (value == null) return [];
      if (value is List) {
        return value.whereType<String>().toList();
      }
      return [];
    }

    final flags = getRiskFlags();
    return _buildCard(
      title: 'SECURITY SCAN RESULTS',
      icon: Icons.security,
      child: flags.isEmpty
          ? const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'No security risks detected.',
                  style: TextStyle(color: Colors.green),
                ),
              ],
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: flags.map((f) => _buildRiskChip(f)).toList(),
            ),
    );
  }

  Widget _buildRiskChip(String flag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              flag.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    // Safe string extraction
    String getPreviewText() {
      final value = _analysis!['content_preview'];
      if (value == null) return 'No preview available.';
      if (value is String) return value;
      if (value is Map || value is List) return 'No preview available.';
      return value.toString();
    }

    return _buildCard(
      title: 'CLEAN CONTENT PREVIEW',
      icon: Icons.remove_red_eye,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          getPreviewText(),
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAIAnalysisPanel() {
    // Safe extraction with type checking and fallbacks - enhanced version
    String getSafeString(dynamic value, String fallback) {
      if (value == null) return fallback;
      if (value is String) return value;
      // Handle Map and List - these should return fallback, not toString()
      if (value is Map || value is List) return fallback;
      // For primitives (int, double, bool), convert safely
      if (value is num || value is bool) return value.toString();
      // Last resort - but this should rarely be hit
      try {
        return value.toString();
      } catch (e) {
        return fallback;
      }
    }

    final documentType = getSafeString(_analysis!['document_type'], 'Document');
    final detectedStructure = getSafeString(
      _analysis!['detected_structure'],
      'Unknown',
    );
    final sensitivityLevel = getSafeString(
      _analysis!['sensitivity_level'],
      'Low',
    );
    final language = getSafeString(_analysis!['language'], 'English');
    final extractionMethod = getSafeString(
      _analysis!['extraction_method'],
      'Text-based',
    );
    final confidence = getSafeString(
      _analysis!['analysis_confidence'],
      'unknown',
    ).toUpperCase();
    final securityStatus = getSafeString(
      _analysis!['security_status'],
      'unknown',
    ).toUpperCase();

    Color confidenceColor = Colors.grey;
    IconData confidenceIcon = Icons.help_outline;
    if (confidence == 'HIGH') {
      confidenceColor = const Color(0xFF10B981);
      confidenceIcon = Icons.verified;
    }
    if (confidence == 'MEDIUM') {
      confidenceColor = const Color(0xFFF59E0B);
      confidenceIcon = Icons.report_problem;
    }
    if (confidence == 'LOW') {
      confidenceColor = const Color(0xFFEF4444);
      confidenceIcon = Icons.error;
    }

    Color securityColor = Colors.grey;
    IconData securityIcon = Icons.shield_outlined;
    if (securityStatus == 'SAFE') {
      securityColor = const Color(0xFF10B981);
      securityIcon = Icons.shield;
    }
    if (securityStatus == 'SUSPICIOUS') {
      securityColor = const Color(0xFFF59E0B);
      securityIcon = Icons.shield_moon;
    }
    if (securityStatus == 'RISKY') {
      securityColor = const Color(0xFFEF4444);
      securityIcon = Icons.gpp_bad;
    }

    Color sensitivityColor = Colors.grey;
    IconData sensitivityIcon = Icons.security;
    if (sensitivityLevel.toUpperCase() == 'LOW') {
      sensitivityColor = const Color(0xFF10B981);
      sensitivityIcon = Icons.lock_open;
    }
    if (sensitivityLevel.toUpperCase() == 'MEDIUM') {
      sensitivityColor = const Color(0xFFF59E0B);
      sensitivityIcon = Icons.lock_clock;
    }
    if (sensitivityLevel.toUpperCase() == 'HIGH') {
      sensitivityColor = const Color(0xFFEF4444);
      sensitivityIcon = Icons.lock;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B).withOpacity(0.8),
                  const Color(0xFF0F172A).withOpacity(0.9),
                ]
              : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Subtle pattern overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: CustomPaint(painter: _DotPatternPainter()),
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with gradient
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.psychology,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'AI ANALYSIS PANEL',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Powered by Advanced AI',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.outline,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Document Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          'Document Type',
                          documentType,
                          Icons.description_rounded,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          'Structure',
                          detectedStructure,
                          Icons.account_tree_rounded,
                          const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Status Badges - Premium Design
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STATUS METRICS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPremiumBadge(
                                'Confidence',
                                confidence,
                                confidenceColor,
                                confidenceIcon,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildPremiumBadge(
                                'Security',
                                securityStatus,
                                securityColor,
                                securityIcon,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildPremiumBadge(
                                'Sensitivity',
                                sensitivityLevel.toUpperCase(),
                                sensitivityColor,
                                sensitivityIcon,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Metadata Section
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetadataChip(
                          language,
                          Icons.language_rounded,
                          const Color(0xFFEC4899),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetadataChip(
                          extractionMethod,
                          Icons.text_snippet_rounded,
                          extractionMethod.toUpperCase().contains('OCR')
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF06B6D4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.outline,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBadge(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.2 : 0.1),
            color.withOpacity(isDark ? 0.15 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.outline,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip(String text, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(isDark ? 0.2 : 0.1),
            color.withOpacity(isDark ? 0.15 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    final notesContent = _analysis!['notes'] ?? '';

    return InkWell(
      onTap: () {
        if (notesContent.isNotEmpty) {
          _showNotesDetailPage();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: _buildCard(
        title: 'ANALYSIS NOTES',
        icon: Icons.info_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notesContent,
              style: TextStyle(
                height: 1.5,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (notesContent.length > 100) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Tap to read full note',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showNotesDetailPage() {
    final notesContent = _analysis!['notes'] ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          initialContent: notesContent,
          title: 'Analysis Notes',
        ),
      ),
    );
  }
}

// Custom painter for subtle dot pattern background
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
