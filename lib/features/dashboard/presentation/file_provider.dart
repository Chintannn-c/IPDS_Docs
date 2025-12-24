import 'package:file_stroage_system/core/api/api_client.dart';
import 'package:file_stroage_system/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class FileProvider with ChangeNotifier {
  final Dio _dio = ApiClient().dio;
  bool _isLoading = false;
  final List<dynamic> _files = []; // Simplified model

  // Upload state tracking
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadingFileName = '';

  bool get isLoading => _isLoading;
  List<dynamic> get files => _files;

  // Upload progress getters
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String get uploadingFileName => _uploadingFileName;
  int get uploadProgressPercent => (_uploadProgress * 100).toInt();

  String get totalUsage {
    int totalBytes = 0;
    for (var file in _files) {
      final size = file['size'];
      if (size is int) {
        totalBytes += size;
      }
    }
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024)
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> uploadFile([PlatformFile? existingFile]) async {
    PlatformFile file;

    if (existingFile != null) {
      file = existingFile;
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null) return;
      file = result.files.single;
    }

    // Check file size (100MB limit on frontend, backend has 50MB)
    const maxSize = 100 * 1024 * 1024; // 100MB
    final fileSize = file.size;
    if (fileSize > maxSize) {
      NotificationService().error(
        "File too large. Maximum size is 100MB.",
        title: "Upload Error",
      );
      return;
    }

    _isUploading = true;
    _isLoading = true;
    _uploadProgress = 0.0;
    _uploadingFileName = file.name;
    notifyListeners();

    try {
      String fileName = file.name;

      FormData formData;
      // Check bytes first (common for Web)
      if (file.bytes != null) {
        formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(file.bytes!, filename: fileName),
        });
      } else if (file.path != null) {
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path!, filename: fileName),
        });
      } else {
        throw Exception("No file data available");
      }

      await _dio.post(
        '/files/upload',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 10),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            _uploadProgress = sent / total;
            notifyListeners();
          }
        },
      );

      await fetchFiles(); // Refresh list
      NotificationService().success(
        "File uploaded successfully",
        title: "Upload Complete",
      );
    } catch (e) {
      debugPrint("Upload error: $e");
      String errorMessage = "Failed to upload file";
      if (e is DioException) {
        if (e.response?.statusCode == 413) {
          errorMessage = "File too large. Maximum size is 50MB.";
        } else if (e.response?.statusCode == 406) {
          errorMessage =
              e.response?.data?['detail'] ?? "File rejected by security scan";
        } else if (e.response?.statusCode == 409) {
          // Duplicate file detected
          errorMessage =
              e.response?.data?['detail'] ??
              "This file already exists in your storage.";
        } else if (e.type == DioExceptionType.sendTimeout) {
          errorMessage = "Upload timed out. Please try a smaller file.";
        }
      }
      NotificationService().error(errorMessage, title: "Upload Error");
    } finally {
      _isUploading = false;
      _isLoading = false;
      _uploadProgress = 0.0;
      _uploadingFileName = '';
      notifyListeners();
    }
  }

  Future<void> fetchFiles() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.get('/files/');
      _files.clear();
      _files.addAll(response.data);
    } catch (e) {
      debugPrint("Fetch files error: $e");
      // Don't notify on fetch error to avoid spamming on load
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteFile(String id) async {
    try {
      await _dio.delete('/files/$id');
      _files.removeWhere((file) => file['id'] == id);
      notifyListeners();
      NotificationService().success(
        "File deleted successfully",
        title: "Deleted",
      );
      return true;
    } catch (e) {
      debugPrint("Delete file error: $e");
      NotificationService().error(
        "Failed to delete file",
        title: "Delete Error",
      );
      return false;
    }
  }

  Future<bool> confirmRisk(String id) async {
    try {
      await _dio.post('/files/$id/confirm-risk');
      _files.removeWhere((file) => file['id'] == id);
      notifyListeners();
      NotificationService().success(
        "Risky file removed successfully",
        title: "Confirmed",
      );
      return true;
    } catch (e) {
      debugPrint("Confirm risk error: $e");
      NotificationService().error(
        "Failed to remove risky file",
        title: "Error",
      );
      return false;
    }
  }

  Future<bool> declineRisk(String id) async {
    try {
      await _dio.post('/files/$id/decline-risk');
      await fetchFiles(); // Refresh to get updated status
      NotificationService().success(
        "File remains risky but is now accessible.",
        title: "Risk Accepted",
      );
      return true;
    } catch (e) {
      debugPrint("Accept risk error: $e");
      NotificationService().error("Failed to accept risk", title: "Error");
      return false;
    }
  }

  Future<String?> downloadFile(String id, String filename) async {
    try {
      // Show downloading notification
      NotificationService().info(
        "Downloading $filename...",
        title: "Please Wait",
      );

      if (kIsWeb) {
        await _downloadForWeb(id, filename);
        NotificationService().success(
          "File download started",
          title: "Download Complete",
        );
        return "web_download";
      }

      // Check file extension to determine if it's an image
      final ext = filename.split('.').last.toLowerCase();
      final isImage = [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'bmp',
      ].contains(ext);

      // First download to temp directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$filename';

      debugPrint("Downloading file to temp: $tempPath");
      await _dio.download('/files/download/$id', tempPath);
      debugPrint("File downloaded to temp successfully");

      if (isImage) {
        // Save image to gallery
        try {
          final result = await SaverGallery.saveFile(
            filePath: tempPath,
            fileName: filename,
            androidRelativePath: "Pictures/FileVault",
            skipIfExists: false,
          );

          if (result.isSuccess) {
            NotificationService().success(
              "Image saved to Gallery",
              title: "Download Complete",
            );
            // Open the saved image
            await OpenFilex.open(tempPath);
            return tempPath;
          }
        } catch (e) {
          debugPrint("Gallery save error: $e");
        }

        // Fallback - open from temp
        NotificationService().success(
          "Image downloaded",
          title: "Download Complete",
        );
        await OpenFilex.open(tempPath);
        return tempPath;
      } else {
        // For documents - download and open directly
        NotificationService().success(
          "Opening file...",
          title: "Download Complete",
        );

        // Open the file with system default app
        final result = await OpenFilex.open(tempPath);

        if (result.type == ResultType.done) {
          return tempPath;
        } else if (result.type == ResultType.noAppToOpen) {
          NotificationService().warning(
            "No app available to open this file type. File saved to temp folder.",
            title: "Cannot Open",
          );
        }

        return tempPath;
      }
    } catch (e) {
      debugPrint("Download file error: $e");
      NotificationService().error(
        "Failed to download file: ${e.toString()}",
        title: "Download Error",
      );
      return null;
    }
  }

  /// Share file - downloads to temp then opens share menu to save anywhere
  Future<bool> shareFile(String id, String filename) async {
    try {
      if (kIsWeb) {
        await _downloadForWeb(id, filename);
        return true;
      }

      // Download to temp directory first
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$filename';

      debugPrint("Downloading file for sharing: $tempPath");
      await _dio.download('/files/download/$id', tempPath);

      // Share the file - user can choose to save it anywhere
      await Share.shareXFiles([XFile(tempPath)], text: 'Save $filename');

      return true;
    } catch (e) {
      debugPrint("Share file error: $e");
      NotificationService().error(
        "Failed to share file: ${e.toString()}",
        title: "Share Error",
      );
      return false;
    }
  }

  /// Opens a file by downloading it first and then opening with system default app
  Future<bool> openFile(String id, String filename) async {
    try {
      if (kIsWeb) {
        // On web, "opening" is essentially downloading/viewing in browser
        NotificationService().info(
          "Opening file in browser...",
          title: "Please Wait",
        );
        await _downloadForWeb(id, filename);
        return true;
      }

      // Show downloading notification
      NotificationService().info(
        "Downloading $filename...",
        title: "Please Wait",
      );

      // Get temp directory to store the file temporarily
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';

      // Download the file
      await _dio.download('/files/download/$id', filePath);

      // Open the file with system default application
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done) {
        // If can't open, show error with reason
        String errorMessage = 'Cannot open this file type';
        if (result.type == ResultType.noAppToOpen) {
          errorMessage = 'No app available to open this file type';
        } else if (result.type == ResultType.fileNotFound) {
          errorMessage = 'File not found';
        } else if (result.type == ResultType.permissionDenied) {
          errorMessage = 'Permission denied to open file';
        }

        NotificationService().error(errorMessage, title: "Cannot Open File");
        return false;
      }

      // Show success notification
      NotificationService().success(
        "$filename opened successfully",
        title: "File Opened",
      );
      return true;
    } catch (e) {
      debugPrint("Open file error: $e");
      NotificationService().error(
        "Failed to open file: ${e.toString()}",
        title: "Open Error",
      );
      return false;
    }
  }

  Future<void> _downloadForWeb(String id, String filename) async {
    final response = await _dio.get(
      '/files/download/$id',
      options: Options(responseType: ResponseType.bytes),
    );
    final blob = html.Blob([response.data]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void clearData() {
    _files.clear();
    notifyListeners();
  }
}
