import 'package:flutter/material.dart';
import 'package:file_stroage_system/core/services/notification_service.dart';
import 'package:file_stroage_system/core/presentation/widgets/app_toast.dart'; // Add this import
import 'dart:async';

class NotificationListenerWidget extends StatefulWidget {
  final Widget child;

  const NotificationListenerWidget({super.key, required this.child});

  @override
  _NotificationListenerWidgetState createState() =>
      _NotificationListenerWidgetState();
}

class _NotificationListenerWidgetState
    extends State<NotificationListenerWidget> {
  StreamSubscription<NotificationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = NotificationService().stream.listen((event) {
      if (mounted) {
        _showSnackBar(event);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _showSnackBar(NotificationEvent event) {
    // Map NotificationType to ToastType
    ToastType type;
    switch (event.type) {
      case NotificationType.error:
        type = ToastType.error;
        break;
      case NotificationType.warning:
        type = ToastType.warning;
        break;
      case NotificationType.success:
        type = ToastType.success;
        break;
      case NotificationType.info:
        type = ToastType.info;
        break;
    }

    AppToast.show(
      context,
      message: event.message,
      type: type,
      duration: event.duration ?? const Duration(seconds: 3),
      title: event.title,
      actionLabel: event.onUndo != null ? 'UNDO' : null,
      onAction: event.onUndo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
