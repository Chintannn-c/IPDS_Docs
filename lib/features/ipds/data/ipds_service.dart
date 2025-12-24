import '../../../core/api/api_client.dart';
import '../../../core/models/activity_log.dart';
import '../../../core/models/file_tracking.dart';

class IPDSService {
  final ApiClient _apiClient = ApiClient();

  Future<List<ActivityLog>> fetchActivityLogs({int limit = 50}) async {
    try {
      final response = await _apiClient.dio.get(
        '/live/activity-logs',
        queryParameters: {'limit': limit},
      );
      return (response.data as List)
          .map((json) => ActivityLog.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch logs: $e');
    }
  }

  Future<FileTracking> fetchFileTracking(String fileId) async {
    try {
      final response = await _apiClient.dio.get('/live/file-tracking/$fileId');
      return FileTracking.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch file tracking: $e');
    }
  }
}
