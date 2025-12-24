import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class Summary {
  final String id;
  final String documentId;
  final String documentName;
  final String summary;
  final List<String> keyPoints;
  final List<String> riskFlags;
  final String contentPreview;
  final int version;
  final String userEmail;
  final DateTime summarizedAt;

  Summary({
    required this.id,
    required this.documentId,
    required this.documentName,
    required this.summary,
    required this.keyPoints,
    required this.riskFlags,
    required this.contentPreview,
    required this.version,
    required this.userEmail,
    required this.summarizedAt,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    try {
      String dateStr =
          json['summarized_at'] ?? DateTime.now().toIso8601String();
      if (!dateStr.contains('Z') && !dateStr.contains('+')) {
        dateStr += 'Z';
      }

      final summarizedBy = json['summarized_by'] as Map<String, dynamic>?;

      return Summary(
        id: json['_id']?.toString() ?? '',
        documentId: json['document_id']?.toString() ?? '',
        documentName: json['document_name']?.toString() ?? 'Unknown',
        summary: json['summary']?.toString() ?? 'No summary content available.',
        keyPoints: json['key_points'] != null
            ? List<String>.from(json['key_points'])
            : [],
        riskFlags: json['risk_flags'] != null
            ? List<String>.from(json['risk_flags'])
            : [],
        contentPreview: json['content_preview']?.toString() ?? '',
        version: json['version'] ?? 1,
        userEmail: summarizedBy?['user_email']?.toString() ?? 'Unknown',
        summarizedAt: DateTime.parse(dateStr).toLocal(),
      );
    } catch (e, stack) {
      debugPrint('Error parsing Summary JSON: $e');
      debugPrint('JSON data: $json');
      debugPrint('Stack trace: $stack');
      // Return a fallback summary to prevent the list from crashing entirely
      return Summary(
        id: 'error',
        documentId: '',
        documentName: 'Error Loading',
        summary: 'Failed to parse this summary.',
        keyPoints: [],
        riskFlags: [],
        contentPreview: '',
        version: 0,
        userEmail: '',
        summarizedAt: DateTime.now(),
      );
    }
  }
}

class SummaryProvider extends ChangeNotifier {
  List<Summary> _summaries = [];
  bool _isLoading = false;

  List<Summary> get summaries => _summaries;
  bool get isLoading => _isLoading;

  Future<void> fetchHistory() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiClient().fetchSummaryHistory();
      _summaries = data.map((json) => Summary.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching summary history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addSummaryFromData(Map<String, dynamic> data) {
    _summaries.insert(0, Summary.fromJson(data));
    notifyListeners();
  }
}
