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
  bool _isSaving = false;
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
        final data = await ApiClient().analyzeFile(widget.fileId);
        setState(() {
          _analysis = data;
        });
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

  Future<void> _saveSummary() async {
    if (_analysis == null) return;
    setState(() => _isSaving = true);
    try {
      final result = await ApiClient().saveSummary(
        widget.fileId,
        widget.filename,
        _analysis!,
      );
      AppToast.success(context, 'Summary saved to history');
      await _loadHistory();
      setState(() {
        _summaryId = result['_id'];
      });
      if (mounted) {
        context.read<SummaryProvider>().addSummaryFromData(result);
        context.read<SummaryProvider>().fetchHistory();
      }
    } catch (e) {
      AppToast.error(context, 'Failed to save: $e');
    } finally {
      setState(() => _isSaving = false);
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
        'Please save the summary first to download PDF',
      );
      return;
    }

    try {
      final bytes = await ApiClient().exportSummaryPdf(_summaryId!);
      final filename = 'summary_${_analysis?['document_name'] ?? 'report'}.pdf';

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
                // Show analysis metadata if available
                if (_analysis!['analysis_confidence'] != null ||
                    _analysis!['security_status'] != null)
                  _buildAnalysisMetadata(),
                if (_analysis!['analysis_confidence'] != null ||
                    _analysis!['security_status'] != null)
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSummary,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('SAVE SUMMARY'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
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
    return _buildCard(
      title: 'SECURITY-SAFE SUMMARY',
      icon: Icons.summarize,
      child: Text(
        _analysis!['summary'] ?? 'No summary available.',
        style: const TextStyle(height: 1.5, fontSize: 15),
      ),
    );
  }

  Widget _buildKeyPointsSection() {
    final points = List<String>.from(_analysis!['key_points'] ?? []);
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
    final flags = List<String>.from(_analysis!['risk_flags'] ?? []);
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
          _analysis!['content_preview'] ?? 'No preview available.',
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

  Widget _buildAnalysisMetadata() {
    final confidence =
        _analysis!['analysis_confidence']?.toString().toUpperCase() ??
        'UNKNOWN';
    final securityStatus =
        _analysis!['security_status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final extractionMethod = _analysis!['text_source']
        ?.toString()
        .toUpperCase();
    final ocrExecuted = _analysis!['ocr_executed'] == true;

    Color confidenceColor = Colors.grey;
    if (confidence == 'HIGH') confidenceColor = Colors.green;
    if (confidence == 'MEDIUM') confidenceColor = Colors.orange;
    if (confidence == 'LOW') confidenceColor = Colors.red;

    Color securityColor = Colors.grey;
    if (securityStatus == 'SAFE') securityColor = Colors.green;
    if (securityStatus == 'SUSPICIOUS') securityColor = Colors.orange;
    if (securityStatus == 'RISKY') securityColor = Colors.red;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetadataBadge(
                    'Confidence',
                    confidence,
                    confidenceColor,
                    Icons.analytics,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetadataBadge(
                    'Security',
                    securityStatus,
                    securityColor,
                    Icons.shield,
                  ),
                ),
                if (extractionMethod != null) const SizedBox(width: 12),
                if (extractionMethod != null)
                  Expanded(
                    child: _buildMetadataBadge(
                      'Method',
                      extractionMethod,
                      Colors.blue,
                      Icons.text_fields,
                    ),
                  ),
              ],
            ),
            if (ocrExecuted) const SizedBox(height: 12),
            if (ocrExecuted)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.document_scanner,
                      color: Colors.purple,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OCR PROCESSING APPLIED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataBadge(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return _buildCard(
      title: 'ANALYSIS NOTES',
      icon: Icons.info_outline,
      child: Text(
        _analysis!['notes'] ?? '',
        style: TextStyle(
          height: 1.5,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
