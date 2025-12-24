import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class TimeProvider extends ChangeNotifier {
  DateTime _now = DateTime.now();
  Timer? _timer;

  DateTime get now => _now;

  TimeProvider() {
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _now = DateTime.now();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(dateTime.toLocal());
  }

  String getTimeAgo(DateTime dateTime) {
    final difference = _now.difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    if (difference.inSeconds > 10) return '${difference.inSeconds}s ago';
    return 'Just now';
  }
}
