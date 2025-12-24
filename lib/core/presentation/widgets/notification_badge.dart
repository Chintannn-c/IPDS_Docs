import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_stroage_system/core/controllers/notification_controller.dart';

class NotificationBadge extends StatelessWidget {
  final VoidCallback onTap;

  const NotificationBadge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NotificationController());

    return Obx(() {
      final count = controller.unreadCount.value;
      final hasUnread = count > 0;

      return Stack(
        children: [
          IconButton(
            icon: Icon(
              hasUnread
                  ? Icons.notifications_active
                  : Icons.notifications_outlined,
              color: Colors.white,
            ),
            onPressed: onTap,
          ),
          if (hasUnread)
            Positioned(
              right: 8,
              top: 8,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444), // Red-500
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    });
  }
}
