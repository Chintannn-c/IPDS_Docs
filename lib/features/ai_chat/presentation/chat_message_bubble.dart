import 'package:flutter/material.dart';

class ChatMessageBubble extends StatelessWidget {
  final bool isUser;
  final String message;

  const ChatMessageBubble({
    super.key,
    required this.isUser,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Text(
          message,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
