import 'package:flutter/material.dart';

/// Toast notification types
enum ToastType { success, error, warning, info }

/// Custom toast/snackbar utility for consistent notifications across the app
class AppToast {
  /// Show a styled toast notification
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration? duration,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final config = _getConfig(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            // Icon with background
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(config.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),

            // Message
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? config.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: config.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration ?? const Duration(seconds: 3),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  /// Show success toast
  /// Show success toast
  static void success(
    BuildContext context,
    String message, {
    Duration? duration,
    String? title,
  }) {
    show(
      context,
      message: message,
      type: ToastType.success,
      duration: duration,
      title: title,
    );
  }

  /// Show error toast
  static void error(
    BuildContext context,
    String message, {
    Duration? duration,
    String? title,
  }) {
    show(
      context,
      message: message,
      type: ToastType.error,
      duration: duration,
      title: title,
    );
  }

  /// Show warning toast
  static void warning(
    BuildContext context,
    String message, {
    Duration? duration,
    String? title,
  }) {
    show(
      context,
      message: message,
      type: ToastType.warning,
      duration: duration,
      title: title,
    );
  }

  /// Show info toast
  static void info(
    BuildContext context,
    String message, {
    Duration? duration,
    String? title,
  }) {
    show(
      context,
      message: message,
      type: ToastType.info,
      duration: duration,
      title: title,
    );
  }

  static _ToastConfig _getConfig(ToastType type) {
    switch (type) {
      case ToastType.success:
        return _ToastConfig(
          title: 'Success',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF059669), // Emerald
        );
      case ToastType.error:
        return _ToastConfig(
          title: 'Error',
          icon: Icons.error_rounded,
          color: const Color(0xFFDC2626), // Red
        );
      case ToastType.warning:
        return _ToastConfig(
          title: 'Warning',
          icon: Icons.warning_rounded,
          color: const Color(0xFFF59E0B), // Amber
        );
      case ToastType.info:
        return _ToastConfig(
          title: 'Info',
          icon: Icons.info_rounded,
          color: const Color(0xFF3B82F6), // Blue
        );
    }
  }
}

class _ToastConfig {
  final String title;
  final IconData icon;
  final Color color;

  _ToastConfig({required this.title, required this.icon, required this.color});
}
