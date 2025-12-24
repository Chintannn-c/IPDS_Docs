import 'package:flutter/material.dart';
import 'chat_sidebar.dart';
import 'chat_message_bubble.dart';
import 'chat_input_bar.dart';

class AIChatPage extends StatelessWidget {
  const AIChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          const ChatSidebar(),

          Expanded(
            child: Column(
              children: [
                _ChatHeader(),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return ChatMessageBubble(
                        isUser: index.isEven,
                        message: index.isEven
                            ? "Uploaded a PDF document"
                            : "Here is a summary of the uploaded document...",
                      );
                    },
                  ),
                ),

                const ChatInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: const Row(
        children: [
          Icon(Icons.smart_toy_outlined),
          SizedBox(width: 10),
          Text(
            "IPDS AI Assistant",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
