import 'package:file_stroage_system/core/api/api_client.dart';
import 'package:file_stroage_system/core/services/notification_service.dart';
import 'package:file_stroage_system/features/items/data/item_model.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class ItemsProvider extends ChangeNotifier {
  final Dio _dio = ApiClient().dio;

  List<Item> _items = [];
  bool _isLoading = false;

  List<Item> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> fetchItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _dio.get('/items/');
      final List<dynamic> data = response.data;
      _items = data.map((json) => Item.fromJson(json)).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return;
      debugPrint('Fetch Items Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addItem(
    String name,
    String description, {
    String type = 'text',
    bool? isSummarized,
    String? summaryParagraph,
    String? originalContent,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> data = {
        'name': name,
        'description': description,
        'type': type,
      };
      if (isSummarized != null) {
        data['is_summarized'] = isSummarized;
      }
      if (summaryParagraph != null) {
        data['summary_paragraph'] = summaryParagraph;
      }
      if (originalContent != null) {
        data['original_content'] = originalContent;
      }

      final response = await _dio.post('/items/', data: data);
      final newItem = Item.fromJson(response.data);
      _items.add(newItem);
      NotificationService().success("Item added successfully");
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return false;

      debugPrint('Add Item Error: $e');
      NotificationService().error("Failed to add item");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateItem(
    String id,
    String name,
    String description,
    String type, {
    bool? isSummarized,
    String? summaryParagraph,
    List<String>? bulletPoints,
    List<String>? keywords,
    String? originalContent,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> data = {
        'name': name,
        'description': description,
        'type': type,
      };
      if (isSummarized != null) {
        data['is_summarized'] = isSummarized;
      }
      if (summaryParagraph != null) {
        data['summary_paragraph'] = summaryParagraph;
      }
      if (bulletPoints != null) {
        data['bullet_points'] = bulletPoints;
      }
      if (keywords != null) {
        data['keywords'] = keywords;
      }
      if (originalContent != null) {
        data['original_content'] = originalContent;
      }

      final response = await _dio.put('/items/$id', data: data);
      final updatedItem = Item.fromJson(response.data);
      final index = _items.indexWhere((item) => item.id == id);
      if (index != -1) {
        _items[index] = updatedItem;
      }
      NotificationService().success("Item updated successfully");
      return true;
    } on DioException catch (e) {
      debugPrint('Update Item Error: $e');
      NotificationService().error("Failed to update item");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteItem(String id) async {
    try {
      await _dio.delete('/items/$id');
      _items.removeWhere((item) => item.id == id);
      NotificationService().success("Item deleted");
      notifyListeners();
      return true;
    } on DioException catch (e) {
      debugPrint('Delete Item Error: $e');
      NotificationService().error("Failed to delete item");
      return false;
    }
  }
}
